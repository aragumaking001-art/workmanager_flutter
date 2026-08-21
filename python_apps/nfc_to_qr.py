import tkinter as tk
from tkinter import ttk
import threading
import time
import binascii
import qrcode
from PIL import Image, ImageTk
import sys
import os
import pyautogui # 追加: キーボード入力用

from smartcard.System import readers
from smartcard.util import toHexString
from smartcard.Exceptions import NoCardException, CardConnectionException

class NFCScannerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("NFC to QR Scanner")
        self.root.geometry("450x650")
        self.root.configure(bg="#2C3E50")

        self.label_title = tk.Label(root, text="NFCカード(社員証)をかざしてください", font=("Helvetica", 14, "bold"), fg="white", bg="#2C3E50")
        self.label_title.pack(pady=20)

        # モード切替UI
        self.mode_var = tk.StringVar(value="qr")
        
        mode_frame = tk.Frame(root, bg="#2C3E50")
        mode_frame.pack(pady=10)
        
        style = ttk.Style()
        style.configure("TRadiobutton", background="#2C3E50", foreground="white", font=("Helvetica", 12))
        
        rb_qr = ttk.Radiobutton(mode_frame, text="タブレット用 (QR出力)", variable=self.mode_var, value="qr", command=self.reset_ui)
        rb_qr.pack(side=tk.LEFT, padx=10)
        
        rb_kb = ttk.Radiobutton(mode_frame, text="PC用 (キーボード自動入力)", variable=self.mode_var, value="keyboard", command=self.reset_ui)
        rb_kb.pack(side=tk.LEFT, padx=10)

        self.qr_label = tk.Label(root, bg="#2C3E50")
        self.qr_label.pack(expand=True)

        self.label_id = tk.Label(root, text="ID: 待機中...", font=("Helvetica", 16, "bold"), fg="#1ABC9C", bg="#2C3E50")
        self.label_id.pack(pady=10)

        self.reset_button = tk.Button(root, text="次のカードを読み取る (リセット)", font=("Helvetica", 12, "bold"), bg="#3498DB", fg="white", state=tk.DISABLED, command=self.manual_reset)
        self.reset_button.pack(pady=10)

        self.running = True
        self.waiting_for_reset = False
        self.nfc_thread = threading.Thread(target=self.nfc_scan_loop, daemon=True)
        self.nfc_thread.start()

    def process_card(self, card_id):
        mode = self.mode_var.get()
        
        if mode == "qr":
            # Generate QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=12,
                border=4,
            )
            qr.add_data(card_id)
            qr.make(fit=True)
            img = qr.make_image(fill_color="black", back_color="white")
            
            # Resize for display
            img = img.resize((300, 300), Image.Resampling.LANCZOS)
            self.tk_img = ImageTk.PhotoImage(img)
            
            self.qr_label.config(image=self.tk_img)
            self.label_id.config(text=f"読取成功 ID: {card_id}", fg="#F1C40F")
            self.label_title.config(text="QRコード生成完了！", fg="#F1C40F")
            
        elif mode == "keyboard":
            self.qr_label.config(image='')
            self.label_id.config(text=f"入力完了 ID: {card_id}", fg="#F1C40F")
            self.label_title.config(text="キーボード入力を送信しました", fg="#F1C40F")
            
            # PCへのキーボード入力の送信
            pyautogui.write(card_id)
            pyautogui.press('enter')

        if mode == "qr":
            self.reset_button.config(state=tk.NORMAL)
            self.waiting_for_reset = True
        elif mode == "keyboard":
            self.waiting_for_reset = True
            self.root.after(1500, self.manual_reset)

    def manual_reset(self):
        self.waiting_for_reset = False
        self.reset_button.config(state=tk.DISABLED)
        self.reset_ui()

    def nfc_scan_loop(self):
        # PC/SC Command to get UID/IDm
        GET_UID = [0xFF, 0xCA, 0x00, 0x00, 0x00]
        
        while self.running:
            if self.waiting_for_reset:
                time.sleep(0.5)
                continue

            try:
                r = readers()
                if len(r) == 0:
                    self.root.after(0, self.show_error, "PC/SC対応のNFCリーダーが見つかりません。")
                    time.sleep(3)
                    continue

                reader = r[0]
                connection = reader.createConnection()
                
                try:
                    connection.connect()
                    data, sw1, sw2 = connection.transmit(GET_UID)
                    
                    if sw1 == 0x90 and sw2 == 0x00:
                        # Success
                        card_id = binascii.hexlify(bytearray(data)).decode('utf-8').upper()
                        self.root.after(0, self.process_card, card_id)
                        
                        # Once success, the process_card will set waiting_for_reset = True, 
                        # so the next loop iteration will sleep until manual reset.
                        time.sleep(1)
                except (NoCardException, CardConnectionException):
                    # No card present, just wait and loop
                    time.sleep(0.5)
                except Exception as inner_e:
                    # Some other connection error (e.g. card removed mid-read)
                    time.sleep(0.5)

            except Exception as e:
                self.root.after(0, self.show_error, f"予期せぬエラー: {str(e)}")
                time.sleep(3)

    def reset_ui(self):
        self.qr_label.config(image='')
        self.label_title.config(text="NFCカード(社員証)をかざしてください", fg="white")
        self.label_id.config(text="ID: 待機中...", fg="#1ABC9C")

    def show_error(self, error_msg):
        self.label_title.config(text="NFCリーダー 待機中...", fg="#E74C3C")
        self.label_id.config(
            text=error_msg, 
            font=("Helvetica", 10),
            fg="#E74C3C"
        )

if __name__ == "__main__":
    root = tk.Tk()
    app = NFCScannerApp(root)
    root.mainloop()
