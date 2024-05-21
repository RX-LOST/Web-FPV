# Installation

First, install mjpg streamer This is how will be running our video.

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

In your pi's current state, it this will only work over the local network. So we will install Tailscale to make a virtual "local network" over the internet for any device with the Login and software.

To install Tailscale on the pi:

```curl -fsSL https://tailscale.com/install.sh | sh```

After the installation, run:

```sudo tailscale up```

It will then give you a link to connect the pi to your account. 

Once Tailscale is set up, you need to reboot the pi, connect the webcam before boot, and then open the provided ```Web-control-V1.html```. Now connect a gamepad and type the pi's tailnet ip adress into the textbox and click "connect". *Make sure to connect the gamepad first, otherwise the html spits out an error and it won't start. 

# Wiring

The Controls will be output through servo type pwm like a hobby reciever. the pins are configurable inside of ```the websocket_server.py``` file, but by default throttle is GPIO 13 and steering servo is GPIO 12.

Connect the gnd pins of the servo, esc, and pi together, the 5v of the esc and servo together, but make sure your pi 5v is powered with a regulated 5v and not the 6v from the esc. 

Lastly, connect the usb webcam to the pi before powering on. (I reccomend a webcam with low compression and lower resolution to allow for the least amount of processing and latency)

###### If you've come this far, well done! You now have an internet controlled rc car vtx and controller rx. To use 4g lte, buy a small 4g wifi hotspot usb stick, and you should be good to go!

Please note. Your internet speeds for both your computer and pi, your computer's multitasking abilities, and numer of tabs open at the time heavily effect latency. 
