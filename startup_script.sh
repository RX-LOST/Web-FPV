#!/bin/bash
# This is the shell script to start your internet vtx/rx on boot

# Go into mjpg folder
cd /home/pi/mjpg-streamer/mjpg-streamer-experimental/

# Start MJPG-Streamer (Set your resoltion here)
sudo mjpg_streamer -i 'input_uvc.so -d /dev/video0 -r 1280x720 -f 15 -n' -o 'output_http.so -w www -p 8080' &
# cd back to home
cd /home/pi/
# Start pigpiofactory service
sudo pigpiod
#cd to github repository folder
cd /home/pi/Web-FPV/
# Start WebSocket server
sudo python3 websocket_server.py &
