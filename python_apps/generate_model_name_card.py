import pandas as pd
from html2image import Html2Image
import os

# 出力フォルダ
output_dir = 'model_nfc_cards_tate_no_border'
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

hti = Html2Image(output_path=output_dir)

def get_task_color(work_type):
    # 条件分岐に「筐体交換」を追加
    if '筐体交換' in work_type:
        return "#ffca28"  # Amber 400
    elif 'エアー' in work_type:
        return "#0288d1"  # エアー：青
    elif '清掃' in work_type:
        return "#2e7d32"  # 清掃：緑
    else:
        return "#1a237e"  # その他：紺

def generate_impact_card_html(model_name, maker_abbr, work_type):
    task_color = get_task_color(work_type)
    
    # 筐体交換(Amber)の場合、白文字だと見にくい可能性があるため
    # 文字色を自動調整する処理（お好みで調整してください）
    text_color = "#ffffff"
    if task_color == "#ffca28":
        text_color = "#ffffff" # Amberの時は濃いグレーにする

    html_template = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@700;900&display=swap" rel="stylesheet">
        <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
        <style>
            body {{
                margin: 0; padding: 0;
                width: 700px; height: 1100px;
                background-color: white;
                display: flex; justify-content: center; align-items: center;
                font-family: 'Noto Sans JP', sans-serif;
            }}
            .card {{
                width: 570px; height: 910px;
                background: white;
                border: none; 
                box-shadow: none;
                display: flex; flex-direction: column;
                position: relative;
                overflow: hidden;
                box-sizing: border-box;
            }}
            .top-bar {{
                width: 100%; height: 35px;
                background: {task_color};
            }}
            .main-content {{
                flex: 1;
                padding: 40px 20px;
                display: flex; flex-direction: column;
                justify-content: center;
                align-items: center; text-align: center;
            }}
            .label {{
                color: #ccc; font-size: 16px;
                letter-spacing: 4px; margin-bottom: 15px;
                font-weight: 700;
                text-transform: uppercase;
            }}
            .model-section {{
                width: 100%;
                margin-bottom: 80px;
            }}
            .model-full-name {{
                color: #000;
                font-size: 68px;
                font-weight: 900;
                line-height: 1.2;
                display: flex;
                flex-wrap: wrap;
                justify-content: center;
                gap: 15px;
            }}
            .task-section {{
                width: 100%;
            }}
            .work-badge {{
                background: {task_color};
                color: {text_color}; /* 動的に変更 */
                width: 95%;
                padding: 45px 5px;
                border-radius: 40px;
                font-size: 68px;
                font-weight: 900;
                display: inline-block;
                box-shadow: 0 10px 20px rgba(0,0,0,0.1);
                letter-spacing: 2px;
                line-height: 1;
            }}
            .nfc-panel {{
                height: 250px;
                background: #fff;
                display: flex; flex-direction: column;
                justify-content: center; align-items: center;
                border-top: none;
                width: 100%;
            }}
            .nfc-icon-wrapper {{
                width: 120px; height: 120px;
                background: white;
                border-radius: 35px;
                display: flex; justify-content: center; align-items: center;
                border: 2px solid #f0f0f0;
                color: {task_color};
            }}
            .nfc-icon-wrapper .material-icons {{ font-size: 70px; }}
            .touch-msg {{
                margin-top: 15px;
                color: #444;
                font-size: 22px; font-weight: 900;
                letter-spacing: 1px;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="top-bar"></div>
            <div class="main-content">
                <div class="model-section">
                    <div class="label">Model & Maker</div>
                    <div class="model-full-name">
                        <span>{model_name}</span>
                        <span>{maker_abbr}</span>  </div>
                </div>
                
                <div class="task-section">
                    <div class="label">Task Category</div>
                    <div class="work-badge">{work_type}</div>
                </div>
            </div>
            
            <div class="nfc-panel">
                <div class="nfc-icon-wrapper">
                    <span class="material-icons">sensors</span>
                </div>
                <div class="touch-msg">NFC TOUCH</div>
            </div>
        </div>
    </body>
    </html>
    """
    return html_template

def main():
    try:
        df = pd.read_csv('model_name.csv', encoding='utf-8-sig')
    except:
        df = pd.read_csv('model_name.csv', encoding='cp932')

    # ★ 追加：すべての空欄(NaN)を空文字('')に置き換える
    df = df.fillna('')

    print("筐体交換(Amber対応)版NFCカード生成中...")
    for _, row in df.iterrows():
        mid = str(row['機種番号'])
        mname = str(row['機種名'])
        
        # 略称を取得
        m_abbr = str(row['メーカー略称']).strip()
        
        # ★ もし略称がある場合だけカッコを付ける処理（見た目の調整）
        m_abbr_display = f"({m_abbr})" if m_abbr != "" else ""
        
        work = str(row['作業内容'])
        
        # HTML生成側へ渡す（テンプレート内のカッコは外して渡すとより柔軟になります）
        html = generate_impact_card_html(mname, m_abbr_display, work)
        hti.screenshot(html_str=html, save_as=f'model_card_{mid}.png', size=(700, 1100))
        
        # ログ表示用
        print(f"作成完了: {mname} {m_abbr_display} - {work}")

if __name__ == "__main__":
    main()