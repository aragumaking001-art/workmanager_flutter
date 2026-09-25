import asyncio
import traceback
import sys

IP = "192.168.10.177"
EMAIL = "daftly@hotmail.co.jp"
PASSWORD = "yama0322"

print(f"=== Testing Tapo P105 at {IP} ===")

# Test 1: PyP100
print("\n--- [Test 1: PyP100 (Legacy Protocol)] ---")
try:
    from PyP100 import PyP100
    p100 = PyP100.P100(IP, EMAIL, PASSWORD)
    p100.handshake()
    p100.login()
    print("SUCCESS: PyP100 login succeeded!")
    info = p100.getDeviceInfo()
    print("Device Info:", info)
except Exception as e:
    print(f"FAILED (PyP100): {e}")

# Test 2: Tapo (KLAP Protocol) with p105
print("\n--- [Test 2: Tapo KLAP (p105)] ---")
async def test_klap_p105():
    from tapo import ApiClient
    client = ApiClient(EMAIL, PASSWORD)
    try:
        device = await client.p105(IP)
        info = await device.get_device_info()
        print("SUCCESS: Tapo p105 connected!")
        print("Device Info:", info)
        print("Testing ON...")
        await device.on()
        print("ON succeeded!")
        await asyncio.sleep(2)
        print("Testing OFF...")
        await device.off()
        print("OFF succeeded!")
    except Exception as e:
        print(f"FAILED (KLAP p105): {type(e).__name__}: {e}")

asyncio.run(test_klap_p105())

# Test 3: Tapo (KLAP Protocol) with p100
print("\n--- [Test 3: Tapo KLAP (p100)] ---")
async def test_klap_p100():
    from tapo import ApiClient
    client = ApiClient(EMAIL, PASSWORD)
    try:
        device = await client.p100(IP)
        info = await device.get_device_info()
        print("SUCCESS: Tapo p100 connected!")
        print("Device Info:", info)
    except Exception as e:
        print(f"FAILED (KLAP p100): {type(e).__name__}: {e}")

asyncio.run(test_klap_p100())
