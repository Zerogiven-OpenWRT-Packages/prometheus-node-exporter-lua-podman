-- Podman per-container metrics collector for prometheus-node-exporter-lua
-- Collects CPU, memory, block I/O, network, and PID stats per container
-- Note: This requires one API call per running container

local cjson = require "cjson"
local curl = require "lcurl"
local nixio = require "nixio"

-- Podman API socket path
local SOCKET_PATH = "/run/podman/podman.sock"
local API_BASE = "http://d/v5.0.0/libpod"

-- Check if socket exists using nixio
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
  c:setopt(curl.OPT_TIMEOUT, 120)
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

-- Extract block I/O stats (read/write bytes)
local function get_blkio_bytes(blkio_stats, op)
  if type(blkio_stats) ~= "table" then
    return 0
  end
  local ios = blkio_stats.io_service_bytes_recursive
  if type(ios) ~= "table" then
    return 0
  end
  local total = 0
  for _, entry in ipairs(ios) do
    if entry.op == op then
      total = total + (entry.value or 0)
    end
  end
  return total
end

-- Sum network stats across all interfaces
local function sum_network_stats(networks, field)
  if type(networks) ~= "table" then
    return 0
  end
  local total = 0
  for _, iface in pairs(networks) do
    if type(iface) == "table" and iface[field] then
      total = total + iface[field]
    end
  end
  return total
end

-- Scrape per-container stats
local function scrape()
  -- Check if Podman socket exists
  if not file_exists(SOCKET_PATH) then
    return
  end

  -- Get list of running containers
  local containers = podman_api("/containers/json")
  if not containers then
    return
  end

  -- Define metrics
  local cpu_total = metric("podman_container_cpu_seconds_total", "counter")
  local cpu_system = metric("podman_container_cpu_system_seconds_total", "counter")
  local mem_usage = metric("podman_container_mem_usage_bytes", "gauge")
  local mem_limit = metric("podman_container_mem_limit_bytes", "gauge")
  local pids = metric("podman_container_pids", "gauge")
  local block_input = metric("podman_container_block_input_total", "counter")
  local block_output = metric("podman_container_block_output_total", "counter")
  local net_rx_bytes = metric("podman_container_net_input_total", "counter")
  local net_tx_bytes = metric("podman_container_net_output_total", "counter")
  local net_rx_packets = metric("podman_container_net_input_packets_total", "counter")
  local net_tx_packets = metric("podman_container_net_output_packets_total", "counter")
  local net_rx_dropped = metric("podman_container_net_input_dropped_total", "counter")
  local net_tx_dropped = metric("podman_container_net_output_dropped_total", "counter")
  local net_rx_errors = metric("podman_container_net_input_errors_total", "counter")
  local net_tx_errors = metric("podman_container_net_output_errors_total", "counter")

  for _, c in ipairs(containers) do
    -- Only get stats for running containers
    if c.State == "running" then
      local id = c.Id or ""
      local short_id = id:sub(1, 12)
      local name = ""
      if type(c.Names) == "table" and #c.Names > 0 then
        name = c.Names[1]:gsub("^/", "")
      end
      local pod_id = c.PodName and c.PodName ~= "" and (c.Pod or ""):sub(1, 12) or ""
      local pod_name = c.PodName or ""

      local labels = {
        id = short_id,
        name = name,
        pod_id = pod_id,
        pod_name = pod_name
      }

      -- Get stats for this container
      local stats = podman_api("/containers/" .. id .. "/stats?stream=false")
      if stats then
        -- CPU stats (convert nanoseconds to seconds)
        if type(stats.cpu_stats) == "table" and type(stats.cpu_stats.cpu_usage) == "table" then
          local total_ns = stats.cpu_stats.cpu_usage.total_usage or 0
          local system_ns = stats.cpu_stats.cpu_usage.usage_in_kernelmode or 0
          cpu_total(labels, total_ns / 1e9)
          cpu_system(labels, system_ns / 1e9)
        end

        -- Memory stats
        if type(stats.memory_stats) == "table" then
          mem_usage(labels, stats.memory_stats.usage or 0)
          mem_limit(labels, stats.memory_stats.limit or 0)
        end

        -- PID stats
        if type(stats.pids_stats) == "table" then
          pids(labels, stats.pids_stats.current or 0)
        end

        -- Block I/O stats
        block_input(labels, get_blkio_bytes(stats.blkio_stats, "read"))
        block_output(labels, get_blkio_bytes(stats.blkio_stats, "write"))

        -- Network stats
        net_rx_bytes(labels, sum_network_stats(stats.networks, "rx_bytes"))
        net_tx_bytes(labels, sum_network_stats(stats.networks, "tx_bytes"))
        net_rx_packets(labels, sum_network_stats(stats.networks, "rx_packets"))
        net_tx_packets(labels, sum_network_stats(stats.networks, "tx_packets"))
        net_rx_dropped(labels, sum_network_stats(stats.networks, "rx_dropped"))
        net_tx_dropped(labels, sum_network_stats(stats.networks, "tx_dropped"))
        net_rx_errors(labels, sum_network_stats(stats.networks, "rx_errors"))
        net_tx_errors(labels, sum_network_stats(stats.networks, "tx_errors"))
      end
    end
  end
end

return { scrape = scrape }
