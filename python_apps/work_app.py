import flet as ft
import sqlite3
import time
import asyncio
from datetime import datetime, timedelta
import os
import sys
import pandas as pd
import math # 作業時間計算用に追加
import random
import serial
import serial.tools.list_ports
import winsound
import ctypes
from ctypes import wintypes
import threading

# --- 効果音の設定 ---
# ランダム再生をオフにして、常に success.wav だけを鳴らす場合はここを False に変更します
ENABLE_RANDOM_SUCCESS_SOUND = True



try:
    # Windows 10/11で高解像度ディスプレイ使用時に文字をクッキリさせる設定
    ctypes.windll.shcore.SetProcessDpiAwareness(1)
except:
    ctypes.windll.user32.SetProcessDPIAware()

# 💡 追加：Windowsに接続されている全モニターの位置とサイズを自動取得して、左から右へ並び替える関数
def get_monitor_positions():
    monitors = []
    MonitorEnumProc = ctypes.WINFUNCTYPE(
        ctypes.c_int, ctypes.c_ulong, ctypes.c_ulong, ctypes.POINTER(wintypes.RECT), ctypes.c_double)

    def callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
        rect = lprcMonitor.contents
        monitors.append({
            "x": rect.left, 
            "y": rect.top, 
            "width": rect.right - rect.left, 
            "height": rect.bottom - rect.top
        })
        return 1

    ctypes.windll.user32.EnumDisplayMonitors(0, 0, MonitorEnumProc(callback), 0)
    # X座標の小さい順（左から右）に並び替え
    monitors.sort(key=lambda m: m["x"])
    return monitors


# --- 【修正ポイント1】 main 関数をシンプルにする ---
def main(page: ft.Page):
    # 1. フォントの登録
    page.fonts = {
        "NotoSansJP": "NotoSansJP-VariableFont_wght.ttf",
        "Material Icons": "MaterialIcons-Regular.ttf", 
        "Emoji": "/TwemojiMozilla.ttf",
    }
    
    page.theme = ft.Theme(font_family="NotoSansJP")

    # 💡 【重要】ここで確実に [ 0 ] や [ 1 ] を使って「1つのモニター情報」を取り出す！
    monitors = get_monitor_positions()
    
    if len(monitors) >= 2:
        target_monitor = monitors[ 1 ]  # モニターが2つ以上なら右側を選択
    else:
        target_monitor = monitors[ 0 ]  # モニターが1つしかない場合はそれを使う

    # --- 🖥️ 自動モニター判別によるフルスクリーン設定 ---
    try:
        page.window.title_bar_hidden = True
        page.window.frameless = True
        # 💡 固定の数値ではなく、右側のモニターの座標とサイズを自動適用
        page.window.left = target_monitor["x"]
        page.window.top = target_monitor["y"]
        page.window.width = target_monitor["width"]
        page.window.height = target_monitor["height"]
    except AttributeError:
        page.window_title_bar_hidden = True
        page.window_frameless = True
        page.window_left = target_monitor["x"]
        page.window_top = target_monitor["y"]
        page.window_width = target_monitor["width"]
        page.window_height = target_monitor["height"]

    # アプリのコンテンツを先に読み込む
    app_instance = WorkApp(page)
    
    # 💡 クラス側にモニター情報を渡しておく
    app_instance.target_monitor = target_monitor
    
    page.update()
    
# NFC用のライブラリを冒頭にまとめる
from smartcard.System import readers
from smartcard.util import toHexString

class WorkApp:
    def __init__(self, page: ft.Page):
        self.page = page
        self.page.title = "和気センター WorkManager Registration"
        self.page.theme_mode = ft.ThemeMode.DARK
        self.page.bgcolor = "#1A1A1A"
        
        # 1. 最初にスプラッシュ画面（アニメーション）を表示
        self.page.run_task(self.show_splash_and_init)

    async def show_splash_and_init(self):
        # 💡 ここにあった手動の座標移動（1920）は削除し、初期設定の座標を信じる
        self.page.update()
        
        await asyncio.sleep(0.5)
        
        # 指定されたモニター（右画面）の中で最大化
        try:
            self.page.window.state = ft.WindowState.MAXIMIZED
        except AttributeError:
            self.page.window_state = "maximized"
        self.page.update()
        # ---------------------------------------------------------

        loading_text = ft.Text("System Initializing...", color="#00ccff", size=16, italic=True)
        progress_bar = ft.ProgressBar(width=400, color="#00ccff", bgcolor="#333333", value=0)
    
        # ネオンタイトル
        # 修正ポイント：TypeErrorを避けるためstyleの中にBoxShadowを入れ、
        # 属性エラーを避けるため type=ft.ShadowType.OUTER を削除
        neon_title = ft.Text(
            "和気センター WorkManager",
            size=55,
            weight="bold",
            color="white",
            style=ft.TextStyle(
                shadow=ft.BoxShadow(
                    spread_radius=15,
                    blur_radius=25,
                    color=ft.Colors.with_opacity(0.6, "#00ccff"),
                    # type=ft.ShadowType.OUTER  <-- この行を削除
                )
            )
        )

        splash_content = ft.Container(
            content=ft.Column([
                ft.Container(
                    content=neon_title,
                    animate_opacity=1500,
                    opacity=0,
                ),
                ft.Container(height=40),
                ft.ProgressRing(width=60, height=60, stroke_width=6, color="#00ccff"),
                ft.Container(height=30),
                ft.Column([
                    loading_text,
                    ft.Container(height=10),
                    progress_bar,
                ], horizontal_alignment="center")
            ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment="center"),
            expand=True,
            alignment=ft.alignment.center,
            gradient=ft.LinearGradient(
                begin=ft.alignment.top_left,
                end=ft.alignment.bottom_right,
                colors=["#1A1C23", "#08090A"]
            )
        )
        
        # 自作スプラッシュ画面を描画
        self.page.add(splash_content)
        self.page.update()

        # --- 【修正2】 ここで PyInstaller のスプラッシュを閉じる ---
        # Flet の画面が描画されたので、ネイティブ画像を消す
        if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
            try:
                import pyi_splash
                pyi_splash.close()
            except ImportError:
                pass
        
        # タイトルをふわっと表示
        await asyncio.sleep(0.2)
        splash_content.content.controls[0].opacity = 1
        self.page.update()

        # --- 初期化プロセス ---
        # Step 1: データベース
        loading_text.value = "Connecting to Database..."
        progress_bar.value = 0.2
        self.page.update()
        self.db_path = "work_data.db"
        self.init_db()
        await asyncio.sleep(0.3)

        # Step 2: ハードウェア
        loading_text.value = "Initializing Arduino & NFC Reader..."
        progress_bar.value = 0.5
        self.page.update()
        self.arduino = self.init_arduino()
        await asyncio.sleep(0.3)

        # Step 3: マスターデータ
        loading_text.value = "Loading Master Data (Members & Models)..."
        progress_bar.value = 0.8
        self.page.update()
        self.load_masters()
        await asyncio.sleep(0.4)

        # Step 4: 完了
        loading_text.value = "System Ready."
        loading_text.color = ft.Colors.GREEN_ACCENT
        progress_bar.value = 1.0
        self.page.update()
        await asyncio.sleep(0.5)

        # 3. 準備が整ったらUIコンポーネントを初期化
        self.initialize_ui_components()
        
        # 4. ★重要：スプラッシュを消して、組み立てたStackを1回だけ追加
        self.page.clean()
        self.page.add(self.layout_stack) # ここでStackを追加
        self.show_main_view() # main_viewの中にコンテンツを流し込む
        self.page.update()
        
        # 5. ループを開始
        self.page.run_task(self.refresh_loop)
        self.page.run_task(self.nfc_monitor_loop)

    def initialize_ui_components(self):
        self.processing_lock = False
        self.page.on_keyboard_event = self.on_key_down
        
        # 3秒ごとにこのアプリを最前面に持ってくる処理を開始
        threading.Thread(target=self.keep_focus_work_app, daemon=True).start()
        
        
        self.status = "IDLE" 
        self.input_buffer = ""
        self.my_worker_id = ""
        self.my_worker_name = ""
        self.reg_data = {"model": "", "abbr": "", "maker": "", "air": 0, "clean": 0, "swap": 0, "ng": 0}
        
        self.msg_label = ft.Text("", size=48, weight="bold", color="white", text_align="center")
        self.live_input_label = ft.Text("", size=100, color="#00ccff", text_align="center", weight="w900")
        
        
        
        self.history_row = ft.Row(alignment="center", spacing=30)
        self.active_list = ft.GridView(
            expand=True, runs_count=3, spacing=10, run_spacing=10,
            child_aspect_ratio=5.0, animate_size=100 
        )

        # 1. 画像パーツの定義
        self.lucky_popup_img = ft.Container(
            content=ft.Image(src="lucky_popup.png", width=800, height=600, fit=ft.ImageFit.CONTAIN),
            alignment=ft.alignment.center,
            bgcolor=ft.Colors.with_opacity(0.8, "#000000"),
            expand=True,
            visible=False,
            animate_opacity=500,
        )

        # 2. メインビュー（土台）の定義
        self.main_view = ft.Container(expand=True)

        # 3. その他パーツ（ダイアログ、フォーム）の初期化
        # TextField をやめて Text コンテナに変更します
        self.fix_hour_val = ""
        self.fix_min_val = ""
        self.fix_current_focus = "hour" # "hour" or "min"

        self.fix_hour_label = ft.Text("", size=60, color="white", weight="bold")
        self.fix_minute_label = ft.Text("", size=60, color="white", weight="bold")

        self.fix_hour_container = ft.Container(
            content=self.fix_hour_label,
            width=150, height=100,
            alignment=ft.alignment.center,
            border=ft.border.all(3, "#00ccff"),
            border_radius=10,
            bgcolor="#1A1C23"
        )
        self.fix_minute_container = ft.Container(
            content=self.fix_minute_label,
            width=150, height=100,
            alignment=ft.alignment.center,
            border=ft.border.all(1, "#33363F"),
            border_radius=10,
            bgcolor="#1A1C23"
        )

        self.fix_error_msg = ft.Text("", color="red", size=24, weight="bold")
        

        self.cancel_dlg_target_id = ""
        self.cancel_dlg_text = ft.Text("", size=20)
        self.btn_yes = ft.TextButton("はい (削除)", on_click=self.do_cancel_session)
        self.btn_no = ft.TextButton("いいえ", on_click=self.close_cancel_dialog)
        self.cancel_dialog = ft.AlertDialog(title=ft.Text("削除確認"), content=self.cancel_dlg_text, actions=[self.btn_yes, self.btn_no])
        self.page.overlay.append(self.cancel_dialog)
        
        self.alert_dlg_val = "" 
        self.alert_dialog_text = ft.Text("", size=20)
        self.alert_dialog = ft.AlertDialog(
            title=ft.Text("⚠️ 台数の再確認", color=ft.Colors.ORANGE_ACCENT, weight="bold"),
            content=self.alert_dialog_text,
            actions=[
                ft.ElevatedButton("正しい (緑ボタン)", on_click=self.confirm_alert_value, bgcolor=ft.Colors.GREEN_800, color="white"),
                ft.ElevatedButton("やり直す (赤ボタン)", on_click=self.close_alert_dialog, bgcolor=ft.Colors.RED_800, color="white"),
            ],
            modal=True, # 💡 枠外をクリックしても閉じないように設定
        )
        self.page.overlay.append(self.alert_dialog)
        
        # --- クレジット（システム情報）ダイアログの定義 ---
        self.credit_dialog = ft.AlertDialog(
            title=ft.Text("SYSTEM INFO", weight="bold", color="#00ccff", font_family="Emoji"),
            content=ft.Column([
                ft.Text("和気センター WorkManager", weight="bold", size=20, color="white"),
                ft.Text("Version: 1.0.0", color=ft.Colors.GREY_500, size=14),
                ft.Divider(color="#33363F", height=20, thickness=2),
                ft.Text("■ LICENSE", weight="bold", color="#FFD700"),
                ft.Text("Audio Engine: VOICEVOX:ずんだもん", color="#00ffcc", weight="bold", size=18),
                ft.Text("UI Framework: Flet / Python", color=ft.Colors.GREY_500, size=14),
            ], tight=True, spacing=5),
            actions=[
                ft.TextButton("CLOSE", on_click=self.close_credit_dialog)
            ],
            bgcolor="#1A1C23",
            shape=ft.RoundedRectangleBorder(radius=15),
        )
        self.page.overlay.append(self.credit_dialog)
        

       # 4. ★重要：Stackを組み立てる
        self.layout_stack = ft.Stack([
            self.main_view,
            self.lucky_popup_img,
            # 右上の閉じるボタン
            ft.Container(
                content=ft.IconButton(
                    icon=ft.Icons.CLOSE,
                    icon_color=ft.Colors.with_opacity(0.3, "white"),
                    icon_size=30,
                    on_click=lambda _: self.page.window.close(), 
                    tooltip="アプリを終了する",
                ),
                top=10,
                right=10,
            ),
            # ★新規追加：右下のインフォメーションボタン
            ft.Container(
                content=ft.IconButton(
                    icon=ft.Icons.INFO_OUTLINE,
                    icon_color=ft.Colors.with_opacity(0.3, "white"),
                    icon_size=30,
                    on_click=self.open_credit_dialog,
                    tooltip="システム情報・ライセンス",
                ),
                bottom=10,
                right=10,
            ),
        ], expand=True)
        
    def init_arduino(self):
        try:
            # 接続されているポート一覧を取得
            ports = list(serial.tools.list_ports.comports())
            for p in ports:
                # どんな名前で認識されているか確認（デバッグ用）
                print(f"Port Found: {p.device} - {p.description}")
                
                # 判定条件を大幅に緩める
                # "Arduino", "USB Serial" に加え、日本語の "USB シリアル", "USBシリアル" も対象に含める
                targets = ["Arduino", "USB Serial", "USB シリアル", "USBシリアル", "CH340"]
                if any(x.lower() in p.description.lower() for x in targets):
                    ser = serial.Serial(p.device, 9600, timeout=1)
                    time.sleep(2) # 接続安定待ち
                    return ser
            
            # --- 【最終手段】もし上記で見つからなかった場合、1つでもポートがあればそれに繋ぐ ---
            if len(ports) > 0:
                # COM1などはPC標準ポートの可能性があるため、COM3以降などを優先的に選ぶロジック
                # ここではシンプルに最後に見つかったポートを試す
                p = ports[-1]
                ser = serial.Serial(p.device, 9600, timeout=1)
                time.sleep(2)
                return ser

        except Exception as e:
            print(f"Arduino接続失敗: {e}")
            return None
        return None

    def send_to_arduino(self, char):
        if self.arduino and self.arduino.is_open:
            try:
                self.arduino.write(char.encode())
            except:
                pass


    # --- NFC 監視ループ (インデント修正済み) ---
    # --- NFC 監視ループ ---
    async def nfc_monitor_loop(self):
        while True:
            try:
                r = await asyncio.to_thread(readers) 
                if len(r) > 0:
                    reader = r [0]
                    connection = reader.createConnection()
                    await asyncio.to_thread(connection.connect)
                    
                    try:
                        GET_DATA = [0xFF, 0xCA, 0x00, 0x00, 0x00]
                        # 通信部分をスレッド化
                        data, sw1, sw2 = await asyncio.to_thread(connection.transmit, GET_DATA)
                        
                        if sw1 == 0x90 and sw2 == 0x00:
                            idm = toHexString(data).replace(" ", "")
                            self.process_nfc_id(idm)
                    finally:
                        # ★ここが最重要：読み取りが終わったら必ず切断してリソースを解放する！
                        try:
                            await asyncio.to_thread(connection.disconnect)
                        except:
                            pass
            except Exception:
                pass
            
            await asyncio.sleep(0.5)

    def process_nfc_id(self, idm):
        # --- 【修正】ロック中は何もしない（音も鳴らさない） ---
        if hasattr(self, 'processing_lock') and self.processing_lock:
            return

        # 音の再生判定
        try:
            if self.status == "INPUT":
                sound_path = os.path.join("assets", "model_touch.wav")
            else:
                sound_path = os.path.join("assets", "touch.wav")
            winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
        except Exception:
            winsound.Beep(2000, 200)

        # 判定処理へ飛ばす
        if self.status in ["IDLE", "FIX_SCAN_WORKER"]:
            self.handle_worker_scan(idm)
        elif self.status == "INPUT":
            # 入力バッファを一旦クリアしてからステップ入力へ（誤動作防止）
            self.input_buffer = ""
            self.handle_step_input(idm)
            
    def get_db_conn(self):
        if getattr(sys, "frozen", False):
            base_dir = os.path.dirname(sys.executable)
        else:
            base_dir = os.path.dirname(os.path.abspath(__file__))
        db_path = os.path.join(base_dir, "work_data.db")
        return sqlite3.connect(db_path, timeout=10.0)
    
    def on_window_event(self, e):
        # ウィンドウが閉じられる時の処理
        if e.data == "close":
            pass

    def init_db(self):
        conn = self.get_db_conn()
        # 1. テーブル作成（💡 location を追加）
        conn.execute("""CREATE TABLE IF NOT EXISTS unit_cleaning_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            location TEXT,
            work_date TEXT, worker_id TEXT, model_name TEXT, maker TEXT, maker_abbr TEXT, 
            category TEXT, 
            air_clean_qty INTEGER, 
            to_clean_qty INTEGER, 
            clean_qty INTEGER, to_swap_qty INTEGER, swap_qty INTEGER, 
            start_time_str TEXT, end_time_str TEXT, work_minutes INTEGER, created_at TEXT,
            sync_flag INTEGER DEFAULT 0,
            std_qty REAL, 
            lucky_flag TEXT,
            edit_count INTEGER DEFAULT 0,
            reserve_3 TEXT, reserve_4 TEXT, reserve_5 TEXT
        )""")

        # 作業中セッションテーブル
        conn.execute("""CREATE TABLE IF NOT EXISTS active_sessions (
            worker_id TEXT PRIMARY KEY, 
            start_time REAL,
            is_paused INTEGER DEFAULT 0,
            paused_at REAL DEFAULT 0
        )""")
        
        # 既存のDBにカラムがない場合のための追加処理
        try: conn.execute("ALTER TABLE active_sessions ADD COLUMN is_paused INTEGER DEFAULT 0")
        except: pass
        try: conn.execute("ALTER TABLE active_sessions ADD COLUMN paused_at REAL DEFAULT 0")
        except: pass
        
        # 2. カラム追加（既存のDBをアップデート）
        new_columns = [
            ("std_qty", "REAL"),
            ("lucky_flag", "TEXT"),
            ("maker_abbr", "TEXT"),
            ("edit_count", "INTEGER DEFAULT 0"),
            ("location", "TEXT DEFAULT 'A'")  # 💡 追加 (デフォルトはA拠点)
        ]
        for col_name, col_type in new_columns:
            try:
                conn.execute(f"ALTER TABLE unit_cleaning_logs ADD COLUMN {col_name} {col_type}")
            except sqlite3.OperationalError:
                pass # すでに存在すればOK

        # 今日のラッキー演出表示済みレコード
        conn.execute("CREATE TABLE IF NOT EXISTS lucky_history (date TEXT PRIMARY KEY, shown_id TEXT)")
        conn.commit()
        conn.close()

    def load_masters(self):
        # 1. メンバーマスターの読み込み
        self.members = {} 
        self.lucky_candidates = [] 
        
        # 💡 DB(m_members)から優先して読み込み、失敗したらCSVから読み込む
        try:
            conn = self.get_db_conn()
            df_members = pd.read_sql_query("SELECT * FROM m_members", conn)
            conn.close()
            
            if df_members is not None and not df_members.empty:
                id_col = next((c for c in ['社員番号', '従業員ID', 'worker_id', 'id'] if c in df_members.columns), None)
                if id_col:
                    for _, row in df_members.iterrows():
                        m_id = str(row[id_col]).strip()
                        name_col = '氏名' if '氏名' in df_members.columns else ('name' if 'name' in df_members.columns else df_members.columns[1])
                        self.members[m_id] = str(row[name_col]).strip()
                    self.lucky_candidates = sorted(list(self.members.keys()))
        except Exception as e:
            import traceback
            import sys
            import os
            try:
                log_path = os.path.join(os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__)), 'db_error.log')
                with open(log_path, 'w', encoding='utf-8') as f:
                    f.write(traceback.format_exc())
            except:
                pass
            print(f"DB Load Error (m_members): {e}. Fallback to CSV.")
            
        if not self.members and os.path.exists('members.csv'):
            try:
                df = pd.read_csv('members.csv', encoding='utf-8-sig')
                id_col = next((c for c in ['社員番号', '従業員ID'] if c in df.columns), None)
                if id_col:
                    for _, row in df.iterrows():
                        m_id = str(row[id_col]).strip()
                        name_col = '氏名' if '氏名' in df.columns else df.columns[1]
                        self.members[m_id] = str(row[name_col]).strip()
                    self.lucky_candidates = sorted(list(self.members.keys()))
            except Exception as e:
                print(f"CSV Load Error (members): {e}")

        # 2. 機種マスターの読み込み（一本化・NaN対策）
        self.models_db = {}
        
        # 💡 DB(m_models)から優先して読み込み、失敗したらCSVから読み込む
        try:
            conn = self.get_db_conn()
            df_models = pd.read_sql_query("SELECT * FROM m_models", conn)
            conn.close()
            
            if df_models is not None and not df_models.empty:
                for _, row in df_models.iterrows():
                    m_id = str(row['model_id']).strip()
                    target_val = row.get('std_qty')
                    std_qty = float(target_val) if pd.notnull(target_val) else 10.0
                    m_data = {
                        "name": str(row['model_name']).strip(),
                        "abbr": str(row.get('maker_abbr', '')).strip(),
                        "maker": str(row.get('maker', '不明')).strip(),
                        "cat": str(row.get('category', '未分類')).strip(),
                        "work_type": str(row.get('work_type', '清掃')).strip(),
                        "std_qty": std_qty 
                    }
                    self.models_db[m_id] = m_data
                    self.models_db[m_data["name"]] = m_data 
        except Exception as e:
            import traceback
            import sys
            import os
            try:
                log_path = os.path.join(os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__)), 'db_error_models.log')
                with open(log_path, 'w', encoding='utf-8') as f:
                    f.write(traceback.format_exc())
            except:
                pass
            print(f"DB Load Error (m_models): {e}. Fallback to CSV.")
            
        if not self.models_db and os.path.exists('model_name.csv'):
            try:
                # 機種名が入っている行だけを読み込み
                df = pd.read_csv('model_name.csv', encoding='utf-8-sig').dropna(subset=['機種名'])
                
                for _, row in df.iterrows():
                    m_id = str(row['機種番号']).strip()
                    
                    # 💡 CSVの「1時間標準作業台数」列から値を取得。無ければ 10.0
                    target_val = row.get('1時間標準作業台数')
                    std_qty = float(target_val) if pd.notnull(target_val) else 10.0
                    m_data = {
                        "name": str(row['機種名']).strip(),
                        "abbr": str(row['メーカー略称']).strip(),
                        "maker": str(row.get('メーカー', '不明')).strip(),
                        "cat": str(row.get('分類', '未分類')).strip(),
                        "work_type": str(row.get('作業内容', '清掃')).strip(),
                        "std_qty": std_qty 
                    }
                    
                    # IDと機種名の両方で引けるように辞書へ登録
                    self.models_db[m_id] = m_data
                    self.models_db[m_data["name"]] = m_data 
                
                print(f"Master Loaded: {len(self.models_db)} models.")
            except Exception as e:
                print(f"CSV Load Error (models): {e}")

    def show_main_view(self):
        self.status = "IDLE"
        self.input_buffer = ""
        self.main_view.bgcolor = "#1A1A1A"
        self.main_view.content = ft.Container(
            padding=20,
            content=ft.Row([
                ft.Container(
                    content=ft.Column([
                        ft.Icon(ft.Icons.SENSORS, size=100, color="#00ccff"),
                        self.msg_label,
                        ft.Text("作業開始・終了時", size=16, color=ft.Colors.GREY_500),
                        ft.Text("担当者カードをタッチして下さい", size=16, color=ft.Colors.GREY_500),
                        ft.Container(content=self.live_input_label, padding=5)
                    ], horizontal_alignment="center", alignment="center", spacing=10), 
                    expand=3, bgcolor="#242424", border_radius=20, padding=30
                ),
                ft.Container(
                    content=ft.Column([
                        ft.Row([
                            ft.Icon(ft.Icons.PEOPLE, color="#FFD700", size=30), 
                            ft.Text(" 現在作業中", size=28, weight="bold", color="#FFD700")
                        ], alignment="center"), 
                        ft.Divider(color="#33363F", thickness=2), 
                        self.active_list
                    ]), 
                    expand=9, bgcolor="#14161E", padding=20, border_radius=20
                )
            ], spacing=20)
        )
        self.msg_label.value = "CARD TOUCH"
        self.msg_label.size = 32
        self.msg_label.color = "white"
        self.live_input_label.size = 60 
        
        # 画面構築と同時にリストを最新化
        self.refresh_active_list()
        self.page.update()
        
    def refresh_active_list(self):
        """作業中リストの描画"""
        # ★修正：不要な複雑なロックを廃止（refresh_loopが一元管理するため不要になりました）
        try:
            conn = self.get_db_conn()
            actives = conn.execute("SELECT worker_id, start_time, is_paused, paused_at FROM active_sessions").fetchall()
            conn.close()
            
            new_states = {}
            items = []
            new_time_labels = {} 

            for wid, st, is_paused, paused_at in actives:
                new_states[wid] = is_paused
                
                # 一時停止中なら停止した時刻、動いていれば現在時刻で計算
                calc_ts = paused_at if is_paused else time.time()
                status_sec, is_breaking = self.get_timer_status_custom(st, calc_ts)
                status_sec, _ = self.get_timer_status_custom(st, calc_ts)
                
                worker_name = self.members.get(wid, wid)
                
                # --- 表示スタイルの決定 ---
                # 1. 色の決定（優先順位：休憩中(オレンジ) > 一時停止(グレー) > 通常(水色)）
                if is_breaking:
                    text_color = ft.Colors.ORANGE_400
                    bg_color = "#1E2129"
                    border_color = ft.Colors.ORANGE_700
                elif is_paused:
                    text_color = ft.Colors.GREY_500
                    bg_color = "#111217"
                    border_color = ft.Colors.RED_700
                else:
                    text_color = "#00ccff"
                    bg_color = "#1E2129"
                    border_color = "#33363F"

                # 2. テキストの決定
                status_suffix = ""
                if is_breaking:
                    status_suffix = ""
                elif is_paused:
                    status_suffix = " (停止中)"
                
                # 時間ラベルの作成
                display_time = self.format_time(status_sec)
                lbl = ft.Text(display_time, color=text_color, size=24, weight="bold")
                new_time_labels[wid] = lbl
                
                # リストアイテム（カード）の組み立て
                items.append(
                    ft.GestureDetector(
                        content=ft.Container(
                            content=ft.Row([
                                ft.Text(f"{worker_name}{status_suffix}", 
                                        size=24, weight="bold", expand=True, 
                                        color="white" if not (is_paused or is_breaking) else ft.Colors.GREY_400),
                                lbl
                            ], alignment="spaceBetween"),
                            bgcolor=bg_color, 
                            padding=ft.Padding(15, 5, 15, 5), 
                            border_radius=8,
                            border=ft.border.all(1, border_color),
                        ),
                        on_tap=lambda e, w_id=wid: self.toggle_pause(w_id),
                        on_long_press_start=lambda e, w_id=wid, w_name=worker_name: self.open_cancel_dialog(w_id, w_name),
                        on_secondary_tap=lambda e, w_id=wid, w_name=worker_name: self.open_cancel_dialog(w_id, w_name),
                    )
                )
            
            self.time_labels = new_time_labels
            self.active_list.controls = items
            
            if self.active_list.page:
                self.active_list.update()
                self.page.update()
            
            self.current_active_states = new_states
            
        except Exception as e:
            print(f"Refresh Error: {e}")
        finally:
            self.is_refreshing_list = False

    def toggle_pause(self, worker_id):
        """タイマーの一時停止/再開を切り替える（即時レスポンス版）"""
        # ★連打防止ロック（一瞬の間に2回押されてバグるのを防ぐ）
        if getattr(self, "is_toggling", False):
            return
        self.is_toggling = True

        try:
            conn = self.get_db_conn()
            row = conn.execute("SELECT is_paused, start_time, paused_at FROM active_sessions WHERE worker_id=?", (worker_id,)).fetchone()
            
            if row:
                # ★ここも [ 0 ] を使って正確に取り出す
                is_paused = row[ 0 ]
                start_time = row[ 1 ]
                paused_at = row[ 2 ]
                
                now = time.time()
                calc_ts = paused_at if is_paused else now
                _, is_breaking = self.get_timer_status_custom(start_time, calc_ts)

                # 休憩中なら何もしない
                if is_breaking:
                    conn.close()
                    return
                
                if is_paused:
                    # 再開
                    pause_duration = now - paused_at
                    new_start_time = start_time + pause_duration
                    conn.execute("UPDATE active_sessions SET is_paused=0, start_time=?, paused_at=0 WHERE worker_id=?", 
                                 (new_start_time, worker_id))
                else:
                    # 一時停止
                    conn.execute("UPDATE active_sessions SET is_paused=1, paused_at=? WHERE worker_id=?", 
                                 (now, worker_id))
                
                conn.commit()
            conn.close()
            
            # ★修正: ループを待たずに、今すぐ自分でリストを再描画する！
            # これで「押した瞬間に色がグレーになる」という即時レスポンスが実現します。
            self.refresh_active_list()

        finally:
            # 処理が終わったらロック解除
            self.is_toggling = False

    def get_timer_status_custom(self, start_ts, end_ts):
        """指定された時刻までの実稼働時間を計算（休憩を除く）"""
        now_ts = end_ts
        breaks = [(10, 0, 5), (12, 0, 45), (15, 0, 10), (18, 30, 10)]
        start_dt, now_dt = datetime.fromtimestamp(start_ts), datetime.fromtimestamp(now_ts)
        today, total_break_sec, is_breaking = start_dt.date(), 0, False
        
        for h, m, duration in breaks:
            b_start = datetime.combine(today, datetime.min.time()).replace(hour=h, minute=m)
            b_end = b_start + timedelta(minutes=duration)
            
            # 今まさに休憩中か判定
            if b_start <= now_dt < b_end: 
                is_breaking = True
                
            # 休憩時間と作業時間が重なっている分を計算
            overlap_start, overlap_end = max(start_dt, b_start), min(now_dt, b_end)
            if overlap_start < overlap_end: 
                total_break_sec += (overlap_end - overlap_start).total_seconds()

        # ★重要：ここ（forループの外）で最終計算を行う！
        # 計算結果に 0.1 を足して、int による切り捨てでの「1秒戻り」を防ぐ
        final_sec = (now_ts - start_ts) - total_break_sec
        return int(max(0, final_sec + 0.1)), is_breaking









    def handle_worker_scan(self, worker_id):
        # ロック中は何もしない
        if hasattr(self, 'processing_lock') and self.processing_lock:
            return
        self.processing_lock = True

        # FIX判定用ID
        target_nfc_id = "04C514AA852190" #04C514AA852190
        
        # --- FIXモード（手入力モード）の開始 ---
        if worker_id.upper() == "FIX" or worker_id.upper() == target_nfc_id:
            self.status = "FIX_SCAN_WORKER"
            self.msg_label.value = "【担当者カード】をタッチ"
            self.msg_label.color = ft.Colors.ORANGE_400
            self.page.update()
            self.processing_lock = False 
            return

        # --- FIXモード中に担当者カードがスキャンされた時 ---
        if self.status == "FIX_SCAN_WORKER":
            if worker_id in self.members:
                # ★修正：セッションは作らず、フラグを保持して通常の入力フローへ
                self.my_worker_id = worker_id
                self.my_worker_name = self.members[worker_id]
                self.is_fix_mode = True  # 手入力フラグON
                self.is_lucky_session = False
                self.start_dynamic_registration() # 機種選択画面へ
                self.processing_lock = False
                return
            else:
                self.msg_label.value = "未登録です"
                self.msg_label.color = ft.Colors.RED_ACCENT_400
                self.page.update()
                async def fix_error_reset():
                    await asyncio.sleep(2)
                    self.show_main_view()
                    self.processing_lock = False
                self.page.run_task(fix_error_reset)
                return
        
        # 通常の開始・終了判定
        if worker_id not in self.members:
            try:
                sound_path = os.path.join("assets", "error.wav")
                winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
            except: winsound.Beep(500, 500)
            self.msg_label.value = "未登録です"
            self.msg_label.color = ft.Colors.RED_ACCENT_400
            self.page.update()
            async def delayed_reset():
                await asyncio.sleep(1)
                self.reset_main_msg()
                self.processing_lock = False 
            self.page.run_task(delayed_reset)
            return

        # 通常モード時は手入力フラグをOFFにする
        self.is_fix_mode = False




        # --- ラッキー判定 ---
        is_lucky = False
        today_str = datetime.now().strftime("%Y%m%d")
        
        # 1. 社員番号のリストを取得（常に同じ順序にするため sorted を使用）
        worker_ids = sorted(list(self.members.keys()))
        
        if worker_ids:
            # 2. 今日の日付を「種」にして、その日限定のランダムを生成
            rng = random.Random(today_str)
            
            # 3. ★ここがポイント：名簿の中から「今日のラッキーさん」を一人選出
            lucky_worker_id = None # rng.choice(worker_ids)
            # lucky_worker_id = "OFF"

        show_popup = False 
        if worker_id == lucky_worker_id:
            is_lucky = True
            self.is_lucky_session = True 
            
            # 今日の日付でDBチェック
            conn = self.get_db_conn()
            today_date = datetime.now().strftime("%Y-%m-%d")
            history = conn.execute("SELECT shown_id FROM lucky_history WHERE date=?", (today_date,)).fetchone()
            
            # ★テスト用：一度画像を見たい場合は or True を付けて強制表示
            # 本番運用時は or True を消してください
            if not history: 
                show_popup = True
                if not history: # 実際に記録がない時だけ挿入
                    conn.execute("INSERT OR REPLACE INTO lucky_history (date, shown_id) VALUES (?, ?)", (today_date, worker_id))
                    conn.commit()
            conn.close()

            if show_popup:
                # クラス末尾に定義したメソッドを呼び出す
                self.show_lucky_effect() 
            else:
                try: winsound.PlaySound(os.path.join("assets", "lucky.wav"), winsound.SND_FILENAME | winsound.SND_ASYNC)
                except: pass

        self.is_lucky_session = is_lucky
        worker_name = self.members[worker_id]
        conn = self.get_db_conn()
        existing = conn.execute("SELECT start_time FROM active_sessions WHERE worker_id=?", (worker_id,)).fetchone()
        
        if existing:
            # --- 終了処理 ---
            self.my_start_ts = existing[0]; self.my_worker_id, self.my_worker_name = worker_id, worker_name
            conn.execute("DELETE FROM active_sessions WHERE worker_id=?", (worker_id,)); conn.commit(); conn.close()
            self.refresh_active_list(); self.input_buffer = ""
            self.msg_label.value = f"{worker_name}さん！\nLUCKY DAY!" if is_lucky else f"{worker_name}さん 終了"
            self.msg_label.color = "#FFD700" if is_lucky else ft.Colors.GREEN_ACCENT_400
            self.page.update()
            async def wait_reg(): await asyncio.sleep(0.5 if show_popup else 0.0); self.start_dynamic_registration(); self.processing_lock = False
            self.page.run_task(wait_reg)
        else:
            # --- 開始処理 ---
            conn.execute("INSERT INTO active_sessions (worker_id, start_time) VALUES (?, ?)", (worker_id, time.time())); conn.commit(); conn.close()
            self.refresh_active_list()
            self.msg_label.value = f"{worker_name}さん！\nLUCKY DAY!" if is_lucky else f"{worker_name}さん 開始"
            self.msg_label.color = "#FFD700" if is_lucky else ft.Colors.GREEN_ACCENT_400
            self.page.update()
            async def dr(): await asyncio.sleep(1); self.reset_main_msg(); self.processing_lock = False
            self.page.run_task(dr)




    def get_timer_status(self, start_ts):
        """現在の実稼働秒数と休憩中フラグを返す"""
        now_ts = time.time()
        breaks = [(10, 0, 5), (12, 0, 45), (15, 0, 10), (18, 30, 10)]
        start_dt, now_dt = datetime.fromtimestamp(start_ts), datetime.fromtimestamp(now_ts)
        today, total_break_sec, is_breaking = start_dt.date(), 0, False
        for h, m, duration in breaks:
            b_start = datetime.combine(today, datetime.min.time()).replace(hour=h, minute=m)
            b_end = b_start + timedelta(minutes=duration)
            if b_start <= now_dt < b_end: is_breaking = True
            overlap_start, overlap_end = max(start_dt, b_start), min(now_dt, b_end)
            if overlap_start < overlap_end: total_break_sec += (overlap_end - overlap_start).total_seconds()
        return int(max(0, (now_ts - start_ts) - total_break_sec)), is_breaking

      
            
            
            
            
   
               
            
            
    async def refresh_loop(self):
        """1秒ごとにタイマー表示更新"""
        loop_count = 0
        while True:
            try:
                loop_count += 1
                if loop_count >= 60:
                    self.load_masters()
                    loop_count = 0
                    
                # ★修正：特定のステータスに関わらず、「アクティブリストが画面に存在している間」は常に描画する
                if getattr(self.active_list, "page", None):
                    conn = self.get_db_conn()
                    actives = conn.execute("SELECT worker_id, start_time, is_paused, paused_at FROM active_sessions").fetchall()
                    conn.close()

                    # ゴミ掃除
                    active_worker_ids = {str(row[ 0 ]) for row in actives}
                    keys_to_del = [wid for wid in self.time_labels if wid not in active_worker_ids]
                    for k in keys_to_del:
                        if k in self.time_labels:
                            del self.time_labels[k]

                    db_states = {str(row[ 0 ]): row[ 2 ] for row in actives}

                    if len(self.active_list.controls) != len(actives) or getattr(self, 'current_active_states', {}) != db_states:
                        self.refresh_active_list()
                    else:
                        current_break_states = {}

                        for row in actives:
                            wid = str(row[ 0 ])
                            st = row[ 1 ]
                            is_paused = row[ 2 ]
                            paused_at = row[ 3 ]
                            
                            if wid in self.time_labels:
                                calc_ts = paused_at if is_paused else time.time()
                                status_sec, is_breaking = self.get_timer_status_custom(st, calc_ts)
                                current_break_states[wid] = is_breaking
                                
                                new_time_str = self.format_time(status_sec)
                                
                                if is_breaking:
                                    new_time_str = f"休憩中 ( {new_time_str} )"
                                    self.time_labels[wid].color = ft.Colors.ORANGE_400
                                elif is_paused:
                                    self.time_labels[wid].color = ft.Colors.GREY_500
                                else:
                                    self.time_labels[wid].color = "#00ccff"

                                self.time_labels[wid].value = new_time_str

                        if self.active_list.page:
                            self.page.update()
                        
                        last_break_states = getattr(self, "last_break_states", {})
                        if last_break_states != current_break_states:
                            self.last_break_states = current_break_states
                            self.refresh_active_list()

            except Exception as e:
                print(f"Loop Error: {e}")
            
            await asyncio.sleep(1)




    def start_dynamic_registration(self):
        self.send_to_arduino('L') # LED消灯
        self.reg_step = "MODEL"
        # cat を追加
        self.reg_data = {"model": "", "abbr": "", "maker": "", "cat": "", "air": 0, "clean": 0, "swap": 0, "ng": 0}
        self.history_row.controls.clear()
        self.show_step_view("【機種名カード】をタッチ")

    def handle_step_input(self, val):
        # --- 1. 機種選択ステップ ---
        if self.reg_step == "MODEL":
            info = self.models_db.get(val)
            if not info:
                original_title = self.msg_label.value  # 💡 追加：元の文字を記憶しておく
                self.msg_label.value = "未登録の機種です"
                self.msg_label.color = ft.Colors.RED_ACCENT_400
                self.page.update()
                
                # 💡 追加：3秒後に元の文字に戻す裏タスク
                async def reset_model_error():
                    await asyncio.sleep(3)
                    # まだ機種入力画面のままだったら文字を戻す
                    if self.status == "INPUT" and self.reg_step == "MODEL":
                        self.msg_label.value = original_title
                        self.msg_label.color = "white"
                        self.page.update()
                
                self.page.run_task(reset_model_error)  # 💡 追加：裏タスクをスタートさせる
                return
            
            self.reg_data.update({
                 "model": info["name"], "abbr": info["abbr"], "maker": info["maker"], 
                 "cat": info["cat"], "work_type": info["work_type"],
                 "std_qty": info.get("std_qty", 10.0) 
            })

            self.history_row.controls.clear()
            abbr_disp = f" ({info['abbr']})" if info['abbr'] and str(info['abbr']).lower() != "nan" else ""
            self.history_row.controls.append(ft.Text(f"機種: {info['name']}{abbr_disp}", size=24, weight="bold", color="#00ccff"))
            
            if info["work_type"] == "エアー清掃":
                self.reg_step = "AIR"; self.show_step_view("エアー清掃台数を入力")
            elif info["work_type"] == "筐体交換":
                self.reg_step = "SWAP"; self.show_step_view("筐体交換台数を入力")
            else:
                self.reg_step = "CLEAN"; self.show_step_view("清掃台数を入力")
            return

        # --- 2. 共通：整数チェック ---
        if self.reg_step in ["CLEAN", "AIR", "SWAP", "NG"]:
            if not str(val).isdigit():
                original_title = self.msg_label.value
                self.msg_label.value = "整数で入力してください"
                self.msg_label.color = ft.Colors.RED_ACCENT_400
                self.page.update()
                async def reset_error_msg():
                    await asyncio.sleep(3)
                    if self.status == "INPUT":
                        self.msg_label.value = original_title
                        self.msg_label.color = "white"
                        self.page.update()
                self.page.run_task(reset_error_msg)
                return

        # --- 3. 効率判定ロジック (★ここを修正) ---
        # 手動モード(is_fix_mode)ではない時だけペースチェックを行う
        if self.reg_step in ["CLEAN", "AIR", "SWAP"] and not getattr(self, "is_fix_mode", False):
            if hasattr(self, 'my_start_ts'): # 安全策として属性チェック追加
                input_val = int(val)
                active_sec, _ = self.get_timer_status(self.my_start_ts)
                work_hour = active_sec / 3600
                std_qty = self.reg_data.get("std_qty", 10.0) 

                if work_hour > (1 / 60): 
                    actual_speed = input_val / work_hour
                    if actual_speed >= (std_qty * 2) or actual_speed <= (std_qty / 2):
                        self.alert_dlg_val = val
                        self.alert_dialog_text.value = (
                            f"現在のペース：{actual_speed:.1f} 台/時\n"
                            f"標準のペース：{std_qty:.1f} 台/時\n\n"
                            f"入力された【{val}台】は\n"
                            "標準台数と大きく異なります。よろしいですか？"
                        )
                        self.alert_dialog.open = True; self.page.update()
                        return

        # --- 4. ステップごとの確定処理 (★ここも修正) ---
        if self.reg_step == "CLEAN":
            self.proceed_to_ng(val)

        elif self.reg_step == "AIR":
            self.reg_data["air"] = int(val)
            self.history_row.controls.append(ft.Text(f"エアー: {val}台", size=24, weight="bold", color="white"))
            self.reg_step = "NG"; self.show_step_view("清掃行き台数を入力")

        elif self.reg_step == "SWAP":
            self.reg_data["swap"] = int(val)
            self.history_row.controls.append(ft.Text(f"交換: {val}台", size=24, weight="bold", color="white"))
            # 手入力モードなら時間入力へ、通常なら確認画面へ
            if getattr(self, "is_fix_mode", False):
                self.show_duration_input_view()
            else:
                self.show_confirm_view()

        elif self.reg_step == "NG":
            # (既存のNG入力チェックは維持)
            input_val = int(val or 0)
            if self.reg_data["work_type"] == "エアー清掃" and input_val >= 1000:
                self.alert_dlg_val = val
                self.alert_dialog_text.value = f"入力された【清掃行き: {input_val}台】は、間違いありませんか？"
                self.alert_dialog.open = True; self.page.update()
                return
            elif self.reg_data["work_type"] == "清掃" and input_val > self.reg_data["clean"]:
                self.alert_dlg_val = val
                self.alert_dialog_text.value = f"筐体交換行き({input_val}台)が、清掃台数を超えています。よろしいですか？"
                self.alert_dialog.open = True; self.page.update()
                return
            
            self.confirm_ng_value(val)

    def show_confirm_view(self):
        self.send_to_arduino('H') 
        self.status = "CONFIRM"
        self.main_view.bgcolor = "#1A1A1A"
        detail_items = []
        
        # ★作業時間の決定
        if getattr(self, "is_fix_mode", False):
            display_minutes = self.reg_data.get("fix_duration_min", 0)
        else:
            active_sec, _ = self.get_timer_status(self.my_start_ts)
            display_minutes = math.ceil(active_sec / 60)

        ng_label = "清掃行き" if self.reg_data.get("work_type") == "エアー清掃" else "筐体交換行き"
        confirm_items = [
            ("エアー清掃", "air", "#00ccff"),
            ("通常清掃", "clean", "#00ffcc"),
            ("筐体交換", "swap", ft.Colors.AMBER_400),
            (ng_label, "ng", ft.Colors.RED_ACCENT_400)
        ]

        for label, key, color in confirm_items:
            if self.reg_data.get(key, 0) > 0: 
                detail_items.append(self.create_confirm_row(label, self.reg_data[key], color))

        abbr_val = self.reg_data.get("abbr", "")
        if pd.isna(abbr_val) or str(abbr_val).lower() == "nan" or str(abbr_val).strip() == "":
            display_model_title = f"{self.reg_data['model']}"
        else:
            display_model_title = f"{self.reg_data['model']} ({abbr_val})"

        confirm_card = ft.Column([
            ft.Text("✅ 登録内容の確認", size=45, weight="bold", color="#00ffcc",font_family="Emoji"),
            ft.Text(f"担当者: {self.my_worker_name} | 作業時間: {display_minutes} 分", size=32, color="white", weight="bold"),
            ft.Container(
                content=ft.Column([
                    ft.Text(display_model_title, size=55, weight="w900"),
                    ft.Divider(height=20, color="#33363F", thickness=2),
                    ft.Column(detail_items, spacing=10, horizontal_alignment="center")
                ], horizontal_alignment="center"),
                bgcolor="#242424", padding=40, border_radius=20, 
                border=ft.border.all(3, "#444444"), 
                width=900
            ),
            ft.Row([
                ft.Container(content=ft.Column([ft.Text("確定", size=24, weight="bold")], horizontal_alignment="center"), bgcolor=ft.Colors.GREEN_800, padding=15, width=220, border_radius=15, on_click=lambda _: self.save_data()),
                ft.Container(content=ft.Column([ft.Text("修正", size=24, weight="bold")], horizontal_alignment="center"), bgcolor=ft.Colors.RED_800, padding=15, width=220, border_radius=15, on_click=lambda _: self.start_dynamic_registration())
            ], alignment="center", spacing=100)
        ], horizontal_alignment="center", alignment="center", spacing=20)

        self.main_view.content = ft.Stack([
            ft.Container(content=confirm_card, alignment=ft.Alignment(0, 0), expand=True),
            ft.Container(content=ft.IconButton(icon=ft.Icons.CLOSE, icon_color=ft.Colors.RED_400, icon_size=50, on_click=lambda _: self.show_main_view()), top=30, right=30)
        ])
        self.page.update()

    def save_data(self):
        self.send_to_arduino('L')
        conn = self.get_db_conn()
        now = datetime.now()
        
        std_qty = self.reg_data.get("std_qty", 10.0)
        is_lucky = getattr(self, 'is_lucky_session', False)
        lucky_val = "Lucky" if is_lucky else ""

        is_air = (self.reg_data.get("work_type") == "エアー清掃")
        to_clean_val = self.reg_data.get("ng", 0) if is_air else 0
        to_swap_val = self.reg_data.get("ng", 0) if not is_air else 0

        # ★手入力モードか通常モードかで保存する数値を切り替え
        if getattr(self, "is_fix_mode", False):
            duration_min = self.reg_data.get("fix_duration_min", 0)
            start_time_str = "00:00"
            end_time_str = "00:00"
            work_min = duration_min
        else:
            active_sec, _ = self.get_timer_status(self.my_start_ts)
            start_time_str = datetime.fromtimestamp(self.my_start_ts).strftime("%H:%M")
            work_min = math.ceil(active_sec / 60)
            end_time_str = now.strftime("%H:%M")

        # 💡 location に "A" を保存するように INSERT 文を修正
        conn.execute("""
            INSERT INTO unit_cleaning_logs (
                location, work_date, worker_id, model_name, maker, maker_abbr, category, 
                air_clean_qty, to_clean_qty, clean_qty, 
                to_swap_qty, swap_qty, 
                start_time_str, end_time_str, work_minutes, created_at, sync_flag,
                std_qty, lucky_flag, edit_count, reserve_3, reserve_4, reserve_5
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", 
            (
                "A", # 💡 拠点コード（B拠点のPCなら "B" に変更する）
                now.strftime("%Y/%m/%d"), self.my_worker_id, self.reg_data["model"], self.reg_data["maker"], self.reg_data.get("abbr", ""), self.reg_data.get("cat", "未分類"), 
                self.reg_data["air"], to_clean_val, self.reg_data["clean"], 
                to_swap_val, self.reg_data["swap"], 
                start_time_str, end_time_str, work_min, now.strftime("%Y-%m-%d %H:%M:%S"), 
                0, std_qty, lucky_val, 0, "", "", ""
            )
        )
        conn.commit()
        conn.close()
        
        # フラグをリセット
        self.is_lucky_session = False
        self.is_fix_mode = False 

        try:
            sound_name = "success.wav"
            if globals().get('ENABLE_RANDOM_SUCCESS_SOUND', True):
                r = random.random()
                if r < 0.7:
                    sound_name = "success.wav"
                elif r < 0.9:
                    sound_name = "success2.wav"
                else:
                    sound_name = "success3.wav"
            
            sound_path = os.path.join("assets", sound_name)
            winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
        except: pass

        self.status = "FINISHED"
        self.main_view.content = ft.Container(
            content=ft.Column([
                ft.Icon(ft.Icons.CHECK_CIRCLE, size=150, color="white"), 
                
                ft.Row([
                    ft.Text("✅", font_family="Emoji", size=80), 
                    ft.Text("登録完了", size=80, weight="bold", color="white")
                ], alignment="center", spacing=20) 
                
            ], alignment="center", horizontal_alignment="center"), 
            bgcolor="#2ecc71", 
            expand=True, 
            alignment=ft.Alignment(0, 0)
        )
        
        self.page.update()
        
        async def go_back():
            await asyncio.sleep(2)
            self.show_main_view()
        self.page.run_task(go_back)
        
    def go_back_step(self):
        self.send_to_arduino('L')
        # 最初の入力項目の場合は最初（機種選択）に戻る
        if self.reg_step in ["CLEAN", "AIR", "SWAP"]:
            self.start_dynamic_registration()
            
        elif self.reg_step == "NG":
            # 履歴から最後の項目（台数）を消す
            if len(self.history_row.controls) > 1:
                self.history_row.controls.pop()
            
            # 作業内容に合わせて1つ前のステップに戻る
            if self.reg_data["work_type"] == "エアー清掃":
                self.reg_step = "AIR"
                self.show_step_view("エアー清掃台数を入力")
            else:
                self.reg_step = "CLEAN"
                self.show_step_view("清掃台数を入力")
        
        self.input_buffer = ""
        self.live_input_label.value = "" 
        self.page.update()

    # --- UI制御・ユーティリティ ---
    def show_step_view(self, title):
        self.status = "INPUT"
        
        # タイトル設定
        self.msg_label.value = title
        self.msg_label.size = 55  # 少し大きくして視認性アップ
        self.msg_label.color = "white"
        
        # 入力中の文字表示
        self.live_input_label.value = self.input_buffer
        self.live_input_label.size = 140 # 数字をさらに大きく

        # メインビューの再構築
        self.main_view.content = ft.Container(
            padding=40,
            expand=True,
            content=ft.Column([
                # 1. 最上部：担当者名と指示タイトル
                ft.Column([
                    ft.Text(f"担当: {self.my_worker_name}", size=24, color=ft.Colors.GREY_500, weight="bold"),
                    ft.Container(height=10),
                    self.msg_label,
                ], horizontal_alignment="center"),
                
                # 2. 中央：入力値を画面のど真ん中に配置するための expand コンテナ
                ft.Container(
                    content=self.live_input_label,
                    alignment=ft.Alignment(0, 0), # コンテナ内の真ん中に配置
                    expand=True, # これが上下の余白を埋めて、他の要素を端に追いやります
                ),
                
                # 3. 下部：現在の入力状況（履歴）
                ft.Container(
                    content=ft.Column([
                        ft.Divider(color="#33363F", thickness=2),
                        ft.Text("--- 現在の入力内容 ---", size=20, color=ft.Colors.GREY_600, weight="bold"),
                        self.history_row
                    ], horizontal_alignment="center", spacing=15),
                    padding=20,
                    bgcolor="#14161E",
                    border_radius=20,
                    height=160
                )
            ], horizontal_alignment="center")
        )
        self.main_view.bgcolor = "#242424"
        self.page.update()
        
    def create_confirm_row(self, label, count, color): return ft.Row([ft.Text(f"{label}：", size=35, color=ft.Colors.GREY_300, weight="bold"), ft.Text(f"{count}", size=100, weight="w900", color=color), ft.Text(" 台", size=35, color=ft.Colors.GREY_300, weight="bold")], alignment="center", vertical_alignment="end")
    def on_key_down(self, e: ft.KeyboardEvent):
        # 1. 警告ダイアログ表示中の処理
        if self.alert_dialog.open:
            if e.key in ["Enter", "Numpad Enter"]:
                self.confirm_alert_value(None)
            elif e.key == "Escape":
                self.close_alert_dialog(None)
            return 

        # 2. Escapeキーの挙動
        if e.key == "Escape":
            
            if self.status == "IDLE":
                return  # 待機画面の時は何もしない（画面の再構築を防ぐ）
            
            if self.status == "INPUT" and getattr(self, "reg_step", "") == "MODEL":
                if getattr(self, "is_fix_mode", False):
                    self.status = "IDLE" 
                    self.is_fix_mode = False
                    self.show_main_view()
                    return
                
                if hasattr(self, 'my_worker_id') and self.my_worker_id:
                    conn = self.get_db_conn()
                    existing = conn.execute("SELECT 1 FROM active_sessions WHERE worker_id=?", (self.my_worker_id,)).fetchone()
                    if not existing and hasattr(self, 'my_start_ts'):
                        conn.execute("INSERT INTO active_sessions (worker_id, start_time) VALUES (?, ?)", 
                                     (self.my_worker_id, self.my_start_ts))
                        conn.commit()
                    conn.close()
                self.status = "IDLE" 
                self.show_main_view()
                return

            if self.status == "CONFIRM":
                self.start_dynamic_registration()
                return
            elif self.status == "INPUT":
                self.go_back_step()
                return
            elif self.status == "FIX_DURATION_INPUT":
                self.cancel_duration_input()
                return
            else:
                self.show_main_view()
                return

        # 3. Enterキーの挙動
        if e.key in ["Enter", "Numpad Enter"]:
            if self.status == "CONFIRM":
                self.save_data()
                return
            
            if self.status == "FIX_DURATION_INPUT":
                if self.fix_current_focus == "hour":
                    # 時から分へフォーカス移動
                    self.fix_current_focus = "min"
                    self.fix_hour_container.border = ft.border.all(1, "#33363F")
                    self.fix_minute_container.border = ft.border.all(3, "#00ccff")
                    self.page.update()
                else:
                    self.submit_duration_time()
                return

            if self.status == "INPUT":
                val = self.input_buffer
                self.input_buffer = ""
                self.live_input_label.value = "" 
                self.process_input(val)
            return

        # 4. 数字キー・テンキー・Backspace の処理
        if e.key == "Backspace":
            if self.status == "INPUT":
                self.input_buffer = self.input_buffer[ :-1 ]
                self.live_input_label.value = self.input_buffer
                self.page.update()
            
            elif self.status == "FIX_DURATION_INPUT":
                if self.fix_current_focus == "hour":
                    self.fix_hour_val = self.fix_hour_val[ :-1 ]
                    self.fix_hour_label.value = self.fix_hour_val
                elif self.fix_current_focus == "min":
                    # 分が空の状態でBackspaceを押したら、時に戻る
                    if len(self.fix_min_val) == 0:
                        self.fix_current_focus = "hour"
                        self.fix_hour_container.border = ft.border.all(3, "#00ccff")
                        self.fix_minute_container.border = ft.border.all(1, "#33363F")
                    else:
                        self.fix_min_val = self.fix_min_val[ :-1 ]
                        self.fix_minute_label.value = self.fix_min_val
                self.page.update()

        elif len(e.key) == 1 and e.key.isdigit() or (e.key.startswith("Numpad ") and len(e.key.split()) == 2):
            input_char = e.key.split()[ 1 ] if e.key.startswith("Numpad ") else e.key
            if input_char.isdigit():
                if self.status == "INPUT":
                    self.input_buffer += input_char
                    self.live_input_label.value = self.input_buffer
                    self.page.update()
                
                elif self.status == "FIX_DURATION_INPUT":
                    if self.fix_current_focus == "hour":
                        if len(self.fix_hour_val) < 2:
                            self.fix_hour_val += input_char
                            self.fix_hour_label.value = self.fix_hour_val
                    elif self.fix_current_focus == "min":
                        if len(self.fix_min_val) < 2:
                            self.fix_min_val += input_char
                            self.fix_minute_label.value = self.fix_min_val
                    self.page.update()
            
    def process_input(self, val):
        if self.status in ["IDLE", "FIX_SCAN_WORKER"]: 
            self.handle_worker_scan(val) # 引数は1つだけにする
        elif self.status == "INPUT": 
            self.handle_step_input(val)
    def submit_fix_time(self, e):
        try:
            h, m = int(self.fix_hour_input.value), int(self.fix_minute_input.value)
            now = datetime.now(); start_dt = now.replace(hour=h, minute=m, second=0, microsecond=0)
            if start_dt > now: start_dt = start_dt - timedelta(days=1)
            conn = self.get_db_conn(); conn.execute("INSERT OR REPLACE INTO active_sessions (worker_id, start_time) VALUES (?, ?)", (self.fix_target_id, start_dt.timestamp())); conn.commit(); conn.close(); self.show_main_view()
        except: pass
        
    def show_fix_form_view(self, worker_id):
        self.status = "FIX_TIME_FORM"
        self.fix_target_id = worker_id
        self.fix_target_name = self.members[worker_id]
        
        # --- Enterキーの挙動設定 ---
        self.fix_hour_input.value = ""
        self.fix_hour_input.on_submit = lambda _: (
            self.fix_minute_input.focus() if self.fix_hour_input.value != "" 
            else self.fix_hour_input.focus()
        )
        
        self.fix_minute_input.value = ""
        self.fix_minute_input.on_submit = lambda _: (
            self.submit_fix_time(None) if self.fix_minute_input.value != "" 
            else self.fix_hour_input.focus()
        )
        
        self.fix_error_msg.value = ""
        
        # --- UI構築（ここを省略せずに全部書く必要があります） ---
        self.main_view.content = ft.Container(
            content=ft.Column([
                ft.Icon(ft.Icons.ACCESS_TIME, size=80, color=ft.Colors.ORANGE_400),
                ft.Text(f"【開始時刻の入力】", size=32, weight="bold", color=ft.Colors.ORANGE_400),
                ft.Text(f"担当: {self.fix_target_name} さん", size=44, weight="bold"),
                ft.Row([
                    ft.Column([
                        self.fix_hour_input, 
                        ft.Text("時", size=20, color="#00ccff")
                    ], horizontal_alignment="center"),
                    ft.Text("：", size=60, weight="bold"),
                    ft.Column([
                        self.fix_minute_input, 
                        ft.Text("分", size=20, color="#00ccff")
                    ], horizontal_alignment="center")
                ], alignment="center", spacing=20),
                self.fix_error_msg,
                ft.Row([
                    ft.ElevatedButton("修正する (緑ボタンを押す)", on_click=self.submit_fix_time, bgcolor=ft.Colors.GREEN_800, color="white", height=70, width=300),
                    ft.ElevatedButton("戻る", on_click=lambda _: self.show_main_view(), height=60, width=150)
                ], alignment="center", spacing=40)
            ], horizontal_alignment="center", alignment="center", spacing=40),
            bgcolor="#242424",
            border_radius=30,
            expand=True
        )
        
        self.page.update()
        self.fix_hour_input.focus() # 「時」にフォーカスを当てる
    
    def open_cancel_dialog(self, worker_id, worker_name):
        self.cancel_dlg_target_id = worker_id
        self.cancel_dlg_text.value = f"{worker_name} さんの計測を削除しますか？"
        self.cancel_dialog.open = True
        self.page.update()
        
    def close_cancel_dialog(self, e): 
        self.cancel_dialog.open = False
        self.page.update()
        # 閉じたらすぐに1回リストを更新させるため、IDLE状態を維持
    def do_cancel_session(self, e):
        conn = self.get_db_conn()
        conn.execute("DELETE FROM active_sessions WHERE worker_id=?", (self.cancel_dlg_target_id,))
        conn.commit()
        conn.close()
        
        self.cancel_dialog.open = False
        
        # キャッシュを完全に空にする
        self.time_labels.clear()
        self.active_list.controls.clear()
        
        # ★修正ポイント：画面全体を作り直す show_main_view() は使わず、
        # リストだけを更新する refresh_active_list() を呼び出します。
        # これによりタイマーが迷子にならず、カウントが止まりません。
        self.refresh_active_list()
        self.page.update()
        
    def set_step_msg(self, text): self.msg_label.value = text; self.msg_label.color = "white"; self.page.update()
    
    def reset_main_msg(self):
        if self.status == "IDLE": self.msg_label.value = "CARD TOUCH"; self.msg_label.size = 24; self.msg_label.color = "white"; self.page.update()
    def format_time(self, seconds): mm, ss = divmod(seconds, 60); hh, mm = divmod(mm, 60); return f"{hh:02d}:{mm:02d}:{ss:02d}" if hh > 0 else f"{mm:02d}:{ss:02d}"
    # ★ ここに追加！ (WorkAppクラスの中、インデントを合わせる)
    def show_lucky_effect(self):
        """ラッキー画像を5秒間表示する"""
        if self.lucky_popup_img.page:
            # 1. 画像を表示（フェードイン：visible=True, opacity=1）
            self.lucky_popup_img.visible = True
            self.lucky_popup_img.opacity = 1
            self.lucky_popup_img.update()

            # 2. 音を鳴らす（既存の lucky.wav）
            try:
                sound_path = os.path.join("assets", "lucky.wav")
                winsound.PlaySound(sound_path, winsound.SND_FILENAME | winsound.SND_ASYNC)
            except: pass

            # 3. 5秒後に消すタスクを起動
            async def hide_popup():
                await asyncio.sleep(5)
                # フェードアウト（opacity=0）
                self.lucky_popup_img.opacity = 0
                self.lucky_popup_img.update()
                
                # フェードアニメーション時間を待ってから完全に非表示（visible=False）
                await asyncio.sleep(0.5) 
                self.lucky_popup_img.visible = False
                self.lucky_popup_img.update()
            
            self.page.run_task(hide_popup)
            
    def confirm_alert_value(self, e):
        """警告が出たが、そのまま確定する場合 (Enter対応)"""
        val = self.alert_dlg_val
        self.alert_dialog.open = False
        
        # 💡 追加：時間入力画面でのアラート確定時
        if val == "FIX_TIME_CONFIRM":
            self.show_confirm_view()
            return

        # 現在のステップがNG入力中の場合は、NGの確定処理を呼ぶ
        if self.reg_step == "NG":
            self.confirm_ng_value(val)
            
        # それ以外のステップ（CLEAN/AIR/SWAP）から来た場合は、それぞれの確定処理
        elif self.reg_step == "CLEAN":
            self.proceed_to_ng(val)
        elif self.reg_step == "AIR":
            self.reg_data["air"] = int(val)
            self.history_row.controls.append(ft.Text(f"エアー: {val}台", size=24, weight="bold", color="white"))
            self.reg_step = "NG"
            self.show_step_view("清掃行き台数を入力")
        elif self.reg_step == "SWAP":
            self.reg_data["swap"] = int(val)
            self.history_row.controls.append(ft.Text(f"交換: {val}台", size=24, weight="bold", color="white"))
            # 手動モードなら時間入力へ、通常なら確認画面へ
            if getattr(self, "is_fix_mode", False):
                self.show_duration_input_view()
            else:
                self.show_confirm_view()
        
        self.page.update()

    def close_alert_dialog(self, e):
        """入力をやり直す場合 (Esc対応)"""
        self.alert_dialog.open = False
        self.input_buffer = ""
        self.live_input_label.value = ""
        # 💡 フォーカスを奪い返されないように一度更新
        self.page.update()

    def proceed_to_ng(self, val):
        """通常清掃台数の確定後の処理"""
        self.reg_data["clean"] = int(val or 0)
        self.history_row.controls.append(ft.Text(f"通常: {val}台", size=24, weight="bold", color="white"))
        self.reg_step = "NG"
        
        # 指示メッセージを作業内容で切り替え
        msg = "筐体交換行き台数を入力"
        if self.reg_data["work_type"] == "エアー清掃":
            msg = "清掃行き台数を入力"
            
        self.show_step_view(msg)
        self.page.update()
        
    def confirm_ng_value(self, val):
        """NGステップの値を確定"""
        self.reg_data["ng"] = int(val or 0)
        label = "清掃行" if self.reg_data["work_type"] == "エアー清掃" else "NG行"
        self.history_row.controls.append(ft.Text(f"{label}: {val}台", size=24, weight="bold", color="white"))
        
        # ★修正：手入力モードなら時間入力画面へ、通常なら確認画面へ
        if getattr(self, "is_fix_mode", False):
            self.show_duration_input_view()
        else:
            self.show_confirm_view()
            
    def show_duration_input_view(self):
        """作業時間を直接入力する画面（〇時間〇分）"""
        self.status = "FIX_DURATION_INPUT"
        self.fix_hour_val = ""
        self.fix_min_val = ""
        self.fix_current_focus = "hour"

        # 表示のリセットとフォーカスの初期化
        self.fix_hour_label.value = ""
        self.fix_minute_label.value = ""
        self.fix_hour_container.border = ft.border.all(3, "#00ccff")
        self.fix_minute_container.border = ft.border.all(1, "#33363F")

        self.main_view.content = ft.Container(
            content=ft.Column([
                ft.Icon(ft.Icons.TIMER, size=80, color=ft.Colors.ORANGE_400),
                ft.Text("【作業時間の入力】", size=32, weight="bold", color=ft.Colors.ORANGE_400),
                ft.Text("※遡りではなく、実際にかかった時間を入力", size=16, color=ft.Colors.GREY_400),
                ft.Row([
                    ft.Column([self.fix_hour_container, ft.Text("時間", size=20, color="#00ccff")], horizontal_alignment="center"),
                    ft.Text("：", size=60, weight="bold"),
                    ft.Column([self.fix_minute_container, ft.Text("分", size=20, color="#00ccff")], horizontal_alignment="center")
                ], alignment="center", spacing=20),
                self.fix_error_msg,
                ft.Row([
                    ft.ElevatedButton("確定 (Enter)", on_click=lambda _: self.submit_duration_time(), bgcolor=ft.Colors.GREEN_800, color="white", height=70, width=250),
                    ft.ElevatedButton("戻る (Esc)", on_click=lambda _: self.cancel_duration_input(), bgcolor=ft.Colors.GREY_800, color="white", height=70, width=150)
                ], alignment="center", spacing=20)
            ], horizontal_alignment="center", alignment="center", spacing=30),
            bgcolor="#242424",
            expand=True
        )
        self.page.update()

    def cancel_duration_input(self):
        """時間入力画面から1つ前のステップ（NG入力）へ戻る"""
        self.reg_step = "NG"
        msg = "筐体交換行き台数を入力" if self.reg_data.get("work_type") != "エアー清掃" else "清掃行き台数を入力"
        self.show_step_view(msg)

    def submit_duration_time(self):
        """入力された時間を分に換算し、ペースチェックを行ってから次へ進む"""
        try:
            # ✨ 新しい変数を参照
            h = int(self.fix_hour_val or 0)
            m = int(self.fix_min_val or 0)
            total_min = (h * 60) + m
            
            if total_min <= 0:
                return # 0分入力は無視

            # 合計分を一時保存
            self.reg_data["fix_duration_min"] = total_min
            
            # --- 手入力モード用の効率判定 (ペースチェック) ---
            # 入力された合計台数を算出
            total_units = self.reg_data.get("clean", 0) + self.reg_data.get("air", 0) + self.reg_data.get("swap", 0)
            work_hour = total_min / 60
            std_qty = self.reg_data.get("std_qty", 10.0)

            # 標準ペースと乖離（2倍以上または半分以下）があるかチェック
            actual_speed = total_units / work_hour
            if actual_speed >= (std_qty * 2) or actual_speed <= (std_qty / 2):
                self.status = "FIX_DURATION_INPUT" # ステータスを維持
                self.alert_dlg_val = "FIX_TIME_CONFIRM" # 時間入力からのアラートであることを識別
                self.alert_dialog_text.value = (
                    f"入力された作業時間：{h}時間{m}分\n"
                    f"計算ペース：{actual_speed:.1f} 台/時\n"
                    f"標準のペース：{std_qty:.1f} 台/時\n\n"
                    "作業時間と台数のバランスが標準と大きく異なります。\n"
                    "このまま登録してもよろしいですか？"
                )
                self.alert_dialog.open = True
                self.page.update()
                return 

            # チェックに問題なければ確認画面へ
            self.show_confirm_view()
        except ValueError:
            pass
        
    def keep_focus_work_app(self):
        import pygetwindow as gw
        import pyautogui
        import time
    
        while True:
            try:
                target_title = "和気センター WorkManager Registration"
                wins = gw.getWindowsWithTitle(target_title)
                if wins:
                    win = wins[ 0 ]
                
                    if win.isMinimized:
                        win.restore()
                    if not win.isActive:
                        pyautogui.press("alt")
                        time.sleep(0.1)
                        win.activate()
            except Exception:
                pass
            time.sleep(1)

    def open_credit_dialog(self, e):
        self.credit_dialog.open = True
        self.page.update()

    def close_credit_dialog(self, e):
        self.credit_dialog.open = False
        self.page.update()

if __name__ == "__main__":
    # --- 【修正】assetsフォルダをリソースのルートとして認識させる ---
    ft.app(target=main, assets_dir="assets", web_renderer=ft.WebRenderer.CANVAS_KIT)
    