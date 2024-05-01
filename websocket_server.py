import asyncio
import websockets
from gpiozero.pins.pigpio import PiGPIOFactory
import gpiozero

# Initialize PiGPIOFactory
factory = PiGPIOFactory()

# Initialize servo and motor with factory
servo = gpiozero.AngularServo(12, min_angle=-90, max_angle=90, pin_factory=factory)  # Assuming GPIO 12 is used for servo
motor = gpiozero.AngularServo(13, min_angle=-90, max_angle=90, pin_factory=factory)  # Assuming GPIO 13 is used for motor

async def control_rc_car(websocket, path):
    print("WebSocket connection established")

    try:
        async for message in websocket:
            throttle, steering = message.split(",")
            throttle = int(throttle)
            steering = int(steering)

            # Map throttle and steering values to servo angles
            motor_angle = throttle  # Assuming motor angle is directly proportional to throttle
            steering_angle = steering  # Assuming steering angle is directly proportional to controller input

            # Set servo and motor angles
            servo.angle = steering_angle
            motor.angle = motor_angle

            
    except websockets.exceptions.ConnectionClosedError:
        print("WebSocket connection closed unexpectedly")

start_server = websockets.serve(control_rc_car, "0.0.0.0", 8765)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
