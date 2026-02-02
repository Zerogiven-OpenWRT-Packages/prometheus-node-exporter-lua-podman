[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10.x-darkgreen.svg)](https://openwrt.org/)
[![GitHub Release](https://img.shields.io/github/v/release/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman)](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman/releases)
[![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman/total?color=blue)](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman/releases)
[![GitHub Issues or Pull Requests](https://img.shields.io/github/issues/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman)](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman/issues)

# Prometheus Node Exporter Podman

Prometheus metrics collectors for Podman containers on OpenWrt, designed for use with `prometheus-node-exporter-lua`.

## Table of Contents

- [Features](#features)
- [Packages](#packages)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Metrics Reference](#metrics-reference)
- [Credits](#credits)

## Features

- **Container Metrics**: State, info, timestamps, exit codes, restart counts
- **Pod Metrics**: State, container counts, metadata
- **Image Metrics**: Size, creation time, metadata
- **Network & Volume Metrics**: Configuration and metadata
- **System Metrics**: Podman version, API version, runtime info
- **Per-Container Stats**: CPU, memory, network I/O, block I/O, PIDs
- **Low Overhead**: Optimized API calls (~300ms basic, ~200ms stats)
- **Native Unix Socket**: Direct communication via `/run/podman/podman.sock`

## Packages

| Package | Overhead | Description |
|---------|----------|-------------|
| `prometheus-node-exporter-lua-podman` | ~300ms | Basic metrics for containers, pods, images, networks, volumes, system |
| `prometheus-node-exporter-lua-podman-container` | ~200ms | Per-container resource stats (CPU, memory, network, block I/O) |

## Requirements

- OpenWrt 24.10.x
- Podman with API socket enabled
- `prometheus-node-exporter-lua`

## Installation

### From Package Feed

You can setup the package feed to install and update with opkg:

[https://github.com/Zerogiven-OpenWRT-Packages/package-feed](https://github.com/Zerogiven-OpenWRT-Packages/package-feed)

### From IPK Package

Download from the [Releases](https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman/releases) page:

```bash
opkg update
opkg install prometheus-node-exporter-lua-podman_*.ipk
opkg install prometheus-node-exporter-lua-podman-container_*.ipk
```

### From Source

```bash
git clone https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman.git package/prometheus-node-exporter-lua-podman
make menuconfig  # Navigate to: Utilities → prometheus-node-exporter-lua-podman
make package/prometheus-node-exporter-lua-podman/compile V=s
```

## Usage

After installation, the collectors are automatically available. Ensure Podman is running:

```bash
/etc/init.d/podman start
/etc/init.d/podman enable
```

Metrics are available at the standard node exporter endpoint:

```
http://your-router-ip:9100/metrics
```

### Prometheus Configuration

If collectors don't appear in the default scrape, explicitly request them:

```yaml
scrape_configs:
  - job_name: 'openwrt'
    params:
      collect:
        - podman
        - podman-container
    static_configs:
      - targets: ['router:9100']
```

## Metrics Reference

### Basic Package (`podman.lua`)

#### Container Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `podman_container_info` | gauge | Container metadata (image, name, id, ports, pod) |
| `podman_container_state` | gauge | Container state as numeric value |
| `podman_container_created_seconds` | gauge | Container creation timestamp |
| `podman_container_started_seconds` | gauge | Container start timestamp |
| `podman_container_exited_seconds` | gauge | Container exit timestamp |
| `podman_container_exit_code` | gauge | Container exit code |
| `podman_container_restarts_total` | counter | Number of container restarts |

#### Pod Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `podman_pod_info` | gauge | Pod metadata |
| `podman_pod_state` | gauge | Pod state as numeric value |
| `podman_pod_containers` | gauge | Number of containers in pod |
| `podman_pod_created_seconds` | gauge | Pod creation timestamp |

#### Image, Network, Volume, System Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `podman_image_info` | gauge | Image metadata |
| `podman_image_size_bytes` | gauge | Image size |
| `podman_network_info` | gauge | Network metadata (driver, interface) |
| `podman_volume_info` | gauge | Volume metadata |
| `podman_system_api_version` | gauge | Podman API version |

### Container Stats Package (`podman-container.lua`)

| Metric | Type | Description |
|--------|------|-------------|
| `podman_container_cpu_seconds_total` | counter | CPU time consumed |
| `podman_container_cpu_system_seconds_total` | counter | System CPU time |
| `podman_container_mem_usage_bytes` | gauge | Current memory usage |
| `podman_container_mem_limit_bytes` | gauge | Memory limit |
| `podman_container_pids` | gauge | Number of processes |
| `podman_container_block_input_total` | counter | Block I/O read bytes |
| `podman_container_block_output_total` | counter | Block I/O write bytes |
| `podman_container_net_input_total` | counter | Network received bytes |
| `podman_container_net_output_total` | counter | Network transmitted bytes |

### State Mappings

Container states are mapped to numeric values for Prometheus:

| State | Value |
|-------|-------|
| unknown | -1 |
| created | 0 |
| initialized | 1 |
| running | 2 |
| stopped | 3 |
| paused | 4 |
| exited | 5 |
| removing | 6 |
| stopping | 7 |

## Credits

- [prometheus-node-exporter-lua](https://github.com/openwrt/packages/tree/master/utils/prometheus-node-exporter-lua) - OpenWrt metrics framework
- [prometheus-podman-exporter](https://github.com/containers/prometheus-podman-exporter)
- [Podman](https://podman.io/) - Container runtime
