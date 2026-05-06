# Web-FPV

A modern web-based FPV control system for Raspberry Pi, featuring real-time video streaming and low-latency RC car control via gamepad or mobile touch joysticks.

## Features

- **Modern Web Interface** - Responsive dark/light theme, mobile-friendly
- **Multiple Control Methods** - Gamepad, mobile touch joysticks, or both
- **uStreamer Video** - Low-latency MJPEG streaming with same-frame dropping for bandwidth savings
- **Low Latency** - Optimized for Pi Zero 2W, ~60msg/s rate limiting
- **Auto-reconnect** - WebSocket reconnection with exponential backoff
- **Persistent Settings** - All preferences saved to localStorage
- **One-Command Install** - curl install script with systemd services
- **Live Stats** - FPS counter, latency tester, message rate display

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/RX-LOST/Web-FPV/main/install.sh | sudo sh
```

Or clone and run manually:

```bash
git clone https://github.com/RX-LOST/Web-FPV.git
cd Web-FPV
chmod +x install.sh
sudo ./install.sh
```

## Access

After installation, open `http://<pi-ip>` in your browser. The page auto-connects to the Pi's WebSocket on port 8765 and video stream on port 8080 automatically.

## Wiring

| Component | Pi GPIO | Notes |
|-----------|---------|-------|
| Steering Servo | GPIO 12 | PWM output |
| Throttle ESC | GPIO 13 | PWM output |
| Servo Ground | Pi GND | Common ground |
| ESC/servo 5V | Regulated 5V | NOT Pi 5V rail (use external regulator) |
| USB Webcam | Any USB | Connect before boot |

**Important**: Use a regulated 5V supply for servos/ESC. Do NOT power servos directly from Pi's 5V pin.

## Configuration

Edit these files to customize:
- `websocket_server.py` - GPIO pins, servo angles
- `index.html` - UI settings, default values (served automatically)
- Systemd services: `/etc/systemd/system/webfpv.service` and `/etc/systemd/system/ustreamer.service`

## Services

```bash
# Check status
systemctl status webfpv
systemctl status ustreamer
systemctl status pigpiod

# View logs
journalctl -u webfpv -f
journalctl -u ustreamer -f

# Restart services
sudo systemctl restart webfpv
sudo systemctl restart ustreamer
```

## Manual Installation Steps

1. Install ustreamer: https://github.com/pikvm/ustreamer
2. Install dependencies: `sudo apt install pigpio python3-pip`
3. Install Python packages: `pip3 install websockets gpiozero`
4. Run install script or set up systemd services manually

## Tailscale Setup (Optional)

For remote access over the internet:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Then access your Pi via its Tailscale IP.

## Troubleshooting

- **No video**: Check webcam is connected, run `ls /dev/video*`
- **No GPIO control**: Ensure `pigpiod` is running: `systemctl status pigpiod`
- **High latency**: Lower video resolution/FPS in ustreamer service
- **Gamepad not detected**: Connect gamepad before opening the page

## License

MIT License - see LICENSE file
