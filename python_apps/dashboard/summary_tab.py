import flet as ft
import pandas as pd
import math
import time # 💡 時間管理用に追加
import threading # 💡 これを追加

class SummaryView(ft.Row):
    def __init__(self):
        super().__init__(expand=True, spacing=0)
        # --- CSVマスターの読み込み ---
        self.masters_df = pd.DataFrame()
            
        # --- 左側：機種選択リスト ---
        self.model_list_column = ft.Column(scroll=ft.ScrollMode.ADAPTIVE, expand=True, spacing=10)
        self.master_panel = ft.Container(
            content=ft.Column([
                ft.Row([ft.Icon(ft.Icons.LIST_ALT, color="#00ccff"), ft.Text("機種一覧", size=20, weight="bold")], spacing=10),
                ft.Divider(color="#33363F", height=20),
                self.model_list_column
            ]),
            width=350,
            padding=25,
            bgcolor="#14161E",
        )

        # --- 右側：詳細分析エリア ---
        self.detail_area = ft.Container(
            content=ft.Column([
                ft.Icon(ft.Icons.ANALYTICS_OUTLINED, size=100, color="#33363F"),
                ft.Text("左のリストから機種を選択してください", color="#555555", size=18)
            ], alignment="center", horizontal_alignment="center"),
            expand=True,
            padding=ft.padding.all(40),
            bgcolor="#0F1115",
        )

        self.controls = [
            self.master_panel,
            ft.VerticalDivider(width=1, color="#33363F"),
            self.detail_area
        ]
        
        self.full_df = None
        
        # 💡 アニメーションの状態管理用
        self.animation_task = None
        self.is_animating = False

        # --- 💡 ここでマスター情報を整理しておく ---
        self.model_info_map = {}

    # --- ✨ 不足していた load_model_info を追加 (nan対策済み) ---
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

                # 作業内容（エアー清掃 / 清掃 / 筐体交換）ごとに数値を保存
                w_type = str(row.get('作業内容', '')).strip()
                try:
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
        # 1. データがあるかどうかの判定
        has_data = actual > 0
        # 2. 目標達成かどうかの判定（データがある場合のみ有効）
        is_efficient = actual >= std if std > 0 else True
        
        if not has_data:
            # ⚪ データなし：グレーアウト設定
            bg_color = "#1A1A1A"        # 非常に暗いグレー
            border_color = "#333333"    # 暗い枠線
            display_actual = "0.0"
            display_icon_color = ft.Colors.GREY_700 # アイコンも暗く
            text_color = ft.Colors.GREY_600
        elif is_efficient:
            # 🟢 達成時：深い緑
            bg_color = "#0D3211" 
            border_color = "#1B5E20"
            display_actual = f"{actual:.1f}"
            display_icon_color = icon_color
            text_color = ft.Colors.WHITE
        else:
            # 🟡 未達成時：深いアンバー
            bg_color = "#2E2401" 
            border_color = "#B8860B"
            display_actual = f"{actual:.1f}"
            display_icon_color = icon_color
            text_color = ft.Colors.WHITE

        return ft.Container(
            padding=20, 
            bgcolor=bg_color, 
            border_radius=15, 
            border=ft.border.all(2, border_color),
            expand=True,
            content=ft.Column([
                ft.Icon(icon, color=display_icon_color, size=35), 
                ft.Text(label, size=16, color=ft.Colors.GREY_300 if has_data else ft.Colors.GREY_700, weight="bold"),
                ft.Text(display_actual, size=42, color=text_color, weight="w900"),
                ft.Text(f"台/1H (目標: {std:.1f})", size=13, color=ft.Colors.GREY_500 if has_data else ft.Colors.GREY_800),
            ], spacing=5, horizontal_alignment="center")
        )

    # --- 💡 create_mini_stat も修正（ラベル色固定） ---
    def create_mini_stat(self, label, value, unit, label_color, value_color):
        return ft.Column([
            # ラベルを中央寄せにするために Container で包む
            ft.Container(
                content=ft.Text(label, size=15, color=label_color, weight="bold"),
                alignment=ft.alignment.center, # 💡 ラベルを中央に
                width=80 # 💡 各項目の幅を固定して揃える
            ), 
            # 数字部分は右揃え
            ft.Container(
                content=ft.Row([
                    ft.Text(value, size=26, weight="bold", color=value_color),
                    ft.Text(unit, size=13, color=ft.Colors.GREY_500) if unit else ft.Container(),
                ], vertical_alignment="end", spacing=2, alignment=ft.MainAxisAlignment.END), # 💡 数字を右に寄せる
                width=80
            )
        ], spacing=2, horizontal_alignment="center")

    def create_mini_gauge(self, label, value, color):
        return ft.Column([
            ft.Text(label, size=10, color=ft.Colors.GREY_500),
            ft.Row([
                ft.ProgressBar(value=value/100, color=color, bgcolor="#333333", height=8, width=120),
                ft.Text(f"{value:.0f}%", size=12, weight="bold", color=color),
            ], spacing=10)
        ], spacing=4)

    def create_flow_item(self, label, count, icon, color, show_arrow=True):
        items = []
        if show_arrow: items.append(ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color="#33363F", size=24))
        items.append(ft.Container(
            content=ft.Column([
                ft.Icon(icon, size=30, color=color),
                ft.Text(f"{count:,}", size=30, weight="bold"),
                ft.Text(label, size=16, color=ft.Colors.GREY_500, weight="bold")
            ], horizontal_alignment="center", spacing=2),
            width=110
        ))
        return ft.Row(items, vertical_alignment="center")

    def show_detail(self, model_name):
        # 1. 特定の機種のデータを抽出
        model_df = self.full_df[self.full_df["機種名"] == model_name].copy()
        
        # 💡 データ型を確実に数値に変換
        target_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数', '清掃行き台数', '筐体交換行き台数', '作業時間']
        for col in target_cols:
            if col in model_df.columns:
                model_df[col] = pd.to_numeric(model_df[col], errors='coerce').fillna(0)

        # 2. 【重要】まず代表的な目標値を初期化（NameError対策）
        # デフォルト値を設定
        target_air = 0.0
        target_clean = 0.0
        target_swap = 0.0

        for (m_k_name, m_k_maker), info in self.model_info_map.items():
            if m_k_name in model_name:
                t_map = info.get("targets", {})
                # CSVの「作業内容」列の文字列と完全一致させて取得
                target_air = t_map.get("エアー清掃", 0.0)
                target_clean = t_map.get("清掃", 0.0)
                target_swap = t_map.get("筐体交換", 0.0)
                break

        # 3. 累計計算
        m_air = int(model_df['エアー清掃台数'].sum())
        m_clean = int(model_df['清掃台数'].sum())
        m_swap = int(model_df['筐体交換台数'].sum())
        total_gen_clean = int(model_df['清掃行き台数'].sum())
        total_gen_swap = int(model_df['筐体交換行き台数'].sum())
        m_to_clean, m_to_swap = max(0, total_gen_clean - m_clean), max(0, total_gen_swap - m_swap)
        finished_total = m_air + m_clean + m_swap

        # 速度計算関数
        def calc_spd(u, t): return u / (t / 60) if t > 0 else 0.0
        air_speed = calc_spd(m_air, model_df[model_df['エアー清掃台数'] > 0]['作業時間'].sum())
        clean_speed = calc_spd(m_clean, model_df[model_df['清掃台数'] > 0]['作業時間'].sum())
        swap_speed = calc_spd(m_swap, model_df[model_df['筐体交換台数'] > 0]['作業時間'].sum())
        
        m_swap_rate, m_air_rate = self.calculate_rates(m_air, m_clean, total_gen_swap, total_gen_clean)

        # --- メーカー別行リスト作成 ---
        maker_rows = []
        model_df["メーカー"] = model_df["メーカー"].fillna("").astype(str)
        maker_groups = model_df.groupby("メーカー")

        for maker_raw_name, m_df in maker_groups:
            # メーカー名自体の表示ガード
            clean_m_name = maker_raw_name.strip()
            if not clean_m_name or clean_m_name.lower() == "nan":
                clean_m_name = ""

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
            
            # 略称の逆引き取得
            mfr_abbr = ""
            row_std_val = 10.0
            for (m_k_name, m_k_maker), info in self.model_info_map.items():
                if m_k_name in model_name and m_k_maker == maker_raw_name:
                    mfr_abbr = info.get("abbr", "")
                    row_std_val = info.get("std_qty", 10.0)
                    break
            
            # 表示ラベルの組み立て（nanを徹底排除）
            if mfr_abbr and str(mfr_abbr).lower() != "nan":
                maker_display_label = f"{clean_m_name} ({mfr_abbr})"
            else:
                maker_display_label = f"{clean_m_name}"
            
            # 色判定
            a_color = ft.Colors.GREEN_ACCENT if r_air_spd >= row_std_val else ft.Colors.ORANGE_ACCENT
            c_color = ft.Colors.GREEN_ACCENT if r_clean_spd >= row_std_val else ft.Colors.ORANGE_ACCENT
            s_color = ft.Colors.GREEN_ACCENT if r_swap_spd >= row_std_val else ft.Colors.ORANGE_ACCENT
            
            maker_rows.append(ft.Container(
                bgcolor="#1A1C23", padding=ft.padding.symmetric(vertical=15, horizontal=25), border_radius=12, border=ft.border.all(1, "#33363F"),
                content=ft.Row([
                    ft.Container(content=ft.Column([
                        ft.Text(maker_display_label, size=18, weight="bold", color="#00ccff", overflow=ft.TextOverflow.ELLIPSIS),
                        ft.Row([ft.Text("完了合計:", size=14, color=ft.Colors.GREY_500), ft.Text(f"{r_total:,}", size=24, weight="w900", color="white")], vertical_alignment="end", spacing=4),
                    ], spacing=2), width=220),
                    ft.VerticalDivider(color="#33363F", width=20),
                    ft.Container(content=ft.Row([
                        self.create_mini_stat("エアー", f"{r_air_spd:.1f}", "台/1H", "#00ccff", a_color),
                        self.create_mini_stat("通常清掃", f"{r_clean_spd:.1f}", "台/1H", "#00ffcc", c_color),
                        self.create_mini_stat("筐体交換", f"{r_swap_spd:.1f}", "台/1H", ft.Colors.AMBER_400, s_color),
                    ], spacing=20, alignment=ft.MainAxisAlignment.END), width=350, alignment=ft.alignment.center_right),
                    ft.VerticalDivider(color="#33363F", width=20),
                    ft.Container(content=ft.Row([
                        ft.Column([ft.Icon(ft.Icons.AIR_ROUNDED, size=24, color="#00ccff"), ft.Text(f"{r_air:,}", size=28, weight="w900")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.ARROW_FORWARD_IOS_ROUNDED, color=ft.Colors.GREY_800, size=12),
                        ft.Column([ft.Icon(ft.Icons.FORWARD_ROUNDED, size=24, color=ft.Colors.GREY_500), ft.Text(f"{r_to_clean:,}", size=28, weight="bold")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.ARROW_FORWARD_IOS_ROUNDED, color=ft.Colors.GREY_800, size=12),
                        ft.Column([ft.Icon(ft.Icons.CLEANING_SERVICES_ROUNDED, size=24, color="#00ffcc"), ft.Text(f"{r_clean:,}", size=28, weight="w900")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.ARROW_FORWARD_IOS_ROUNDED, color=ft.Colors.GREY_800, size=12),
                        ft.Column([ft.Icon(ft.Icons.REPORT_PROBLEM_OUTLINED, size=24, color=ft.Colors.ORANGE_ACCENT_700), ft.Text(f"{r_to_swap:,}", size=28, weight="bold")], horizontal_alignment="center", spacing=2),
                        ft.Icon(ft.Icons.ARROW_FORWARD_IOS_ROUNDED, color=ft.Colors.GREY_800, size=12),
                        ft.Column([ft.Icon(ft.Icons.SETTINGS_OUTLINED, size=24, color=ft.Colors.AMBER_400), ft.Text(f"{r_swap:,}", size=28, weight="w900")], horizontal_alignment="center", spacing=2),
                    ], spacing=10, alignment="center"), width=450),
                    ft.VerticalDivider(color="#33363F", width=20),
                    ft.Row([
                        ft.Column([ft.Text("エアー率", size=14, color=ft.Colors.GREY_500, weight="bold"), ft.Row([ft.Text(f"{ar_rate:.0f}", size=30, weight="w900", color="#00ccff"), ft.Text("%", size=14, color=ft.Colors.GREY_500)], vertical_alignment="end", spacing=2)], spacing=0, horizontal_alignment="center"),
                        ft.Container(width=15),
                        ft.Column([ft.Text("交換率", size=14, color=ft.Colors.GREY_500, weight="bold"), ft.Row([ft.Text(f"{sw_rate:.0f}", size=30, weight="w900", color=ft.Colors.RED_ACCENT_400), ft.Text("%", size=14, color=ft.Colors.GREY_500)], vertical_alignment="end", spacing=2)], spacing=0, horizontal_alignment="center"),
                    ], expand=True, alignment="end"),
                ], vertical_alignment="center")
            ))

        # UI描画
        self.detail_area.padding = 0
        self.detail_area.content = ft.Column([
            ft.Container(
                padding=ft.padding.all(40),
                content=ft.Column([
                    ft.Row([
                        ft.Column([ft.Text("機種名", size=14, color="#00ccff", weight="bold"), ft.Text(model_name, size=45, weight="w900", color="white", overflow=ft.TextOverflow.ELLIPSIS)], expand=True, spacing=0),
                        ft.Row([
                            ft.Container(content=ft.Column([ft.Text("未清掃", size=12, color=ft.Colors.GREY_500, weight="bold"), ft.Text(f"{m_to_clean:,}", size=35, weight="w900", color=ft.Colors.ORANGE_ACCENT)], horizontal_alignment="center", spacing=0), bgcolor="#25211E", padding=ft.padding.symmetric(horizontal=25, vertical=12), border_radius=12, border=ft.border.all(1, "#3D342E")),
                            ft.Container(content=ft.Column([ft.Text("未交換", size=12, color=ft.Colors.GREY_500, weight="bold"), ft.Text(f"{m_to_swap:,}", size=35, weight="w900", color=ft.Colors.RED_ACCENT)], horizontal_alignment="center", spacing=0), bgcolor="#2A1E1E", padding=ft.padding.symmetric(horizontal=25, vertical=12), border_radius=12, border=ft.border.all(1, "#4D2B2B")),
                            ft.Container(width=10),
                            ft.Column([ft.Text("筐体完了合計", size=16, color="#FFD700", weight="bold"), ft.Row([ft.Text(f"{finished_total:,}", size=65, weight="w900", color="#FFD700"), ft.Text("台", size=24, color="#FFD700", weight="bold")], vertical_alignment="end", spacing=8)], horizontal_alignment="end", spacing=0),
                        ], vertical_alignment="center", spacing=20),
                    ], alignment="spaceBetween", vertical_alignment="end"),
                    ft.Divider(height=40, color="#33363F"),
                    ft.Row([ft.Icon(ft.Icons.SPEED_ROUNDED, color="#00ccff", size=28), ft.Text("作業効率", size=24, weight="bold")]),
                    ft.Container(height=10),
                    ft.Row([self.create_speed_card("エアー清掃", air_speed, target_air, "#00ccff", ft.Icons.AIR_ROUNDED), self.create_speed_card("通常清掃", clean_speed, target_clean, "#00ffcc", ft.Icons.CLEANING_SERVICES_ROUNDED), self.create_speed_card("筐体交換", swap_speed, target_swap, ft.Colors.AMBER_400, ft.Icons.SETTINGS_OUTLINED)], spacing=15),
                    ft.Container(height=30),
                    ft.Row([ft.Icon(ft.Icons.ANALYTICS_ROUNDED, color="#00ffcc", size=28), ft.Text("実績フロー ＆ 品質", size=24, weight="bold")]),
                    ft.Container(height=10),
                    ft.Row([
                        ft.Container(expand=7, height=180, padding=20, bgcolor="#111319", border_radius=20, border=ft.border.all(1, "#252830"), content=ft.Column([ft.Container(expand=True), ft.Row([self.create_flow_item("エアー清掃", m_air, ft.Icons.AIR_ROUNDED, "#00ccff", False), self.create_flow_item("清掃行き", total_gen_clean, ft.Icons.FORWARD_ROUNDED, ft.Colors.BLUE_GREY_400), self.create_flow_item("通常清掃", m_clean, ft.Icons.CLEANING_SERVICES_ROUNDED, "#00ffcc"), self.create_flow_item("筐体交換行き", total_gen_swap, ft.Icons.REPORT_PROBLEM_OUTLINED, ft.Colors.ORANGE_ACCENT_700), self.create_flow_item("筐体交換完了", m_swap, ft.Icons.SETTINGS_OUTLINED, ft.Colors.AMBER_400)], alignment="center", spacing=5), ft.Container(expand=True)], spacing=0)),
                        ft.Container(expand=3, height=180, padding=ft.padding.all(20), bgcolor="#1A1C23", border_radius=20, border=ft.border.all(1, "#33363F"), content=ft.Column([ft.Row([ft.Icon(ft.Icons.QUERY_STATS_ROUNDED, size=16, color=ft.Colors.GREY_500), ft.Text("発生率概要", size=18, weight="bold", color=ft.Colors.GREY_500)], spacing=8, alignment="center"), ft.Divider(color="#33363F", height=10), ft.Column([ft.Container(expand=True), ft.Column([ft.Row([ft.Text("エアー清掃率", size=15, weight="bold", color=ft.Colors.GREY_300), ft.Text(f"{m_air_rate:.1f}%", size=20, weight="w900", color="#00ccff")], alignment="spaceBetween", vertical_alignment="end"), ft.ProgressBar(value=m_air_rate/100, color="#00ccff", bgcolor="#333333", height=12)], spacing=5), ft.Container(height=10), ft.Column([ft.Row([ft.Text("筐体交換発生率", size=15, weight="bold", color=ft.Colors.GREY_300), ft.Text(f"{m_swap_rate:.1f}%", size=20, weight="w900", color=ft.Colors.RED_ACCENT_400)], alignment="spaceBetween", vertical_alignment="end"), ft.ProgressBar(value=m_swap_rate/100, color=ft.Colors.RED_ACCENT_400, bgcolor="#333333", height=12)], spacing=5), ft.Container(expand=True)], expand=True, spacing=0)], spacing=0)),
                    ], spacing=15, height=180),
                    ft.Container(height=40),
                    ft.Row([ft.Icon(ft.Icons.LIST_ALT_ROUNDED, color="#00ccff", size=28), ft.Text("メーカー別実績一覧", size=24, weight="bold")]),
                    ft.Container(height=10),
                    ft.ExpansionTile(
                        title=ft.Text("メーカー別の詳細情報を表示", size=18, weight="bold", color="#00ccff"),
                        leading=ft.Icon(ft.Icons.TABLE_CHART_ROUNDED, color="#00ccff"),
                        initially_expanded=False,
                        controls=[ft.Column(maker_rows, spacing=5)],
                        controls_padding=ft.padding.only(top=10, bottom=20),
                    ),
                ], spacing=0)
            )
        ], scroll=ft.ScrollMode.ADAPTIVE, spacing=0)
        self.update()

    # --- 💡 修正版 update_tab (アニメーション設定を追加) ---
    def update_tab(self, df, df_members=None, df_models=None):
        if df_models is not None:
            self.masters_df = df_models.rename(columns={"model_name": "機種名", "maker": "メーカー", "maker_abbr": "メーカー略称", "category": "分類", "work_type": "作業内容", "std_qty": "1時間標準作業台数"}).fillna("")
        self.model_info_map = self.load_model_info(df_models)

        if df is None or df.empty: return
        self.full_df = df.copy()
        
        # 数値型への変換
        numeric_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数', '筐体交換行き台数', '清掃行き台数', '作業時間']
        for col in numeric_cols:
            if col in self.full_df.columns: 
                self.full_df[col] = pd.to_numeric(self.full_df[col], errors='coerce').fillna(0)

        self.model_list_column.controls.clear()
        model_names = sorted(self.full_df["機種名"].unique())
        current_op = getattr(self, "current_pulse_opacity", 0.1)

        for name in model_names:
            m_df = self.full_df[self.full_df["機種名"] == name]
            
            # マスターから目標値を取得（nan対策済み辞書から安全に引く）
            t_air = 0.0
            t_clean = 0.0
            t_swap = 0.0
            for (m_k_name, m_k_maker), info in self.model_info_map.items():
                if m_k_name in name: 
                    t_map = info.get("targets", {})
                    t_air = t_map.get("エアー清掃", 0.0)
                    t_clean = t_map.get("清掃", 0.0)
                    t_swap = t_map.get("筐体交換", 0.0)
                    break

            # 実績計算
            m_air = int(m_df['エアー清掃台数'].sum())
            a_time = m_df[m_df['エアー清掃台数'] > 0]['作業時間'].sum()
            
            m_clean = int(m_df['清掃台数'].sum())
            c_time = m_df[m_df['清掃台数'] > 0]['作業時間'].sum()
            
            m_swap = int(m_df['筐体交換台数'].sum())
            s_time = m_df[m_df['筐体交換台数'] > 0]['作業時間'].sum()
            
            def calc_spd(u, t): return u / (t / 60) if t > 0 else 0.0
            a_spd = calc_spd(m_air, a_time)
            c_spd = calc_spd(m_clean, c_time)
            s_spd = calc_spd(m_swap, s_time)
            
            total_count = m_air + m_clean + m_swap
            
            # 💡 【重要】1台でも作業していて、かつ(目標値が0ではなく)目標ペースを下回っているか？
            has_air_issue = (m_air > 0) and (t_air > 0) and (a_spd < t_air)
            has_clean_issue = (m_clean > 0) and (t_clean > 0) and (c_spd < t_clean)
            has_swap_issue = (m_swap > 0) and (t_swap > 0) and (s_spd < t_swap)
            
            # 1つでも当てはまれば警告フラグON
            has_issue = has_air_issue or has_clean_issue or has_swap_issue

            # カード構築
            if has_issue:
                card_content = ft.Stack([
                    ft.Container(bgcolor="#2E2401", border_radius=12, left=0, top=0, right=0, bottom=0),
                    ft.Container(bgcolor="#FFBF00", border_radius=12, opacity=current_op, key="blink_layer", left=0, top=0, right=0, bottom=0),
                    ft.Container(content=ft.Row([ft.Text(name, size=15, weight="bold", expand=True, color="white"), ft.Text(f"{total_count:,}台", size=13, color="#FFD700", weight="bold")]), padding=18)
                ], height=60)
                bg_color, border_style = None, ft.border.all(1, "#B8860B")
            else:
                card_content = ft.Row([ft.Text(name, size=15, weight="bold", expand=True, color="white"), ft.Text(f"{total_count:,}台", size=13, color="#A5D6A7", weight="bold")])
                bg_color, border_style = "#0D3211", ft.border.all(1, "#1B5E20")

            self.model_list_column.controls.append(ft.Container(
                content=card_content, padding=0 if has_issue else 18, border_radius=12, bgcolor=bg_color, border=border_style,
                key=str(has_issue), data=bg_color, on_click=lambda e, n=name: self.show_detail(n), on_hover=self.on_list_hover
            ))
            
        self.update() 
        if not self.is_animating: self.start_alert_animation()
        
    # --- 2. start_alert_animation メソッド ---
    def start_alert_animation(self):
        if self.is_animating: return
        self.is_animating = True
        t = threading.Thread(target=self.run_animation_loop, daemon=True)
        t.start()

    # --- 3. run_animation_loop メソッド (究極安定版) ---
    def run_animation_loop(self):
        self.current_pulse_opacity = 0.1
        step = 0.05 # 💡 1回あたり0.05ずつ変化させる（滑らかさの要）
        
        while self.is_animating:
            if not self.page: break
            
            # 波の計算
            self.current_pulse_opacity += step
            
            # 上限と下限で反転＆少しキープ（呼吸感の演出）
            if self.current_pulse_opacity >= 1.0:
                self.current_pulse_opacity = 1.0
                step = -0.05
                time.sleep(0.5) # 明るいまま0.5秒キープ
            elif self.current_pulse_opacity <= 0.1:
                self.current_pulse_opacity = 0.1
                step = 0.05
                time.sleep(0.3) # 暗いまま0.3秒キープ

            layers = []
            controls = self.model_list_column.controls[:]
            for card in controls:
                if card.key == "True" and isinstance(card.content, ft.Stack):
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
            
            # 💡 通信負荷を抑えた安全な更新頻度（1秒間に10回）
            # これなら過去のようなSocketエラーは起きず、パラパラ漫画のように滑らかに動きます
            time.sleep(0.1)

    def stop_alert_animation(self):
        self.is_animating = False

    def will_unmount(self):
        self.stop_alert_animation()
        
    def on_list_hover(self, e):
        if e.control.key == "True":
            e.control.border = ft.border.all(2, "white") if e.data == "true" else None
            e.control.update()
            return

        # 通常カード（達成・緑）のホバー処理
        base_color = e.control.data # 達成時は "#1B5E20"
        if e.data == "true":
            e.control.bgcolor = "#2E7D32" # 💡 ホバー時は少し明るい緑に
        else:
            e.control.bgcolor = base_color
        e.control.update()