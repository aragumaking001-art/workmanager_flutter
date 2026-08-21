import flet as ft
import pandas as pd
import random
from datetime import datetime


class TodayWorkSummaryView(ft.Column):
    def __init__(self):
        super().__init__(expand=True, spacing=10)

        # 1. 💡 応援担当の名簿（アイコンは1日固定）
        self.cheer_staff = [
            {"name": "ネコ軍曹", "icon": "😸", "suffix": "ニャ！"},
            {"name": "イヌ隊長", "icon": "🐶", "suffix": "ワン！"},
            {"name": "ウサギ中尉", "icon": "🐰", "suffix": "ぴょん！"},
            {"name": "パンダ上等兵", "icon": "🐼", "suffix": "メエ"},
            {"name": "ライオン将軍", "icon": "🦁", "suffix": "ガオー！"},
        ]

        random.seed(datetime.now().strftime("%Y%m%d"))
        self.today_staff = random.choice(self.cheer_staff)

        self.targets = {"エアー": 0, "清掃": 0, "筐体交換": 0}
        self.total_target = 0

        self.display_order = []
        self.last_order_date = ""

        # --- 💡 手順2: UI部品（パーツ）を先に作る ---
        self.date_text = ft.Text("", size=42, weight="bold", color="white")
        self.weekday_text = ft.Text("", size=20, color="#00ccff", weight="bold")
        self.total_progress_bar = ft.ProgressBar(
            value=0, color="#00ffcc", bgcolor="white10", height=10
        )
        self.total_pct_text = ft.Text("0%", size=14, color="white38", weight="bold")
        self.cheer_icon = ft.Text(self.today_staff["icon"], size=45)
        self.cheer_msg = ft.Text(
            "本日もご安全に！", size=18, weight="bold", color="#00ffcc"
        )
        self.cheer_name_text = ft.Text(
            f"応援担当: {self.today_staff['name']}",
            size=14,
            color="white38",
            weight="bold",
        )

        self.stats_cards = {
            "エアー": self.create_giant_card("エアー", "#00ccff", ft.Icons.AIR),
            "清掃": self.create_giant_card(
                "清掃", "#00ffcc", ft.Icons.CLEANING_SERVICES
            ),
            "筐体交換": self.create_giant_card(
                "筐体交換", ft.Colors.AMBER, ft.Icons.SETTINGS_OUTLINED
            ),
        }
        self.model_list = ft.ListView(expand=True, spacing=5)

        # 応援担当セクションの作成
        self.cheer_icon = ft.Text(self.today_staff["icon"], size=45)
        self.cheer_msg = ft.Text(
            "本日もご安全に！", size=18, weight="bold", color="#00ffcc"
        )
        self.total_pct_text = ft.Text("0%", size=14, color="white38", weight="bold")
        self.cheer_name_text = ft.Text(
            f"応援担当: {self.today_staff['name']}",
            size=14,
            color="white38",
            weight="bold",
        )

        self.cheer_section = ft.Container(
            content=ft.Column(
                [
                    ft.Row(
                        [
                            self.cheer_icon,
                            ft.Column(
                                [
                                    ft.Row(
                                        [self.cheer_name_text, self.total_pct_text],
                                        alignment="spaceBetween",
                                        width=320,
                                    ),
                                    self.cheer_msg,
                                ],
                                spacing=2,
                            ),
                        ]
                    ),
                    ft.Container(
                        content=self.total_progress_bar,
                        padding=ft.padding.only(left=5, right=10),
                    ),
                ],
                spacing=10,
            ),
            padding=15,
            bgcolor="#23262F",
            border_radius=20,
            border=ft.border.all(1, "#33363F"),
        )

        self.controls = [
            # --- 最上部：日付セクション ---
            ft.Container(
                content=ft.Column(
                    [
                        ft.Row([self.date_text], alignment=ft.MainAxisAlignment.START),
                        ft.Row(
                            [
                                ft.Icon(
                                    ft.Icons.CALENDAR_MONTH, color="#00ccff", size=30
                                ),
                                ft.Container(
                                    content=self.weekday_text,
                                    margin=ft.margin.only(bottom=5),
                                ),
                            ],
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=10,
                        ),
                    ],
                    spacing=0,
                ),
                padding=ft.padding.only(left=20, bottom=5, top=30),
            ),
            ft.Row(
                [
                    # --- 左側：応援担当(進捗バー付) + 3つの実績カード ---
                    ft.Column(
                        [
                            self.cheer_section,
                            self.stats_cards["エアー"],
                            self.stats_cards["清掃"],
                            self.stats_cards["筐体交換"],
                        ],
                        width=430,
                        spacing=12,
                        alignment=ft.MainAxisAlignment.END,
                    ),
                    # --- 右側：機種別リスト ---
                    ft.Container(
                        content=ft.Column(
                            [
                                ft.Row(
                                    [
                                        ft.Icon(ft.Icons.LIST_ALT, color="#00ffcc"),
                                        ft.Text(
                                            "本日機種別 詳細内訳",
                                            size=26,
                                            weight="bold",
                                        ),
                                    ]
                                ),
                                ft.Container(
                                    content=ft.Row(
                                        [
                                            ft.Text(
                                                "機種 (メーカー)",
                                                expand=True,
                                                color="white38",
                                                size=18,
                                                weight="bold",
                                            ),
                                            ft.Text(
                                                "エアー",
                                                width=110,
                                                text_align="center",
                                                color="white38",
                                                size=18,
                                                weight="bold",
                                            ),  
                                            ft.Text(
                                                "清掃",
                                                width=110,
                                                text_align="center",
                                                color="white38",
                                                size=18,
                                                weight="bold",
                                            ),  
                                            ft.Text(
                                                "筐体交換",
                                                width=110,
                                                text_align="center",
                                                color="white38",
                                                size=18,
                                                weight="bold",
                                            ),  
                                            ft.Text(
                                                "合計台数",
                                                width=150,
                                                text_align="center",
                                                color="white",
                                                size=20,
                                                weight="bold",
                                            ),  
                                        ]
                                    ),
                                    padding=ft.padding.only(right=15, left=15),
                                ),
                                ft.Divider(height=1, color="#33363F"),
                                ft.Container(content=self.model_list, expand=True),
                            ]
                        ),
                        expand=True,
                        bgcolor="#1A1C23",
                        padding=25,
                        border_radius=25,
                        border=ft.border.all(1, "#33363F"),
                        margin=ft.margin.only(top=-135),
                    ),
                ],
                expand=True,
            ),
        ]

    def create_giant_card(self, label, color, icon):
        return ft.Container(
            expand=True,  
            content=ft.Column(
                [
                    ft.Row(
                        [
                            ft.Row(
                                [
                                    ft.Icon(icon, color=color, size=28),
                                    ft.Text(label, size=20, weight="bold", color=color),
                                ],
                                spacing=8,
                            ),
                            ft.Text(
                                f"目標 {self.targets.get(label, 100):,}",
                                size=18,
                                color="white38",
                                weight="bold",
                                key=f"{label}_target",
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    ),
                    ft.Row(
                        [
                            ft.Text(
                                "0",
                                size=75,
                                weight="w900",
                                color="white",
                                key=f"{label}_val",
                            ),
                            ft.Text("台", size=22, color="white38", weight="bold"),
                        ],
                        alignment=ft.MainAxisAlignment.END,
                        vertical_alignment=ft.CrossAxisAlignment.END,
                    ),
                    ft.Row(
                        [
                            ft.ProgressBar(
                                value=0,
                                color=color,
                                bgcolor="#2D3039",
                                height=12,
                                key=f"{label}_bar",
                                expand=True,
                            ),
                            ft.Text(
                                "0%",
                                size=22,
                                weight="bold",
                                color=color,
                                key=f"{label}_pct",
                                width=80,
                                text_align="right",
                            ),
                        ],
                        vertical_alignment="center",
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN, 
                spacing=0, 
            ),
            padding=ft.padding.only(left=20, top=15, right=20, bottom=15),
            bgcolor="#1A1C23",
            border_radius=20,
            border=ft.border.all(2, "#33363F"),
        )

    def update_tab(self, df_all, date_str, db_targets=None, df_members=None, df_models=None):

        # 💡 【完全修正版】無限ループを防ぎ、確実に値を取り出す（表示バグ対策のスペース入り）
        if db_targets:
            safe_targets = {}
            for k, v in db_targets.items():
                while isinstance(v, (tuple, list, bytearray, bytes)):
                    if len(v) > 0:
                        v = v[ 0 ]
                    else:
                        v = 0
                try:
                    safe_targets[k] = int(v)
                except:
                    safe_targets[k] = 0
            self.targets = safe_targets
            self.total_target = sum(self.targets.values())

        # 💡 Pythonの「2026/04/15」とMariaDBの「2026-04-15」の表記ゆれをスラッシュ(/)に統一
        clean_date_str = date_str.strip().replace("-", "/")

        if getattr(self, "last_order_date", "") != clean_date_str:
            self.display_order = []
            self.last_order_date = clean_date_str

        try:
            dt = datetime.strptime(clean_date_str, "%Y/%m/%d")
            weekdays = [
                "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日",
            ]
            self.date_text.value = dt.strftime("%Y年 %m月 %d日")
            self.weekday_text.value = weekdays[dt.weekday()]
        except Exception as e:
            print(f"日付のパースに失敗しました: {e}")

        # 💡 データベース側の「日付」カラムもすべてスラッシュ(/)に置換・空白除去
        if not df_all.empty and "日付" in df_all.columns:
            df_all["日付"] = df_all["日付"].astype(str).str.strip().str.replace("-", "/")

        # 完璧に表記が揃った状態でフィルタリング！
        df_today = df_all[df_all["日付"] == clean_date_str].copy()

        # 数値変換の徹底
        for c in ["清掃台数", "エアー清掃台数", "筐体交換台数"]:
            if c in df_today.columns:
                df_today[c] = pd.to_numeric(df_today[c], errors="coerce").fillna(0)

        summary = {
            "エアー": (
                int(df_today["エアー清掃台数"].sum()) if not df_today.empty else 0
            ),
            "清掃": int(df_today["清掃台数"].sum()) if not df_today.empty else 0,
            "筐体交換": (
                int(df_today["筐体交換台数"].sum()) if not df_today.empty else 0
            ),  
        }

        # 全体進捗の計算
        total_done = sum(summary.values())
        total_prog = (
            min(total_done / self.total_target, 1.0) if self.total_target > 0 else 0
        )
        self.total_progress_bar.value = total_prog
        self.total_pct_text.value = f"全体進捗: {int(total_prog * 100)}%"

        sfx = self.today_staff["suffix"]
        self.cheer_icon.value = self.today_staff["icon"]  

        if total_prog == 0:
            self.cheer_msg.value = f"準備中{sfx}"
            self.cheer_msg.color = "white38"
        elif total_prog < 0.3:
            self.cheer_msg.value = f"まずは1台！ここから{sfx}"
            self.cheer_msg.color = "#00ccff"
        elif total_prog < 0.6:
            self.cheer_msg.value = f"いいペース{sfx} その調子{sfx}"
            self.cheer_msg.color = "#00ffcc"
        elif total_prog < 0.9:
            self.cheer_msg.value = f"スゴい{sfx} 目標まであと少し{sfx}"
            self.cheer_msg.color = "amber"
        else:
            self.cheer_msg.value = f"爆速{sfx} 和気センター最強{sfx}"
            self.cheer_msg.color = "#ff00ff"

        for label, val in summary.items():
            card = self.stats_cards[label]

            target_key = label
            target_val = self.targets.get(target_key, 100)
            prog = min(val / target_val, 1.0) if target_val > 0 else 0

            def update_recursive(controls):
                for c in controls:
                    if hasattr(c, "key") and c.key:
                        if c.key == f"{label}_val":
                            c.value = str(val)
                        elif c.key == f"{label}_pct":
                            c.value = f"{int(prog*100)}%"
                        elif c.key == f"{label}_bar":
                            c.value = prog
                        elif (
                            c.key == f"{label}_target"
                        ):  
                            c.value = f"目標 {target_val:,}"

                    if hasattr(c, "controls"):
                        update_recursive(c.controls)

            update_recursive(card.content.controls)

        self.model_list.controls.clear()
        if not df_today.empty:
            group_cols = ["機種名", "メーカー略称"] 
            
            temp_df = df_today.copy()
            
            if "id" in temp_df.columns:
                temp_df["first_id"] = pd.to_numeric(temp_df["id"], errors="coerce").fillna(9999999)
            elif "id_x" in temp_df.columns:
                temp_df["first_id"] = pd.to_numeric(temp_df["id_x"], errors="coerce").fillna(9999999)
            else:
                temp_df["first_id"] = temp_df.reset_index().index
                
            temp_df["メーカー略称"] = temp_df["メーカー略称"].fillna("")
            
            # 合計を計算しつつ、各機種の最初の登場ID (min) を取得する
            m_sum = temp_df.groupby(group_cols, dropna=False).agg(
                エアー清掃台数=("エアー清掃台数", "sum"),
                清掃台数=("清掃台数", "sum"),
                筐体交換台数=("筐体交換台数", "sum"),
                first_id=("first_id", "min")
            ).reset_index()

            m_sum["total"] = m_sum[["エアー清掃台数", "清掃台数", "筐体交換台数"]].sum(axis=1)

            # 💡 "first_id" が小さい順（＝その日に一番早く作業ログが登録された順）に並び替える
            m_sum["first_id"] = pd.to_numeric(m_sum["first_id"], errors="coerce").fillna(9999999)
            m_sum = m_sum.sort_values("first_id", ascending=True)

            for _, r in m_sum.iterrows():
                if r["total"] > 0:
                    base_name = str(r.get("機種名", "")).strip()
                    abbr = str(r.get("メーカー略称", "")).strip()
                    
                    if abbr and abbr.lower() not in ["nan", "none", ""]:
                        display_name = f"{base_name} ({abbr})"
                    else:
                        display_name = base_name

                    row_total = int(r["total"])

                    self.model_list.controls.append(
                        ft.Container(
                            content=ft.Row(
                                [
                                    ft.Text(
                                        display_name,
                                        expand=True,
                                        size=32,
                                        weight="bold",
                                        overflow=ft.TextOverflow.ELLIPSIS,
                                    ),
                                    ft.Text(
                                        f"{int(r['エアー清掃台数'])}",
                                        width=110,
                                        text_align="center",
                                        color=(
                                            "#00ccff"
                                            if r["エアー清掃台数"] > 0
                                            else "white10"
                                        ),
                                        weight="bold",
                                        size=32,
                                    ),
                                    ft.Text(
                                        f"{int(r['清掃台数'])}",
                                        width=110,
                                        text_align="center",
                                        color=(
                                            "#00ffcc"
                                            if r["清掃台数"] > 0
                                            else "white10"
                                        ),
                                        weight="bold",
                                        size=32,
                                    ),
                                    ft.Text(
                                        f"{int(r['筐体交換台数'])}",
                                        width=110,
                                        text_align="center",
                                        color=(
                                            ft.Colors.AMBER
                                            if r["筐体交換台数"] > 0
                                            else "white10"
                                        ),
                                        weight="bold",
                                        size=32,
                                    ),
                                    ft.Container(
                                        content=ft.Text(
                                            f"{row_total}",
                                            size=42,
                                            weight="bold",
                                            color="white",
                                            text_align="center",
                                        ),
                                        width=140,
                                        bgcolor="#2D3243",
                                        border_radius=12,
                                        padding=ft.padding.symmetric(vertical=8),
                                        border=ft.border.all(2, "#444B63"),
                                    ),
                                ]
                            ),
                            padding=ft.padding.symmetric(vertical=15, horizontal=20),
                            border=ft.border.only(
                                bottom=ft.border.BorderSide(1, "#2D3039")
                            ),
                        )
                    )

        if self.page:
            self.update()