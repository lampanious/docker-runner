#!/bin/bash

# Docker .NET Build Resource Issues Remediation Script for Linux
# Purpose: Diagnose and resolve Docker resource issues for .NET build runners
# Usage: ./dotnet-docker-fix.sh [clean|restart|prune|optimize|stats|fix-all]

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

check_docker_running() {
    if ! docker info &>/dev/null; then
        echo -e "${RED}[ERROR] Docker is not running!${NC}"
        echo -e "${YELLOW}Attempting to start Docker service...${NC}"
        sudo systemctl start docker
        sleep 5
        
        if ! docker info &>/dev/null; then
            echo -e "${RED}[FAILED] Could not start Docker service.${NC}"
            echo -e "${YELLOW}Please start Docker manually and try again.${NC}"
            exit 1
        else
            echo -e "${GREEN}[SUCCESS] Docker service started successfully.${NC}"
        fi
    fi
}

check_docker_stats() {
    print_header "Checking Docker .NET Build Container Resource Usage"
    
    echo -e "${YELLOW}--- Container CPU and Memory Usage ---${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" | grep -E "dotnet|build|NAME"
    
    echo -e "\n${YELLOW}--- Docker Host System Resource Usage ---${NC}"
    
    # Check CPU Load
    echo -e "${YELLOW}CPU Load:${NC}"
    cat /proc/loadavg | awk '{print "1 minute: " $1 ", 5 minutes: " $2 ", 15 minutes: " $3}'
    CPU_CORES=$(nproc)
    LOAD_1M=$(cat /proc/loadavg | awk '{print $1}')
    LOAD_PERCENT=$(echo "scale=2; $LOAD_1M * 100 / $CPU_CORES" | bc)
    echo -e "CPU Load percentage: ${LOAD_PERCENT}% (based on $CPU_CORES cores)"
    
    # Check Memory Usage
    echo -e "\n${YELLOW}Memory Usage:${NC}"
    free -h
    MEM_TOTAL=$(free | grep "Mem:" | awk '{print $2}')
    MEM_USED=$(free | grep "Mem:" | awk '{print $3}')
    MEM_PERCENT=$(echo "scale=2; $MEM_USED * 100 / $MEM_TOTAL" | bc)
    echo -e "Memory Usage: ${MEM_PERCENT}%"
    
    # Check Disk Usage
    echo -e "\n${YELLOW}Disk Usage:${NC}"
    df -h / /var/lib/docker
    
    # Check for .NET build processes
    echo -e "\n${YELLOW}Active .NET Build Processes:${NC}"
    ps aux | grep -E "dotnet|msbuild" | grep -v grep
    
    # Check Docker daemon resource usage
    echo -e "\n${YELLOW}Docker Service Resource Usage:${NC}"
    systemctl status docker | grep Memory
    DOCKER_PID=$(pgrep -f dockerd)
    if [ -n "$DOCKER_PID" ]; then
        echo -e "Docker daemon (PID $DOCKER_PID) resource usage:"
        ps -o pid,ppid,cmd,%mem,%cpu -p $DOCKER_PID
    fi
    
    # Check for common .NET build cache locations
    echo -e "\n${YELLOW}.NET Build Cache Status:${NC}"
    NUGET_CACHE_SIZE=$(du -sh ~/.nuget 2>/dev/null || echo "NuGet cache not found")
    echo -e "NuGet cache size: $NUGET_CACHE_SIZE"
    
    # Check for docker container caches
    echo -e "\n${YELLOW}Docker Container Cache Volumes:${NC}"
    docker volume ls | grep -E "nuget|dotnet|build"
}

cleanup_dotnet_docker() {
    print_header "Cleaning up Docker resources for .NET builds"
    
    echo -e "${YELLOW}--- Removing stopped .NET build containers ---${NC}"
    STOPPED_CONTAINERS=$(docker ps -a -f "status=exited" -f "name=dotnet" -q)
    if [ -n "$STOPPED_CONTAINERS" ]; then
        docker rm $STOPPED_CONTAINERS
        echo -e "${GREEN}Removed stopped .NET build containers.${NC}"
    else
        echo -e "No stopped .NET build containers found."
    fi
    
    echo -e "\n${YELLOW}--- Removing dangling build images ---${NC}"
    DANGLING_IMAGES=$(docker images -f "dangling=true" -q)
    if [ -n "$DANGLING_IMAGES" ]; then
        docker rmi $DANGLING_IMAGES
        echo -e "${GREEN}Removed dangling images.${NC}"
    else
        echo -e "No dangling images found."
    fi
    
    echo -e "\n${YELLOW}--- Checking for unused .NET SDK images ---${NC}"
    OLD_DOTNET_IMAGES=$(docker images | grep "dotnet" | grep -v "latest" | awk '{print $1":"$2}')
    if [ -n "$OLD_DOTNET_IMAGES" ]; then
        echo -e "Found the following older .NET SDK images:"
        docker images | grep "dotnet" | grep -v "latest"
        echo -e "\nWould you like to remove them? (y/n)"
        read -r REMOVE_OLD_IMAGES
        
        if [ "$REMOVE_OLD_IMAGES" = "y" ]; then
            docker images | grep "dotnet" | grep -v "latest" | awk '{print $1":"$2}' | xargs docker rmi
            echo -e "${GREEN}Removed old .NET SDK images.${NC}"
        fi
    else
        echo -e "No older .NET SDK images found."
    fi
    
    echo -e "\n${YELLOW}--- Cleaning .NET local build cache ---${NC}"
    if [ -d ~/.dotnet ]; then
        echo -e "Current .NET SDK cache size:"
        du -sh ~/.dotnet
        echo -e "\nWould you like to clean the .NET SDK cache? (y/n)"
        read -r CLEAN_DOTNET_CACHE
        
        if [ "$CLEAN_DOTNET_CACHE" = "y" ]; then
            if command -v dotnet &>/dev/null; then
                dotnet nuget locals all --clear
                echo -e "${GREEN}Cleared .NET NuGet cache.${NC}"
            else
                echo -e "${YELLOW}Warning: dotnet command not found in host. Can't clear cache.${NC}"
                echo -e "Attempting to clear cache using Docker container..."
                docker run --rm -v $HOME/.nuget:/root/.nuget mcr.microsoft.com/dotnet/sdk:latest dotnet nuget locals all --clear
            fi
        fi
    fi
}

restart_docker() {
    print_header "Restarting Docker service"
    
    echo -e "${YELLOW}--- Stopping all running .NET build containers ---${NC}"
    RUNNING_CONTAINERS=$(docker ps -f "name=dotnet" -q)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        docker stop $RUNNING_CONTAINERS
        echo -e "${GREEN}Stopped all running .NET build containers.${NC}"
    else
        echo -e "No running .NET build containers found."
    fi
    
    echo -e "\n${YELLOW}--- Restarting Docker service ---${NC}"
    sudo systemctl restart docker
    sleep 5
    
    echo -e "\n${YELLOW}--- Checking Docker service status ---${NC}"
    systemctl status docker --no-pager
}

prune_docker() {
    print_header "Deep cleaning Docker system"
    
    echo -e "${YELLOW}--- Running system prune ---${NC}"
    docker system prune -f
    
    echo -e "\n${YELLOW}--- Removing unused volumes ---${NC}"
    docker volume prune -f
    
    echo -e "\n${YELLOW}--- Would you like to perform a deep clean including all unused images? (y/n) ---${NC}"
    read -r DEEP_CLEAN
    
    if [ "$DEEP_CLEAN" = "y" ]; then
        echo -e "${YELLOW}Removing all unused images...${NC}"
        docker system prune -a -f
        echo -e "${GREEN}Deep clean completed.${NC}"
    fi
}

optimize_dotnet_build() {
    print_header "Optimizing Docker for .NET Builds"
    
    echo -e "${YELLOW}--- Setting up persistent .NET build cache volume ---${NC}"
    
    if ! docker volume ls | grep -q "dotnet-nuget-cache"; then
        docker volume create dotnet-nuget-cache
        echo -e "${GREEN}Created persistent NuGet cache volume.${NC}"
    else
        echo -e "Persistent NuGet cache volume already exists."
    fi
    
    echo -e "\n${YELLOW}--- Creating optimized .NET build image ---${NC}"
    
    # Create a temporary Dockerfile with build caching optimizations
    cat << EOF > Dockerfile.optimized
FROM mcr.microsoft.com/dotnet/sdk:7.0

# Install additional tools if needed
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Configure NuGet
RUN dotnet nuget disable source nuget.org && \
    dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org

# Optimize for caching
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_NOLOGO=true \
    NUGET_XMLDOC_MODE=skip

# Create a directory for better layer caching
WORKDIR /build

# Copy just the project files first to better utilize Docker layer caching
ONBUILD COPY *.sln ./*.sln ./
ONBUILD COPY */*.csproj ./
ONBUILD RUN for file in $(ls *.csproj); do \
            mkdir -p ${file%.*}/ && mv $file ${file%.*}/; \
        done
ONBUILD RUN dotnet restore

# Actual build happens after copying the entire codebase
ONBUILD COPY . .
ONBUILD RUN dotnet build -c Release --no-restore

# Set entry point for development usage
ENTRYPOINT ["dotnet"]
EOF
    
    docker build -t optimized-dotnet-build:latest -f Dockerfile.optimized .
    
    echo -e "\n${GREEN}Built optimized .NET build image.${NC}"
    echo -e "${YELLOW}To use this image for builds, run:${NC}"
    echo -e "docker run -it --rm -v \$(pwd):/app -v dotnet-nuget-cache:/root/.nuget/packages -w /app optimized-dotnet-build:latest build"
    
    echo -e "\n${YELLOW}--- Setting up Docker daemon optimizations ---${NC}"
    
    # Create or modify Docker daemon.json with optimizations
    DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
    
    if [ -f "$DOCKER_DAEMON_FILE" ]; then
        cp "$DOCKER_DAEMON_FILE" "$DOCKER_DAEMON_FILE.bak"
        echo -e "${YELLOW}Backed up existing Docker daemon config to $DOCKER_DAEMON_FILE.bak${NC}"
    fi
    
    cat << EOF | sudo tee "$DOCKER_DAEMON_FILE"
{
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF
    
    echo -e "\n${YELLOW}Would you like to restart Docker daemon to apply these changes? (y/n)${NC}"
    read -r RESTART_DAEMON
    
    if [ "$RESTART_DAEMON" = "y" ]; then
        sudo systemctl restart docker
        sleep 5
        echo -e "${GREEN}Docker daemon restarted with optimized settings.${NC}"
    else
        echo -e "${YELLOW}Please restart Docker daemon later to apply changes.${NC}"
    fi
    
    # Cleanup
    rm Dockerfile.optimized
}

fix_all() {
    print_header "Performing all fixes for Docker .NET build resource issues"
    
    # 1. Check stats first
    check_docker_stats
    
    # 2. Clean up Docker resources
    cleanup_dotnet_docker
    
    # 3. Optimize .NET builds
    optimize_dotnet_build
    
    # 4. Prune Docker system
    echo -e "\n${YELLOW}--- Running System Prune ---${NC}"
    docker system prune -f
    
    # 5. Restart Docker
    restart_docker
    
    # 6. Final stats check
    check_docker_stats
    
    echo -e "\n${GREEN}--- All fixes completed ---${NC}"
    echo -e "${YELLOW}Recommended practices for .NET Docker builds:${NC}"
    echo -e "1. Use multi-stage Docker builds for .NET applications"
    echo -e "2. Add .dockerignore file to exclude bin, obj directories"
    echo -e "3. Keep NuGet packages in a named volume or bind mount"
    echo -e "4. Use BuildKit for improved performance and caching"
    echo -e "5. Consider implementing a CI/CD pipeline with proper caching"
}

# Main execution
check_docker_running

# Parse command line arguments
ACTION=${1:-"stats"}

case "$ACTION" in
    "clean")
        cleanup_dotnet_docker
        ;;
    "restart")
        restart_docker
        ;;
    "prune")
        prune_docker
        ;;
    "optimize")
        optimize_dotnet_build
        ;;
    "stats")
        check_docker_stats
        ;;
    "fix-all")
        fix_all
        ;;
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        echo -e "${YELLOW}Available actions: clean, restart, prune, optimize, stats, fix-all${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Docker .NET build resource management script completed.${NC}"