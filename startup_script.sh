#!/bin/bash

# go into mjpg folder
cd /home/pi/mjpg-streamer/mjpg-streamer-experimental/

# Start MJPG-Streamer
sudo mjpg_streamer -i 'input_uvc.so -d /dev/video0 -r 320x250 -f 15 -n' -o 'output_http.so -w www -p 8080' &
# cd back to home
cd /home/pi/
#start pigpiofactory service
sudo pigpiod
# Start WebSocket server
sudo python3 websocket_server4.py &
