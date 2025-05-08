# Docker .NET Build Runner Monitoring and Optimization

This repository contains a comprehensive solution for monitoring and optimizing Docker containers used for building .NET applications. It focuses on resource monitoring, performance optimization, and automatic remediation of common issues that affect .NET build performance in Docker environments.

## Table of Contents

- [Overview](#overview)
- [Components](#components)
- [Installation](#installation)
- [Usage](#usage)
- [Alert Rules](#alert-rules)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Contributing](#contributing)

## Overview

Docker containers are commonly used for building .NET applications in CI/CD pipelines and development environments. However, they can encounter resource issues that impact build performance, such as:

- High CPU or memory usage leading to slow builds
- Inefficient caching of NuGet packages and build artifacts
- Disk space issues affecting Docker layer caching
- Resource contention between concurrent builds

This solution provides tools to monitor, detect, and resolve these issues, ensuring optimal performance of your Docker .NET build runners.

## Components

This solution consists of the following components:

1. **cAdvisor Setup Script** (`cadvisor-setup.sh`): Sets up container monitoring with cAdvisor to collect metrics from Docker containers.

2. **Prometheus Alert Rules** (`dotnet-docker-alerts.yml`): Specialized alerts for detecting .NET build performance issues in Docker environments.

3. **Resource Management Script** (`dotnet-docker-fix.sh`): A Linux-compatible script for diagnosing and fixing Docker resource issues with .NET build containers.

4. **Optimized Docker Composition** (`docker-compose.yml`): A Docker Compose configuration optimized for .NET builds with proper caching and resource management.

## Installation

### Prerequisites

- Linux server running Docker
- Prometheus monitoring system
- Alertmanager (optional, for notifications)
- Existing node_exporter and process_exporter (assumed to be already installed)

### Step 1: Set up Container Monitoring with cAdvisor

```bash
# Make the script executable
chmod +x cadvisor-setup.sh

# Run the setup script
./cadvisor-setup.sh
```

This script will:
- Install cAdvisor as a systemd service
- Configure the necessary volume mounts
- Offer to add cAdvisor as a Prometheus target
- Start the cAdvisor service

### Step 2: Configure Prometheus Alert Rules

1. Save the `dotnet-docker-alerts.yml` file to your Prometheus configuration directory.

2. Add the rules file to your Prometheus configuration:

```yaml
# In prometheus.yml
rule_files:
  - "/path/to/dotnet-docker-alerts.yml"
```

3. Restart Prometheus to apply the changes:

```bash
sudo systemctl restart prometheus
```

### Step 3: Prepare the Resource Management Script

```bash
# Make the script executable
chmod +x dotnet-docker-fix.sh

# Verify it works correctly
./dotnet-docker-fix.sh stats
```

### Step 4: Set Up Optimized Docker Composition

```bash
# Create the persistent NuGet cache volume
docker volume create nuget-cache

# Verify the docker-compose.yml file works
docker-compose config
```

## Usage

### Monitoring Docker .NET Build Containers

To check the current resource usage of your Docker .NET build containers:

```bash
./dotnet-docker-fix.sh stats
```

This will show:
- Container CPU and memory usage
- Host system resource usage
- Active .NET build processes
- Docker daemon resource usage
- .NET build cache status

### Cleaning Up Docker Resources

To clean up unnecessary Docker resources related to .NET builds:

```bash
./dotnet-docker-fix.sh clean
```

This will:
- Remove stopped .NET build containers
- Remove dangling build images
- Check for and optionally remove unused .NET SDK images
- Clean the .NET local build cache

### Optimizing Docker for .NET Builds

To optimize your Docker environment specifically for .NET builds:

```bash
./dotnet-docker-fix.sh optimize
```

This will:
- Set up a persistent .NET build cache volume
- Create an optimized .NET build image with layer caching
- Configure Docker daemon for better performance
- Provide guidance on using the optimized setup

### Running .NET Builds with Optimized Configuration

```bash
# For regular development builds
docker-compose up dotnet-builder

# For CI/CD builds with higher resource allocations
docker-compose --profile ci up dotnet-ci-builder
```

### Fixing All Issues Automatically

To perform all remediation steps at once:

```bash
./dotnet-docker-fix.sh fix-all
```

This comprehensive fix will:
1. Check current resource usage
2. Clean up Docker resources
3. Optimize for .NET builds
4. Prune the Docker system
5. Restart the Docker service
6. Verify the fixes with a final stats check

## Alert Rules

The Prometheus alert rules in `dotnet-docker-alerts.yml` are specifically designed to detect issues that affect .NET build performance in Docker containers. Here are the key alerts:

### Container Resource Alerts

- **DotNetBuildHighCpuUsage**: Triggers when a .NET build container uses >90% CPU for more than 2 minutes
- **DotNetBuildHighMemoryUsage**: Triggers when a .NET build container uses >85% of its memory limit
- **DotNetBuildHighDiskUsage**: Triggers when a .NET build container uses >80% of its disk space

### Build Performance Alerts

- **DotNetBuildSlowPerformance**: Detects when .NET builds are running slower than expected
- **DotNetBuildTooManyProcesses**: Alerts when too many concurrent .NET build processes are running
- **NuGetPackageCacheHeavyUsage**: Identifies inefficient NuGet package caching operations
- **DotNetBuildCacheInefficient**: Detects inefficient MSBuild caching

### Host Resource Alerts

- **DockerHostSwapUsageHigh**: Alerts when the Docker host is using excessive swap space
- **DockerHostHighDiskIO**: Alerts when high disk I/O might be affecting build performance

## Troubleshooting

### Common Issues and Solutions

#### Slow .NET Builds

If your .NET builds are running slower than expected:

1. Check for resource contention:
   ```bash
   ./dotnet-docker-fix.sh stats
   ```

2. Optimize Docker for .NET builds:
   ```bash
   ./dotnet-docker-fix.sh optimize
   ```

3. Ensure you're using the persistent NuGet cache:
   ```bash
   docker volume inspect nuget-cache
   ```

#### Out of Disk Space

If you're running out of disk space:

```bash
# Clean up unused Docker resources
./dotnet-docker-fix.sh clean

# Deep clean the Docker system
./dotnet-docker-fix.sh prune
```

#### Docker Container Crashes

If your .NET build containers are crashing:

1. Check the container logs:
   ```bash
   docker logs <container_name>
   ```

2. Verify resource limits are appropriate:
   ```bash
   docker inspect <container_name> | grep -A 20 "HostConfig"
   ```

3. Restart the Docker service:
   ```bash
   ./dotnet-docker-fix.sh restart
   ```

## Best Practices

### Optimizing .NET Docker Builds

1. **Use Multi-Stage Builds**: Reduce final image size and improve build caching.

2. **Create a .dockerignore File**: Exclude unnecessary files:
   ```
   # .dockerignore example
   **/bin/
   **/obj/
   **/node_modules/
   **/.git/
   **/.vs/
   ```

3. **Optimize Layer Caching**:
   - Copy project files first, then restore
   - Copy source code after restore
   - Build after copying all files

4. **Use BuildKit**:
   ```bash
   export DOCKER_BUILDKIT=1
   ```

5. **Limit Resource Usage**:
   - Set appropriate resource limits in docker-compose.yml
   - Monitor resource usage regularly

6. **Persistent Cache Volumes**:
   - Always use named volumes for NuGet packages
   - Consider using host mounts for better performance

### Monitoring Best Practices

1. **Regular Monitoring**: Check resource usage at least once per day.

2. **Alert Thresholds**: Adjust alert thresholds based on your specific environment.

3. **Historical Data**: Keep historical metrics to identify performance trends.

4. **Preventative Maintenance**: Run cleanup scripts regularly as part of scheduled maintenance.
