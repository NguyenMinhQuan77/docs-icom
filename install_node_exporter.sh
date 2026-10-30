#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

echo "=== Starting Node Exporter Installation for Ubuntu 22.04 ==="

# 1. Create a system user for node_exporter
if ! id "node_exporter" &>/dev/null; then
    echo "[1/6] Creating node_exporter system user..."
    useradd --system --no-create-home --shell /bin/false node_exporter
else
    echo "[1/6] User node_exporter already exists, skipping."
fi

# 2. Fetch the latest version of Node Exporter
echo "[2/6] Fetching the latest Node Exporter version from GitHub..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")')
if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch latest version. Falling back to 1.8.2"
    LATEST_VERSION="1.8.2"
fi
echo "      Latest version: v${LATEST_VERSION}"

# 3. Download and extract
cd /tmp
echo "[3/6] Downloading node_exporter-${LATEST_VERSION}.linux-amd64.tar.gz..."
curl -sLO https://github.com/prometheus/node_exporter/releases/download/v${LATEST_VERSION}/node_exporter-${LATEST_VERSION}.linux-amd64.tar.gz

echo "[4/6] Extracting binary..."
tar -xzf node_exporter-${LATEST_VERSION}.linux-amd64.tar.gz

# Install binary
echo "      Moving binary to /usr/local/bin/..."
cp node_exporter-${LATEST_VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Clean up
rm -rf node_exporter-${LATEST_VERSION}.linux-amd64.tar.gz node_exporter-${LATEST_VERSION}.linux-amd64

# 5. Create systemd service file
echo "[5/6] Creating systemd service file (/etc/systemd/system/node_exporter.service)..."
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

NoNewPrivileges=true
ProtectHome=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF

# 6. Enable and start the service
echo "[6/6] Reloading systemd and starting Node Exporter service..."
systemctl daemon-reload
systemctl enable --now node_exporter

echo "=== Installation Completed Successfully! ==="
echo "Node Exporter is now running on port 9100."
echo "You can check its status with: systemctl status node_exporter"