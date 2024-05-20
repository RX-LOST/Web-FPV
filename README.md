First, install mjpg streamer. This is how will be running our video.

Get instructions here

```https://github.com/jacksonliam/mjpg-streamer?tab=readme-ov-file```

Next, clone this repository into your /home/pi folder.

```git clone https://github.com/RX-LOST/Web-FPV.git```

For stable servo control, install PiGpioFactory.

```sudo apt install pigpio```

Finally, copy my shell command into rc.local via:

```sudo nano /etc/rc.local``` 

and put this before the "exit 0"

```/home/pi/Web-FPV/startup_script.sh &```
