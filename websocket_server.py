import asyncio
import websockets
from gpiozero.pins.pigpio import PiGPIOFactory
import gpiozero
import os
import subprocess
import signal
import sys

current_dir = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = "/etc/webfpv.conf"

with open(os.path.join(current_dir, 'index.html'), 'rb') as f:
    HTML_CONTENT = f.read()

def load_config():
    config = {
        "resolution": "640x480",
        "fps": "30",
        "quality": "80"
    }
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    key, val = line.split("=", 1)
                    config[key.strip()] = val.strip()
    return config

def save_config(key, value):
    config = load_config()
    config[key] = value
    with open(CONFIG_FILE, "w") as f:
        f.write(f"# Web-FPV Configuration\n")
        f.write(f"resolution={config['resolution']}\n")
        f.write(f"fps={config['fps']}\n")
        f.write(f"quality={config['quality']}\n")

def restart_ustreamer(resolution=None, fps=None):
    try:
        subprocess.run(["pkill", "ustreamer"], stderr=subprocess.DEVNULL)
    except:
        pass
    config = load_config()
    if resolution:
        save_config("resolution", resolution)
        config = load_config()
    if fps:
        save_config("fps", fps)
        config = load_config()
    cmd = [
        "/opt/ustreamer/ustreamer",
        "--device=/dev/video0",
        f"--resolution={config['resolution']}",
        "--format=JPEG",
        f"--quality={config['quality']}",
        f"--desired-fps={config['fps']}",
        "--drop-same-frames=30",
        "--host=0.0.0.0",
        "--port=8080",
        "--allow-origin=*",
        "--persistent",
        "--verbose"
    ]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

factory = PiGPIOFactory()
servo = gpiozero.AngularServo(12, min_angle=-90, max_angle=90, pin_factory=factory)
motor = gpiozero.AngularServo(13, min_angle=-90, max_angle=90, pin_factory=factory)

def clamp(value, min_val=-90, max_val=90):
    return max(min_val, min(max_val, value))

async def control_rc_car(websocket, path):
    print("WebSocket connection established")
    try:
        async for message in websocket:
            try:
                msg = message.strip()
                if msg == "ping":
                    await websocket.send("pong")
                    continue
                if msg.startswith("resolution:"):
                    resolution = msg.split(":", 1)[1]
                    print(f"Changing resolution to: {resolution}")
                    await websocket.send("resolution_ok")
                    restart_ustreamer(resolution=resolution)
                    continue
                if msg.startswith("fps:"):
                    fps = msg.split(":", 1)[1]
                    print(f"Changing FPS to: {fps}")
                    await websocket.send("fps_ok")
                    restart_ustreamer(fps=fps)
                    continue
                if msg.startswith("query_config"):
                    config = load_config()
                    await websocket.send(f"config:{config['resolution']}")
                    continue
                throttle_str, steering_str = msg.split(",")
                throttle = clamp(int(throttle_str))
                steering = clamp(int(steering_str))
                servo.angle = steering
                motor.angle = throttle
            except (ValueError, IndexError) as e:
                print(f"Invalid message: {message}, error: {e}")
    except websockets.exceptions.ConnectionClosedError:
        print("WebSocket connection closed unexpectedly")
    except Exception as e:
        print(f"WebSocket error: {e}")

async def handle_http(reader, writer):
    try:
        request = await reader.read(1024)
        request_line = request.decode().split('\r\n')[0]
        if request_line.startswith('GET / '):
            response = (
                b'HTTP/1.1 200 OK\r\n'
                b'Content-Type: text/html; charset=utf-8\r\n'
                b'Cache-Control: no-cache\r\n'
                b'Content-Length: ' + str(len(HTML_CONTENT)).encode() + b'\r\n'
                b'\r\n' + HTML_CONTENT
            )
        else:
            response = b'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n'
        writer.write(response)
        await writer.drain()
    except Exception as e:
        print(f"HTTP error: {e}")
    finally:
        writer.close()

async def main():
    http_server = await asyncio.start_server(handle_http, '0.0.0.0', 80)
    print("HTTP server listening on port 80")
    ws_server = await websockets.serve(control_rc_car, "0.0.0.0", 8765)
    print("WebSocket server listening on port 8765")
    async with http_server, ws_server:
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
