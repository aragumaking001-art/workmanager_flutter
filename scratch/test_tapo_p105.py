import sys
import os
import time
import asyncio
import getpass
import traceback

def test_pyp100(ip: str, email: str, password: str):
    print("\n--- [試行 1] PyP100 プロトコル (旧・標準ファームウェア用) ---")
    try:
        from PyP100 import PyP100
        p100 = PyP100.P100(ip, email, password)
        p100.handshake()
        p100.login()
        print("✅ PyP100 ログイン成功！")
        
        info = p100.getDeviceInfo()
        print("機器情報:", info)
        
        print(">> ON テスト...")
        p100.setPowerState(True)
        time.sleep(2)
        print(">> OFF テスト...")
        p100.setPowerState(False)
        print("🎉 PyP100 での制御に成功しました！")
        return True
    except Exception as e:
        print(f"❌ PyP100 失敗: {e}")
        return False

async def test_tapo_klap(ip: str, email: str, password: str):
    print("\n--- [試行 2] Tapo KLAP プロトコル (最新ファームウェア用) ---")
    try:
        from tapo import ApiClient
        client = ApiClient(email, password)
        
        # Try p105 then p100
        try:
            device = await client.p105(ip)
        except Exception:
            device = await client.p100(ip)
            
        info = await device.get_device_info()
        print("✅ Tapo KLAP 接続成功！")
        print(f"機器名: {info.nickname}, モデル: {info.model}, FW: {info.fw_ver}")
        
        print(">> ON テスト...")
        await device.on()
        await asyncio.sleep(2)
        print(">> OFF テスト...")
        await device.off()
        print("🎉 Tapo KLAP での制御に成功しました！")
        return True
    except Exception as e:
        print(f"❌ Tapo KLAP 失敗: {e}")
        traceback.print_exc()
        return False

def main():
    ip = "192.168.0.10"
    print("=========================================")
    print("  Tapo P105 診断＆ON/OFF 動作確認テスト")
    print("=========================================")
    print(f"接続先IPアドレス: {ip}")
    
    if len(sys.argv) >= 3:
        email = sys.argv[1]
        password = sys.argv[2]
    else:
        email = input("Tapoログイン メールアドレス (または端末アカウント名): ").strip()
        password = getpass.getpass("パスワード (非表示): ").strip()

    if not email or not password:
        print("メールアドレスとパスワードを入力してください。")
        sys.exit(1)

    # 1. Test PyP100
    success = test_pyp100(ip, email, password)
    
    # 2. If failed, test Tapo KLAP
    if not success:
        success = asyncio.run(test_tapo_klap(ip, email, password))

    if not success:
        print("\n=========================================")
        print("  【両方のプロトコルで接続失敗】")
        print("=========================================")
        print("TP-Linkアカウントで『2段階認証（2FA）』が有効になっている可能性があります。")
        print("その場合、TP-Link IDのパスワードでは外部からログインできません。")
        print("\n★解決策（端末アカウントの作成）：")
        print("1. スマホの「Tapo」アプリを開く")
        print("2. P105 ＞ 右上の歯車アイコン（設定） ＞「詳細設定」を開く")
        print("3.「端末のアカウント」（または「デバイスのアカウント」）をタップ")
        print("4. 任意のユーザー名（例: admin）とパスワードを設定して保存")
        print("5. このスクリプトを再実行し、設定した端末アカウント名とパスワードを入力してください！")

if __name__ == "__main__":
    main()
