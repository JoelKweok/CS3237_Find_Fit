"""
Scan/Discovery
--------------

Example showing how to scan for BLE devices.

Updated on 2019-03-25 by hbldh <henrik.blidh@nedomkull.com>

"""

import asyncio
import CoreBluetooth
from bleak import discover

async def run():
    devices = await discover()
    for d in devices:
        print(d)
        print("it goes here")
    print("it goes there")


loop = asyncio.get_event_loop()
loop.run_until_complete(run())
