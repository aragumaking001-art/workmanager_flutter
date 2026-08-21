import flet as ft
import pandas as pd
import os
from datetime import datetime, timedelta
import asyncio

class TotalRankingView(ft.Column):
    def __init__(self):
        super().__init__(expand=True, spacing=10)
        self.last_max_id = 0  
        self.is_first_open = True 
        self.rank_mode = "Week" 
        self.custom_start_date = datetime.now()
        self.custom_end_date = datetime.now()

        self.chart_columns = [ft.Column(spacing=15, scroll=ft.ScrollMode.ADAPTIVE, horizontal_alignment=ft.CrossAxisAlignment.STRETCH) for _ in range(3)]
        self.worker_master = {}
        self.model_info_map = {}
        self.last_worker_points = None
        
        self.weekly_period_label = ft.Text("", size=18, color=ft.Colors.WHITE, weight="bold")

        # カレンダー設定（共通）
        self.start_picker = ft.DatePicker(on_change=self.on_start_date_change, first_date=datetime(2023, 1, 1), last_date=datetime(2030, 12, 31))
        self.end_picker = ft.DatePicker(on_change=self.on_end_date_change, first_date=datetime(2023, 1, 1), last_date=datetime(2030, 12, 31))

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

        self.controls = [
            ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Icon(ft.Icons.EMOJI_EVENTS_ROUNDED, color="#FFD700", size=30), 
                        ft.Text("4F 作業ランキング", size=28, weight="bold"), 
                        self.weekly_period_label, 
                        ft.Container(expand=True), 
                        self.mode_selector
                    ], vertical_alignment="center"),
                    ft.Row([
                        ft.Container(content=self.chart_columns[ 0 ], expand=True),
                        ft.VerticalDivider(color="#33363F", width=1),
                        ft.Container(content=self.chart_columns[ 1 ], expand=True),
                        ft.VerticalDivider(color="#33363F", width=1),
                        ft.Container(content=self.chart_columns[ 2 ], expand=True),
                    ], expand=True, spacing=20, vertical_alignment="start"),
                ]),
                expand=True, bgcolor="#1A1C23", padding=30, border_radius=20,
            )
        ]

    def did_mount(self):
        if self.page:
            self.page.overlay.extend([self.start_picker, self.end_picker])
            self.page.update()

    def load_worker_master(self, df_members=None):
        if df_members is not None and not df_members.empty:
            try:
                # m_members から辞書作成: worker_id -> worker_name
                return df_members.set_index("worker_id")["worker_name"].to_dict()
            except: pass
        if not os.path.exists('members.csv'): return {}
        try:
            df = pd.read_csv('members.csv', encoding='utf-8-sig')
            return df.set_index(df.columns[ 0 ].strip())[df.columns[ 1 ].strip()].to_dict()
        except: return {}

    def load_model_info(self, df_models=None):
        if df_models is not None and not df_models.empty:
            try:
                info_dict = {}
                for _, row in df_models.iterrows():
                    key = (str(row['model_name']).strip(), str(row['maker']).strip(), str(row['work_type']).strip())
                    try:
                        std_qty = float(row['std_qty'])
                        if std_qty <= 0: std_qty = 10.0
                    except: std_qty = 10.0
                    info_dict[key] = std_qty
                return info_dict
            except: pass
            
        if not os.path.exists('model_name.csv'): return {}
        try:
            df = pd.read_csv('model_name.csv', encoding='utf-8-sig')
            info_dict = {}
            for _, row in df.iterrows():
                key = (str(row['機種名']).strip(), str(row['メーカー']).strip(), str(row['作業内容']).strip())
                try:
                    std_qty = float(row['1時間標準作業台数'])
                    if std_qty <= 0: std_qty = 10.0
                except: std_qty = 10.0
                info_dict[key] = std_qty
            return info_dict
        except: return {}

    def create_neon_bar(self, name, value, max_value, color, rank_emoji="", current_width=0, font_size=22, name_color="white"):
        percent = value / max_value if max_value > 0 else 0
        return ft.Column([
            ft.Row([
                ft.Row([
                    ft.Text(f"{rank_emoji}", size=22, font_family="Emoji"),
                    ft.Text(f"{name}", size=font_size, weight="bold", color=name_color, overflow=ft.TextOverflow.ELLIPSIS),
                    ft.Text(" さん", size=14, color=ft.Colors.GREY_400),
                ], spacing=0, expand=True, vertical_alignment=ft.CrossAxisAlignment.END),
                ft.Text(f"{value:.1f}pt", size=24, weight="w900", color=color),
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.CENTER),
            ft.Stack([
                ft.Container(height=22, bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.WHITE), border_radius=12),
                ft.Container(height=22, width=current_width, bgcolor=color, border_radius=12, animate=ft.Animation(1000, "decelerate"), data=percent),
            ])
        ], spacing=10)

    def update_tab(self, df_all, date_str, df_members=None, df_models=None):
        self.worker_master = self.load_worker_master(df_members)
        self.model_info_map = self.load_model_info(df_models)

        # 期間計算ロジック (他タブと同様)
        today_dt = datetime.strptime(date_str, "%Y/%m/%d")
        if self.rank_mode == "Day": start_dt, end_dt = today_dt, today_dt
        elif self.rank_mode == "Week":
            monday_dt = today_dt - timedelta(days=today_dt.weekday())
            start_dt, end_dt = monday_dt, monday_dt + timedelta(days=5)
        elif self.rank_mode == "Month":
            start_dt = today_dt.replace(day=1)
            next_month = today_dt.replace(day=28) + timedelta(days=4)
            end_dt = next_month - timedelta(days=next_month.day)
        else: start_dt, end_dt = self.custom_start_date, self.custom_end_date

        self.weekly_period_label.value = f" ({start_dt.strftime('%m/%d')} ～ {end_dt.strftime('%m/%d')})"
        df_rank = df_all[(df_all["日付"] >= start_dt.strftime("%Y/%m/%d")) & (df_all["日付"] <= end_dt.strftime("%Y/%m/%d"))].copy()

        def calc_total_pt(row):
            total_pt = 0
            m_name, m_maker = str(row.get('機種名', '')).strip(), str(row.get('メーカー', '')).strip()
            lucky_bonus = 1.2 if str(row.get('ラッキーフラグ', '')).strip() == "Lucky" else 1.0
            
            # 各作業のポイントを合算
            for work_type, col_name in [("清掃", "清掃台数"), ("エアー清掃", "エアー清掃台数"), ("筐体交換", "筐体交換台数")]:
                qty = pd.to_numeric(row.get(col_name, 0), errors='coerce') or 0
                if qty > 0:
                    std = self.model_info_map.get((m_name, m_maker, work_type), 10.0 if "清掃" in work_type else 30.0)
                    total_pt += (qty * (60.0 / std))
            return total_pt * lucky_bonus

        if not df_rank.empty:
            df_rank['ポイント'] = df_rank.apply(calc_total_pt, axis=1)
            worker_points = df_rank.groupby('社員番号')['ポイント'].sum().sort_values(ascending=False)
            worker_points = worker_points[worker_points > 0]
            
            # 💡 データが前回と全く同じなら再描画とアニメーションをスキップ
            if self.last_worker_points is not None and self.last_worker_points.equals(worker_points):
                return
            self.last_worker_points = worker_points.copy()

            # 💡 差分があるときだけクリアして再構築する
            for col in self.chart_columns: col.controls.clear()
            
            max_pt = worker_points.max() if not worker_points.empty else 10
            
            for i in range(3):
                subset = worker_points.iloc[i*10:(i+1)*10]
                for idx, (s_id, pts) in enumerate(subset.items()):
                    name = self.worker_master.get(str(s_id).strip(), str(s_id))[:10]
                    rank_emoji, bar_color, name_color = "", "#00ccff", "white"
                    
                    if i == 0:
                        if idx == 0: rank_emoji, bar_color = "🥇 ", "#FFD700"
                        elif idx == 1: rank_emoji, bar_color = "🥈 ", "#C0C0C0"
                        elif idx == 2: rank_emoji, bar_color = "🥉 ", "#CD7F32"
                    
                    self.chart_columns[ i ].controls.append(self.create_neon_bar(name, pts, max_pt, bar_color, rank_emoji))

        if self.page:
            self.update()
            async def animate():
                await asyncio.sleep(0.1)
                for col in self.chart_columns:
                    for ctrl in col.controls:
                        try:
                            bar = ctrl.controls[ 1 ].controls[ 1 ]
                            bar.width = 300 * bar.data
                        except: continue
                if self.page: # ここでも念のためチェック
                    self.update()
            self.page.run_task(animate)

    def on_mode_change(self, e):
        self.rank_mode = list(e.control.selected)[ 0 ]
        self.last_worker_points = None # 💡 モード変更時は強制再描画
        if self.rank_mode == "Custom": self.page.open(self.start_picker)
        if hasattr(self, 'on_mode_change_callback'): self.on_mode_change_callback()

    def on_start_date_change(self, e):
        self.custom_start_date = e.control.value
        self.page.open(self.end_picker)

    def on_end_date_change(self, e):
        self.custom_end_date = e.control.value
        if hasattr(self, 'on_mode_change_callback'): self.on_mode_change_callback()