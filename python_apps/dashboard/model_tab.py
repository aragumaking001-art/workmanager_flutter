import flet as ft
import pandas as pd
import os

class ModelView(ft.Column):
    def __init__(self):
        super().__init__(expand=True, spacing=15)
        
        # 1. PieChart の定義
        self.chart = ft.PieChart(
            sections=[],
            sections_space=2,
            center_space_radius=100, 
            expand=True,
            on_chart_event=self.on_chart_event,
        )
        
        # メイン数字 (完了台数)
        self.model_master = {}
        
        self.total_text = ft.Text("0", size=45, weight="bold", color="white")
        
        self.center_labels = ft.TransparentPointer(
            content=ft.Container(
                content=ft.Column([
                    ft.Text("総完了数", size=26, weight="bold", color=ft.Colors.GREY_500),
                    self.total_text,
                    ft.Text("台", size=22, weight="bold", color=ft.Colors.GREY_500),
                ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                alignment=ft.alignment.center,
            )
        )

        self.chart_stack = ft.Stack([
            self.chart,
            self.center_labels
        ], expand=True)

        self.indicators_column = ft.Column(
            scroll=ft.ScrollMode.AUTO,
            spacing=10,
            width=240,
        )

        self.detail_list = ft.ListView(expand=True, spacing=15, padding=10)
        self.model_master = self.load_model_master()

        def get_border(color="#2D3039", width=2):
            return ft.border.all(width, color)

        self.controls = [
            ft.Row([
                ft.Container(
                    content=ft.Column([
                        ft.Row([
                            ft.Icon(ft.Icons.PIE_CHART_ROUNDED, color="#FFD700", size=36), 
                            ft.Text("機種別 完了占有率", size=34, weight="bold")
                        ]),
                        ft.Row([
                            self.chart_stack,
                            self.indicators_column
                        ], expand=True)
                    ]),
                    bgcolor="#1A1C23", padding=20, border_radius=25, expand=4,
                    border=get_border("#FFD700", 2)
                ),
                ft.Container(
                    content=ft.Column([
                        ft.Row([
                            ft.Icon(ft.Icons.ANALYTICS_ROUNDED, color="#FFD700", size=36), 
                            ft.Text("実績詳細分析", size=34, weight="bold")
                        ]),
                        ft.Divider(height=10, color="#444444"),
                        self.detail_list
                    ]),
                    bgcolor="#1A1C23", padding=20, border_radius=25, expand=6,
                    border=get_border()
                )
            ], expand=True, spacing=20)
        ]

    def on_chart_event(self, e: ft.PieChartEvent):
        for i, section in enumerate(self.chart.sections):
            is_hovered = (i == e.section_index)
            section.radius = 60 if is_hovered else 50
            section.title_style = ft.TextStyle(
                size=22 if is_hovered else 16,
                weight="bold",
                color=ft.Colors.WHITE
            )
        self.chart.update()

    def load_model_master(self, df_models=None):
        if df_models is not None and not df_models.empty:
            try:
                return {
                    (str(row['model_name']).strip(), str(row['maker']).strip()): str(row['maker_abbr']).strip()
                    for _, row in df_models.iterrows()
                }
            except: pass
        if not os.path.exists('model_name.csv'): return {}
        try:
            for enc in ['utf-8-sig', 'cp932', 'utf-8']:
                try:
                    df = pd.read_csv('model_name.csv', encoding=enc)
                    df.columns = df.columns.str.strip()
                    return {
                        (str(row['機種名']).strip(), str(row['メーカー']).strip()): str(row['メーカー略称']).strip()
                        for _, row in df.iterrows()
                    }
                except: continue
        except: return {}
        return {}

    def update_tab(self, df_today, df_members=None, df_models=None):
        self.model_master = self.load_model_master(df_models)
        
        if df_today.empty:
            self.total_text.value = "0"
            self.chart.sections = []
            self.indicators_column.controls.clear()
            self.detail_list.controls.clear()
            self.update()
            return

        # --- 完了としてカウントするカラム (NGは除外) ---
        done_cols = ['エアー清掃台数', '清掃台数', '筐体交換台数']
        ng_col = '筐体交換行き台数'
        
        all_cols = done_cols + [ng_col]
        for col in all_cols:
            if col not in df_today.columns:
                df_today[col] = 0
            df_today[col] = df_today[col].fillna(0)

        # 集計
        model_detail = df_today.groupby(['機種名', 'メーカー'])[all_cols].sum()
        
        # 「合計」は完了分（エアー・清掃・交換済）のみで計算
        model_detail['合計'] = model_detail[done_cols].sum(axis=1)
        
        # 表示対象：完了が1台以上、またはNGが1台以上ある機種
        model_detail = model_detail[(model_detail['合計'] > 0) | (model_detail[ng_col] > 0)].sort_values('合計', ascending=False)

        # 総完了数 (中央に表示する数字)
        total_all = int(model_detail['合計'].sum())
        self.total_text.value = str(total_all)
        
        palette = [
            ft.Colors.BLUE_400, ft.Colors.GREEN_400, ft.Colors.ORANGE_400, 
            ft.Colors.PURPLE_400, ft.Colors.RED_400, ft.Colors.TEAL_400, 
            ft.Colors.PINK_400, ft.Colors.AMBER_400, ft.Colors.CYAN_400, ft.Colors.LIME_400
        ]

        sections = []
        self.indicators_column.controls.clear()
        self.detail_list.controls.clear()
        
        for i, ((m_name, mfr), row) in enumerate(model_detail.iterrows()):
            color = palette[i % len(palette)]
            
            # 占有率は「全完了数の中での割合」として計算
            percentage = (row['合計'] / total_all * 100) if total_all > 0 else 0
            mfr_abbr = self.model_master.get((m_name, mfr), mfr)
            
            # 完了台数が0より大きい場合のみグラフに表示
            if row['合計'] > 0:
                sections.append(
                    ft.PieChartSection(
                        value=row['合計'],
                        title=f"{int(row['合計'])}",
                        title_style=ft.TextStyle(size=18, weight="bold", color=ft.Colors.WHITE),
                        color=color,
                        radius=50,
                    )
                )
            
            # 凡例 (完了数に基づいた%)
            self.indicators_column.controls.append(
                ft.Row([
                    ft.Container(width=14, height=14, bgcolor=color, border_radius=3),
                    ft.Text(f"{m_name} ({mfr_abbr})", size=16, weight="bold", color=ft.Colors.GREY_300, expand=True, no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS),
                    ft.Text(f"{percentage:.1f}%", size=16, weight="w900", color=color),
                ], spacing=8)
            )

            rank_icon = "🥇" if i == 0 else "🥈" if i == 1 else "🥉" if i == 2 else f"#{i+1}"
            v_air = int(row['エアー清掃台数'])
            v_clean = int(row['清掃台数'])
            v_swap_done = int(row['筐体交換台数'])
            v_swap_ng = int(row[ng_col])
            
            # 内訳バー用の比率 (見た目用)
            f_air = max(0.1, v_air)
            f_clean = max(0.1, v_clean)
            f_done = max(0.1, v_swap_done)
            f_ng = max(0.1, v_swap_ng)

            # 詳細カード
            self.detail_list.controls.append(ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Text(rank_icon, size=26),
                        ft.Text(m_name, size=26, weight="w900"),
                        ft.Text(f"({mfr_abbr})", size=26, weight="bold"),
                        ft.Container(expand=True),
                        ft.Container(
                            content=ft.Text(f"{percentage:.1f}%", size=15, weight="bold", color="#1A1C23"),
                            bgcolor=color, padding=ft.padding.symmetric(horizontal=10, vertical=3),
                            border_radius=10
                        )
                    ], spacing=12, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                    
                    # 内訳バー (完了3項目 + NG1項目)
                    ft.Row([
                        ft.Container(height=10, bgcolor="#00ccff", expand=int(f_air*10) if v_air>0 else 0, border_radius=ft.border_radius.only(top_left=5, bottom_left=5) if v_air>0 else 0),
                        ft.Container(height=10, bgcolor="#00ffcc", expand=int(f_clean*10) if v_clean>0 else 0),
                        ft.Container(height=10, bgcolor=ft.Colors.AMBER_400, expand=int(f_done*10) if v_swap_done>0 else 0),
                        ft.Container(height=10, bgcolor=ft.Colors.RED_ACCENT_400, expand=int(f_ng*10) if v_swap_ng>0 else 0, border_radius=ft.border_radius.only(top_right=5, bottom_right=5) if v_swap_ng>0 else 0),
                    ], spacing=2),

                    # 数値詳細
                    ft.Row([
                        ft.Row([
                            ft.Icon(ft.Icons.AIR_ROUNDED, color="#00ccff", size=20),
                            ft.Text(f"{v_air}", color="#00ccff", size=18, weight="bold"),
                        ], spacing=4),
                        ft.Row([
                            ft.Icon(ft.Icons.CLEAN_HANDS_ROUNDED, color="#00ffcc", size=20),
                            ft.Text(f"{v_clean}", color="#00ffcc", size=18, weight="bold"),
                        ], spacing=4),
                        ft.Row([
                            ft.Icon(ft.Icons.SETTINGS_OUTLINED, color=ft.Colors.AMBER_400, size=20),
                            ft.Text(f"{v_swap_done}", color=ft.Colors.AMBER_400, size=18, weight="bold"),
                        ], spacing=4),
                        ft.Row([
                            ft.Icon(ft.Icons.REPORT_GMAILERRORRED_ROUNDED, color=ft.Colors.RED_ACCENT_400, size=20),
                            ft.Text(f"筐体交換行き:{v_swap_ng}", color=ft.Colors.RED_ACCENT_400, size=18, weight="bold"),
                        ], spacing=4),
                        ft.Text(f"{int(row['合計'])}台", expand=True, text_align="right", size=32, weight="w900", color="#FFD700")
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
                ]),
                bgcolor="#23262F", padding=20, border_radius=15,
                border=ft.border.all(1, "#33363F")
            ))

        self.chart.sections = sections
        self.update()
