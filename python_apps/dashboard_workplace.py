import flet as ft

pyi_splash = None  # 先に None で初期化しておく
try:
    import pyi_splash
except ImportError:
    pass
import sqlite3
import pandas as pd
from datetime import datetime
import os
import sys

# 💡 Windowsコンソールでの絵文字(cp932)によるクラッシュを防ぐ
if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

import traceback
import warnings
import ctypes
from ctypes import wintypes

warnings.simplefilter("ignore", UserWarning)

if getattr(sys, "frozen", False):
    BASE_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

import threading
import time
import asyncio
import matplotlib

matplotlib.use("Agg")
import mysql.connector
from mysql.connector import pooling

from dashboard.worker_total_ranking_tab import TotalRankingView
from dashboard.worker_today_summary_tab import TodayWorkSummaryView
from dashboard.worker_cleaning_tab import CleaningView
from dashboard.worker_air_tab import AirView
from dashboard.model_tab import ModelView
from dashboard.worker_swap_tab import SwapView
from dashboard.summary_tab import SummaryView
from dashboard.worker_analysis_tab import WorkerAnalysisView

def get_monitor_positions():
    monitors = []
    MonitorEnumProc = ctypes.WINFUNCTYPE(
        wintypes.BOOL,
        wintypes.HANDLE,
        wintypes.HANDLE,
        ctypes.POINTER(wintypes.RECT),
        wintypes.LPARAM
    )

    def callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
        rect = lprcMonitor.contents
        monitors.append({
            "x": rect.left, 
            "y": rect.top, 
            "width": rect.right - rect.left, 
            "height": rect.bottom - rect.top
        })
        return True

    ctypes.windll.user32.EnumDisplayMonitors(0, 0, MonitorEnumProc(callback), 0)
    monitors.sort(key=lambda m: m["x"])
    
    if len(monitors) == 0:
        monitors.append({"x": 0, "y": 0, "width": 1920, "height": 1080})
        
    return monitors


def main(page: ft.Page):
    page.fonts = {
        "Emoji": "/TwemojiMozilla.ttf",
    }
    page.theme = ft.Theme(font_family="MS Gothic")

    # 💡 ここに追加：モニター情報を取得し、「左側（1番目）」のモニターを選ぶ
    monitors = get_monitor_positions()
    target_monitor = monitors[ 0 ]

    try:
        page.window.title_bar_hidden = True
        page.window.frameless = True
        # 💡 固定の数値(-1920)ではなく、取得した左側のモニター座標とサイズを自動適用
        page.window.left = target_monitor["x"]
        page.window.top = target_monitor["y"]
        page.window.width = target_monitor["width"]
        page.window.height = target_monitor["height"]
        page.window.state = ft.WindowState.MAXIMIZED
    except AttributeError:
        page.window_title_bar_hidden = True
        page.window_frameless = True
        page.window_left = target_monitor["x"]
        page.window_top = target_monitor["y"]
        page.window_width = target_monitor["width"]
        page.window_height = target_monitor["height"]
        page.window_state = "maximized"

    def handle_close():
        # 💡 まず一瞬でウィンドウを透明(非表示)にして「即座に閉じた」ように見せる
        try: page.window.visible = False
        except: pass
        try: page.window_visible = False
        except: pass
        try: page.update()
        except: pass

        # 💡 その後、ゆっくりFletの終了処理(約2秒)を走らせる
        try: page.window_destroy()
        except: pass
        try: page.window.destroy()
        except: pass
        try: page.window_close()
        except: pass
        try: page.window.close()
        except: pass

    def init_mariadb_environment():
        try:
            temp_conn = mysql.connector.connect(
                host="192.168.10.101", user="work_user", password="work1234",
                charset="utf8mb4", auth_plugin="mysql_native_password", connection_timeout=10,
            )
            temp_cur = temp_conn.cursor()
            temp_cur.execute("CREATE DATABASE IF NOT EXISTS work_manager_db CHARACTER SET utf8mb4")
            temp_conn.close()

            my_conn = get_db_connection()
            my_cur = my_conn.cursor()
            my_cur.execute("""
                CREATE TABLE IF NOT EXISTS unit_cleaning_logs (
                    id INT AUTO_INCREMENT PRIMARY KEY, 
                    location VARCHAR(50),
                    work_date VARCHAR(20), worker_id VARCHAR(20), model_name VARCHAR(255),
                    maker VARCHAR(100), maker_abbr VARCHAR(50), category VARCHAR(100), air_clean_qty INT,
                    to_clean_qty INT, clean_qty INT, to_swap_qty INT, swap_qty INT,
                    start_time_str VARCHAR(10), end_time_str VARCHAR(10), work_minutes INT,
                    created_at DATETIME, sync_flag INT DEFAULT 0, std_qty DOUBLE,
                    lucky_flag VARCHAR(50), edit_count INT DEFAULT 0, reserve_3 VARCHAR(255), reserve_4 VARCHAR(255), reserve_5 VARCHAR(255)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            try: my_cur.execute("ALTER TABLE unit_cleaning_logs MODIFY id INT AUTO_INCREMENT;")
            except: pass
            try: my_cur.execute("ALTER TABLE unit_cleaning_logs ADD COLUMN location VARCHAR(50) AFTER id;")
            except: pass
            try: my_cur.execute("ALTER TABLE unit_cleaning_logs ADD COLUMN maker_abbr VARCHAR(50) AFTER maker;")
            except: pass
            try: my_cur.execute("ALTER TABLE unit_cleaning_logs ADD COLUMN edit_count INT DEFAULT 0 AFTER lucky_flag;")
            except: pass

            my_cur.execute("""
                CREATE TABLE IF NOT EXISTS daily_targets (
                    id INT PRIMARY KEY, air_target INT, clean_target INT, swap_target INT
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """)
            my_cur.execute("INSERT IGNORE INTO daily_targets (id, air_target, clean_target, swap_target) VALUES (1, 600, 1200, 50)")

            # 永続接続を使用するためcloseは呼ばない
            my_conn.commit()
            # my_conn.close()
            print("✅ MariaDB データベース・テーブル準備完了")
        except Exception as ex:
            print(f"⚠️ MariaDB 初期化失敗: {ex}")

    # 💡 スレッド間のUI更新・データ処理の衝突を防ぐロック
    refresh_lock = threading.Lock()
    
    # 💡 コネクションの毎秒切断によるポート枯渇（TIME_WAIT）を防ぐため、1つの接続を開きっぱなしにする
    _db_state = {"conn": None}
    _conn_lock = threading.Lock()
    
    # 💡 データベースへの同時アクセスを防ぎ、コネクション破損による自動切断（とポート枯渇）を防ぐ
    db_lock = threading.Lock()

    def get_db_connection():
        with _conn_lock:
            try:
                if _db_state["conn"] is not None and _db_state["conn"].is_connected():
                    return _db_state["conn"]
            except:
                pass
                
            try:
                if _db_state["conn"] is not None:
                    _db_state["conn"].close()
            except: pass
            
            _db_state["conn"] = mysql.connector.connect(
                host="192.168.10.101",
                user="work_user",
                password="work1234",
                database="work_manager_db",
                charset="utf8mb4",
                auth_plugin="mysql_native_password",
                connection_timeout=5,
                autocommit=True  # 💡 永続接続で他端末の更新(最新データ)を常に読み取るために必須
            )
            return _db_state["conn"]

    def sync_to_mariadb():
        sl_conn = None
        # 💡 ここもロックを取得して他のスレッドからのDBアクセスをブロック
        with db_lock:
            try:
                db_path = os.path.join(BASE_DIR, "work_data.db")
                if not os.path.exists(db_path): return

                sl_conn = sqlite3.connect(db_path)
                sl_conn.row_factory = sqlite3.Row
                my_conn = get_db_connection()
                sl_cur, my_cur = sl_conn.cursor(), my_conn.cursor()

                target_columns = [
                    "location", "work_date", "worker_id", "model_name", "maker", "maker_abbr", 
                    "category", "air_clean_qty", "to_clean_qty", "clean_qty", "to_swap_qty", "swap_qty", 
                    "start_time_str", "end_time_str", "work_minutes", "created_at", 
                    "std_qty", "lucky_flag", "edit_count", "reserve_3", "reserve_4", "reserve_5"
                ]
                cols_str = ", ".join(target_columns)

                sl_cur.execute(f"SELECT id, {cols_str} FROM unit_cleaning_logs WHERE sync_flag = 0")
                new_rows = sl_cur.fetchall()

                if new_rows:
                    placeholders = ", ".join(["%s"] * len(target_columns))
                    insert_sql = f"INSERT INTO unit_cleaning_logs ({cols_str}) VALUES ({placeholders})"

                    synced_ids = []
                    for row in new_rows:
                        data_tuple = tuple(row[col] for col in target_columns)
                        try:
                            my_cur.execute(insert_sql, data_tuple)
                            synced_ids.append(row["id"]) 

                            # --- 💡 スケジュールへの前倒し消化連動 ---
                            try:
                                # エアー清掃、通常清掃、筐体交換の合計値を算出
                                air_qty = int(row["air_clean_qty"] or 0)
                                cln_qty = int(row["clean_qty"] or 0)
                                swp_qty = int(row["swap_qty"] or 0)
                                c_qty = air_qty + cln_qty + swp_qty
                                
                                if c_qty > 0:
                                    m_name = str(row["model_name"] or "").strip()
                                    m_maker = str(row["maker_abbr"] or "").strip()
                                    
                                    # 表記揺れ吸収：マスター側の F-D(M) などをスケジュール側の F-D に一致させるため、末尾のカッコを削除
                                    import re
                                    m_name = re.sub(r'[\(（][A-Za-z0-9_]+[\)）]$', '', m_name).strip()


                                    if m_name != "":
                                        # まず未達成のスケジュールを古い順に取得
                                        my_cur.execute(
                                            "SELECT id, plan_count, actual_count FROM t_schedules WHERE model_name = %s AND maker_name = %s AND actual_count < plan_count ORDER BY target_date ASC",
                                            (m_name, m_maker)
                                        )
                                        scheds = my_cur.fetchall()
                                        
                                        rem = int(c_qty)
                                        if len(scheds) > 0:
                                            # 未達成枠がある場合は古いものから埋めていく
                                            for sid, p_cnt, a_cnt in scheds:
                                                if rem <= 0: break
                                                shortage = p_cnt - a_cnt
                                                add_amt = shortage if rem >= shortage else rem
                                                my_cur.execute("UPDATE t_schedules SET actual_count = actual_count + %s WHERE id = %s", (add_amt, sid))
                                                rem -= add_amt
                                                
                                            # 全て埋めても余った場合は、オーバーさせずに捨てる（何もしない）
                                            pass
                                        else:
                                            # 全て達成済み(未達成ゼロ)の場合も、予定を超過させずに捨てる
                                            pass

                                        # --- 💡 追加：左側の3種類 (t_model_schedules) への自動加算 ---
                                        my_cur.execute("""
                                            INSERT INTO t_model_schedules (model_name, maker_name, air_count, clean_count, swap_count, total_count)
                                            VALUES (%s, %s, %s, %s, %s, %s)
                                            ON DUPLICATE KEY UPDATE
                                            air_count = air_count + VALUES(air_count),
                                            clean_count = clean_count + VALUES(clean_count),
                                            swap_count = swap_count + VALUES(swap_count),
                                            total_count = total_count + VALUES(total_count)
                                        """, (m_name, m_maker, air_qty, cln_qty, swp_qty, c_qty))
                            except Exception as sync_err:
                                print(f"⚠️ スケジュール連動エラー: {sync_err}")
                            # ------------------------------------
                            
                        except Exception as e:
                            print(f"❌ MariaDB挿入エラー: {e}")

                    if synced_ids:
                        placeholders_sl = ", ".join(["?"] * len(synced_ids))
                        sl_conn.execute(f"UPDATE unit_cleaning_logs SET sync_flag = 1 WHERE id IN ({placeholders_sl})", synced_ids)
                        sl_conn.commit()
                        try:
                            my_cur.execute("UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1")
                            my_conn.commit()
                        except: pass
                        print(f"🔄 MariaDB同期完了: {len(synced_ids)}件を送信しました")
            except Exception as ex:
                print(f"⚠️ 同期失敗（詳細）: {type(ex).__name__} - {ex}")
            finally:
                try:
                    if 'sl_cur' in locals() and sl_cur: sl_cur.close()
                except: pass
                try:
                    if 'my_cur' in locals() and my_cur: my_cur.close()
                except: pass
                try:
                    if sl_conn: sl_conn.close()
                except: pass
                # my_conn は永続接続のためクローズしない
    threading.Thread(target=init_mariadb_environment, daemon=True).start()

    total_ranking_screen = TotalRankingView()
    today_summary_screen = TodayWorkSummaryView()
    cleaning_screen = CleaningView()
    air_screen = AirView()
    swap_screen = SwapView()
    model_screen = ModelView()
    summary_screen = SummaryView()
    worker_analysis_screen = WorkerAnalysisView(pd.DataFrame())

    status_text = ft.Text("", color=ft.Colors.GREY_500, size=16)

    def on_keyboard(e: ft.KeyboardEvent):
        if e.key == "F5" or (e.ctrl and e.key == "R"):
            refresh_data()

    page.on_keyboard_event = on_keyboard

    # 💡 完全にプロセスを終了させるためのイベントハンドラ
    try:
        page.window.prevent_close = True
    except AttributeError:
        page.window_prevent_close = True

    def window_event(e):
        if e.data == "close":
            os._exit(0)  # スレッドやポートを道連れにして完全に終了
            
    page.on_window_event = window_event

    def refresh_data(sync=False):
        # 💡 ロックを取得。別の更新処理が走っている間はブロックし、UI破壊を防ぐ
        if not refresh_lock.acquire(blocking=False):
            print("⏳ 既に更新処理が走っているためスキップします")
            return
            
        try:
            if sync:
                sync_to_mariadb()

            df_logs = pd.DataFrame()
            df_models = pd.DataFrame()
            db_targets = {"エアー": 600, "清掃": 1200, "筐体交換": 50}

            try:
                # 💡 DBアクセス全体をロックで保護する
                with db_lock:
                    my_conn = get_db_connection()
                    df_logs = pd.read_sql_query("SELECT * FROM unit_cleaning_logs", my_conn)
                    df_models = pd.read_sql_query("SELECT * FROM m_models", my_conn)
                    df_members = pd.read_sql_query("SELECT * FROM m_members", my_conn)
                    
                    my_cur = my_conn.cursor()
                    my_cur.execute("SELECT air_target, clean_target, swap_target FROM daily_targets WHERE id = 1")
                    t_row = my_cur.fetchone()
                    
                    try:
                        if 'my_cur' in locals() and my_cur: my_cur.close()
                    except: pass

                if t_row:
                    def safe_int(val):
                        while isinstance(val, (tuple, list, bytearray, bytes)):
                            if len(val) == 0:
                                return 0
                            val = val[ 0 ]
                        try:
                            return int(val)
                        except:
                            return 0

                    db_targets = {
                        "エアー": safe_int(t_row[ 0 ] if len(t_row) > 0 else 600), 
                        "清掃": safe_int(t_row[ 1 ] if len(t_row) > 1 else 1200), 
                        "筐体交換": safe_int(t_row[ 2 ] if len(t_row) > 2 else 50)
                    }
                    
                # 💡 キャッシュに保存 (SQLite)
                try:
                    conn_sl = sqlite3.connect(os.path.join(BASE_DIR, "work_data.db"), timeout=10.0)
                    df_logs.to_sql("unit_cleaning_logs_cache", conn_sl, if_exists="replace", index=False)
                    df_models.to_sql("m_models", conn_sl, if_exists="replace", index=False)
                    df_members.to_sql("m_members", conn_sl, if_exists="replace", index=False)
                    conn_sl.close()
                except Exception as cache_err:
                    print(f"キャッシュ保存エラー: {cache_err}")

                # 💡 🟢 Online の表示
                status_text.value = f"🟢 最終更新: {datetime.now().strftime('%H:%M:%S')} (Online)"
                status_text.color = "#00FFCC"
                
            except Exception as e:
                print(f"MariaDB接続エラー。ローカルキャッシュから読み込みます: {e}")
                
                # 💡 🔴 通信エラー時、オフラインモード表示
                status_text.value = f"🔴 オフラインモード (Offline) - {datetime.now().strftime('%H:%M')}"
                status_text.color = "red"
                
                try:
                    conn_sl = sqlite3.connect(os.path.join(BASE_DIR, "work_data.db"), timeout=10.0)
                    
                    try: df_logs = pd.read_sql_query("SELECT * FROM unit_cleaning_logs_cache", conn_sl)
                    except: df_logs = pd.read_sql_query("SELECT * FROM unit_cleaning_logs", conn_sl)
                    
                    df_models = pd.read_sql_query("SELECT * FROM m_models", conn_sl)
                    
                    df_members = pd.read_sql_query("SELECT * FROM m_members", conn_sl)
                    
                    conn_sl.close()
                except Exception as cache_err:
                    print(f"ローカルキャッシュ読み込みエラー: {cache_err}")
                    try: page.update()
                    except: pass
                    return  # キャッシュすらない場合は維持するのみ

            try:
                # 💡 オフライン時（空のデータ）でもエラーにならないようガード
                if not df_models.empty and not df_logs.empty:
                    if "maker" in df_models.columns:
                        df_models = df_models.drop_duplicates(subset=["model_name", "maker"])
                        df_all = pd.merge(df_logs, df_models[["model_name", "maker"]], on=["model_name", "maker"], how="left")
                    else:
                        df_models = df_models.drop_duplicates(subset=["model_name"])
                        df_all = pd.merge(df_logs, df_models[["model_name"]], on="model_name", how="left")
                else:
                    df_all = pd.DataFrame() # データ0件
                    
                rename_map = {
                    "location": "拠点", "work_date": "日付", "worker_id": "社員番号",
                    "model_name": "機種名", "maker": "メーカー", "maker_abbr": "メーカー略称",
                    "air_clean_qty": "エアー清掃台数", "clean_qty": "清掃台数", "swap_qty": "筐体交換台数",
                    "to_clean_qty": "清掃行き台数", "to_swap_qty": "筐体交換行き台数", 
                    "work_minutes": "作業時間", "lucky_flag": "ラッキーフラグ",
                    "edit_count": "修正回数", "category": "分類", 
                }
                df_all = df_all.rename(columns=rename_map)
                
                if df_all.empty:
                    df_all = pd.DataFrame(columns=list(rename_map.values()))
                else:
                    df_all = df_all.fillna("")

                today_str = datetime.now().strftime("%Y/%m/%d")
                total_ranking_screen.update_tab(df_all.copy(), today_str, df_members, df_models)
                today_summary_screen.update_tab(df_all.copy(), today_str, db_targets, df_members, df_models)

                page.update()
            except Exception as e:
                print(f"Refresh Data Error:\n{traceback.format_exc()}")
                status_text.value = "🔴 画面描画エラー"
                status_text.color = "red"
                try: page.update()
                except: pass
                
        finally:
            refresh_lock.release()


    page.title = "和気センター WorkManager"
    page.theme_mode = ft.ThemeMode.DARK
    page.bgcolor = "#0F1115"
    page.padding = 0

    loading_text = ft.Text("System Initializing...", color="#00ccff", size=16, italic=True)
    progress_bar = ft.ProgressBar(width=400, color="#00ccff", bgcolor="#333333", value=0)
    splash_container = ft.Container(
        content=ft.Column(
            [
                ft.Text("和気センター WorkManager", size=55, weight="bold", color="white"),
                ft.Container(height=40),
                ft.ProgressRing(width=60, height=60, color="#00ccff"),
                ft.Column([loading_text, progress_bar], horizontal_alignment="center"),
            ],
            alignment="center", horizontal_alignment="center",
        ),
        expand=True, bgcolor="#0F1115",
    )

    main_layout_container = ft.Container(expand=True)
    page_stack = ft.Stack([main_layout_container, splash_container], expand=True)
    page.add(page_stack)

    async def initialize_app():
        db_path = os.path.join(BASE_DIR, "work_data.db")
        my_conn = None
        conn_sl = None
        try:
            my_conn = get_db_connection()
            df_m_models = pd.read_sql_query("SELECT * FROM m_models", my_conn)
            df_m_members = pd.read_sql_query("SELECT * FROM m_members", my_conn)

            conn_sl = sqlite3.connect(db_path, timeout=10.0)
            if not df_m_models.empty:
                if "maker" in df_m_models.columns:
                    df_m_models.drop_duplicates(subset=["model_name", "maker"]).to_sql("m_models", conn_sl, if_exists="replace", index=False)
                else:
                    df_m_models.drop_duplicates(subset=["model_name"]).to_sql("m_models", conn_sl, if_exists="replace", index=False)
            if not df_m_members.empty:
                df_m_members.to_sql("m_members", conn_sl, if_exists="replace", index=False)
            print(f"✅ 起動時のマスタ同期完了: 機種{len(df_m_models)}件, メンバー{len(df_m_members)}件")
        except Exception as e:
            print(f"⚠️ 起動時のマスタ同期失敗: {e}")
        finally:
            # my_conn は永続接続のためクローズしない
            # try:
            #     if my_conn and my_conn.is_connected(): my_conn.close()
            # except: pass
            try:
                if conn_sl: conn_sl.close()
            except: pass

        await asyncio.sleep(0.5)
        loading_text.value = "Building UI Layout..."
        progress_bar.value = 0.4
        page.update()

        header = ft.Container(
            content=ft.Row(
                [
                    ft.Row(
                        [
                            ft.Icon(ft.Icons.DASHBOARD_ROUNDED, color="#00ccff", size=30),
                            ft.Text("和気センター WorkManager", size=32, weight="bold"),
                        ]
                    ),
                    ft.Row(
                        [
                            status_text,
                            ft.Container(width=20),
                            ft.IconButton(
                                icon=ft.Icons.CLOSE, icon_color=ft.Colors.with_opacity(0.4, "white"),
                                icon_size=30, on_click=lambda _: handle_close(), tooltip="アプリを終了する",
                            ),
                        ],
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            ),
            padding=ft.padding.only(left=20, right=10, top=10, bottom=10),
            bgcolor="#1A1C23",
        )

        tabs = ft.Tabs(
            selected_index=0, indicator_color="#00ccff", label_color="#00ccff",
            unselected_label_color="white38", divider_color="transparent",
            tabs=[
                ft.Tab(text="総合ランキング", icon=ft.Icons.EMOJI_EVENTS_ROUNDED, content=total_ranking_screen),
                ft.Tab(text="本日の出来高", icon=ft.Icons.FACT_CHECK_ROUNDED, content=today_summary_screen),
            ],
            expand=True,
        )

        total_ranking_screen.on_mode_change_callback = refresh_data

        main_layout_container.content = ft.Column([header, ft.Container(content=tabs, expand=True, padding=20)], spacing=0)
        page.window_maximized = True
        page.update()

        progress_bar.value = 1.0
        splash_container.opacity = 0
        await asyncio.sleep(0.5)
        page_stack.controls.remove(splash_container)
        try: page.update()
        except: pass
        
        refresh_data(sync=True)
        threading.Thread(target=auto_refresh, daemon=True).start()

        if pyi_splash:
            try:
                pyi_splash.update_text("UI Loaded.")
                pyi_splash.close()
            except Exception:
                pass  # 画面がない場合（RuntimeErrorなど）は無視する

    def auto_refresh():
        last_mtime = 0
        last_db_time = None  
        db_path = os.path.join(BASE_DIR, "work_data.db")
        wal_path = db_path + "-wal" 
        
        loop_count = 0 
        was_offline = False  

        while True:
            try:
                local_updated = False
                remote_updated = False

                try:
                    current_mtime = 0
                    if os.path.exists(db_path): current_mtime = max(current_mtime, os.path.getmtime(db_path))
                    if os.path.exists(wal_path): current_mtime = max(current_mtime, os.path.getmtime(wal_path))
                    if last_mtime != 0 and current_mtime > last_mtime:
                        local_updated = True
                    last_mtime = current_mtime
                except: pass

                if loop_count >= 2: 
                    loop_count = 0
                    
                    try:
                        # 💡 ここもDBアクセスなのでロックで保護する
                        with db_lock:
                            my_conn = get_db_connection()
                            my_cur = my_conn.cursor()
                            my_cur.execute("SELECT last_updated FROM data_update_tracker WHERE id = 1")
                            res = my_cur.fetchone()
                            
                            try:
                                if 'my_cur' in locals() and my_cur: my_cur.close()
                            except: pass
                        
                        if res:
                            current_db_time = res[ 0 ]
                            if last_db_time is None:
                                remote_updated = True
                            elif current_db_time > last_db_time:
                                remote_updated = True
                            elif was_offline:
                                remote_updated = True
                                
                            last_db_time = current_db_time
                        
                        was_offline = False
                        
                    except Exception as e:
                        print(f"auto_refresh内のDBエラー: {e}")
                        if not was_offline:
                            was_offline = True
                else:
                    loop_count += 1

                if local_updated or remote_updated:
                    try:
                        refresh_data(sync=local_updated)
                    except Exception as e:
                        print(f"⚠️ refresh_data で致命的なエラー: {e}")
            except Exception as outer_e:
                print(f"⚠️ auto_refresh ループ全体でエラー発生: {outer_e}")
            finally:
                time.sleep(0.5)
            
    page.update()
    asyncio.run(initialize_app())

if __name__ == "__main__":
    ft.app(target=main, assets_dir="assets", web_renderer=ft.WebRenderer.CANVAS_KIT)
    os._exit(0)  # Fletプロセス終了後にバックグラウンドタスクやポートを確実に解放