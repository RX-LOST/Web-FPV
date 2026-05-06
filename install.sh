#!/bin/bash
# Web-FPV Installation Script
# For Raspberry Pi Zero 2W running Raspberry Pi OS
# Usage: curl -fsSL https://raw.githubusercontent.com/RX-LOST/Web-FPV/main/install.sh | sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; }

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    error "This script is intended for Raspberry Pi only!"
    exit 1
fi

# Check for root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (use sudo)"
    exit 1
fi

# Get the script directory (where Web-FPV will be installed)
INSTALL_DIR="/home/pi/Web-FPV"
if [ -d "$INSTALL_DIR" ]; then
    log "Web-FPV directory exists at $INSTALL_DIR"
else
    log "Cloning Web-FPV repository..."
    cd /home/pi
    git clone https://github.com/RX-LOST/Web-FPV.git || {
        error "Failed to clone repository"
        exit 1
    }
fi

cd "$INSTALL_DIR"

# Prompt for resolution and FPS
echo ""
echo "========================================"
echo "  Web-FPV Video Stream Configuration"
echo "========================================"
echo ""
echo "Recommended settings for Pi Zero 2W:"
echo "  1) 640x480 @ 30fps (default, low latency + low bandwidth)"
echo "  2) 640x480 @ 60fps (higher frame rate, more bandwidth)"
echo "  3) 800x600 @ 30fps (balanced)"
echo "  4) 1280x720 @ 30fps (HD, higher CPU)"
echo "  5) Custom settings"
echo ""
read -p "Select option (1-5) [default: 1]: " video_option
video_option=${video_option:-1}

case $video_option in
    1)
        RESOLUTION="640x480"
        FPS="30"
        ;;
    2)
        RESOLUTION="640x480"
        FPS="60"
        ;;
    3)
        RESOLUTION="800x600"
        FPS="30"
        ;;
    4)
        RESOLUTION="1280x720"
        FPS="30"
        ;;
    5)
        read -p "Enter resolution (e.g., 640x480): " RESOLUTION
        read -p "Enter FPS (e.g., 30): " FPS
        ;;
    *)
        RESOLUTION="640x480"
        FPS="30"
        ;;
esac

# Prompt for quality (affects bandwidth)
echo ""
echo "JPEG quality (1-100, default: 80):"
echo "  Lower = less bandwidth, more compression artifacts"
echo "  Higher = better quality, more bandwidth"
read -p "Quality [default: 80]: " QUALITY
QUALITY=${QUALITY:-80}

log "Video settings: $RESOLUTION @ ${FPS}fps, quality: $QUALITY"
echo ""

# Step 1: Install system dependencies
log "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq \
    pigpio \
    python3-pip \
    git \
    build-essential \
    libevent-dev \
    libjpeg62-turbo-dev \
    libbsd-dev \
    libgpiod-dev \
    2>/dev/null || true

# Step 2: Install ustreamer
USTREAMER_DIR="/opt/ustreamer"
if [ -f "$USTREAMER_DIR/ustreamer" ]; then
    log "ustreamer already installed at $USTREAMER_DIR"
else
    log "Building and installing ustreamer..."
    cd /tmp
    git clone --depth 1 https://github.com/pikvm/ustreamer.git || {
        error "Failed to clone ustreamer"
        exit 1
    }
    cd ustreamer
    make -j$(nproc) WITH_GPIO=0 > /dev/null 2>&1 || make WITH_GPIO=0
    mkdir -p "$USTREAMER_DIR"
    cp ustreamer "$USTREAMER_DIR/"
    cd /tmp
    rm -rf ustreamer
    log "ustreamer installed to $USTREAMER_DIR"
fi

# Step 3: Install Python dependencies
log "Installing Python dependencies..."
pip3 install -q websockets gpiozero || {
    warn "pip install failed, trying with --break-system-packages..."
    pip3 install --break-system-packages -q websockets gpiozero
}

# Step 4: Create config file and systemd services
log "Creating config file and systemd services..."

# Create initial config file
cat > /etc/webfpv.conf << EOF
RESOLUTION=$RESOLUTION
FPS=$FPS
QUALITY=$QUALITY
EOF

# pigpiod service (if not exists)
if [ ! -f /etc/systemd/system/pigpiod.service ]; then
    cat > /etc/systemd/system/pigpiod.service << 'EOF'
[Unit]
Description=Pigpio daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/pigpiod
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    log "Created pigpiod service"
fi

# ustreamer service (reads resolution from EnvironmentFile)
cat > /etc/systemd/system/ustreamer.service << EOF
[Unit]
Description=uStreamer MJPEG video streamer
After=network.target

[Service]
Type=simple
EnvironmentFile=/etc/webfpv.conf
ExecStart=$USTREAMER_DIR/ustreamer \\
    --device=/dev/video0 \\
    --resolution=\$RESOLUTION \\
    --format=JPEG \\
    --quality=\$QUALITY \\
    --desired-fps=\$FPS \\
    --drop-same-frames=30 \\
    --host=0.0.0.0 \\
    --port=8080 \\
    --allow-origin=* \\
    --persistent \\
    --verbose
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# websocket server service
cat > /etc/systemd/system/webfpv.service << EOF
[Unit]
Description=Web-FPV WebSocket Server
After=network.target pigpiod.service

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/websocket_server.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Step 5: Enable and start services
log "Enabling and starting services..."
systemctl daemon-reload
systemctl enable pigpiod.service
systemctl enable ustreamer.service
systemctl enable webfpv.service

# Disable old mjpg-streamer service if it exists
systemctl disable mjpg-streamer.service 2>/dev/null || true

systemctl start pigpiod.service
sleep 1
systemctl start ustreamer.service
systemctl start webfpv.service

# Step 6: Get Tailscale IP if available
TAILSCALE_IP=""
if command -v tailscale &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
fi

# Determine IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "========================================"
echo "  Web-FPV Installation Complete!"
echo "========================================"
echo ""
echo "Services status:"
systemctl is-active --quiet pigpiod.service && echo "  [OK] pigpiod" || echo "  [!!] pigpiod"
systemctl is-active --quiet ustreamer.service && echo "  [OK] ustreamer" || echo "  [!!] ustreamer"
systemctl is-active --quiet webfpv.service && echo "  [OK] webfpv" || echo "  [!!] webfpv"
echo ""
echo "Access the control interface at:"
echo "  http://$LOCAL_IP"
echo "  http://$LOCAL_IP:8080/stream (video only)"
if [ -n "$TAILSCALE_IP" ]; then
    echo "  http://$TAILSCALE_IP (over Tailscale)"
fi
echo ""
echo "Video settings: $RESOLUTION @ ${FPS}fps, quality: $QUALITY"
echo "Bandwidth optimization: drop-same-frames enabled"
echo ""
echo "To check service status: systemctl status webfpv"
echo "To view ustreamer logs: journalctl -u ustreamer -f"
echo ""
log "Installation complete! Reboot recommended."
