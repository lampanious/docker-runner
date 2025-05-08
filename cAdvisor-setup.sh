#!/bin/bash

# Install cAdvisor for Docker container monitoring
# This script sets up cAdvisor as a systemd service on Linux

echo "Setting up cAdvisor for Docker container monitoring..."

# Create directory for cAdvisor
sudo mkdir -p /var/lib/cadvisor

# Download and install cAdvisor systemd service file
cat << EOF | sudo tee /etc/systemd/system/cadvisor.service
[Unit]
Description=cAdvisor Container Monitoring
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker run \\
  --rm \\
  --name=cadvisor \\
  --volume=/:/rootfs:ro \\
  --volume=/var/run:/var/run:ro \\
  --volume=/sys:/sys:ro \\
  --volume=/var/lib/docker/:/var/lib/docker:ro \\
  --volume=/dev/disk/:/dev/disk:ro \\
  --volume=/var/lib/cadvisor/:/var/lib/cadvisor \\
  --publish=8080:8080 \\
  --privileged \\
  --device=/dev/kmsg \\
  gcr.io/cadvisor/cadvisor:v0.47.0
ExecStop=/usr/bin/docker stop cadvisor
ExecStopPost=/usr/bin/docker rm cadvisor

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start cAdvisor
sudo systemctl daemon-reload
sudo systemctl enable cadvisor
sudo systemctl start cadvisor

# Verify cAdvisor is running
echo "Checking cAdvisor status..."
sudo systemctl status cadvisor

echo "cAdvisor should be accessible at http://localhost:8080"
echo "Add this target to your Prometheus configuration:"
echo ""
echo "  - job_name: 'cadvisor'"
echo "    scrape_interval: 15s"
echo "    static_configs:"
echo "      - targets: ['localhost:8080']"
echo ""

# Check if Prometheus configuration exists and offer to update it
PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
if [ -f "$PROMETHEUS_CONFIG" ]; then
    echo "Found Prometheus configuration at $PROMETHEUS_CONFIG"
    echo "Would you like to add cAdvisor as a target? (y/n)"
    read add_target
    
    if [[ "$add_target" == "y" ]]; then
        # Create a backup of the current configuration
        sudo cp $PROMETHEUS_CONFIG ${PROMETHEUS_CONFIG}.bak
        
        # Add cAdvisor as a target
        cat << EOF | sudo tee -a $PROMETHEUS_CONFIG
  - job_name: 'cadvisor'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:8080']
EOF
        
        echo "cAdvisor target added to Prometheus configuration."
        echo "Restarting Prometheus service..."
        sudo systemctl restart prometheus
    fi
fi

echo "cAdvisor setup complete!"