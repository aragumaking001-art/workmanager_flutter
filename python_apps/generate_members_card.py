import pandas as pd
from html2image import Html2Image
import os

output_dir = 'wake_cards_meishi'
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

hti = Html2Image(output_path=output_dir)

def generate_card_html(worker_name):
    # カード本体のサイズを 910x550 (名刺比率) に設定
    # body全体はそれより一回り大きくして、影や枠線が切れないようにする
    html_template = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;700;900&display=swap" rel="stylesheet">
        <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
        <style>
            body {{
                margin: 0; padding: 0;
                width: 1000px; height: 600px; /* 保存サイズより少し小さく設定 */
                background-color: transparent; /* 背景を透明に */
                display: flex; justify-content: center; align-items: center;
                font-family: 'Noto Sans JP', sans-serif;
            }}
            .card {{
                /* 91:55 の比率を維持 */
                width: 910px; 
                height: 570px;
                background: white;
                border-radius: 30px; 
                display: flex;
                position: relative;
                overflow: hidden;
                /* ★ここを修正：外枠を削除 */
                /* border: 6px solid #1a237e; */ 
                box-sizing: border-box;
                /* 影が切れないよう、少しだけ小さめに配置されるようにする */
                box-shadow: 0 10px 30px rgba(0,0,0,0.15);
            }}
            .side-bar {{
                width: 40px; height: 100%;
                background: linear-gradient(to bottom, #1a237e, #0d47a1);
                position: relative;
            }}
            .bg-text {{
                position: absolute;
                font-size: 350px;
                font-weight: 900;
                color: rgba(0,0,0,0.05);
                top: 50%;
                left: calc(40px + (910px - 40px - 320px) / 2);
                transform: translate(-50%, -50%);
                z-index: 0;
            }}
            .main-content {{
                flex: 1;
                padding: 40px 20px 40px 40px;
                z-index: 1;
                display: flex; flex-direction: column;
                justify-content: space-between;
                position: relative;
            }}
            .location-tag {{
                background: #ffc107; color: #1a237e;
                padding: 8px 20px; border-radius: 50px;
                font-weight: 700; font-size: 22px;
                display: flex; align-items: center; gap: 8px;
                width: fit-content;
            }}
            .label {{
                color: #666; font-size: 18px;
                letter-spacing: 3px; margin-bottom: 5px;
                display: flex; align-items: center; gap: 8px;
            }}
            .name {{
                color: #1a237e; font-size: 72px;
                font-weight: 900; margin: 5px 0;
                border-bottom: 6px solid #ffc107;
                display: inline-block;
            }}
            .nfc-panel {{
                width: 320px;
                background: #fdfdfd;
                display: flex; flex-direction: column;
                justify-content: center; align-items: center;
                position: relative;
                z-index: 1;
            }}
            .nfc-icon-wrapper {{
                width: 170px; height: 170px;
                background: white;
                border-radius: 40px;
                display: flex; justify-content: center; align-items: center;
                box-shadow: 0 10px 20px rgba(0,0,0,0.05);
                border: 1px solid #eee;
                color: #1a237e;
            }}
            .nfc-icon-wrapper .material-icons {{
                font-size: 90px;
            }}
            .touch-msg {{
                margin-top: 20px;
                color: #1a237e;
                font-size: 18px; font-weight: bold;
                text-align: center; line-height: 1.4;
            }}
            .deco-dots {{
                position: absolute; bottom: 30px; left: 70px;
                display: flex; gap: 8px; z-index: 2;
            }}
            .dot {{
                width: 12px; height: 12px;
                background: #ddd; border-radius: 50%;
            }}
            .dot.active {{ background: #ffc107; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="side-bar"></div>
            <div class="bg-text">W</div>
            <div class="main-content">
                <div class="header">
                    <div class="location-tag">
                        <span class="material-icons">location_on</span>和気センター
                    </div>
                </div>
                <div>
                    <div class="label"><span class="material-icons">person</span>OPERATOR</div>
                    <div class="name">{worker_name}</div>
                </div>
            </div>
            <div class="deco-dots">
                <div class="dot active"></div>
                <div class="dot"></div>
                <div class="dot"></div>
                <div class="dot"></div>
            </div>
            <div class="nfc-panel">
                <div class="label" style="justify-content:center; color:#1a237e; margin-bottom:15px;">
                    <span class="material-icons" style="font-size:24px">contactless</span>NFC TOUCH
                </div>
                <div class="nfc-icon-wrapper">
                    <span class="material-icons">sensors</span>
                </div>
                <div class="touch-msg">作業開始・終了時<br>リーダーにタッチしてください</div>
            </div>
        </div>
    </body>
    </html>
    """
    return html_template

def main():
    try:
        df = pd.read_csv('members.csv', encoding='utf-8-sig')
    except:
        # CP932(Shift_JIS)で試行
        try:
            df = pd.read_csv('members.csv', encoding='cp932')
        except FileNotFoundError:
            print("エラー: members.csv が見つかりません。")
            return

    print("外枠なし・名刺サイズ生成中...")
    for _, row in df.iterrows():
        name = str(row['氏名'])
        wid = str(row['社員番号'])
        html = generate_card_html(name)
        # ブラウザのウィンドウサイズをHTMLより大きく設定(1100x700)することで、
        # 影が切れるのを防ぎます。
        hti.screenshot(html_str=html, save_as=f'wake_card_{wid}.png', size=(1100, 700))
        print(f"作成完了: {name}")

if __name__ == "__main__":
    main()
    # --- ここから追加 ---
    print("\nすべての処理が完了しました。")
    input("Enterキーを押すと終了します...")