import flet as ft
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib
import io
import base64

# 日本語表示・化け対策
matplotlib.use('Agg')
matplotlib.rc('font', family='MS Gothic') 

class WorkerAnalysisView(ft.Row):
    def __init__(self, df=None):
        super().__init__(expand=True, spacing=0)
        try:
            self.masters_df = pd.DataFrame()
        except:
            self.masters_df = pd.DataFrame()
            
        self.worker_list_column = ft.Column(scroll=ft.ScrollMode.ADAPTIVE, expand=True, spacing=10)
        self.detail_area = ft.Container(expand=True, padding=40, bgcolor="#0F1115")
        self.show_initial_state()

        self.controls = [
            ft.Container(
                content=ft.Column([
                    ft.Row([ft.Icon(ft.Icons.PEOPLE_ALT, color="#00ccff"), ft.Text("作業員一覧", size=20, weight="bold")], spacing=10),
                    ft.Divider(color="#33363F", height=20),
                    self.worker_list_column
                ]),
                width=300, padding=25, bgcolor="#14161E",
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
            height=60,
            alignment=ft.alignment.center,
            bgcolor="#0F1115",
            border_radius=10,
            border=ft.border.all(1, "#252830") if show_border else None,
        )
    
    def show_initial_state(self):
        self.detail_area.content = ft.Column([
            ft.Icon(ft.Icons.PERSON_SEARCH_OUTLINED, size=100, color="#33363F"),
            ft.Text("左のリストから作業員を選択してください", color="#555555", size=18)
        ], alignment="center", horizontal_alignment="center")

    def calculate_rates(self, air, clean, to_swap, to_clean):
        base_total = air + clean
        swap_trigger_rate = (to_swap / base_total * 100) if base_total > 0 else 0
        air_op_total = air + to_clean
        air_rate = (air / air_op_total * 100) if air_op_total > 0 else 0
        return swap_trigger_rate, air_rate

    def update_tab(self, df, df_members=None, df_models=None):
        if df_models is not None:
            self.masters_df = df_models.rename(columns={"model_name": "機種名", "maker": "メーカー", "maker_abbr": "メーカー略称", "category": "分類", "work_type": "作業内容", "std_qty": "1時間標準作業台数"}).fillna("")
        if df_members is not None and not df_members.empty:
            try:
                self.members_dict = df_members.set_index("worker_id")["worker_name"].to_dict()
            except: pass
            
        if df is None or df.empty: return
        self.full_df = df.copy()
        
        target_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数', '清掃行き台数', '筐体交換行き台数', '作業時間']
        for col in target_cols:
            if col in self.full_df.columns:
                self.full_df[col] = pd.to_numeric(self.full_df[col], errors='coerce').fillna(0)

        self.worker_list_column.controls.clear()
        workers = sorted(self.full_df["社員番号"].unique())
        for w_id in workers:
            w_name = self.members_dict.get(str(w_id), f"不明({w_id})")
            w_df = self.full_df[self.full_df["社員番号"] == w_id]
            total_qty = int(w_df[['エアー清掃台数', '清掃台数', '筐体交換台数']].sum().sum())
            self.worker_list_column.controls.append(
                ft.Container(
                    content=ft.Row([
                        ft.Text(w_name, size=16, weight="bold", expand=True),
                        ft.Text(f"{total_qty}台", size=14, color="#00ccff", weight="bold")
                    ]),
                    padding=20, border_radius=12, border=ft.border.all(1, "#33363F"),
                    bgcolor="#1A1C23",
                    on_click=lambda e, wid=w_id: self.show_worker_detail(wid),
                    on_hover=self.on_hover_effect
                )
            )
        self.update()

    def generate_radar_chart(self, air, clean, swap):
        # 1. 値の制限（1000台MAX）と達成判定
        display_air = min(air, 1000)
        display_clean = min(clean, 1000)
        display_swap = min(swap, 1000)
        achieved_air = air >= 1000
        achieved_clean = clean >= 1000
        achieved_swap = swap >= 1000
        all_achieved = achieved_air and achieved_clean and achieved_swap
        
        # 演出用カラーの設定
        if all_achieved:
            chart_fill_color = "#FFD700"  # 完全制覇はゴールド
            alpha_val = 0.5
            line_width = 4
        else:
            chart_fill_color = "#00ccff"  # 通常は青
            # 💡 ゴールドの線を際立たせるため、少し透明度を上げる（0.3 -> 0.2）
            alpha_val = 0.2
            line_width = 2

        values = [display_air, display_clean, display_swap]
        values += values[:1]
        
        categories = ['エアー', '通常清掃', '筐体交換']
        angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist()
        angles += angles[:1]

        fig, ax = plt.subplots(figsize=(4.5, 4.5), subplot_kw=dict(polar=True), facecolor='#1A1C23')
        ax.set_facecolor('#1A1C23')
        
        # --- 2. 💡 グラフの描画（ここを修正） ---
        # 塗りつぶし（fill）の zorder をゴールドの線（10）より小さくする（例：3）
        ax.fill(angles, values, color=chart_fill_color, alpha=alpha_val, zorder=3)
        # 枠線（plot）の zorder も調整（例：4）
        ax.plot(angles, values, color=chart_fill_color, linewidth=line_width, zorder=4)
        
        # 3. 軸の基本設定
        ax.set_ylim(0, 1000)
        ticks =[250, 500, 750, 1000]
        ax.set_yticks(ticks)
        ax.set_yticklabels(["250", "500", "750", "1,000"], color="#666666", fontsize=12)
        
        # 4. ラベルとグリッドの初期設定
        ax.set_xticks(angles[:-1])
        ax.xaxis.grid(False) # 放射状の線(xaxis)は一旦全部消す
        
        # 同心円の線(yaxis)だけ点線で描く (zorder=1 で一番奥)
        ax.yaxis.grid(True, color='#33363F', linestyle='--', linewidth=1, zorder=1)
        ax.spines['polar'].set_visible(False) # 外枠の線を消す

        # 5. ラベル設定
        labels_and_colors = [
            ('エアー', '#00ccff'),
            ('通常清掃', '#00ffcc'),
            ('筐体交換', '#FFCA28')
        ]
        ax.set_xticklabels([lc[0] for lc in labels_and_colors], fontsize=14, fontweight='bold')
        for label, (_, color) in zip(ax.get_xticklabels(), labels_and_colors):
            label.set_color(color)

        # 6. 線の色付け演出 (zorder=10 でグラフの手前に表示)
       # --- 6. 💡 線の色付け演出（手動で上書き描画） ---
        # 既存の自動グリッド線はすべて非表示にする
        for gl in ax.xaxis.get_gridlines():
            gl.set_visible(False)

        # 達成状況に合わせて、中心(0)から端(1000)まで手動で線を引く
        achievement_list = [
            (angles[0], achieved_air),
            (angles[1], achieved_clean),
            (angles[2], achieved_swap)
        ]

        for angle, is_achieved in achievement_list:
            if is_achieved:
                # 💡 1000台達成時：太いゴールドの線を「最前面(zorder=10)」に描く
                ax.plot([angle, angle], [0, 1000], 
                        color="#FFD700", 
                        linewidth=4.5, 
                        solid_capstyle="round", # 角を丸くして綺麗に
                        zorder=10)
            else:
                # 未達成時：細いグレーの線を「グラフの後ろ(zorder=2)」に描く
                ax.plot([angle, angle], [0, 1000], 
                        color="#33363F", 
                        linewidth=1.0, 
                        zorder=2)

        # 7. 中央のMAX表示
        if all_achieved:
            ax.text(0, 0, "MAX", color="#FFD700", fontsize=20, 
                    fontweight='bold', ha='center', va='center',
                    bbox=dict(facecolor='#1A1C23', alpha=0.9, edgecolor='#FFD700', boxstyle='circle'),
                    zorder=20) # 一番手前

        ax.tick_params(axis='x', pad=15)
        plt.subplots_adjust(left=0.2, right=0.8, top=0.8, bottom=0.2)

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
            m_master = self.masters_df[self.masters_df['機種名'] == model_name]
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
                                    ft.Icon(ft.Icons.WARNING_AMBER_ROUNDED, color=ft.Colors.AMBER_ACCENT, size=16),
                                    ft.Text(model_name, size=13, weight="bold", expand=True, overflow=ft.TextOverflow.ELLIPSIS),
                                    ft.Text(label, size=12, color=ft.Colors.GREY_400),
                                    ft.Text(f"{spd:.1f}", size=14, weight="bold", color=ft.Colors.RED_ACCENT),
                                    ft.Text(f"/{target:.0f}", size=11, color=ft.Colors.GREY_600),
                                ], spacing=10),
                                padding=ft.padding.symmetric(vertical=5, horizontal=10),
                                bgcolor="#1A1C23", border_radius=5
                            )
                        )

        summary_row = ft.Row([
            ft.Container(content=ft.Column([self.create_stat_card("エアー清掃", m_air, "#00ccff", ft.Icons.AIR), self.create_stat_card("通常清掃", m_clean, "#00ffcc", ft.Icons.CLEANING_SERVICES), self.create_stat_card("筐体交換", m_swap, ft.Colors.AMBER_400, ft.Icons.SETTINGS)], spacing=5, alignment=ft.MainAxisAlignment.CENTER, expand=True), width=220, height=340),
            ft.Container(content=ft.Column([ft.Text("作業習得状況", size=14, weight="bold", color=ft.Colors.GREY_500), ft.Image(src_base64=chart_base64, width=280, height=280) if chart_base64 else ft.Text("データなし")], horizontal_alignment="center", spacing=5), bgcolor="#1A1C23", padding=15, border_radius=15, border=ft.border.all(1, "#33363F"), width=340, height=340, alignment=ft.alignment.center),
            ft.Container(content=ft.Column([ft.Row([ft.Icon(ft.Icons.QUERY_STATS_ROUNDED, size=18, color="#00ccff"), ft.Text("発生率概要", size=16, weight="bold", color=ft.Colors.GREY_500)], spacing=8), ft.Divider(color="#33363F", height=15), ft.Column([ft.Column([ft.Row([ft.Text("エアー率", size=13, color=ft.Colors.GREY_300), ft.Text(f"{m_air_rate:.1f}%", size=18, weight="bold", color="#00ccff")], alignment="spaceBetween"), ft.ProgressBar(value=m_air_rate/100, color="#00ccff", bgcolor="#333333", height=10)], spacing=3), ft.Container(height=15), ft.Column([ft.Row([ft.Text("交換発生率", size=13, color=ft.Colors.GREY_300), ft.Text(f"{m_swap_rate:.1f}%", size=18, weight="bold", color=ft.Colors.RED_ACCENT_400)], alignment="spaceBetween"), ft.ProgressBar(value=m_swap_rate/100, color=ft.Colors.RED_ACCENT_400, bgcolor="#333333", height=10)], spacing=3)], alignment="center", expand=True)]), bgcolor="#14161E", padding=20, border_radius=15, border=ft.border.all(1, "#33363F"), width=260, height=340),
            ft.Container(content=ft.Column([ft.Row([ft.Icon(ft.Icons.ERROR_OUTLINE, size=18, color=ft.Colors.RED_ACCENT), ft.Text("要改善項目", size=16, weight="bold", color=ft.Colors.GREY_500)], spacing=8), ft.Divider(color="#33363F", height=15), ft.Column(alert_items if alert_items else [ft.Text("未達成項目なし", color=ft.Colors.GREY_700, size=13)], scroll=ft.ScrollMode.ADAPTIVE, expand=True, spacing=5)]), bgcolor="#111319", padding=20, border_radius=15, border=ft.border.all(1, "#33363F"), expand=True, height=340)
        ], spacing=15)

        # 💡 リストヘッダー（これをボトムシートでも使い回す）
        list_header = ft.Container(
            padding=ft.padding.only(left=15, right=15, bottom=15, top=10), 
            content=ft.Row([
                ft.Container(content=ft.Text("対象機種名", size=15, color=ft.Colors.GREY_500, weight="bold"), width=200, alignment=ft.alignment.center_left, padding=ft.padding.only(left=24)),
                ft.Container(width=260, content=ft.Column([ft.Container(content=ft.Text("完了台数内訳", size=15, color=ft.Colors.GREY_500, weight="bold"), alignment=ft.alignment.center), ft.Row([ft.Text("エアー", size=12, color="#00ccff", weight="bold", width=80, text_align="center"), ft.Text("清掃", size=12, color="#00ffcc", weight="bold", width=80, text_align="center"), ft.Text("筐体交換", size=12, color=ft.Colors.AMBER_400, weight="bold", width=80, text_align="center")], spacing=10)], spacing=8)),
                ft.Container(width=260, content=ft.Column([ft.Container(content=ft.Text("作業効率 (実測 / 目標)", size=15, color=ft.Colors.GREY_500, weight="bold"), alignment=ft.alignment.center), ft.Row([ft.Text("エアー", size=12, color="#00ccff", weight="bold", width=80, text_align="center"), ft.Text("清掃", size=12, color="#00ffcc", weight="bold", width=80, text_align="center"), ft.Text("筐体交換", size=12, color=ft.Colors.AMBER_400, weight="bold", width=80, text_align="center")], spacing=10)], spacing=8)),
                ft.Container(width=130, content=ft.Column([ft.Container(content=ft.Text("傾向 / 発生率", size=15, color=ft.Colors.GREY_500, weight="bold"), alignment=ft.alignment.center), ft.Row([ft.Text("エアー率", size=12, color="#00ccff", weight="bold", width=60, text_align="center"), ft.Text("交換率", size=12, color=ft.Colors.RED_ACCENT_400, weight="bold", width=60, text_align="center")], spacing=10)], spacing=8)),
            ], spacing=50, alignment=ft.MainAxisAlignment.START),
        )

        model_tiles = []
        for model_name, m_df in w_df.groupby("機種名"):
            m_master = self.masters_df[self.masters_df['機種名'] == model_name]
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
                    tile_padding=ft.padding.symmetric(horizontal=15), 
                    title=ft.Row([
                        ft.Container(content=ft.Row([ft.Icon(ft.Icons.CIRCLE, color=sig_color, size=14), ft.Text(model_name, weight="bold", size=16, overflow=ft.TextOverflow.ELLIPSIS)], spacing=10), width=200, height=75, alignment=ft.alignment.center_left),
                        ft.Container(content=ft.Row([self.create_data_cell(ft.Text(f"{air_q}", size=16, weight="w900", color="#00ccff"), 80), self.create_data_cell(ft.Text(f"{cln_q}", size=16, weight="w900", color="#00ffcc"), 80), self.create_data_cell(ft.Text(f"{swp_q}", size=16, weight="w900", color=ft.Colors.AMBER_400), 80)], spacing=10), width=260),
                        ft.Container(content=ft.Row([self.create_data_cell(self.create_mini_efficiency_chip("エアー", air_s, air_t, "#00ccff", flat=True), 80), self.create_data_cell(self.create_mini_efficiency_chip("清掃", cln_s, cln_t, "#00ffcc", flat=True), 80), self.create_data_cell(self.create_mini_efficiency_chip("交換", swp_s, swp_t, ft.Colors.AMBER_400, flat=True), 80)], spacing=10), width=260),
                        ft.Container(content=ft.Row([self.create_data_cell(ft.Text(f"{m_air_rate:.0f}%", size=16, weight="w900", color="#00ccff"), 60), self.create_data_cell(ft.Text(f"{m_swap_rate:.0f}%", size=16, weight="w900", color=ft.Colors.RED_ACCENT_400), 60)], spacing=10), width=130),
                    ], spacing=50, alignment=ft.MainAxisAlignment.START),
                    controls=self.build_maker_details(m_df),
                    bgcolor="#1C1F26", collapsed_bgcolor="#111319", maintain_state=True,
                    shape=ft.RoundedRectangleBorder(radius=12), collapsed_shape=ft.RoundedRectangleBorder(radius=12), icon_color="#00ccff",
                )
            )

        # 💡 ここを修正: 見出しをクリック可能にする
        section_title = ft.Container(
            content=ft.Row([
                ft.Container(width=4, height=20, bgcolor="#00ccff", border_radius=2),
                ft.Icon(ft.Icons.LIST_ALT, color="white", size=22),
                ft.Text("全機種の実績・効率一覧 (クリックで拡大表示)", size=18, weight="bold", color="white"), # 💡文言追加
                ft.Container(expand=True),
                ft.Icon(ft.Icons.OPEN_IN_FULL, color=ft.Colors.GREY_500, size=16), # 💡 アイコン追加
            ], spacing=15),
            padding=ft.padding.only(left=15, top=10, bottom=10, right=20),
            bgcolor="#1A1C23",
            border_radius=10,
            on_click=lambda _: self.show_full_list(list_header, model_tiles), # 💡 クリックで拡大表示
            on_hover=lambda e: setattr(e.control, "bgcolor", "#252830" if e.data == "true" else "#1A1C23") or e.control.update() # ホバー演出
        )

        self.detail_area.content = ft.Column([
            ft.Row([ft.Icon(ft.Icons.PERSON, color="#00ccff"), ft.Text(f"{w_name} さんの分析レポート", size=26, weight="bold")], spacing=15),
            summary_row,
            ft.Divider(height=20, color="transparent"),
            section_title,
            ft.Column([
                list_header,
                ft.Column(model_tiles, spacing=8, scroll=ft.ScrollMode.ADAPTIVE, expand=True)
            ], expand=True, spacing=0)
        ], spacing=10)
        self.update()

    def create_stat_card(self, label, val, color, icon):
        # 💡 数値が1,000を超えた場合に少しフォントを小さくして、はみ出しを防ぐ
        display_font_size = 36 if val < 1000 else 32
        
        return ft.Container(
            expand=True,
            padding=ft.padding.symmetric(horizontal=15), # 左右パディングを少し詰め（25 -> 15）
            bgcolor="#1A1C23", 
            border_radius=12, 
            border=ft.border.all(1, "#33363F"),
            content=ft.Row([
                # 💡 アイコンのサイズを微調整 (45 -> 38) して横幅を確保
                ft.Icon(icon, color=color, size=38),
                
                ft.Column([
                    ft.Text(label, color=ft.Colors.GREY_400, size=13, weight="bold"),
                    ft.Row([
                        # 💡 数値に合わせてフォントサイズを可変に
                        ft.Text(
                            f"{val:,}", 
                            size=display_font_size, 
                            weight="w900", 
                            color="white",
                            overflow=ft.TextOverflow.ELLIPSIS # 万が一の時も「...」で防ぐ
                        ),
                        ft.Container(
                            content=ft.Text("台", size=12, color=ft.Colors.GREY_500, weight="bold"),
                            margin=ft.margin.only(bottom=5)
                        ),
                    ], vertical_alignment="end", spacing=2, tight=True), # 間隔を詰め
                ], alignment="center", spacing=0, expand=True),
            ], vertical_alignment="center", spacing=10) # アイコンと文字の間隔を詰め（20 -> 10）
        )

    def on_hover_effect(self, e):
        e.control.bgcolor = "#252830" if e.data == "true" else "#1A1C23"
        e.control.update()
        
        
    def create_mini_efficiency_chip(self, label, actual, target, color, flat=False):
        """アコーディオン内に表示する効率インジケーター（数字のみ・垂直中央揃え版）"""
        if actual == 0:
            return ft.Container() 
            
        is_low = actual < target
        val_color = ft.Colors.RED_ACCENT if is_low else color
        
        return ft.Container(
            content=ft.Row([
                # 💡 実績値（大きく強調）
                ft.Text(f"{actual:.1f}", size=18, weight="w900", color=val_color),
                # 💡 目標値（小さく補助的に）
                ft.Text(f"/{target:.0f}", size=11, color=ft.Colors.GREY_600, weight="bold"),
            ], 
            alignment=ft.MainAxisAlignment.CENTER, # 💡 横方向の中央
            vertical_alignment="end",               # 💡 2つの数字の下端を揃える
            spacing=2,
            tight=True
            ),
            alignment=ft.alignment.center, # 💡 コンテナ内での中央配置
            bgcolor="transparent" if flat else "#0F1115",
            width=95,
            expand=True
        )
        
        
        
    def build_maker_details(self, m_df):
        """アコーディオン展開時の詳細リスト（視認性＆デザイン強化版）"""
        details = []
        
        # 💡 詳細エリアのメインカラー（少し青みのある深いグレー）
        detail_bg_color = "#1A1E26" 
        # 💡 縁取り（ボーダー）の色
        accent_border_color = "#2D323E"

        maker_groups = list(m_df.groupby("メーカー"))
        
        for i, (maker, mk_df) in enumerate(maker_groups):
            model_name = m_df['機種名'].iloc[0]
            m_master = self.masters_df[self.masters_df['機種名'] == model_name]
            
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
                    padding=ft.padding.symmetric(horizontal=15, vertical=12),
                    # 💡 背景色を少しだけ透過させるか、深みのある色に
                    bgcolor=detail_bg_color,
                    border_radius=ft.border_radius.only(
                        top_left=15 if is_first else 0,
                        top_right=15 if is_first else 0,
                        bottom_left=15 if is_last else 0,
                        bottom_right=15 if is_last else 0
                    ),
                    # 💡 左右に薄い縦線を入れて「枠の中に収まっている感」を出す
                    border=ft.border.Border(
                        left=ft.border.BorderSide(2, "#00ccff") if is_first or not is_first else None, # 左にアクセント線
                        bottom=ft.border.BorderSide(1, accent_border_color) if not is_last else None,
                        top=ft.border.BorderSide(1, accent_border_color) if is_first else None,
                        right=ft.border.BorderSide(1, accent_border_color)
                    ),
                    content=ft.Row([
                        # 1. メーカー名（色を少し明るく）
                        ft.Container(
                            content=ft.Row([
                                ft.Icon(ft.Icons.SUBDIRECTORY_ARROW_RIGHT, size=18, color="#00ccff"), # アイコンを青く
                                ft.Text(f"{maker}", size=16, weight="bold", color="white", overflow=ft.TextOverflow.ELLIPSIS),
                            ], spacing=10),
                            width=200, alignment=ft.alignment.center_left,
                        ),
                        # 2. 完了台数内訳
                        ft.Container(
                            content=ft.Row([
                                self.create_data_cell(ft.Text(f"{air_q}", size=16, weight="w900", color="#00ccff"), 80, show_border=False),
                                self.create_data_cell(ft.Text(f"{cln_q}", size=16, weight="w900", color="#00ffcc"), 80, show_border=False),
                                self.create_data_cell(ft.Text(f"{swp_q}", size=16, weight="w900", color=ft.Colors.AMBER_400), 80, show_border=False),
                            ], spacing=10),
                            width=260,
                        ),
                        # 3. 作業効率
                        ft.Container(
                            content=ft.Row([
                                self.create_data_cell(self.create_mini_efficiency_chip("エアー", air_s, air_t, "#00ccff", flat=True), 80, show_border=False),
                                self.create_data_cell(self.create_mini_efficiency_chip("清掃", cln_s, cln_t, "#00ffcc", flat=True), 80, show_border=False),
                                self.create_data_cell(self.create_mini_efficiency_chip("交換", swp_s, swp_t, ft.Colors.AMBER_400, flat=True), 80, show_border=False),
                            ], spacing=10),
                            width=260,
                        ),
                        # 4. 傾向/発生率
                        ft.Container(
                            content=ft.Row([
                                self.create_data_cell(ft.Text(f"{mk_air_rate:.0f}%", size=16, weight="w900", color="#00ccff"), 60, show_border=False),
                                self.create_data_cell(ft.Text(f"{mk_swap_rate:.0f}%", size=16, weight="w900", color=ft.Colors.RED_ACCENT_400), 60, show_border=False),
                            ], spacing=10),
                            width=130,
                        ),
                    ], spacing=50, alignment=ft.MainAxisAlignment.START),
                )
            )
        
        # 全体を少し浮かせ、影のようなマージンを作る
        return [
            ft.Container(
                content=ft.Column(details, spacing=0),
                padding=ft.padding.only(left=25, right=10, bottom=20, top=5), # 左を大きく開けて階層構造を強調
                bgcolor="transparent"
            )
        ]
        
        
    def show_full_list(self, header, tiles):
        # 画面のサイズを取得
        page_width = self.page.width
        page_height = self.page.height

        # 💡 ダイアログとして作成（ボトムシートより横に広げられる）
        full_dialog = ft.AlertDialog(
            modal=False, # 外側クリックで閉じれる
            # コンテンツの周りの余白をゼロにして画面端まで使う
            content_padding=0,
            inset_padding=ft.padding.symmetric(horizontal=20, vertical=40),
            bgcolor="#0F1115",
            shape=ft.RoundedRectangleBorder(radius=15),
            content=ft.Container(
                width=page_width, # 💡 ここで画面いっぱいの幅を指定
                height=page_height,
                padding=0,
                content=ft.Column([
                    # --- ワイド・ヘッダー部分 ---
                    ft.Container(
                        content=ft.Row([
                            ft.Icon(ft.Icons.LIST_ALT, color="#00ccff", size=24),
                            ft.Text("全機種実績・効率詳細（全画面モード）", size=22, weight="bold", color="white"),
                            ft.Container(expand=True),
                            ft.IconButton(
                                icon=ft.Icons.CLOSE, 
                                icon_color=ft.Colors.GREY_500,
                                on_click=lambda _: self.page.close(full_dialog)
                            )
                        ], alignment=ft.MainAxisAlignment.CENTER),
                        padding=ft.padding.symmetric(horizontal=30, vertical=20),
                        bgcolor="#161920", # ヘッダーだけ少し色を変える
                        border_radius=ft.border_radius.only(top_left=15, top_right=15)
                    ),
                    ft.Divider(color="#33363F", height=1),

                    # --- スクロールエリア（横幅を制限しない） ---
                    ft.Container(
                        expand=True,
                        padding=ft.padding.symmetric(horizontal=30, vertical=20),
                        content=ft.Column([
                            # 💡 ヘッダー（元の spacing=50 のままで広々と表示）
                            header, 
                            ft.Divider(height=20, color="transparent"),
                            # 💡 リスト（expandで縦いっぱいに広げる）
                            ft.Column(
                                tiles, 
                                spacing=12, 
                                scroll=ft.ScrollMode.ADAPTIVE, 
                                expand=True
                            )
                        ], expand=True)
                    )
                ], spacing=0),
            )
        )

        # 💡 タイルの横幅設定を「ワイド」に戻す（ボトムシート用の圧縮を解除）
        for tile in tiles:
            tile.title.spacing = 50 # 元の広々した設定に戻す

        self.page.open(full_dialog)