# -*- coding: utf-8 -*-
"""
TI CC2650 SensorTag
-------------------

Adapted by Ashwin from the following sources:
 - https://github.com/IanHarvey/bluepy/blob/a7f5db1a31dba50f77454e036b5ee05c3b7e2d6e/bluepy/sensortag.py
 - https://github.com/hbldh/bleak/blob/develop/examples/sensortag.py

"""
import asyncio
import platform
import struct
import uuid
from datetime import date, time, datetime
from dateutil import tz
import paho.mqtt.client as mqtt
import numpy as np
from PIL import Image
import json
from os import PathLike, listdir
from os.path import join

from bleak import BleakClient

def on_connect(client,userdata,flags,rc):
    if rc == 0:
        print("Connected.")
        # client.subscribe("Group_5/predict")
    else:
        print("Failed to connect. Error code: %d." % rc)


def on_message(client,userdata,msg):
    print("Received message from server.")
    resp_dict = json.loads(msg.payload)
    print("Filename: %s, Prediction: %s, Score: %s"
    %(resp_dict["filename"],resp_dict["prediction"], resp_dict["score"]))

def setup(hostname):
    client=mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(hostname,1883,60)
    client.loop_start()
    return client


def send(client,dict):
    client.publish("cs3237/data" ,json.dumps(dict))

class Service:
    """
    Here is a good documentation about the concepts in ble;
    https://learn.adafruit.com/introduction-to-bluetooth-low-energy/gatt

    In TI SensorTag there is a control characteristic and a data characteristic which define a service or sensor
    like the Light Sensor, Humidity Sensor etc

    Please take a look at the official TI user guide as well at
    https://processors.wiki.ti.com/index.php/CC2650_SensorTag_User's_Guide
    """

    def __init__(self):
        self.data_uuid = None
        self.ctrl_uuid = None


class Sensor(Service):

    def callback(self, sender: int, data: bytearray):
        raise NotImplementedError()

    async def start_listener(self, client, *args):
        # start the sensor on the device
        write_value = bytearray([0x01])
        await client.write_gatt_char(self.ctrl_uuid, write_value)

        # listen using the handler
        await client.start_notify(self.data_uuid, self.callback)


class MovementSensorMPU9250SubService:

    def __init__(self):
        self.bits = 0

    def enable_bits(self):
        return self.bits

    def cb_sensor(self, data):
        raise NotImplementedError


class MovementSensorMPU9250(Sensor):
    GYRO_XYZ = 7
    ACCEL_XYZ = 7 << 3
    MAG_XYZ = 1 << 6
    ACCEL_RANGE_2G  = 0 << 8
    ACCEL_RANGE_4G  = 1 << 8
    ACCEL_RANGE_8G  = 2 << 8
    ACCEL_RANGE_16G = 3 << 8

    def __init__(self):
        super().__init__()
        self.data_uuid = "f000aa81-0451-4000-b000-000000000000"
        self.ctrl_uuid = "f000aa82-0451-4000-b000-000000000000"
        self.ctrlBits = 0

        self.sub_callbacks = []

    def register(self, cls_obj: MovementSensorMPU9250SubService):
        self.ctrlBits |= cls_obj.enable_bits()
        self.sub_callbacks.append(cls_obj.cb_sensor)
       # print("This is callback")
       # print(self.sub_callbacks)

    async def start_listener(self, client, *args):
        # start the sensor on the device
        await client.write_gatt_char(self.ctrl_uuid, struct.pack("<H", self.ctrlBits))

        # listen using the handler
        await client.start_notify(self.data_uuid, self.callback)

    def callback(self, sender: int, data: bytearray):
        unpacked_data = struct.unpack("<hhhhhhhhh", data)
        for cb in self.sub_callbacks:
            cb(unpacked_data)


class AccelerometerSensorMovementSensorMPU9250(MovementSensorMPU9250SubService):
    def __init__(self):
        super().__init__()
        self.bits = MovementSensorMPU9250.ACCEL_XYZ | MovementSensorMPU9250.ACCEL_RANGE_4G
        self.scale = 8.0/32768.0 # TODO: why not 4.0, as documented? @Ashwin Need to verify
        self.values = []

    def cb_sensor(self, data):
        '''Returns (x_accel, y_accel, z_accel) in units of g'''
        rawVals = data[3:6]
        self.values = rawVals
        print("[MovementSensor] Accelerometer:", tuple([ v*self.scale for v in rawVals ]))
       
    def read(self):
        readVals = self.values
        return tuple([ v*self.scale for v in readVals ])


class GyroscopeSensorMovementSensorMPU9250(MovementSensorMPU9250SubService):
    def __init__(self):
        super().__init__()
        self.bits = MovementSensorMPU9250.GYRO_XYZ
        self.scale = 500.0/65536.0
        self.values = []

    def cb_sensor(self, data):
        '''Returns (x_gyro, y_gyro, z_gyro) in units of degrees/sec'''
        rawVals = data[0:3]
        self.values = rawVals
        print("[MovementSensor] Gyroscope:", tuple([ v*self.scale for v in rawVals ]))
    
    def read(self):
        readVals = self.values
        return tuple([ v*self.scale for v in readVals ])


class LEDAndBuzzer(Service):
    """
        Adapted from various sources. Src: https://evothings.com/forum/viewtopic.php?t=1514 and the original TI spec
        from https://processors.wiki.ti.com/index.php/CC2650_SensorTag_User's_Guide#Activating_IO

        Codes:
            1 = red
            2 = green
            3 = red + green
            4 = buzzer
            5 = red + buzzer
            6 = green + buzzer
            7 = all
    """

    def __init__(self):
        super().__init__()
        self.data_uuid = "f000aa65-0451-4000-b000-000000000000"
        self.ctrl_uuid = "f000aa66-0451-4000-b000-000000000000"

    async def notify(self, client, code):
        # enable the config
        write_value = bytearray([0x01])
        await client.write_gatt_char(self.ctrl_uuid, write_value)

        # turn on the red led as stated from the list above using 0x01
        write_value = bytearray([code])
        await client.write_gatt_char(self.data_uuid, write_value)


async def run(address,dict):
    async with BleakClient(address) as client:
        x = await client.is_connected()
        print("Connected: {0}".format(x))
        
        led_and_buzzer = LEDAndBuzzer()

        acc_sensor = AccelerometerSensorMovementSensorMPU9250()
        gyro_sensor = GyroscopeSensorMovementSensorMPU9250()

        movement_sensor = MovementSensorMPU9250()
        movement_sensor.register(acc_sensor)
        
        movement_sensor.register(gyro_sensor)

        await movement_sensor.start_listener(client)


        cntr = 0
        count = 0
        connect_client =setup("139.99.89.148")
        session_id = uuid.uuid1()

        while True:
            # we don't want to exit the "with" block initiating the client object as the connection is disconnected
            # unless the object is stored
            await asyncio.sleep(0.3)
            acc_values = acc_sensor.read() # Returns (x_accel, y_accel, z_accel) in units of g
            gyro_values = gyro_sensor.read() #Returns (x_gyro, y_gyro, z_gyro) in units of degrees/sec

            try:
                dict = { "sensorID": 1, "uuid": str(session_id), "ax": acc_values[0], "ay": acc_values[1],
                "az": acc_values[2], "gx": gyro_values[0], "gy": gyro_values[1], "gz": gyro_values[2], "exercise_type": 1, "num_reps":0};
                send(connect_client,dict)
                print(dict)
            except Exception as ex:
                print(ex)
            if cntr == 0:
                # shine the red light
                await led_and_buzzer.notify(client, 0x01)

            if cntr == 5:
                # shine the green light
                await led_and_buzzer.notify(client, 0x02)

            cntr += 1

            if cntr == 10:
                cntr = 0


if __name__ == "__main__":
    """
    To find the address, once your sensor tag is blinking the green led after pressing the button, run the discover.py
    file which was provided as an example from bleak to identify the sensor tag device
    """

    import os
    
    #dict

    os.environ["PYTHONASYNCIODEBUG"] = str(1)
    address = (
        "54:6C:0E:53:45:2F"
        if platform.system() != "Darwin"
        else "A9FC8432-9749-48D7-9663-3E1C15BC13D0"
    )
    dict = {}
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run(address,dict))
    loop.run_forever()

