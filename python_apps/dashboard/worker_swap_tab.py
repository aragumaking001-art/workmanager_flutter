import flet as ft
import pandas as pd
import os
from datetime import datetime, timedelta
import random
import asyncio
import sqlite3

class SwapView(ft.Column):
    def __init__(self):
        super().__init__(expand=True, spacing=10)
        
        # --- 基本設定 ---
        self.last_max_id = 0  
        self.is_first_open = True 
        self.rank_mode = "Week" 
        
        self.custom_start_date = datetime.now()
        self.custom_end_date = datetime.now()

        # 筐体交換用の目標（初期値）
        self.target_count = 200 
        self.target_display_text = ft.Text(f"{self.target_count}", size=20, weight="bold", color="#00ffcc")
        self.target_click_area = ft.Container(
            content=self.target_display_text, 
            on_click=self.open_target_dialog, 
            ink=True, 
            border_radius=5, 
            padding=ft.padding.symmetric(horizontal=10)
        )

        self.daily_seed = datetime.now().strftime("%Y%m%d")
        random.seed(self.daily_seed)
        
        # テーマカラー
        self.theme_color = ft.Colors.AMBER_400

        self.char_list = [
            {"name": "ネコ軍曹", "emojis": ["🐱💤", "🐈🐾", "😸✨", "😼🔥", "😻🏆"], "msgs": ["日向ぼっこ中ニャ", "現場をパトロール中ニャ！", "いいリズムだニャ！", "あと一息！追い込みニャ！", "交換完了！最高だニャ！"]},
            {"name": "情熱のライオン", "emojis": ["🦁💤", "🦁🔥", "🦁📢", "🦁💪", "🦁👑"], "msgs": ["王はまだ眠っている…", "エンジンがかかってきたぜ！", "熱い！現場の熱気が伝わるぞ！", "限界を超えろ！ラストスパートだ！", "完全制覇！君こそ真の王だ！"]},
            {"name": "癒やしのパンダ", "emojis": ["🐼💤", "🐼🍃", "🐼✨", "🐼💝", "🐼🎊"], "msgs": ["まだ夢の中だよ…", "笹を食べて準備万端！", "すごいすごい！順調だね〜", "もうすぐ終わるよ、ファイト！", "目標達成！今日はゆっくり休もうね"]},
            {"name": "爆走ウサギ", "emojis": ["🐰💤", "🐰🥕", "🐇💨", "🐇💥", "🐇🚀"], "msgs": ["耳だけ起きてるよ", "栄養補給完了！", "風を感じる速さだ！ぴょんぴょん！", "加速装置オン！ゴールは目前！", "目標突破！光の速さだったね！"]}
        ]
        self.today_char = random.choice(self.char_list)
        self.status_emoji = ft.Text(self.today_char["emojis"][ 0 ], size=60, font_family="Emoji")
        self.status_message = ft.Text("今日もご安全に！", size=18, weight="bold", color="#00ffcc")
        self.date_text = ft.Text(value="", size=24, weight="bold", color=ft.Colors.WHITE)
        self.total_display = ft.Text(value="", size=40, weight="bold", color=self.theme_color)
        self.progress_percent = ft.Text(value="0%", size=32, weight="bold", color="#FFD700")
        self.progress_bar = ft.ProgressBar(value=0, color="#FFD700", bgcolor="#2D3039", height=15)
        
        # 案内メッセージ本体
        self.calendar_guide = ft.Text("", size=45, weight="bold", color="#FFD700", text_align=ft.TextAlign.CENTER)

        # カレンダー案内オーバーレイ
        self.guide_overlay = ft.Container(
            content=ft.Container(
                content=self.calendar_guide,
                bgcolor=ft.Colors.with_opacity(0.9, "black"),
                padding=20,
                border_radius=20,
                border=ft.border.all(2, "#FFD700"),
                margin=ft.margin.only(bottom=80), 
            ),
            alignment=ft.alignment.bottom_center, 
            expand=True,
            visible=False,
            bgcolor=ft.Colors.with_opacity(0.05, "black") 
        )

        self.chart_columns = [ft.Column(spacing=15, scroll=ft.ScrollMode.ADAPTIVE, horizontal_alignment=ft.CrossAxisAlignment.STRETCH) for _ in range(3)]
        self.model_list = ft.ListView(expand=True, spacing=5)
        self.worker_master = {}
        self.model_info_map = {}
        self.weekly_period_label = ft.Text("", size=18, color=ft.Colors.WHITE, weight="bold")

        # カレンダーUI
        self.start_picker = ft.DatePicker(
            on_change=self.on_start_date_change, 
            on_dismiss=self.on_calendar_dismiss, 
            first_date=datetime(2023, 1, 1), 
            last_date=datetime(2030, 12, 31)
        )
        self.end_picker = ft.DatePicker(
            on_change=self.on_end_date_change, 
            on_dismiss=self.on_calendar_dismiss, 
            first_date=datetime(2023, 1, 1), 
            last_date=datetime(2030, 12, 31)
        )

        # 期間切り替えボタン
        self.mode_selector = ft.SegmentedButton(
            selected={"Week"}, allow_multiple_selection=False, on_change=self.on_mode_change,
            width=450,
            segments=[
                ft.Segment(value="Day", label=ft.Text("当日")), 
                ft.Segment(value="Week", label=ft.Text("週間")), 
                ft.Segment(value="Month", label=ft.Text("月間")), 
                ft.Segment(value="Custom", label=ft.Text("期間指定"))
            ],
        )

        self.side_panel = ft.Container(
            content=ft.Column([
                ft.Column([ft.Row([ft.Text("📅", size=24), self.date_text], alignment="center")], horizontal_alignment="center", spacing=2),
                ft.Divider(color="#33363F"),
                ft.Container(content=ft.Column([ft.Text(f"応援担当: {self.today_char['name']}", size=14, color=ft.Colors.GREY_500), self.status_emoji, self.status_message], horizontal_alignment="center", spacing=5), padding=10),
                ft.Divider(color="#33363F"),
                ft.Column([
                    ft.Text(f"🏁 本日筐体交換目標", size=16, color=ft.Colors.GREY_400, weight="bold"),
                    ft.Row([self.total_display, ft.Text("/", size=20), self.target_click_area], alignment="center", vertical_alignment="end"),
                    ft.Row([ft.Text("本日進捗:"), self.progress_percent], alignment="center", vertical_alignment="end"),
                    self.progress_bar
                ], horizontal_alignment="center", spacing=5),
                ft.Divider(color="#33363F"),
                ft.Row([ft.Text("🛠️", size=20), ft.Text(" 本日筐体交換実績", size=18, weight="bold", color=self.theme_color)]),
                ft.Container(content=self.model_list, expand=True)
            ], horizontal_alignment="center", spacing=10),
            padding=20, bgcolor="#23262F", border_radius=20, width=350 
        )

        # 💡 【重要】リスト構造を修正（外側の [] を維持しつつ Stack を配置）
        self.controls = [
            ft.Stack([
                ft.Row([
                    ft.Container(
                        content=ft.Column([
                            ft.Row([
                                ft.Icon(ft.Icons.SETTINGS_OUTLINED, color=self.theme_color), 
                                ft.Text("筐体交換 ランキング", size=24, weight="bold"), 
                                self.weekly_period_label, 
                                ft.Container(expand=True), 
                                self.mode_selector
                            ], vertical_alignment="center"),
                            ft.Row([
                                ft.Container(content=self.chart_columns [ 0 ], expand=True),
                                ft.VerticalDivider(color="#33363F", width=1),
                                ft.Container(content=self.chart_columns [ 1 ], expand=True),
                                ft.VerticalDivider(color="#33363F", width=1),
                                ft.Container(content=self.chart_columns [ 2 ], expand=True),
                            ], expand=True, spacing=20, vertical_alignment="start"),
                        ]),
                        expand=True, bgcolor="#1A1C23", padding=20, border_radius=20,
                    ),
                    self.side_panel
                ], expand=True, spacing=15),
                self.guide_overlay 
            ], expand=True)
        ]

    def did_mount(self):
        if self.page:
            self.page.overlay.append(self.start_picker)
            self.page.overlay.append(self.end_picker)
            self.page.update()

    def load_worker_master(self, df_members=None):
        if df_members is not None and not df_members.empty:
            try:
                # worker_id (社員番号) -> worker_name (氏名)
                return df_members.set_index("worker_id")["worker_name"].to_dict()
            except: pass
        if not os.path.exists('members.csv'): return {}
        try:
            df = pd.read_csv('members.csv', encoding='utf-8-sig')
            df['社員番号'] = df['社員番号'].astype(str).str.strip()
            return df.set_index('社員番号')['氏名'].to_dict()
        except: return {}

    def load_model_info(self, df_models=None):
        if df_models is not None and not df_models.empty:
            try:
                info_dict = {}
                for _, row in df_models.iterrows():
                    key = (str(row['model_name']).strip(), str(row['maker']).strip())
                    info_dict[key] = {
                        "abbr": str(row['maker_abbr']).strip(),
                        "cat": str(row['category']).strip()
                    }
                return info_dict
            except: pass
        if not os.path.exists('model_name.csv'): return {}
        try:
            df = pd.read_csv('model_name.csv', encoding='utf-8-sig')
            info_dict = {}
            for _, row in df.iterrows():
                key = (str(row['機種名']).strip(), str(row['メーカー']).strip())
                info_dict[key] = {
                    "abbr": str(row['メーカー略称']).strip(),
                    "cat": str(row['分類']).strip()
                }
            return info_dict
        except: return {}

    def get_cheer_content(self, progress):
        emojis, msgs = self.today_char["emojis"], self.today_char["msgs"]
        if progress <= 0: return emojis[ 0 ], msgs[ 0 ]
        elif progress < 0.4: return emojis[ 1 ], msgs[ 1 ]
        elif progress < 0.8: return emojis[ 2 ], msgs[ 2 ]
        elif progress < 1.0: return emojis[ 3 ], msgs[ 3 ]
        else: return emojis[ 4 ], msgs[ 4 ]

    def create_neon_bar(self, name, value, max_value, color, rank_emoji="", current_width=0, font_size=20, name_color="white"):
        percent = value / max_value if max_value > 0 else 0
        return ft.Column([
            ft.Row([
                ft.Row([
                    ft.Text(f"{rank_emoji}", size=20, font_family="Emoji"),
                    ft.Text(f"{name}", size=font_size, weight="bold", color=name_color, overflow=ft.TextOverflow.ELLIPSIS, no_wrap=True),
                    ft.Text(" さん", size=14, color=ft.Colors.GREY_400),
                ], spacing=0, expand=True, vertical_alignment=ft.CrossAxisAlignment.END),
                ft.Text(f"{value:.1f}pt", size=22, weight="w900", color=color),
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ft.Stack([
                ft.Container(height=20, bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.WHITE), border_radius=10),
                ft.Container(height=20, width=current_width, bgcolor=color, border_radius=10, 
                             animate=ft.Animation(1000, "decelerate"), data=percent),
            ])
        ], spacing=8, key=name)

    def update_tab(self, df_all, date_str, df_members=None, df_models=None):
        self.worker_master = self.load_worker_master(df_members)
        self.model_info_map = self.load_model_info(df_models)

        self.date_text.value = f"{date_str}"
        target_col = '筐体交換台数'
        
        # 💡 【統一】数値型への強制変換
        if target_col in df_all.columns:
            df_all[target_col] = pd.to_numeric(df_all[target_col], errors='coerce').fillna(0)

        try:
            today_dt = datetime.strptime(date_str, "%Y/%m/%d")
            if self.rank_mode == "Day":
                start_dt, end_dt = today_dt, today_dt
                self.weekly_period_label.value = f" (当日: {today_dt.strftime('%m/%d')})"
            elif self.rank_mode == "Week":
                monday_dt = today_dt - timedelta(days=today_dt.weekday())
                saturday_dt = monday_dt + timedelta(days=5)
                start_dt, end_dt = monday_dt, saturday_dt
                self.weekly_period_label.value = f" ({start_dt.strftime('%m/%d')} ～ {end_dt.strftime('%m/%d')})"
            elif self.rank_mode == "Month":
                start_dt = today_dt.replace(day=1)
                next_month = today_dt.replace(day=28) + timedelta(days=4)
                end_dt = next_month - timedelta(days=next_month.day)
                self.weekly_period_label.value = f" ({start_dt.strftime('%m/%d')} ～ {end_dt.strftime('%m/%d')})"
            elif self.rank_mode == "Custom":
                start_dt, end_dt = self.custom_start_date, self.custom_end_date
                self.weekly_period_label.value = f" [期間: {start_dt.strftime('%m/%d')} ～ {end_dt.strftime('%m/%d')}]"

            if self.weekly_period_label.page: self.weekly_period_label.update()
            start_str, end_str = start_dt.strftime("%Y/%m/%d"), end_dt.strftime("%Y/%m/%d")
            
            df_today = df_all[df_all["日付"] == date_str].copy()
            df_rank = df_all[(df_all["日付"] >= start_str) & (df_all["日付"] <= end_str)].copy()
            df_rank = df_rank[df_rank[target_col] > 0].copy()
            
        except Exception as e:
            print(f"SwapView Filter Error: {e}"); return

        # --- 右側：本日実績リスト ---
        self.model_list.controls.clear()
        if df_today.empty:
            self.total_display.value, self.progress_bar.value, self.progress_percent.value = "0", 0, "0%"
            self.status_emoji.value, self.status_message.value = self.today_char["emojis"][ 0 ], self.today_char["msgs"][ 0 ]
        else:
            total_units = int(df_today[target_col].sum())
            self.total_display.value = str(total_units)
            progress_val = total_units / self.target_count
            self.progress_bar.value, self.progress_percent.value = min(progress_val, 1.0), f"{int(progress_val * 100)}%"
            self.status_emoji.value, self.status_message.value = self.get_cheer_content(progress_val)
            
            df_swap_only = df_today[df_today[target_col] > 0].copy()
            if not df_swap_only.empty:
                # 💡 【統一】groupby集計
                model_data = df_swap_only.groupby(['機種名', 'メーカー'])[target_col].sum().sort_values(ascending=False).reset_index()
                for _, row in model_data.iterrows():
                    m_name = str(row['機種名']).strip()
                    m_maker = str(row['メーカー']).strip()
                    
                    # 救済ロジック
                    info = self.model_info_map.get((m_name, m_maker))
                    if info is None:
                        for k, v in self.model_info_map.items():
                            if k[ 0 ] in m_name: info = v; break
                    
                    abbr = info.get("abbr", "") if info else ""
                    display_name = m_name
                    if abbr and str(abbr).lower() != "nan" and f"({abbr})" not in m_name:
                        display_name = f"{m_name} ({abbr})"

                    self.model_list.controls.append(
                        ft.Container(
                            content=ft.Row([
                                ft.Text(display_name, size=16, weight="w800", color=ft.Colors.WHITE, expand=True, overflow=ft.TextOverflow.ELLIPSIS),
                                ft.Text(f"{int(row[target_col])}台", size=16, weight="bold", color=self.theme_color)
                            ], alignment="spaceBetween"),
                            padding=ft.Padding(8, 4, 15, 4), 
                            border=ft.Border(bottom=ft.BorderSide(1, "#2D3039"))
                        )
                    )

        # --- 左側：ランキング ---
        for col in self.chart_columns: col.controls.clear()
        if not df_rank.empty:
            df_rank['ポイント'] = df_rank[target_col] * 1.0
            worker_points = df_rank.groupby('社員番号')['ポイント'].sum().sort_values(ascending=False)
            worker_points = worker_points[worker_points > 0]
            max_point_val = worker_points.max() if not worker_points.empty else 10
            for i in range(3):
                subset = worker_points.iloc[i*10:(i+1)*10]
                for idx, (s_id, points) in enumerate(subset.items()):
                    raw_name = self.worker_master.get(str(s_id).strip(), str(s_id))
                    name, rank_emoji, bar_color, name_color = raw_name[:10], "", self.theme_color, "white"
                    is_today_lucky = not df_today[(df_today['社員番号'] == str(s_id)) & (df_today['ラッキーフラグ'] == "Lucky")].empty
                    if is_today_lucky: rank_emoji, name_color = "✨", "#FFD700"
                    if i == 0:
                        if idx == 0: rank_emoji, bar_color = "🥇 ", "#FFD700"
                        elif idx == 1: rank_emoji, bar_color = "🥈 ", "#C0C0C0"
                        elif idx == 2: rank_emoji, bar_color = "🥉 ", "#CD7F32"
                    font_size = 20 if len(name) <= 6 else 16
                    self.chart_columns[ i ].controls.append(self.create_neon_bar(name, points, max_point_val, bar_color, rank_emoji, 0, font_size, name_color))

        current_max_id = df_all["id"].max() if not df_all.empty else 0
        if self.page:
            self.update() 
            if self.is_first_open or current_max_id > self.last_max_id:
                async def animate_bars():
                    await asyncio.sleep(0.1)
                    for col in self.chart_columns:
                        for ctrl in col.controls:
                            try:
                                bar_container = ctrl.controls[ 1 ].controls[ 1 ]
                                bar_container.width = 300 * bar_container.data 
                            except: continue
                    self.update()
                self.page.run_task(animate_bars)
                self.is_first_open, self.last_max_id = False, current_max_id
            else:
                for col in self.chart_columns:
                    for ctrl in col.controls:
                        try:
                            bar_container = ctrl.controls[ 1 ].controls[ 1 ]
                            bar_container.animate = None
                            bar_container.width = 300 * bar_container.data
                        except: continue
                self.update()

    def open_target_dialog(self, e):
        self.target_input = ft.TextField(label="新しい目標台数", value=str(self.target_count), keyboard_type=ft.KeyboardType.NUMBER, text_align=ft.TextAlign.RIGHT, suffix_text=" 台")
        self.target_dialog = ft.AlertDialog(title=ft.Text("筐体交換 目標台数の変更"), content=ft.Column([ft.Text("本日の筐体交換目標を入力してください。"), self.target_input], height=120, tight=True), actions=[ft.TextButton("キャンセル", on_click=self.close_target_dialog), ft.ElevatedButton("確定", on_click=self.change_target_count, bgcolor="#00ccff", color="black")])
        self.page.overlay.append(self.target_dialog)
        self.target_dialog.open = True; self.page.update()

    def close_target_dialog(self, e): self.target_dialog.open = False; self.page.update()

    def change_target_count(self, e):
        try:
            new_val = int(self.target_input.value)
            if new_val > 0:
                self.target_count = new_val
                self.target_display_text.value = str(new_val)
                self.target_dialog.open = False
                if hasattr(self, 'on_mode_change_callback'): self.on_mode_change_callback()
                self.page.update()
        except: pass  
        
    def on_start_date_change(self, e):
        if e.control.value:
            self.custom_start_date = e.control.value
            self.calendar_guide.value = "【STEP 2/2】\n終了日を選んでください"
            self.page.update(); self.page.open(self.end_picker)
        else: self.guide_overlay.visible = False; self.page.update()

    def on_end_date_change(self, e):
        self.guide_overlay.visible = False; self.page.update()
        if e.control.value:
            self.custom_end_date = e.control.value
            if hasattr(self, 'on_mode_change_callback'): self.on_mode_change_callback()

    def on_mode_change(self, e):
        if e.control.selected:
            self.rank_mode = list(e.control.selected)[ 0 ]
            if self.rank_mode == "Custom":
                self.calendar_guide.value = "【STEP 1/2】\n開始日を選んでください"
                self.guide_overlay.visible = True
                self.page.update(); self.page.open(self.start_picker)
            else: self.guide_overlay.visible = False; self.page.update()
            if hasattr(self, 'on_mode_change_callback'): self.on_mode_change_callback()
            else: self.update()
                
    def on_calendar_dismiss(self, e): self.guide_overlay.visible = False; self.page.update()