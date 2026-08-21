import threading
import time
import binascii
import json
import logging
from http.server import BaseHTTPRequestHandler, HTTPServer
from smartcard.System import readers
from smartcard.Exceptions import NoCardException, CardConnectionException

# 最後に読み取ったカード情報を保持する変数
latest_card = {
    "card_id": None,
    "timestamp": 0
}

# カードを同じ人がかざし続けた場合の連続反応を防ぐためのクールダウンタイム
COOLDOWN_SECONDS = 3.0

class NFCRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # ログをコンソールに出さないように無効化（バックグラウンドで静かに動かすため）
        pass

    def do_GET(self):
        # CORS対応 (Flutter Web/Desktopからのアクセス許可)
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        if self.path == '/api/nfc/status':
            response_data = json.dumps(latest_card)
            self.wfile.write(response_data.encode('utf-8'))
        elif self.path == '/api/nfc/clear':
            latest_card["card_id"] = None
            latest_card["timestamp"] = 0
            self.wfile.write(json.dumps({"status": "cleared"}).encode('utf-8'))
        else:
            self.wfile.write(json.dumps({"status": "not_found"}).encode('utf-8'))

def start_http_server():
    server_address = ('127.0.0.1', 8080)
    httpd = HTTPServer(server_address, NFCRequestHandler)
    print("NFC Server running on http://127.0.0.1:8080")
    httpd.serve_forever()

def nfc_scan_loop():
    global latest_card
    GET_UID = [0xFF, 0xCA, 0x00, 0x00, 0x00]
    
    print("NFC Scanner loop started...")
    
    while True:
        try:
            r = readers()
            if len(r) == 0:
                time.sleep(2)
                continue

            reader = r[0]
            connection = reader.createConnection()
            
            try:
                connection.connect()
                data, sw1, sw2 = connection.transmit(GET_UID)
                
                if sw1 == 0x90 and sw2 == 0x00:
                    card_id = binascii.hexlify(bytearray(data)).decode('utf-8').upper()
                    current_time = time.time()
                    
                    # 同じカードが連続で読まれた場合のクールダウン処理
                    if latest_card["card_id"] != card_id or (current_time - latest_card["timestamp"]) > COOLDOWN_SECONDS:
                        latest_card["card_id"] = card_id
                        latest_card["timestamp"] = current_time
                        print(f"Card scanned: {card_id}")
                    
                    time.sleep(1) # 一度読んだら少し休む
            except (NoCardException, CardConnectionException):
                time.sleep(0.5)
            except Exception:
                time.sleep(0.5)

        except Exception as e:
            time.sleep(2)

if __name__ == "__main__":
    # HTTPサーバーを別スレッドで起動
    server_thread = threading.Thread(target=start_http_server, daemon=True)
    server_thread.start()
    
    # NFC読み取りループをメインスレッドで実行
    nfc_scan_loop()
