import flet as ft
import pandas as pd
import os
from datetime import datetime, timedelta
import random
import asyncio
import sqlite3

class CleaningView(ft.Column):
    def __init__(self):
        super().__init__(expand=True, spacing=10)
        
        self.last_max_id = 0  
        self.is_first_open = True 
        self.rank_mode = "Week" 
        
        self.custom_start_date = datetime.now()
        self.custom_end_date = datetime.now()

        self.target_count = 1200 
        self.target_display_text = ft.Text(f"{self.target_count}", size=18, weight="bold", color="#00ffcc")
        self.target_click_area = ft.Container(content=self.target_display_text, on_click=self.open_target_dialog, ink=True, border_radius=5, padding=ft.padding.symmetric(horizontal=8))
        self.daily_seed = datetime.now().strftime("%Y%m%d")
        random.seed(self.daily_seed)
        
        self.char_list = [
            {"name": "ネコ軍曹", "emojis": ["🐱💤", "🐈🐾", "😸✨", "😼🔥", "😻🏆"], "msgs": ["日向ぼっこ中ニャ", "現場をパトロール中ニャ！", "いいリズムだニャ！", "あと一息！追い込みニャ！", "交換完了！最高だニャ！"]},
            {"name": "情熱のライオン", "emojis": ["🦁💤", "🦁🔥", "🦁📢", "🦁💪", "🦁👑"], "msgs": ["王はまだ眠っている…", "エンジンがかかってきたぜ！", "熱い！現場の熱気が伝わるぞ！", "限界を超えろ！ラストスパートだ！", "完全制覇！君こそ真の王だ！"]},
            {"name": "癒やしのパンダ", "emojis": ["🐼💤", "🐼🍃", "🐼✨", "🐼💝", "🐼🎊"], "msgs": ["まだ夢の中だよ…", "笹を食べて準備万端！", "すごいすごい！順調だね〜", "もうすぐ終わるよ、ファイト！", "目標達成！今日はゆっくり休もうね"]},
            {"name": "爆走ウサギ", "emojis": ["🐰💤", "🐰🥕", "🐇💨", "🐇💥", "🐇🚀"], "msgs": ["耳だけ起きてるよ", "栄養補給完了！", "風を感じる速さだ！ぴょんぴょん！", "加速装置オン！ゴールは目前！", "目標突破！光の速さだったね！"]}
        ]
        self.today_char = random.choice(self.char_list)
        self.status_emoji = ft.Text(self.today_char["emojis"][ 0 ], size=50, font_family="Emoji")
        self.status_message = ft.Text("今日もご安全に！", size=16, weight="bold", color="#00ffcc")
        self.date_text = ft.Text(value="", size=20, weight="bold", color=ft.Colors.WHITE)
        self.total_display = ft.Text(value="", size=36, weight="bold", color="#00ffcc")
        self.progress_percent = ft.Text(value="0%", size=28, weight="bold", color="#FFD700")
        self.progress_bar = ft.ProgressBar(value=0, color="#FFD700", bgcolor="#2D3039", height=12)
        
        self.calendar_guide = ft.Text("", size=35, weight="bold", color="#FFD700", text_align=ft.TextAlign.CENTER)
        self.guide_overlay = ft.Container(
            content=ft.Container(
                content=self.calendar_guide,
                bgcolor=ft.Colors.with_opacity(0.9, "black"),
                padding=20, border_radius=20, border=ft.border.all(2, "#FFD700"),
                margin=ft.margin.only(bottom=80), 
            ),
            alignment=ft.alignment.bottom_center, expand=True, visible=False,
            bgcolor=ft.Colors.with_opacity(0.05, "black") 
        )

        self.chart_columns = [ft.Column(spacing=12, scroll=ft.ScrollMode.ADAPTIVE, horizontal_alignment=ft.CrossAxisAlignment.STRETCH) for _ in range(3)]
        self.model_list = ft.ListView(expand=True, spacing=5)
        self.worker_master = self.load_worker_master()
        self.model_info_map = self.load_model_info()
        self.weekly_period_label = ft.Text("", size=16, color=ft.Colors.WHITE, weight="bold")

        self.start_picker = ft.DatePicker(on_change=self.on_start_date_change, on_dismiss=self.on_calendar_dismiss, first_date=datetime(2023, 1, 1), last_date=datetime(2030, 12, 31))
        self.end_picker = ft.DatePicker(on_change=self.on_end_date_change, on_dismiss=self.on_calendar_dismiss, first_date=datetime(2023, 1, 1), last_date=datetime(2030, 12, 31))

        self.mode_selector = ft.SegmentedButton(
            selected={"Week"}, 
            allow_multiple_selection=False, 
            on_change=self.on_mode_change,
            width=380,
            segments=[
                ft.Segment(value="Day", label=ft.Text("当日", size=13)), 
                ft.Segment(value="Week", label=ft.Text("週間", size=13)), 
                ft.Segment(value="Month", label=ft.Text("月間", size=13)), 
                ft.Segment(value="Custom", label=ft.Text("指定", size=13))
            ],
        )

        self.side_panel = ft.Container(
            content=ft.Column([
                ft.Column([ft.Row([ft.Text("📅", size=20), self.date_text], alignment="center")], horizontal_alignment="center", spacing=2),
                ft.Divider(color="#33363F"),
                ft.Container(content=ft.Column([ft.Text(f"応援担当: {self.today_char['name']}", size=12, color=ft.Colors.GREY_500), self.status_emoji, self.status_message], horizontal_alignment="center", spacing=5), padding=5),
                ft.Divider(color="#33363F"),
                ft.Column([
                    ft.Text(f"🏁 本日目標", size=14, color=ft.Colors.GREY_400, weight="bold"),
                    ft.Row([self.total_display, ft.Text("/", size=18), self.target_click_area], alignment="center", vertical_alignment="end"),
                    ft.Row([ft.Text("本日進捗:", size=13), self.progress_percent], alignment="center", vertical_alignment="end"),
                    self.progress_bar
                ], horizontal_alignment="center", spacing=5),
                ft.Divider(color="#33363F"),
                ft.Row([ft.Text("🧼", size=18), ft.Text(" 本日清掃実績", size=16, weight="bold", color="#00ccff")]),
                ft.Container(content=self.model_list, expand=True)
            ], horizontal_alignment="center", spacing=8),
            padding=15, bgcolor="#23262F", border_radius=20, width=280 
        )

        self.controls = [
            ft.Stack([
                ft.Row([
                    ft.Container(
                        content=ft.Column([
                            ft.Row([ft.Icon(ft.Icons.CLEANING_SERVICES, color="#00ccff", size=24), ft.Text("通常清掃 ランキング", size=22, weight="bold"), self.weekly_period_label, ft.Container(expand=True), self.mode_selector], vertical_alignment="center"),
                            ft.Row([
                                ft.Container(content=self.chart_columns[ 0 ], expand=True),
                                ft.VerticalDivider(color="#33363F", width=1),
                                ft.Container(content=self.chart_columns[ 1 ], expand=True),
                                ft.VerticalDivider(color="#33363F", width=1),
                                ft.Container(content=self.chart_columns[ 2 ], expand=True),
                            ], expand=True, spacing=15, vertical_alignment="start"),
                        ]),
                        expand=True, bgcolor="#1A1C23", padding=15, border_radius=20,
                    ),
                    self.side_panel
                ], expand=True, spacing=10),
                self.guide_overlay 
            ], expand=True)
        ]

    def did_mount(self):
        if self.page:
            self.page.overlay.append(self.start_picker)
            self.page.overlay.append(self.end_picker)
            self.page.update()

    def load_worker_master(self):
        if not os.path.exists('members.csv'): return {}
        try:
            df = pd.read_csv('members.csv', encoding='utf-8-sig')
            df['社員番号'] = df['社員番号'].astype(str).str.strip()
            return df.set_index('社員番号')['氏名'].to_dict()
        except: return {}

    def load_model_info(self):
        if not os.path.exists('model_name.csv'): return {}
        try:
            df = pd.read_csv('model_name.csv', encoding='utf-8-sig')
            info_dict = {}
            for _, row in df.iterrows():
                if str(row.get('作業内容', '')).strip() != "清掃": continue
                key = (str(row['機種名']).strip(), str(row['メーカー']).strip())
                try:
                    std_qty = float(row['1時間標準作業台数'])
                    if std_qty <= 0: std_qty = 10.0
                except: std_qty = 10.0
                info_dict[key] = {"abbr": str(row['メーカー略称']).strip(), "std_qty": std_qty}
            return info_dict
        except: return {}

    def get_cheer_content(self, progress):
        emojis, msgs = self.today_char["emojis"], self.today_char["msgs"]
        if progress <= 0: return emojis[ 0 ], msgs[ 0 ]
        elif progress < 0.4: return emojis[ 1 ], msgs[ 1 ]
        elif progress < 0.8: return emojis[ 2 ], msgs[ 2 ]
        elif progress < 1.0: return emojis[ 3 ], msgs[ 3 ]
        else: return emojis[ 4 ], msgs[ 4 ]

    def create_neon_bar(self, name, value, max_value, color, rank_emoji="", current_width=0, font_size=18, name_color="white"):
        percent = value / max_value if max_value > 0 else 0
        return ft.Column([
            ft.Row([
                ft.Row([
                    ft.Text(f"{rank_emoji}", size=18, font_family="Emoji"),
                    ft.Text(f"{name}", size=font_size, weight="bold", color=name_color, overflow=ft.TextOverflow.ELLIPSIS, no_wrap=True),
                    ft.Text(" さん", size=12, color=ft.Colors.GREY_400),
                ], spacing=0, expand=True, vertical_alignment="end"),
                ft.Text(f"{value:.1f}pt", size=20, weight="w900", color=color),
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ft.Stack([
                ft.Container(height=16, bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.WHITE), border_radius=8),
                ft.Container(height=16, width=current_width, bgcolor=color, border_radius=8, 
                             animate=ft.animation.Animation(1000, ft.AnimationCurve.DECELERATE), data=percent),
            ])
        ], spacing=6, key=name)

    def update_tab(self, df_all, date_str):
        self.date_text.value = f"{date_str}"
        
        # 💡 型エラー防止（数値変換）
        if '清掃台数' in df_all.columns:
            df_all['清掃台数'] = pd.to_numeric(df_all['清掃台数'], errors='coerce').fillna(0)

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
            df_rank = df_rank[df_rank['清掃台数'] > 0].copy()
            
        except Exception as e:
            print(f"CleaningView Filter Error: {e}"); return

        # --- 右側：本日実績リスト ---
        self.model_list.controls.clear()
        if df_today.empty:
            self.total_display.value, self.progress_bar.value, self.progress_percent.value = "0", 0, "0%"
            self.status_emoji.value, self.status_message.value = self.today_char["emojis"][ 0 ], self.today_char["msgs"][ 0 ]
        else:
            total_units = int(df_today['清掃台数'].sum())
            self.total_display.value = str(total_units)
            progress_val = total_units / self.target_count if self.target_count > 0 else 0
            self.progress_bar.value, self.progress_percent.value = min(progress_val, 1.0), f"{int(progress_val * 100)}%"
            self.status_emoji.value, self.status_message.value = self.get_cheer_content(progress_val)
            
            df_cleaning_only = df_today[df_today['清掃台数'] > 0].copy()
            if not df_cleaning_only.empty:
                # groupby集計
                model_summary = df_cleaning_only.groupby(['機種名', 'メーカー'])['清掃台数'].sum().reset_index()
                model_summary = model_summary.sort_values('清掃台数', ascending=False)
                
                for _, row in model_summary.iterrows():
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
                                ft.Text(f"{int(row['清掃台数'])}台", size=16, weight="bold", color="#00ffcc")
                            ], alignment="spaceBetween"),
                            padding=ft.Padding(8, 4, 15, 4), 
                            border=ft.Border(bottom=ft.BorderSide(1, "#2D3039"))
                        )
                    )

        # --- 左側：ランキング ---
        for col in self.chart_columns: col.controls.clear()
        if not df_rank.empty:
            def get_pt(row):
                m_name, m_maker = str(row.get('機種名', '')).strip(), str(row.get('メーカー', '')).strip()
                info = self.model_info_map.get((m_name, m_maker))
                if info is None:
                    for k, v in self.model_info_map.items():
                        if k[ 0 ] in m_name: info = v; break
                
                std_qty = float(info["std_qty"]) if info and "std_qty" in info else 10.0
                unit_pt = 60.0 / std_qty
                base_points = float((int(row.get('清掃台数', 0) or 0)) * unit_pt)
                lucky_bonus = 1.2 if str(row.get('ラッキーフラグ', '')).strip() == "Lucky" else 1.0
                return base_points * lucky_bonus

            df_rank['ポイント'] = df_rank.apply(get_pt, axis=1)
            worker_points = df_rank.groupby('社員番号')['ポイント'].sum().sort_values(ascending=False)
            worker_points = worker_points[worker_points > 0]
            max_point_val = worker_points.max() if not worker_points.empty else 10

            for i in range(3):
                subset = worker_points.iloc[i*10:(i+1)*10]
                for idx, (s_id, points) in enumerate(subset.items()):
                    raw_name = self.worker_master.get(str(s_id).strip(), str(s_id))
                    name, rank_emoji, bar_color, name_color = raw_name[:10], "", "#00ccff", "white"
                    is_today_lucky = not df_today[(df_today['社員番号'] == str(s_id)) & (df_today['ラッキーフラグ'] == "Lucky")].empty
                    if is_today_lucky:
                        name = f"{name}"
                        rank_emoji = "✨"
                        name_color = "#FFD700"
                    
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
                                bar_container.width = 180 * bar_container.data # Web版サイズ
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
                            bar_container.width = 180 * bar_container.data
                        except: continue
                self.update()

    def open_target_dialog(self, e):
        self.target_input = ft.TextField(label="新しい目標台数", value=str(self.target_count), keyboard_type=ft.KeyboardType.NUMBER, text_align=ft.TextAlign.RIGHT, suffix_text=" 台")
        self.target_dialog = ft.AlertDialog(title=ft.Text("目標台数の変更"), content=ft.Column([ft.Text("本日の目標台数を入力してください。"), self.target_input], height=120, tight=True), actions=[ft.TextButton("キャンセル", on_click=self.close_target_dialog), ft.ElevatedButton("確定", on_click=self.change_target_count, bgcolor="#00ccff", color="black")])
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