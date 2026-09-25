import asyncio
from tapo import ApiClient

IP = "192.168.10.177"

async def test_cred(user, pwd):
    print(f"Testing with user='{user}', pwd='{pwd}'...")
    client = ApiClient(user, pwd)
    try:
        device = await client.p105(IP)
        info = await device.get_device_info()
        print(f"  -> SUCCESS! Model={info.model}")
        return True
    except Exception as e:
        print(f"  -> FAILED: {e}")
        return False

async def main():
    # Test combinations
    await test_cred("daftly@hotmail.co.jp", "yama0322")
    await test_cred("admin", "admin")
    await test_cred("admin", "admin1234")
    await test_cred("admin", "work1234")

asyncio.run(main())
