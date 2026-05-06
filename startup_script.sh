#!/bin/bash
# Web-FPV Manual Startup Script (for testing without systemd)
# Usage: sudo ./startup_script.sh

echo "Starting Web-FPV services manually..."

# Kill existing processes
pkill -f ustreamer 2>/dev/null || true
pkill -f mjpg_streamer 2>/dev/null || true
pkill -f pigpiod 2>/dev/null || true
pkill -f websocket_server.py 2>/dev/null || true
sleep 1

# Start pigpio daemon
echo "Starting pigpio daemon..."
sudo pigpiod
sleep 1

# Start ustreamer (default 640x480 @ 30fps, quality 80)
echo "Starting ustreamer..."
/opt/ustreamer/ustreamer \
    --device=/dev/video0 \
    --resolution=640x480 \
    --format=JPEG \
    --quality=80 \
    --desired-fps=30 \
    --drop-same-frames=30 \
    --host=0.0.0.0 \
    --port=8080 \
    --persistent \
    --verbose &
sleep 2

# Start WebSocket server
echo "Starting WebSocket server..."
cd /home/pi/Web-FPV
sudo python3 websocket_server.py &

echo "All services started!"
echo "Access the interface at: http://$(hostname -I | awk '{print $1}')"
echo "Video stream: http://$(hostname -I | awk '{print $1}'):8080/stream"
