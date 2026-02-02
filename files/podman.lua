-- Podman metrics collector for prometheus-node-exporter-lua
-- Collects container, pod, image, network, volume, and system metrics

local cjson = require "cjson"
local curl = require "lcurl"
local nixio = require "nixio"

-- Podman API socket path
local SOCKET_PATH = "/run/podman/podman.sock"
local API_BASE = "http://d/v5.0.0/libpod"
local PODMAN_API_TIMEOUT = 120

-- Check if file/socket exists using nixio
local function file_exists(path)
  local stat = nixio.fs.stat(path)
  return stat ~= nil
end

-- Query Podman API via unix socket using lua-curl
local function podman_api(endpoint)
  local response = {}
  local c = curl.easy()

  c:setopt(curl.OPT_UNIX_SOCKET_PATH, SOCKET_PATH)
  c:setopt(curl.OPT_URL, API_BASE .. endpoint)
  c:setopt(curl.OPT_TIMEOUT, PODMAN_API_TIMEOUT)
  c:setopt_writefunction(function(data)
    table.insert(response, data)
    return #data
  end)

  local ok, err = pcall(function()
    c:perform()
  end)
  c:close()

  if not ok then
    return nil
  end

  local body = table.concat(response)
  if not body or body == "" then
    return nil
  end

  local success, result = pcall(cjson.decode, body)
  if not success then
    return nil
  end

  return result
end

-- Convert timestamp to unix timestamp (handles both ISO 8601 strings and unix timestamps)
local function parse_timestamp(ts)
  if not ts then
    return 0
  end
  -- Already a number (unix timestamp)
  if type(ts) == "number" then
    return ts
  end
  -- Empty string
  if ts == "" then
    return 0
  end
  -- Handle format: 2024-01-15T10:30:00.123456789Z or with timezone
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = ts:match(pattern)
  if not year then
    return 0
  end
  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
end

-- Map container state string to numeric value
local function container_state_value(state)
  local states = {
    unknown = -1,
    created = 0,
    initialized = 1,
    running = 2,
    stopped = 3,
    paused = 4,
    exited = 5,
    removing = 6,
    stopping = 7
  }
  return states[string.lower(state or "")] or -1
end

-- Map pod state string to numeric value
local function pod_state_value(state)
  local states = {
    unknown = -1,
    created = 0,
    error = 1,
    exited = 2,
    paused = 3,
    running = 4,
    degraded = 5,
    stopped = 6
  }
  return states[string.lower(state or "")] or -1
end

-- Format port mappings as string
local function format_ports(ports)
  if type(ports) ~= "table" or #ports == 0 then
    return ""
  end
  local result = {}
  for _, p in ipairs(ports) do
    local host_ip = p.host_ip or "0.0.0.0"
    local host_port = p.host_port or ""
    local container_port = p.container_port or ""
    local protocol = p.protocol or "tcp"
    if host_port ~= "" and container_port ~= "" then
      table.insert(result, string.format("%s:%s->%s/%s", host_ip, host_port, container_port, protocol))
    end
  end
  return table.concat(result, ",")
end

-- Scrape container metrics
local function scrape_containers()
  local containers = podman_api("/containers/json?all=true")
  if not containers then
    return
  end

  local info_metric = metric("podman_container_info", "gauge")
  local state_metric = metric("podman_container_state", "gauge")
  local created_metric = metric("podman_container_created_seconds", "gauge")
  local started_metric = metric("podman_container_started_seconds", "gauge")
  local exited_metric = metric("podman_container_exited_seconds", "gauge")
  local exit_code_metric = metric("podman_container_exit_code", "gauge")
  local restarts_metric = metric("podman_container_restarts_total", "counter")

  for _, c in ipairs(containers) do
    local id = c.Id and c.Id:sub(1, 12) or ""
    local name = ""
    if type(c.Names) == "table" and #c.Names > 0 then
      name = c.Names[1]:gsub("^/", "")
    end
    local image = c.Image or ""
    local pod_id = c.PodName and c.PodName ~= "" and (c.Pod or ""):sub(1, 12) or ""
    local pod_name = c.PodName or ""
    local ports = format_ports(c.Ports)
    local state = c.State or "unknown"
    local created = parse_timestamp(c.Created)
    local started = parse_timestamp(c.StartedAt)
    local exited = parse_timestamp(c.ExitedAt)
    local exit_code = c.ExitCode or 0
    local restarts = c.Restarts or 0

    local labels = {
      id = id,
      pod_id = pod_id,
      pod_name = pod_name
    }

    -- Container info
    info_metric({
      id = id,
      name = name,
      image = image,
      pod_id = pod_id,
      pod_name = pod_name,
      ports = ports
    }, 1)

    -- Container state
    state_metric(labels, container_state_value(state))

    -- Container created time
    created_metric(labels, created)

    -- Container started time (0 if never started)
    started_metric(labels, started)

    -- Container exited time (0 if never exited)
    exited_metric(labels, exited)

    -- Container exit code (only meaningful for exited containers)
    exit_code_metric(labels, exit_code)

    -- Container restart count
    restarts_metric(labels, restarts)
  end
end

-- Scrape pod metrics
local function scrape_pods()
  local pods = podman_api("/pods/json")
  if not pods then
    return
  end

  local info_metric = metric("podman_pod_info", "gauge")
  local state_metric = metric("podman_pod_state", "gauge")
  local containers_metric = metric("podman_pod_containers", "gauge")
  local created_metric = metric("podman_pod_created_seconds", "gauge")

  for _, p in ipairs(pods) do
    local id = p.Id and p.Id:sub(1, 12) or ""
    local name = p.Name or ""
    local infra_id = p.InfraId and p.InfraId:sub(1, 12) or ""
    local state = p.Status or "unknown"
    local num_containers = 0
    if type(p.Containers) == "table" then
      num_containers = #p.Containers
    end
    local created = parse_timestamp(p.Created)

    -- Pod info
    info_metric({
      id = id,
      name = name,
      infra_id = infra_id
    }, 1)

    -- Pod state
    state_metric({id = id}, pod_state_value(state))

    -- Pod container count
    containers_metric({id = id}, num_containers)

    -- Pod created time
    created_metric({id = id}, created)
  end
end

-- Scrape image metrics
local function scrape_images()
  local images = podman_api("/images/json")
  if not images then
    return
  end

  local info_metric = metric("podman_image_info", "gauge")
  local created_metric = metric("podman_image_created_seconds", "gauge")
  local size_metric = metric("podman_image_size", "gauge")

  for _, img in ipairs(images) do
    local id = img.Id and img.Id:sub(1, 12) or ""
    -- Remove sha256: prefix if present
    if id:sub(1, 7) == "sha256:" then
      id = id:sub(8, 19)
    end
    local parent_id = img.ParentId and img.ParentId:sub(1, 12) or ""
    if parent_id:sub(1, 7) == "sha256:" then
      parent_id = parent_id:sub(8, 19)
    end
    local size = img.Size or 0
    local created = parse_timestamp(img.Created)

    -- Handle RepoTags - may have multiple tags per image
    local repo_tags = type(img.RepoTags) == "table" and img.RepoTags or {"<none>:<none>"}
    for _, tag in ipairs(repo_tags) do
      local repository, tag_name = tag:match("(.+):(.+)")
      if not repository then
        repository = tag
        tag_name = "<none>"
      end

      -- Get digest
      local digest = ""
      if type(img.RepoDigests) == "table" and #img.RepoDigests > 0 then
        digest = img.RepoDigests[1]:match("@(.+)") or img.RepoDigests[1]
      end

      -- Image info
      info_metric({
        id = id,
        parent_id = parent_id,
        repository = repository,
        tag = tag_name,
        digest = digest
      }, 1)

      -- Image created time
      created_metric({
        id = id,
        repository = repository,
        tag = tag_name
      }, created)

      -- Image size
      size_metric({
        id = id,
        repository = repository,
        tag = tag_name
      }, size)
    end
  end
end

-- Scrape network metrics
local function scrape_networks()
  local networks = podman_api("/networks/json")
  if not networks then
    return
  end

  local info_metric = metric("podman_network_info", "gauge")

  for _, net in ipairs(networks) do
    local id = net.Id and net.Id:sub(1, 12) or net.id and net.id:sub(1, 12) or ""
    local name = net.Name or net.name or ""
    local driver = net.Driver or net.driver or ""
    local interface = net.NetworkInterface or net.network_interface or ""
    local labels = ""
    if type(net.Labels) == "table" then
      local label_parts = {}
      for k, v in pairs(net.Labels) do
        table.insert(label_parts, k .. "=" .. v)
      end
      labels = table.concat(label_parts, ",")
    end

    info_metric({
      id = id,
      name = name,
      driver = driver,
      interface = interface,
      labels = labels
    }, 1)
  end
end

-- Scrape volume metrics
local function scrape_volumes()
  local volumes = podman_api("/volumes/json")
  if not volumes then
    return
  end

  local info_metric = metric("podman_volume_info", "gauge")
  local created_metric = metric("podman_volume_created_seconds", "gauge")

  for _, vol in ipairs(volumes) do
    local name = vol.Name or ""
    local driver = vol.Driver or "local"
    local mount_point = vol.Mountpoint or ""
    local created = parse_timestamp(vol.CreatedAt)

    -- Volume info
    info_metric({
      name = name,
      driver = driver,
      mount_point = mount_point
    }, 1)

    -- Volume created time
    created_metric({name = name}, created)
  end
end

-- Scrape system/version metrics
local function scrape_system()
  local version = podman_api("/version")
  if not version then
    return
  end

  -- API version
  if version.ApiVersion then
    metric("podman_system_api_version", "gauge", {version = version.ApiVersion}, 1)
  end

  -- Podman version
  if version.Version then
    metric("podman_system_version", "gauge", {version = version.Version}, 1)
  end

  -- Get additional info from /info endpoint
  local info = podman_api("/info")
  if info then
    -- Buildah version
    if info.version and info.version.buildahVersion then
      metric("podman_system_buildah_version", "gauge",
        {version = info.version.buildahVersion}, 1)
    end

    -- Conmon version
    if info.host and info.host.conmon and info.host.conmon.version then
      metric("podman_system_conmon_version", "gauge",
        {version = info.host.conmon.version}, 1)
    end

    -- OCI runtime version
    if info.host and info.host.ociRuntime and info.host.ociRuntime.version then
      metric("podman_system_runtime_version", "gauge",
        {version = info.host.ociRuntime.version}, 1)
    end
  end
end

-- Main scrape function called by prometheus-node-exporter-lua
local function scrape()
  -- Check if Podman socket exists
  if not file_exists(SOCKET_PATH) then
    return
  end

  scrape_containers()
  scrape_pods()
  scrape_images()
  scrape_networks()
  scrape_volumes()
  scrape_system()
end

return { scrape = scrape }
