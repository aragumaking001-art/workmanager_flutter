import flet as ft
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
import io
import base64

# 💡 Webサーバー環境（Linuxなど）でも文字化けしないための堅牢なフォント設定
matplotlib.use('Agg')
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['MS Gothic', 'Yu Gothic', 'Hiragino Sans', 'Arial Unicode MS', 'sans-serif']

class WorkerAnalysisView(ft.Row):
    def __init__(self, df=None):
        super().__init__(expand=True, spacing=0)
        try:
            self.masters_df = pd.read_csv('model_name.csv', encoding='utf-8-sig')
        except:
            self.masters_df = pd.DataFrame()
            
        self.worker_list_column = ft.Column(scroll=ft.ScrollMode.ADAPTIVE, expand=True, spacing=8)
        # 💡 タブレット向けにパディングを 40 -> 20 に縮小
        self.detail_area = ft.Container(expand=True, padding=20, bgcolor="#0F1115")
        self.show_initial_state()

        self.controls = [
            ft.Container(
                content=ft.Column([
                    ft.Row([ft.Icon(ft.Icons.PEOPLE_ALT, color="#00ccff", size=20), ft.Text("作業員一覧", size=16, weight="bold")], spacing=10),
                    ft.Divider(color="#33363F", height=15),
                    self.worker_list_column
                ]),
                # 💡 左サイドバーの幅を 300 -> 230 に縮小し、右エリアを広く確保
                width=230, padding=15, bgcolor="#14161E",
            ),
            ft.VerticalDivider(width=1, color="#33363F"),
            self.detail_area
        ]
        self.full_df = df if df is not None else pd.DataFrame()
        self.members_dict = {}
        
    def create_data_cell(self, content_row, width, show_border=True):
        return ft.Container(
            content=content_row,
            width=width,
            height=45, # 💡 セルの高さを 60 -> 45 に縮小
            alignment=ft.alignment.center,
            bgcolor="#0F1115",
            border_radius=8,
            border=ft.border.all(1, "#252830") if show_border else None,
        )
    
    def show_initial_state(self):
        self.detail_area.content = ft.Column([
            ft.Icon(ft.Icons.PERSON_SEARCH_OUTLINED, size=80, color="#33363F"),
            ft.Text("左のリストから作業員を選択してください", color="#555555", size=16)
        ], alignment="center", horizontal_alignment="center")

    def calculate_rates(self, air, clean, to_swap, to_clean):
        base_total = air + clean
        swap_trigger_rate = (to_swap / base_total * 100) if base_total > 0 else 0
        air_op_total = air + to_clean
        air_rate = (air / air_op_total * 100) if air_op_total > 0 else 0
        return swap_trigger_rate, air_rate

    def update_tab(self, df, members_dict=None):
        if df is None or df.empty: return
        self.full_df = df.copy()
        self.members_dict = members_dict if members_dict else {}
        
        # 💡 型エラーを完全に防ぐ数値変換
        target_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数', '清掃行き台数', '筐体交換行き台数', '作業時間']
        for col in target_cols:
            if col in self.full_df.columns:
                self.full_df[col] = pd.to_numeric(self.full_df[col], errors='coerce').fillna(0)

        # --- 💡 【追加】社員番号のズレ（12345.0 等）を強制的に補正 ---
        if "社員番号" in self.full_df.columns:
            # 履歴データの社員番号から .0 を消去
            self.full_df["社員番号"] = self.full_df["社員番号"].astype(str).str.replace(r'\.0$', '', regex=True).str.strip()
            
        # 名簿辞書（members_dict）側の社員番号からも .0 を消去して綺麗にする
        clean_dict = {}
        for k, v in self.members_dict.items():
            clean_key = str(k).replace('.0', '').strip()
            clean_dict[clean_key] = v
        self.members_dict = clean_dict
        # -------------------------------------------------------------

        self.worker_list_column.controls.clear()
        
        # 💡 "nan" や 空文字 を弾く安全処理（文字列化したため条件を変更）
        valid_df = self.full_df[~self.full_df["社員番号"].isin(["nan", "None", ""])]
        workers = sorted(valid_df["社員番号"].unique())
        
        for w_id in workers:
            # これで完全に一致するようになり、名前が表示されます！
            w_name = self.members_dict.get(str(w_id), f"不明({w_id})")
            w_df = valid_df[valid_df["社員番号"] == w_id]
            total_qty = int(w_df[['エアー清掃台数', '清掃台数', '筐体交換台数']].sum().sum())
            
            self.worker_list_column.controls.append(
                ft.Container(
                    content=ft.Row([
                        ft.Text(w_name, size=14, weight="bold", expand=True),
                        ft.Text(f"{total_qty}台", size=13, color="#00ccff", weight="bold")
                    ]),
                    padding=15, border_radius=8, border=ft.border.all(1, "#33363F"),
                    bgcolor="#1A1C23",
                    on_click=lambda e, wid=w_id: self.show_worker_detail(wid),
                    on_hover=self.on_hover_effect
                )
            )
        self.update()

    def generate_radar_chart(self, air, clean, swap):
        display_air = min(air, 1000)
        display_clean = min(clean, 1000)
        display_swap = min(swap, 1000)
        achieved_air = air >= 1000
        achieved_clean = clean >= 1000
        achieved_swap = swap >= 1000
        all_achieved = achieved_air and achieved_clean and achieved_swap
        
        chart_fill_color = "#FFD700" if all_achieved else "#00ccff"
        alpha_val = 0.5 if all_achieved else 0.2
        line_width = 3 if all_achieved else 2

        values = [ display_air, display_clean, display_swap ]
        values += values[ :1 ]
        
        categories = [ 'エアー', '通常清掃', '筐体交換' ]
        angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist()
        angles += angles[ :1 ]

        # 💡 レーダーチャートのサイズを少し縮小 (4.5 -> 3.5)
        fig, ax = plt.subplots(figsize=(3.5, 3.5), subplot_kw=dict(polar=True), facecolor='#1A1C23')
        ax.set_facecolor('#1A1C23')
        
        ax.fill(angles, values, color=chart_fill_color, alpha=alpha_val, zorder=3)
        ax.plot(angles, values, color=chart_fill_color, linewidth=line_width, zorder=4)
        
        ax.set_ylim( 0, 1000 )
        ax.set_yticks( [ 250, 500, 750, 1000 ] )
        # 💡 Y軸ラベルのサイズを縮小
        ax.set_yticklabels( [ "250", "500", "750", "1,000" ], color="#666666", fontsize=10 )
        
        ax.set_xticks(angles[ :-1 ])
        ax.xaxis.grid(False) 
        ax.yaxis.grid(True, color='#33363F', linestyle='--', linewidth=1, zorder=1)
        ax.spines['polar'].set_visible(False) 

        labels_and_colors = [ ('エアー', '#00ccff'), ('通常清掃', '#00ffcc'), ('筐体交換', '#FFCA28') ]
        # 💡 X軸ラベルのサイズを縮小
        ax.set_xticklabels( [ lc[ 0 ] for lc in labels_and_colors ], fontsize=12, fontweight='bold')
        for label, (_, color) in zip(ax.get_xticklabels(), labels_and_colors):
            label.set_color(color)

        for gl in ax.xaxis.get_gridlines():
            gl.set_visible(False)

        achievement_list = [ (angles[ 0 ], achieved_air), (angles[ 1 ], achieved_clean), (angles[ 2 ], achieved_swap) ]

        for angle, is_achieved in achievement_list:
            if is_achieved:
                ax.plot( [ angle, angle ], [ 0, 1000 ], color="#FFD700", linewidth=3.5, solid_capstyle="round", zorder=10)
            else:
                ax.plot( [ angle, angle ], [ 0, 1000 ], color="#33363F", linewidth=1.0, zorder=2)

        if all_achieved:
            ax.text(0, 0, "MAX", color="#FFD700", fontsize=16, 
                    fontweight='bold', ha='center', va='center',
                    bbox=dict(facecolor='#1A1C23', alpha=0.9, edgecolor='#FFD700', boxstyle='circle'),
                    zorder=20) 

        ax.tick_params(axis='x', pad=10)
        plt.subplots_adjust(left=0.15, right=0.85, top=0.85, bottom=0.15)

        buf = io.BytesIO()
        plt.savefig(buf, format='png', transparent=True, bbox_inches='tight')
        plt.close(fig)
        return base64.b64encode(buf.getvalue()).decode('utf-8')


    def show_worker_detail(self, worker_id):
        w_df = self.full_df[self.full_df["社員番号"] == worker_id].copy()
        w_name = self.members_dict.get(str(worker_id), worker_id)
        sums = w_df[['エアー清掃台数', '清掃台数', '筐体交換台数', '清掃行き台数', '筐体交換行き台数']].sum()
        m_air, m_clean, m_swap = int(sums['エアー清掃台数']), int(sums['清掃台数']), int(sums['筐体交換台数'])
        t_clean_gen, t_swap_gen = int(sums['清掃行き台数']), int(sums['筐体交換行き台数'])
        m_swap_rate, m_air_rate = self.calculate_rates(m_air, m_clean, t_swap_gen, t_clean_gen)
        chart_base64 = self.generate_radar_chart(m_air, m_clean, m_swap)

        alert_items = []
        for model_name, m_df in w_df.groupby("機種名"):
            m_name_str = str(model_name if isinstance(model_name, tuple) else model_name)
            m_master = self.masters_df[self.masters_df['機種名'] == m_name_str]
            steps = [("エアー", "エアー清掃台数", "エアー清掃"), ("通常", "清掃台数", "清掃"), ("交換", "筐体交換台数", "筐体交換")]
            for label, col, master_key in steps:
                qty = m_df[col].sum()
                time_h = m_df[m_df[col] > 0]['作業時間'].sum() / 60
                if time_h > 0:
                    spd = qty / time_h
                    target = m_master[m_master['作業内容'] == master_key]['1時間標準作業台数'].mean()
                    target = target if pd.notnull(target) else 10.0
                    if spd < target:
                        alert_items.append(
                            ft.Container(
                                content=ft.Row([
                                    ft.Icon(ft.Icons.WARNING_AMBER_ROUNDED, color=ft.Colors.AMBER_ACCENT, size=14),
                                    ft.Text(m_name_str, size=12, weight="bold", expand=True, overflow=ft.TextOverflow.ELLIPSIS),
                                    ft.Text(label, size=11, color=ft.Colors.GREY_400),
                                    ft.Text(f"{spd:.1f}", size=13, weight="bold", color=ft.Colors.RED_ACCENT),
                                    ft.Text(f"/{target:.0f}", size=10, color=ft.Colors.GREY_600),
                                ], spacing=5),
                                padding=ft.padding.symmetric(vertical=4, horizontal=8),
                                bgcolor="#1A1C23", border_radius=5
                            )
                        )

        # 💡 サマリー行の高さを 340 -> 240 に縮小し、各幅も調整
        summary_row = ft.Row([
            ft.Container(content=ft.Column([
                self.create_stat_card("エアー清掃", m_air, "#00ccff", ft.Icons.AIR), 
                self.create_stat_card("通常清掃", m_clean, "#00ffcc", ft.Icons.CLEANING_SERVICES), 
                self.create_stat_card("筐体交換", m_swap, ft.Colors.AMBER_400, ft.Icons.SETTINGS)
            ], spacing=5, alignment=ft.MainAxisAlignment.CENTER, expand=True), width=180, height=240),
            
            ft.Container(content=ft.Column([
                ft.Text("作業習得状況", size=13, weight="bold", color=ft.Colors.GREY_500), 
                # 💡 画像サイズ縮小
                ft.Image(src_base64=chart_base64, width=200, height=200) if chart_base64 else ft.Text("データなし")
            ], horizontal_alignment="center", spacing=2), bgcolor="#1A1C23", padding=10, border_radius=10, border=ft.border.all(1, "#33363F"), width=240, height=240, alignment=ft.alignment.center),
            
            ft.Container(content=ft.Column([
                ft.Row([ft.Icon(ft.Icons.QUERY_STATS_ROUNDED, size=16, color="#00ccff"), ft.Text("発生率概要", size=14, weight="bold", color=ft.Colors.GREY_500)], spacing=5), 
                ft.Divider(color="#33363F", height=10), 
                ft.Column([
                    ft.Column([ft.Row([ft.Text("エアー率", size=12, color=ft.Colors.GREY_300), ft.Text(f"{m_air_rate:.1f}%", size=16, weight="bold", color="#00ccff")], alignment="spaceBetween"), ft.ProgressBar(value=m_air_rate/100, color="#00ccff", bgcolor="#333333", height=8)], spacing=3), 
                    ft.Container(height=10), 
                    ft.Column([ft.Row([ft.Text("交換発生率", size=12, color=ft.Colors.GREY_300), ft.Text(f"{m_swap_rate:.1f}%", size=16, weight="bold", color=ft.Colors.RED_ACCENT_400)], alignment="spaceBetween"), ft.ProgressBar(value=m_swap_rate/100, color=ft.Colors.RED_ACCENT_400, bgcolor="#333333", height=8)], spacing=3)
                ], alignment="center", expand=True)
            ]), bgcolor="#14161E", padding=15, border_radius=10, border=ft.border.all(1, "#33363F"), width=220, height=240),
            
            ft.Container(content=ft.Column([
                ft.Row([ft.Icon(ft.Icons.ERROR_OUTLINE, size=16, color=ft.Colors.RED_ACCENT), ft.Text("要改善項目", size=14, weight="bold", color=ft.Colors.GREY_500)], spacing=5), 
                ft.Divider(color="#33363F", height=10), 
                ft.Column(alert_items if alert_items else [ft.Text("未達成項目なし", color=ft.Colors.GREY_700, size=12)], scroll=ft.ScrollMode.ADAPTIVE, expand=True, spacing=5)
            ]), bgcolor="#111319", padding=15, border_radius=10, border=ft.border.all(1, "#33363F"), expand=True, height=240)
        ], spacing=10) # row間隔縮小

        # 💡 リストヘッダーの各カラム幅を縮小・最適化
        list_header = ft.Container(
            padding=ft.padding.only(left=10, right=10, bottom=10, top=5), 
            content=ft.Row([
                ft.Container(content=ft.Text("対象機種名", size=13, color=ft.Colors.GREY_500, weight="bold"), width=160, alignment=ft.alignment.center_left, padding=ft.padding.only(left=15)),
                ft.Container(width=220, content=ft.Column([ft.Container(content=ft.Text("完了台数内訳", size=13, color=ft.Colors.GREY_500, weight="bold"), alignment=ft.alignment.center), ft.Row([ft.Text("エアー", size=11, color="#00ccff", weight="bold", width=65, text_align="center"), ft.Text("清掃", size=11, color="#00ffcc", weight="bold", width=65, text_align="center"), ft.Text("筐体交換", size=11, color=ft.Colors.AMBER_400, weight="bold", width=65, text_align="center")], spacing=8)], spacing=4)),
                ft.Container(width=220, content=ft.Column([ft.Container(content=ft.Text("作業効率 (実測 / 目標)", size=13, color=ft.Colors.GREY_500, weight="bold"), alignment=ft.alignment.center), ft.Row([ft.Text("エアー", size=11, color="#00ccff", weight="bold", width=65, text_align="center"), ft.Text("清掃", size=11, color="#00ffcc", weight="bold", width=65, text_align="center"), ft.Text("筐体交換", size=11, color=ft.Colors.AMBER_400, weight="bold", width=65, text_align="center")], spacing=8)], spacing=4)),
                ft.Container(width=110, content=ft.Column([ft.Container(content=ft.Text("傾向 / 発生率", size=13, color=ft.Colors.GREY_500, weight="bold"), alignment=ft.alignment.center), ft.Row([ft.Text("エアー率", size=11, color="#00ccff", weight="bold", width=50, text_align="center"), ft.Text("交換率", size=11, color=ft.Colors.RED_ACCENT_400, weight="bold", width=50, text_align="center")], spacing=6)], spacing=4)),
            ], spacing=20, alignment=ft.MainAxisAlignment.START),
        )

        model_tiles = []
        for model_name, m_df in w_df.groupby("機種名"):
            m_name_str = str(model_name if isinstance(model_name, tuple) else model_name)
            m_master = self.masters_df[self.masters_df['機種名'] == m_name_str]
            def calc_op_stats(op_col, op_name):
                qty = int(m_df[op_col].sum())
                time_h = m_df[m_df[op_col] > 0]['作業時間'].sum() / 60
                spd = qty / time_h if time_h > 0 else 0
                target = m_master[m_master['作業内容'] == op_name]['1時間標準作業台数'].mean() if not m_master.empty else 10.0
                target = target if pd.notnull(target) else 10.0
                return qty, spd, target

            air_q, air_s, air_t = calc_op_stats('エアー清掃台数', 'エアー清掃')
            cln_q, cln_s, cln_t = calc_op_stats('清掃台数', '清掃')
            swp_q, swp_s, swp_t = calc_op_stats('筐体交換台数', '筐体交換')
            mk_total_base = air_q + cln_q
            m_air_rate = (air_q / (air_q + m_df['清掃行き台数'].sum()) * 100) if (air_q + m_df['清掃行き台数'].sum()) > 0 else 0
            m_swap_rate = (m_df['筐体交換行き台数'].sum() / mk_total_base * 100) if mk_total_base > 0 else 0
            main_spd = cln_s if cln_q > 0 else (air_s if air_q > 0 else swp_s)
            main_target = cln_t if cln_q > 0 else (air_t if air_q > 0 else swp_t)
            sig_color = ft.Colors.GREY_700 if main_spd == 0 else (ft.Colors.GREEN_ACCENT if main_spd >= main_target else (ft.Colors.AMBER_ACCENT if main_spd >= main_target * 0.8 else ft.Colors.RED_ACCENT))

            model_tiles.append(
                ft.ExpansionTile(
                    tile_padding=ft.padding.symmetric(horizontal=10), 
                    title=ft.Row([
                        # 💡 各要素の幅とフォントを縮小
                        ft.Container(content=ft.Row([ft.Icon(ft.Icons.CIRCLE, color=sig_color, size=12), ft.Text(m_name_str, weight="bold", size=14, overflow=ft.TextOverflow.ELLIPSIS)], spacing=8), width=160, height=55, alignment=ft.alignment.center_left),
                        ft.Container(content=ft.Row([self.create_data_cell(ft.Text(f"{air_q}", size=14, weight="w900", color="#00ccff"), 65), self.create_data_cell(ft.Text(f"{cln_q}", size=14, weight="w900", color="#00ffcc"), 65), self.create_data_cell(ft.Text(f"{swp_q}", size=14, weight="w900", color=ft.Colors.AMBER_400), 65)], spacing=8), width=220),
                        ft.Container(content=ft.Row([self.create_data_cell(self.create_mini_efficiency_chip("エアー", air_s, air_t, "#00ccff", flat=True), 65), self.create_data_cell(self.create_mini_efficiency_chip("清掃", cln_s, cln_t, "#00ffcc", flat=True), 65), self.create_data_cell(self.create_mini_efficiency_chip("交換", swp_s, swp_t, ft.Colors.AMBER_400, flat=True), 65)], spacing=8), width=220),
                        ft.Container(content=ft.Row([self.create_data_cell(ft.Text(f"{m_air_rate:.0f}%", size=14, weight="w900", color="#00ccff"), 50), self.create_data_cell(ft.Text(f"{m_swap_rate:.0f}%", size=14, weight="w900", color=ft.Colors.RED_ACCENT_400), 50)], spacing=8), width=110),
                    ], spacing=20, alignment=ft.MainAxisAlignment.START),
                    controls=self.build_maker_details(m_df),
                    bgcolor="#1C1F26", collapsed_bgcolor="#111319", maintain_state=True,
                    shape=ft.RoundedRectangleBorder(radius=10), collapsed_shape=ft.RoundedRectangleBorder(radius=10), icon_color="#00ccff",
                )
            )

        section_title = ft.Container(
            content=ft.Row([
                ft.Container(width=4, height=18, bgcolor="#00ccff", border_radius=2),
                ft.Icon(ft.Icons.LIST_ALT, color="white", size=20),
                ft.Text("全機種の実績・効率一覧 (クリックで拡大表示)", size=16, weight="bold", color="white"),
                ft.Container(expand=True),
                ft.Icon(ft.Icons.OPEN_IN_FULL, color=ft.Colors.GREY_500, size=14),
            ], spacing=10),
            padding=ft.padding.only(left=10, top=8, bottom=8, right=15),
            bgcolor="#1A1C23",
            border_radius=8,
            on_click=lambda _: self.show_full_list(list_header, model_tiles), 
            on_hover=lambda e: setattr(e.control, "bgcolor", "#252830" if e.data == "true" else "#1A1C23") or e.control.update() 
        )

        self.detail_area.content = ft.Column([
            ft.Row([ft.Icon(ft.Icons.PERSON, color="#00ccff", size=22), ft.Text(f"{w_name} さんの分析レポート", size=22, weight="bold")], spacing=10),
            summary_row,
            ft.Divider(height=10, color="transparent"),
            section_title,
            ft.Column([
                list_header,
                ft.Column(model_tiles, spacing=6, scroll=ft.ScrollMode.ADAPTIVE, expand=True)
            ], expand=True, spacing=0)
        ], spacing=10)
        self.update()

    def create_stat_card(self, label, val, color, icon):
        display_font_size = 28 if val < 1000 else 24
        return ft.Container(
            expand=True,
            padding=ft.padding.symmetric(horizontal=10), 
            bgcolor="#1A1C23", 
            border_radius=10, 
            border=ft.border.all(1, "#33363F"),
            content=ft.Row([
                ft.Icon(icon, color=color, size=30),
                ft.Column([
                    ft.Text(label, color=ft.Colors.GREY_400, size=11, weight="bold"),
                    ft.Row([
                        ft.Text(
                            f"{val:,}", 
                            size=display_font_size, 
                            weight="w900", 
                            color="white",
                            overflow=ft.TextOverflow.ELLIPSIS
                        ),
                        ft.Container(
                            content=ft.Text("台", size=10, color=ft.Colors.GREY_500, weight="bold"),
                            margin=ft.margin.only(bottom=3)
                        ),
                    ], vertical_alignment="end", spacing=2, tight=True), 
                ], alignment="center", spacing=0, expand=True),
            ], vertical_alignment="center", spacing=8) 
        )

    def on_hover_effect(self, e):
        e.control.bgcolor = "#252830" if e.data == "true" else "#1A1C23"
        e.control.update()
        
    def create_mini_efficiency_chip(self, label, actual, target, color, flat=False):
        if actual == 0: return ft.Container() 
        is_low = actual < target
        val_color = ft.Colors.RED_ACCENT if is_low else color
        return ft.Container(
            content=ft.Row([
                ft.Text(f"{actual:.1f}", size=15, weight="w900", color=val_color),
                ft.Text(f"/{target:.0f}", size=10, color=ft.Colors.GREY_600, weight="bold"),
            ], alignment=ft.MainAxisAlignment.CENTER, vertical_alignment="end", spacing=2, tight=True),
            alignment=ft.alignment.center, bgcolor="transparent" if flat else "#0F1115", width=65, expand=True
        )
        
    def build_maker_details(self, m_df):
        details = []
        detail_bg_color = "#1A1E26" 
        accent_border_color = "#2D323E"
        maker_groups = list(m_df.groupby("メーカー"))
        
        for i, (maker, mk_df) in enumerate(maker_groups):
            model_name = str(mk_df['機種名'].values) 
            m_master = self.masters_df[self.masters_df['機種名'] == model_name]
            maker_str = str(maker if isinstance(maker, tuple) else maker)

            def calc_mk_stats(op_col, op_name):
                qty = int(mk_df[op_col].sum())
                time_h = mk_df[mk_df[op_col] > 0]['作業時間'].sum() / 60
                spd = qty / time_h if time_h > 0 else 0
                target = m_master[m_master['作業内容'] == op_name]['1時間標準作業台数'].mean() if not m_master.empty else 10.0
                target = target if pd.notnull(target) else 10.0
                return qty, spd, target

            air_q, air_s, air_t = calc_mk_stats('エアー清掃台数', 'エアー清掃')
            cln_q, cln_s, cln_t = calc_mk_stats('清掃台数', '清掃')
            swp_q, swp_s, swp_t = calc_mk_stats('筐体交換台数', '筐体交換')
            
            mk_total_base = air_q + cln_q
            mk_air_rate = (air_q / (air_q + mk_df['清掃行き台数'].sum()) * 100) if (air_q + mk_df['清掃行き台数'].sum()) > 0 else 0
            mk_swap_rate = (mk_df['筐体交換行き台数'].sum() / mk_total_base * 100) if mk_total_base > 0 else 0

            is_first = (i == 0)
            is_last = (i == len(maker_groups) - 1)
            
            details.append(
                ft.Container(
                    padding=ft.padding.symmetric(horizontal=10, vertical=8),
                    bgcolor=detail_bg_color,
                    border_radius=ft.border_radius.only(
                        top_left=10 if is_first else 0, top_right=10 if is_first else 0,
                        bottom_left=10 if is_last else 0, bottom_right=10 if is_last else 0
                    ),
                    border=ft.border.Border(
                        left=ft.border.BorderSide(2, "#00ccff") if is_first or not is_first else None, 
                        bottom=ft.border.BorderSide(1, accent_border_color) if not is_last else None,
                        top=ft.border.BorderSide(1, accent_border_color) if is_first else None,
                        right=ft.border.BorderSide(1, accent_border_color)
                    ),
                    content=ft.Row([
                        ft.Container(
                            content=ft.Row([
                                ft.Icon(ft.Icons.SUBDIRECTORY_ARROW_RIGHT, size=16, color="#00ccff"), 
                                ft.Text(f"{maker_str}", size=14, weight="bold", color="white", overflow=ft.TextOverflow.ELLIPSIS),
                            ], spacing=8), width=160, alignment=ft.alignment.center_left,
                        ),
                        ft.Container(
                            content=ft.Row([
                                self.create_data_cell(ft.Text(f"{air_q}", size=14, weight="w900", color="#00ccff"), 65, show_border=False),
                                self.create_data_cell(ft.Text(f"{cln_q}", size=14, weight="w900", color="#00ffcc"), 65, show_border=False),
                                self.create_data_cell(ft.Text(f"{swp_q}", size=14, weight="w900", color=ft.Colors.AMBER_400), 65, show_border=False),
                            ], spacing=8), width=220,
                        ),
                        ft.Container(
                            content=ft.Row([
                                self.create_data_cell(self.create_mini_efficiency_chip("エアー", air_s, air_t, "#00ccff", flat=True), 65, show_border=False),
                                self.create_data_cell(self.create_mini_efficiency_chip("清掃", cln_s, cln_t, "#00ffcc", flat=True), 65, show_border=False),
                                self.create_data_cell(self.create_mini_efficiency_chip("交換", swp_s, swp_t, ft.Colors.AMBER_400, flat=True), 65, show_border=False),
                            ], spacing=8), width=220,
                        ),
                        ft.Container(
                            content=ft.Row([
                                self.create_data_cell(ft.Text(f"{mk_air_rate:.0f}%", size=14, weight="w900", color="#00ccff"), 50, show_border=False),
                                self.create_data_cell(ft.Text(f"{mk_swap_rate:.0f}%", size=14, weight="w900", color=ft.Colors.RED_ACCENT_400), 50, show_border=False),
                            ], spacing=8), width=110,
                        ),
                    ], spacing=20, alignment=ft.MainAxisAlignment.START),
                )
            )
        return [ft.Container(content=ft.Column(details, spacing=0), padding=ft.padding.only(left=20, right=5, bottom=15, top=5), bgcolor="transparent")]
        
    def show_full_list(self, header, tiles):
        page_width = self.page.width
        page_height = self.page.height

        full_dialog = ft.AlertDialog(
            modal=False, 
            content_padding=0,
            inset_padding=ft.padding.symmetric(horizontal=10, vertical=20),
            bgcolor="#0F1115",
            shape=ft.RoundedRectangleBorder(radius=10),
            content=ft.Container(
                width=page_width, 
                height=page_height,
                padding=0,
                content=ft.Column([
                    ft.Container(
                        content=ft.Row([
                            ft.Icon(ft.Icons.LIST_ALT, color="#00ccff", size=20),
                            ft.Text("全機種実績・効率詳細（全画面モード）", size=18, weight="bold", color="white"),
                            ft.Container(expand=True),
                            ft.IconButton(icon=ft.Icons.CLOSE, icon_color=ft.Colors.GREY_500, on_click=lambda _: self.page.close(full_dialog))
                        ], alignment=ft.MainAxisAlignment.CENTER),
                        padding=ft.padding.symmetric(horizontal=20, vertical=15),
                        bgcolor="#161920", border_radius=ft.border_radius.only(top_left=10, top_right=10)
                    ),
                    ft.Divider(color="#33363F", height=1),
                    ft.Container(
                        expand=True,
                        padding=ft.padding.symmetric(horizontal=20, vertical=15),
                        content=ft.Column([
                            header, 
                            ft.Divider(height=10, color="transparent"),
                            ft.Column(tiles, spacing=8, scroll=ft.ScrollMode.ADAPTIVE, expand=True)
                        ], expand=True)
                    )
                ], spacing=0),
            )
        )
        for tile in tiles:
            tile.title.spacing = 30 
        self.page.open(full_dialog)