import flet as ft
import pandas as pd
import math
import asyncio # 💡 Web版の非同期アニメーションに必須

class SummaryView(ft.Row):
    def __init__(self):
        super().__init__(expand=True, spacing=0)
        
        # --- CSVマスターの読み込み ---
        try:
            self.masters_df = pd.read_csv('model_name.csv', encoding='utf-8-sig').fillna("")
        except Exception as e:
            print(f"Master Load Error: {e}")
            self.masters_df = pd.DataFrame()
            
        # --- 左側：機種選択リスト ---
        self.model_list_column = ft.Column(scroll=ft.ScrollMode.ADAPTIVE, expand=True, spacing=8)
        self.master_panel = ft.Container(
            content=ft.Column([
                ft.Row([ft.Icon(ft.Icons.LIST_ALT, color="#00ccff", size=22), ft.Text("機種一覧", size=18, weight="bold")], spacing=8),
                ft.Divider(color="#33363F", height=15),
                self.model_list_column
            ]),
            width=260, # 💡 タブレット向けに幅縮小 (350 -> 260)
            padding=15, # パディング縮小
            bgcolor="#14161E",
        )

        # --- 右側：詳細分析エリア ---
        self.detail_area = ft.Container(
            content=ft.Column([
                ft.Icon(ft.Icons.ANALYTICS_OUTLINED, size=80, color="#33363F"),
                ft.Text("左のリストから機種を選択してください", color="#555555", size=16)
            ], alignment="center", horizontal_alignment="center"),
            expand=True,
            padding=ft.padding.all(20), # 💡 余白縮小 (40 -> 20)
            bgcolor="#0F1115",
        )

        self.controls = [
            self.master_panel,
            ft.VerticalDivider(width=1, color="#33363F"),
            self.detail_area
        ]
        
        self.full_df = None
        
        # アニメーションの状態管理用
        self.is_animating = False

        self.model_info_map = self.load_model_info()

    def load_model_info(self):
        if self.masters_df.empty: return {}
        try:
            info_dict = {}
            for _, row in self.masters_df.iterrows():
                # キーの作成 (機種名, メーカー)
                m_name = str(row["機種名"]).strip()
                m_maker = str(row["メーカー"]).strip()
                key = (m_name, m_maker)
                
                # 機種とメーカーの枠がなければ初期化
                if key not in info_dict:
                    raw_abbr = row.get('メーカー略称', '')
                    abbr = str(raw_abbr).strip() if pd.notna(raw_abbr) and str(raw_abbr).lower() != "nan" else ""
                    info_dict[key] = {"abbr": abbr, "targets": {}}

                # 作業内容（エアー清掃 / 清掃 / 筐体交換）を取得
                w_type = str(row.get('作業内容', '')).strip()
                try:
                    # 💡 空欄またはCSVにない場合は 0.0 に設定
                    std_val = float(row["1時間標準作業台数"]) if row["1時間標準作業台数"] != "" else 0.0
                except:
                    std_val = 0.0
                
                # 特定の作業内容に数値を紐付ける
                info_dict[key]["targets"][w_type] = std_val
                
            return info_dict
        except Exception as e:
            print(f"SummaryView load_model_info Error: {e}")
            return {}
    
    def calculate_rates(self, air, clean, to_swap, to_clean):
        base_total = air + clean
        swap_trigger_rate = (to_swap / base_total * 100) if base_total > 0 else 0
        air_op_total = air + to_clean
        air_rate = (air / air_op_total * 100) if air_op_total > 0 else 0
        return swap_trigger_rate, air_rate

    def create_speed_card(self, label, actual, std, icon_color, icon):
        has_data = actual > 0
        is_efficient = actual >= std if std > 0 else True
        
        if not has_data:
            bg_color, border_color = "#1A1A1A", "#333333"
            display_actual, display_icon_color, text_color = "0.0", ft.Colors.GREY_700, ft.Colors.GREY_600
        elif is_efficient:
            bg_color, border_color = "#0D3211", "#1B5E20"
            display_actual, display_icon_color, text_color = f"{actual:.1f}", icon_color, ft.Colors.WHITE
        else:
            bg_color, border_color = "#2E2401", "#B8860B"
            display_actual, display_icon_color, text_color = f"{actual:.1f}", icon_color, ft.Colors.WHITE

        # 💡 タブレット向けにカードサイズとフォントを縮小
        return ft.Container(
            padding=15, 
            bgcolor=bg_color, 
            border_radius=12, 
            border=ft.border.all(2, border_color),
            expand=True,
            content=ft.Column([
                ft.Row([
                    ft.Icon(icon, color=display_icon_color, size=24),
                    ft.Text(label, size=14, color=ft.Colors.GREY_300 if has_data else ft.Colors.GREY_700, weight="bold"),
                ], alignment="center", spacing=5),
                ft.Text(display_actual, size=32, color=text_color, weight="w900"),
                ft.Text(f"台/1H (目標: {std:.1f})", size=11, color=ft.Colors.GREY_500 if has_data else ft.Colors.GREY_800),
            ], spacing=2, horizontal_alignment="center")
        )

    def create_mini_stat(self, label, value, unit, label_color, value_color):
        return ft.Column([
            ft.Container(content=ft.Text(label, size=12, color=label_color, weight="bold"), alignment=ft.alignment.center, width=60), 
            ft.Container(
                content=ft.Row([
                    ft.Text(value, size=20, weight="bold", color=value_color),
                    # unit(台/1Hなど)はスペース節約のため省略
                ], vertical_alignment="end", spacing=2, alignment=ft.MainAxisAlignment.CENTER),
                width=60
            )
        ], spacing=0, horizontal_alignment="center")

    def create_flow_item(self, label, count, icon, color, show_arrow=True):
        items = []
        if show_arrow: items.append(ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color="#33363F", size=18))
        items.append(ft.Container(
            content=ft.Column([
                ft.Icon(icon, size=24, color=color),
                ft.Text(f"{count:,}", size=22, weight="bold"),
                ft.Text(label, size=11, color=ft.Colors.GREY_500, weight="bold")
            ], horizontal_alignment="center", spacing=0),
            width=80 # 💡 110 -> 80 に圧縮
        ))
        return ft.Row(items, vertical_alignment="center", spacing=0)

    def show_detail(self, model_name):
        model_df = self.full_df[self.full_df["機種名"] == model_name].copy()
        
        target_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数', '清掃行き台数', '筐体交換行き台数', '作業時間']
        for col in target_cols:
            if col in model_df.columns:
                model_df[col] = pd.to_numeric(model_df[col], errors='coerce').fillna(0)

        # 💡 --- 修正箇所：個別に取得し、デフォルトを 0.0 に ---
        target_air = 0.0
        target_clean = 0.0
        target_swap = 0.0

        for (m_k_name, m_k_maker), info in self.model_info_map.items():
            if m_k_name in model_name:
                t_map = info.get("targets", {})
                target_air = t_map.get("エアー清掃", 0.0)
                target_clean = t_map.get("清掃", 0.0)
                target_swap = t_map.get("筐体交換", 0.0)
                break

        m_air = int(model_df['エアー清掃台数'].sum())
        m_clean = int(model_df['清掃台数'].sum())
        m_swap = int(model_df['筐体交換台数'].sum())
        total_gen_clean = int(model_df['清掃行き台数'].sum())
        total_gen_swap = int(model_df['筐体交換行き台数'].sum())
        m_to_clean, m_to_swap = max(0, total_gen_clean - m_clean), max(0, total_gen_swap - m_swap)
        finished_total = m_air + m_clean + m_swap

        def calc_spd(u, t): return u / (t / 60) if t > 0 else 0.0
        air_speed = calc_spd(m_air, model_df[model_df['エアー清掃台数'] > 0]['作業時間'].sum())
        clean_speed = calc_spd(m_clean, model_df[model_df['清掃台数'] > 0]['作業時間'].sum())
        swap_speed = calc_spd(m_swap, model_df[model_df['筐体交換台数'] > 0]['作業時間'].sum())
        
        m_swap_rate, m_air_rate = self.calculate_rates(m_air, m_clean, total_gen_swap, total_gen_clean)

        maker_rows = []
        model_df["メーカー"] = model_df["メーカー"].fillna("").astype(str)
        maker_groups = model_df.groupby("メーカー")

        for maker_raw_name, m_df in maker_groups:
            # 💡 タプル対応・nan排除
            clean_m_name = str(maker_raw_name[ 0 ] if isinstance(maker_raw_name, tuple) else maker_raw_name).strip()
            if not clean_m_name or clean_m_name.lower() == "nan":
                clean_m_name = "不明"

            r_air = int(m_df['エアー清掃台数'].sum())
            r_to_clean = int(m_df['清掃行き台数'].sum())
            r_clean = int(m_df['清掃台数'].sum())
            r_to_swap = int(m_df['筐体交換行き台数'].sum())
            r_swap = int(m_df['筐体交換台数'].sum())
            r_total = r_air + r_clean + r_swap
            
            r_air_spd = calc_spd(r_air, m_df[m_df['エアー清掃台数'] > 0]['作業時間'].sum())
            r_clean_spd = calc_spd(r_clean, m_df[m_df['清掃台数'] > 0]['作業時間'].sum())
            r_swap_spd = calc_spd(r_swap, m_df[m_df['筐体交換台数'] > 0]['作業時間'].sum())
            sw_rate, ar_rate = self.calculate_rates(r_air, r_clean, r_to_swap, r_to_clean)
            
            mfr_abbr = ""
            row_std_val = 10.0
            for (m_k_name, m_k_maker), info in self.model_info_map.items():
                if m_k_name in model_name and m_k_maker == clean_m_name:
                    mfr_abbr = info.get("abbr", "")
                    row_std_val = info.get("std_qty", 10.0)
                    break
            
            if mfr_abbr and str(mfr_abbr).lower() != "nan":
                maker_display_label = f"{clean_m_name} ({mfr_abbr})"
            else:
                maker_display_label = f"{clean_m_name}"
            
            a_color = ft.Colors.GREEN_ACCENT if r_air_spd >= row_std_val else ft.Colors.ORANGE_ACCENT
            c_color = ft.Colors.GREEN_ACCENT if r_clean_spd >= row_std_val else ft.Colors.ORANGE_ACCENT
            s_color = ft.Colors.GREEN_ACCENT if r_swap_spd >= row_std_val else ft.Colors.ORANGE_ACCENT
            
            # 💡 タブレット向けに「メーカー別行」の幅を極限まで圧縮
            maker_rows.append(ft.Container(
                bgcolor="#1A1C23", padding=ft.padding.symmetric(vertical=10, horizontal=15), border_radius=10, border=ft.border.all(1, "#33363F"),
                content=ft.Row([
                    ft.Container(content=ft.Column([
                        ft.Text(maker_display_label, size=15, weight="bold", color="#00ccff", overflow=ft.TextOverflow.ELLIPSIS),
                        ft.Row([ft.Text("完了:", size=12, color=ft.Colors.GREY_500), ft.Text(f"{r_total:,}", size=18, weight="w900", color="white")], vertical_alignment="end", spacing=4),
                    ], spacing=2), width=160),
                    
                    ft.VerticalDivider(color="#33363F", width=15),
                    
                    ft.Container(content=ft.Row([
                        self.create_mini_stat("エアー", f"{r_air_spd:.1f}", "", "#00ccff", a_color),
                        self.create_mini_stat("清掃", f"{r_clean_spd:.1f}", "", "#00ffcc", c_color),
                        self.create_mini_stat("交換", f"{r_swap_spd:.1f}", "", ft.Colors.AMBER_400, s_color),
                    ], spacing=5, alignment=ft.MainAxisAlignment.CENTER), width=200),
                    
                    ft.VerticalDivider(color="#33363F", width=15),
                    
                    ft.Container(content=ft.Row([
                        ft.Column([ft.Icon(ft.Icons.AIR_ROUNDED, size=16, color="#00ccff"), ft.Text(f"{r_air:,}", size=16, weight="w900")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=ft.Colors.GREY_700, size=12),
                        ft.Column([ft.Icon(ft.Icons.FORWARD_ROUNDED, size=16, color=ft.Colors.BLUE_GREY_400), ft.Text(f"{r_to_clean:,}", size=16, weight="bold")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=ft.Colors.GREY_700, size=12),
                        ft.Column([ft.Icon(ft.Icons.CLEANING_SERVICES_ROUNDED, size=16, color="#00ffcc"), ft.Text(f"{r_clean:,}", size=16, weight="w900")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=ft.Colors.GREY_700, size=12),
                        ft.Column([ft.Icon(ft.Icons.REPORT_PROBLEM_OUTLINED, size=16, color=ft.Colors.ORANGE_ACCENT_700), ft.Text(f"{r_to_swap:,}", size=16, weight="bold")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=ft.Colors.GREY_700, size=12),
                        ft.Column([ft.Icon(ft.Icons.SETTINGS_OUTLINED, size=16, color=ft.Colors.AMBER_400), ft.Text(f"{r_swap:,}", size=16, weight="w900")], horizontal_alignment="center", spacing=2),
                    ], spacing=6, alignment="center"), width=340),
                    
                    ft.VerticalDivider(color="#33363F", width=15),
                    
                    ft.Row([
                        ft.Column([ft.Text("ｴｱｰ率", size=11, color=ft.Colors.GREY_500, weight="bold"), ft.Text(f"{ar_rate:.0f}%", size=18, weight="w900", color="#00ccff")], spacing=0, horizontal_alignment="center"),
                        ft.Container(width=10),
                        ft.Column([ft.Text("交換率", size=11, color=ft.Colors.GREY_500, weight="bold"), ft.Text(f"{sw_rate:.0f}%", size=18, weight="w900", color=ft.Colors.RED_ACCENT_400)], spacing=0, horizontal_alignment="center"),
                    ], expand=True, alignment="end"),
                ], vertical_alignment="center")
            ))

        # 💡 全体レイアウトの余白・文字サイズ最適化
        self.detail_area.padding = 0
        self.detail_area.content = ft.Column([
            ft.Container(
                padding=ft.padding.symmetric(horizontal=30, vertical=20),
                content=ft.Column([
                    ft.Row([
                        ft.Column([ft.Text("機種名", size=12, color="#00ccff", weight="bold"), ft.Text(model_name, size=32, weight="w900", color="white", overflow=ft.TextOverflow.ELLIPSIS)], expand=True, spacing=0),
                        ft.Row([
                            ft.Container(content=ft.Column([ft.Text("未清掃", size=11, color=ft.Colors.GREY_500, weight="bold"), ft.Text(f"{m_to_clean:,}", size=24, weight="w900", color=ft.Colors.ORANGE_ACCENT)], horizontal_alignment="center", spacing=0), bgcolor="#25211E", padding=ft.padding.symmetric(horizontal=15, vertical=8), border_radius=8, border=ft.border.all(1, "#3D342E")),
                            ft.Container(content=ft.Column([ft.Text("未交換", size=11, color=ft.Colors.GREY_500, weight="bold"), ft.Text(f"{m_to_swap:,}", size=24, weight="w900", color=ft.Colors.RED_ACCENT)], horizontal_alignment="center", spacing=0), bgcolor="#2A1E1E", padding=ft.padding.symmetric(horizontal=15, vertical=8), border_radius=8, border=ft.border.all(1, "#4D2B2B")),
                            ft.Container(width=10),
                            ft.Column([ft.Text("筐体完了合計", size=14, color="#FFD700", weight="bold"), ft.Row([ft.Text(f"{finished_total:,}", size=45, weight="w900", color="#FFD700"), ft.Text("台", size=18, color="#FFD700", weight="bold")], vertical_alignment="end", spacing=4)], horizontal_alignment="end", spacing=0),
                        ], vertical_alignment="center", spacing=10),
                    ], alignment="spaceBetween", vertical_alignment="end"),
                    
                    ft.Divider(height=20, color="#33363F"),
                    
                    ft.Row([ft.Icon(ft.Icons.SPEED_ROUNDED, color="#00ccff", size=22), ft.Text("作業効率", size=18, weight="bold")]),
                    ft.Row([
                        self.create_speed_card("エアー清掃", air_speed, target_air, "#00ccff", ft.Icons.AIR_ROUNDED), 
                        self.create_speed_card("通常清掃", clean_speed, target_clean, "#00ffcc", ft.Icons.CLEANING_SERVICES_ROUNDED), 
                        self.create_speed_card("筐体交換", swap_speed, target_swap, ft.Colors.AMBER_400, ft.Icons.SETTINGS_OUTLINED)
                    ], spacing=10),
                    
                    ft.Container(height=15),
                    
                    ft.Row([ft.Icon(ft.Icons.ANALYTICS_ROUNDED, color="#00ffcc", size=22), ft.Text("実績フロー ＆ 品質", size=18, weight="bold")]),
                    ft.Row([
                        ft.Container(expand=6, height=140, padding=15, bgcolor="#111319", border_radius=15, border=ft.border.all(1, "#252830"), content=ft.Column([ft.Container(expand=True), ft.Row([self.create_flow_item("エアー", m_air, ft.Icons.AIR_ROUNDED, "#00ccff", False), self.create_flow_item("清掃行き", total_gen_clean, ft.Icons.FORWARD_ROUNDED, ft.Colors.BLUE_GREY_400), self.create_flow_item("清掃", m_clean, ft.Icons.CLEANING_SERVICES_ROUNDED, "#00ffcc"), self.create_flow_item("交換行き", total_gen_swap, ft.Icons.REPORT_PROBLEM_OUTLINED, ft.Colors.ORANGE_ACCENT_700), self.create_flow_item("交換完了", m_swap, ft.Icons.SETTINGS_OUTLINED, ft.Colors.AMBER_400)], alignment="center", spacing=0), ft.Container(expand=True)], spacing=0)),
                        ft.Container(expand=4, height=140, padding=15, bgcolor="#1A1C23", border_radius=15, border=ft.border.all(1, "#33363F"), content=ft.Column([ft.Row([ft.Icon(ft.Icons.QUERY_STATS_ROUNDED, size=14, color=ft.Colors.GREY_500), ft.Text("発生率概要", size=14, weight="bold", color=ft.Colors.GREY_500)], spacing=5, alignment="center"), ft.Divider(color="#33363F", height=10), ft.Column([ft.Container(expand=True), ft.Column([ft.Row([ft.Text("エアー清掃率", size=12, weight="bold", color=ft.Colors.GREY_300), ft.Text(f"{m_air_rate:.1f}%", size=16, weight="w900", color="#00ccff")], alignment="spaceBetween", vertical_alignment="end"), ft.ProgressBar(value=m_air_rate/100, color="#00ccff", bgcolor="#333333", height=8)], spacing=3), ft.Container(height=5), ft.Column([ft.Row([ft.Text("筐体交換発生率", size=12, weight="bold", color=ft.Colors.GREY_300), ft.Text(f"{m_swap_rate:.1f}%", size=16, weight="w900", color=ft.Colors.RED_ACCENT_400)], alignment="spaceBetween", vertical_alignment="end"), ft.ProgressBar(value=m_swap_rate/100, color=ft.Colors.RED_ACCENT_400, bgcolor="#333333", height=8)], spacing=3), ft.Container(expand=True)], expand=True, spacing=0)], spacing=0)),
                    ], spacing=10, height=140),
                    
                    ft.Container(height=20),
                    
                    ft.Row([ft.Icon(ft.Icons.LIST_ALT_ROUNDED, color="#00ccff", size=22), ft.Text("メーカー別実績一覧", size=18, weight="bold")]),
                    ft.ExpansionTile(
                        title=ft.Text("メーカー別の詳細情報を表示", size=15, weight="bold", color="#00ccff"),
                        leading=ft.Icon(ft.Icons.TABLE_CHART_ROUNDED, color="#00ccff", size=20),
                        initially_expanded=False,
                        controls=[ft.Column(maker_rows, spacing=5)],
                        controls_padding=ft.padding.only(top=5, bottom=15),
                    ),
                ], spacing=0)
            )
        ], scroll=ft.ScrollMode.ADAPTIVE, spacing=0)
        self.update()

    def update_tab(self, df):
        if df is None or df.empty: return
        self.full_df = df.copy()
        
        numeric_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数', '筐体交換行き台数', '清掃行き台数', '作業時間']
        for col in numeric_cols:
            if col in self.full_df.columns: 
                self.full_df[col] = pd.to_numeric(self.full_df[col], errors='coerce').fillna(0)

        self.model_list_column.controls.clear()
        model_names = sorted(self.full_df["機種名"].unique())
        current_op = getattr(self, "current_pulse_opacity", 0.1)

        for name in model_names:
            m_df = self.full_df[self.full_df["機種名"] == name]
            
            t_air, t_clean, t_swap = 10.0, 10.0, 10.0
            for (m_k_name, m_k_maker), info in self.model_info_map.items():
                if m_k_name in name: 
                    t_air = info.get("std_qty", 10.0)
                    t_clean = info.get("std_qty", 10.0)
                    t_swap = info.get("std_qty", 10.0)
                    break

            m_air, a_time = int(m_df['エアー清掃台数'].sum()), m_df[m_df['エアー清掃台数'] > 0]['作業時間'].sum()
            m_clean, c_time = int(m_df['清掃台数'].sum()), m_df[m_df['清掃台数'] > 0]['作業時間'].sum()
            m_swap, s_time = int(m_df['筐体交換台数'].sum()), m_df[m_df['筐体交換台数'] > 0]['作業時間'].sum()
            
            def calc_spd(u, t): return u / (t / 60) if t > 0 else 0.0
            a_spd, c_spd, s_spd = calc_spd(m_air, a_time), calc_spd(m_clean, c_time), calc_spd(m_swap, s_time)
            
            total_count = m_air + m_clean + m_swap
            has_issue = (a_time > 0 and a_spd < t_air) or (c_time > 0 and c_spd < t_clean) or (s_time > 0 and s_spd < t_swap)

            if has_issue:
                card_content = ft.Stack([
                    ft.Container(bgcolor="#2E2401", border_radius=10, left=0, top=0, right=0, bottom=0),
                    ft.Container(bgcolor="#FFBF00", border_radius=10, opacity=current_op, key="blink_layer", left=0, top=0, right=0, bottom=0),
                    ft.Container(content=ft.Row([ft.Text(name, size=13, weight="bold", expand=True, color="white"), ft.Text(f"{total_count:,}台", size=12, color="#FFD700", weight="bold")]), padding=12)
                ], height=50)
                bg_color, border_style = None, ft.border.all(1, "#B8860B")
            else:
                card_content = ft.Row([ft.Text(name, size=13, weight="bold", expand=True, color="white"), ft.Text(f"{total_count:,}台", size=12, color="#A5D6A7", weight="bold")])
                bg_color, border_style = "#0D3211", ft.border.all(1, "#1B5E20")

            self.model_list_column.controls.append(ft.Container(
                content=card_content, padding=0 if has_issue else 12, border_radius=10, bgcolor=bg_color, border=border_style,
                key=str(has_issue), data=bg_color, on_click=lambda e, n=name: self.show_detail(n), on_hover=self.on_list_hover
            ))
            
        self.update() 
        if not self.is_animating: self.start_alert_animation()
        
    # --- 💡 Web版の安全な非同期アニメーションに修正 ---
    def start_alert_animation(self):
        if self.is_animating: return
        self.is_animating = True
        if self.page:
            self.page.run_task(self.run_animation_loop)

    async def run_animation_loop(self):
        self.current_pulse_opacity = 0.1
        step = 0.05 
        
        while self.is_animating:
            if getattr(self, "page", None) is None: break
            
            self.current_pulse_opacity += step
            
            if self.current_pulse_opacity >= 1.0:
                self.current_pulse_opacity = 1.0
                step = -0.05
                await asyncio.sleep(0.5) 
            elif self.current_pulse_opacity <= 0.1:
                self.current_pulse_opacity = 0.1
                step = 0.05
                await asyncio.sleep(0.3) 

            layers = []
            for card in self.model_list_column.controls:
                if getattr(card, "key", None) == "True" and isinstance(getattr(card, "content", None), ft.Stack):
                    for item in card.content.controls:
                        if getattr(item, "key", None) == "blink_layer":
                            layers.append(item)

            if layers:
                for layer in layers:
                    layer.opacity = self.current_pulse_opacity
                try:
                    self.model_list_column.update() 
                except:
                    break
            
            await asyncio.sleep(0.1)

    def stop_alert_animation(self):
        self.is_animating = False

    def will_unmount(self):
        self.stop_alert_animation()
        
    def on_list_hover(self, e):
        if e.control.key == "True":
            e.control.border = ft.border.all(2, "white") if e.data == "true" else None
            e.control.update()
            return

        base_color = e.control.data 
        if e.data == "true":
            e.control.bgcolor = "#2E7D32" 
        else:
            e.control.bgcolor = base_color
        e.control.update()