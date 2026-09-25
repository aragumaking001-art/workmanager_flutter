import asyncio
import traceback
import sys

# Force UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

IP = "192.168.10.178"
EMAIL = "daftly@hotmail.co.jp"
PASSWORD = "yama0322"

print(f"=== Testing Tapo P105 at {IP} ===")

async def test_klap():
    from tapo import ApiClient
    client = ApiClient(EMAIL, PASSWORD)
    try:
        print(f"Connecting to {IP} via Tapo KLAP...")
        try:
            device = await client.p105(IP)
        except Exception:
            device = await client.p100(IP)
            
        info = await device.get_device_info()
        print("\n[SUCCESS] Tapo P105 Connected Successfully!")
        print(f"  Device Name    : {info.nickname}")
        print(f"  Model          : {info.model}")
        print(f"  Firmware Ver   : {info.fw_ver}")
        print(f"  Current Power  : {'[ON]' if info.device_on else '[OFF]'}")
        
        print("\n>> Testing ON (Power ON) ...")
        await device.on()
        print(">> Power is now ON! (カチッと音が鳴り、ランプ点灯)")
        await asyncio.sleep(2)
        
        print("\n>> Testing OFF (Power OFF) ...")
        await device.off()
        print(">> Power is now OFF! (カチッと音が鳴り、ランプ消灯)")
        print("\n[ALL TESTS PASSED] Python control succeeded completely!")
        return True
    except Exception as e:
        print(f"\n[FAILED]: {type(e).__name__}: {e}")
        traceback.print_exc()
        return False

asyncio.run(test_klap())
