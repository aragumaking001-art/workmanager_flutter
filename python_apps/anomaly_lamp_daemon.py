"""
WorkManager 異常検知パトランプ / 警告灯 自動制御デーモン
(Tapo P105 Smart Plug Auto-Controller)

【概要】
中央MariaDBの unit_cleaning_logs を常時監視し、
- 未解消の異常（anomaly_flag != 0）が 1件以上: Tapo P105 を ON（自己点滅ランプ点灯）
- 未解消の異常が 0件: Tapo P105 を OFF（消灯）
を自動実行します。

【特徴】
1. エッジトリガー制御: 状態変化時（0件 <-> 1件以上）のみP105へ命令送信。機器負荷ゼロ。
2. オフライン・瞬断自動復帰: DB切断やWi-Fi瞬断が発生してもクラッシュせず自動再接続。
3. IP・設定変更が容易: 同階層の tapo_lamp_config.json でIPや接続先を変更可能。
"""

import os
import sys
import json
import time
import signal
import asyncio
import argparse
from datetime import datetime

import pymysql
from tapo import ApiClient

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

if getattr(sys, "frozen", False):
    SCRIPT_DIR = os.path.dirname(sys.executable)
else:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "tapo_lamp_config.json")

def load_config():
    if not os.path.exists(CONFIG_FILE):
        print(f"[ERROR] 設定ファイルが見つかりません: {CONFIG_FILE}")
        sys.exit(1)
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

class AnomalyLampDaemon:
    def __init__(self, config):
        self.config = config
        self.tapo_cfg = config.get("tapo", {})
        self.db_cfg = config.get("database", {})
        self.poll_interval = config.get("settings", {}).get("poll_interval_sec", 3)
        
        self.db_conn = None
        self.device = None
        self.lamp_is_on = None  # None: 未取得, True: 点灯中, False: 消灯中
        self.running = True

    def log(self, message: str):
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{now_str}] {message}", flush=True)

    async def get_tapo_device(self):
        ip = self.tapo_cfg.get("ip")
        email = self.tapo_cfg.get("email")
        password = self.tapo_cfg.get("password")

        if not email or not password:
            raise ValueError(f"tapo_lamp_config.json に email と password を入力してください。")

        client = ApiClient(email, password)
        try:
            device = await client.p105(ip)
        except Exception:
            device = await client.p100(ip)
        return device

    def get_db_connection(self):
        if self.db_conn:
            try:
                self.db_conn.ping(reconnect=True)
                return self.db_conn
            except Exception:
                self.db_conn = None

        conn = pymysql.connect(
            host=self.db_cfg.get("host", "192.168.10.101"),
            port=self.db_cfg.get("port", 3306),
            user=self.db_cfg.get("user", "work_user"),
            password=self.db_cfg.get("password", "work1234"),
            database=self.db_cfg.get("database", "work_manager_db"),
            charset="utf8mb4",
            autocommit=True,
            connect_timeout=5,
            cursorclass=pymysql.cursors.DictCursor
        )
        self.db_conn = conn
        return self.db_conn

    def query_anomaly_count(self) -> int:
        conn = self.get_db_connection()
        try:
            conn.commit()  # 最新のトランザクションスナップショットを取得
        except Exception:
            pass
        with conn.cursor() as cur:
            # 過去含む全未解消の異常レコード件数
            cur.execute("""
                SELECT COUNT(*) as cnt 
                FROM unit_cleaning_logs 
                WHERE IFNULL(anomaly_flag, 0) != 0
            """)
            row = cur.fetchone()
            return row["cnt"] if row else 0

    async def set_lamp_power(self, power_on: bool):
        for attempt in range(1, 4):
            try:
                if not self.device:
                    self.device = await self.get_tapo_device()
                
                if power_on:
                    await self.device.on()
                else:
                    await self.device.off()
                
                self.lamp_is_on = power_on
                return True
            except Exception as e:
                self.log(f"[WARN] Tapo P105 制御エラー (試行 {attempt}/3): {e}")
                self.device = None  # 再接続を促す
                await asyncio.sleep(1)
        return False

    async def run(self):
        self.log("==================================================")
        self.log("  WorkManager 異常検知パトランプ自動監視デーモン 起動")
        self.log(f"  - 監視先DB: {self.db_cfg.get('host')}:{self.db_cfg.get('port')}/{self.db_cfg.get('database')}")
        self.log(f"  - Tapo IP: {self.tapo_cfg.get('ip')}")
        self.log(f"  - 監視対象: 過去含む未解消の全異常レコード (anomaly_flag != 0)")
        self.log(f"  - ポーリング間隔: {self.poll_interval}秒")
        self.log("==================================================")

        # 初期状態確認
        try:
            self.device = await self.get_tapo_device()
            info = await self.device.get_device_info()
            self.lamp_is_on = info.device_on
            self.log(f"[INIT] Tapo P105 接続確認完了 (現在状態: {'ON(点灯中)' if self.lamp_is_on else 'OFF(消灯中)'})")
        except Exception as e:
            self.log(f"[WARN] Tapo P105 初期接続に失敗しました（監視ループ内で再試行します）: {e}")

        consecutive_errors = 0
        loop_count = 0
        while self.running:
            try:
                # 1. 異常レコード件数の取得
                cnt = self.query_anomaly_count()
                consecutive_errors = 0
                loop_count += 1

                # 2. 状態判定と制御
                if cnt > 0:
                    # 異常あり
                    if self.lamp_is_on is not True:
                        self.log(f"🚨 [ALERT] 異常検知: {cnt}件の未対応データがあります！ -> ランプ電源ON (点滅開始)")
                        await self.set_lamp_power(True)
                    elif loop_count % 10 == 0:
                        self.log(f"🚨 [ALERT継続] 未解消の異常: {cnt}件 | ランプ点灯中 (ON)")
                else:
                    # 異常なし (0件)
                    if self.lamp_is_on is not False:
                        self.log(f"✅ [NORMAL] 異常なし (0件) -> ランプ電源OFF (消灯)")
                        await self.set_lamp_power(False)
                    elif loop_count % 10 == 0:
                        self.log(f"👀 [MONITOR] 異常なし (0件) | 監視中...")

            except Exception as e:
                consecutive_errors += 1
                if consecutive_errors <= 3 or consecutive_errors % 10 == 0:
                    self.log(f"[ERROR] 監視ループエラー: {e}")

            await asyncio.sleep(self.poll_interval)

        self.log("デーモンを安全に終了しました。")

def main():
    parser = argparse.ArgumentParser(description="WorkManager 異常検知パトランプ自動制御デーモン")
    parser.add_argument("--test-on", action="store_true", help="P105をONにして終了")
    parser.add_argument("--test-off", action="store_true", help="P105をOFFにして終了")
    parser.add_argument("--status", action="store_true", help="DBの異常件数とP105の状態を表示して終了")
    args = parser.parse_args()

    config = load_config()
    daemon = AnomalyLampDaemon(config)

    # 単発コマンド処理
    if args.test_on:
        print(f"Connecting to Tapo at {config['tapo']['ip']} to turn ON...")
        asyncio.run(daemon.set_lamp_power(True))
        print("Done: ON")
        return

    if args.test_off:
        print(f"Connecting to Tapo at {config['tapo']['ip']} to turn OFF...")
        asyncio.run(daemon.set_lamp_power(False))
        print("Done: OFF")
        return

    if args.status:
        try:
            cnt = daemon.query_anomaly_count()
            print(f"DB 未解消の異常件数: {cnt} 件")
        except Exception as e:
            print(f"DB接続エラー: {e}")

        try:
            dev = asyncio.run(daemon.get_tapo_device())
            info = asyncio.run(dev.get_device_info())
            print(f"Tapo P105 状態: {'[ON (点滅中)]' if info.device_on else '[OFF (消灯中)]'}")
        except Exception as e:
            print(f"Tapo接続エラー: {e}")
        return

    # 常駐デーモン実行
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    def handle_sig(sig, frame):
        daemon.log("終了シグナルを受信しました。停止中...")
        daemon.running = False

    signal.signal(signal.SIGINT, handle_sig)
    signal.signal(signal.SIGTERM, handle_sig)

    try:
        loop.run_until_complete(daemon.run())
    finally:
        loop.close()

if __name__ == "__main__":
    main()
