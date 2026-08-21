import mysql.connector
import datetime
import requests
import sys
import io

# ターミナルの文字化け対策 (UTF-8強制)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# -----------------------------------------
# 設定項目
# -----------------------------------------
DB_HOST = "192.168.10.101"
DB_USER = "work_user"
DB_PASS = "work1234"
DB_NAME = "work_manager_db"

OLLAMA_URL = "http://192.168.10.101:11434/api/generate"
OLLAMA_MODEL = "gemma2:9b"

# -----------------------------------------
# プロンプトテンプレート（ここを変更してAIの出力を調整）
# -----------------------------------------
PROMPT_TEMPLATE = """
あなたは優秀で優しい業務管理AIアシスタントです。
今回は「和気センター4F」という場所で、ONUなどの通信機器の「筐体清掃作業」を日々頑張っている作業者（{worker_name}さん）へ向けたねぎらいの言葉と、前向きなアドバイスを含むレポートを作成してください。

以下のデータは、基準日（今日または指定日）から遡って「直近1ヶ月分」の作業実績をまとめたものです。

【条件】
・トーンは指定された【口調】に合わせてください。
・作業者の直近1ヶ月の頑張りを認め、モチベーションが上がるように褒めてください。
・アドバイスは無理のない範囲で、ポジティブな言葉で伝えてください。
・回答はAIからのメッセージ本文（本文のみ）を出力してください。「以下はレポートです」などの前置きや挨拶以外の不要な修飾は避けてください。
・4桁以上の数値を記載する場合は、必ず「1,000」のようにカンマ区切りで表記してください。

【口調の設定】
{tone_instruction}

【{worker_name}さんの直近1ヶ月の作業データ】
{data_summary}
"""

def get_db_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        charset='utf8mb4'
    )

def fetch_all_members(conn):
    """全作業員のリストを取得する"""
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT worker_id, worker_name, IFNULL(ai_tone, '標準') as ai_tone FROM m_members ORDER BY worker_id")
    members = cursor.fetchall()
    cursor.close()
    return members

def fetch_worker_data(conn, worker_id, target_date):
    """
    指定された作業員の直近1ヶ月の清掃ログをDBから取得し、テキストにまとめる
    """
    cursor = conn.cursor(dictionary=True)
    
    # まず、基準日（target_date）当日に作業実績があるかチェック
    cursor.execute("""
        SELECT COUNT(*) as cnt
        FROM unit_cleaning_logs
        WHERE worker_id = %s AND work_date = %s
    """, (worker_id, target_date.strftime("%Y/%m/%d")))
    today_work = cursor.fetchone()
    
    if not today_work or today_work['cnt'] == 0:
        cursor.close()
        return None  # 基準日に作業がない場合はスキップ
        
    # 直近1ヶ月（30日前からターゲット日まで）
    start_date = target_date - datetime.timedelta(days=30)
    
    # 1. 総清掃台数と総作業時間
    cursor.execute("""
        SELECT 
            SUM(clean_qty) as total_clean,
            SUM(air_clean_qty) as total_air,
            SUM(swap_qty) as total_swap,
            SUM(work_minutes) as total_minutes
        FROM unit_cleaning_logs
        WHERE worker_id = %s AND work_date BETWEEN %s AND %s
    """, (worker_id, start_date.strftime("%Y/%m/%d"), target_date.strftime("%Y/%m/%d")))
    work_summary = cursor.fetchone()
    
    # 2. 機種別の清掃台数と作業時間
    cursor.execute("""
        SELECT 
            model_name, 
            SUM(clean_qty) as clean_c, 
            SUM(air_clean_qty) as air_c, 
            SUM(swap_qty) as swap_c, 
            SUM(work_minutes) as total_time
        FROM unit_cleaning_logs
        WHERE worker_id = %s AND work_date BETWEEN %s AND %s
        GROUP BY model_name
        ORDER BY (SUM(clean_qty) + SUM(air_clean_qty) + SUM(swap_qty)) DESC
    """, (worker_id, start_date.strftime("%Y/%m/%d"), target_date.strftime("%Y/%m/%d")))
    model_summary = cursor.fetchall()
    
    cursor.close()
    
    # データの存在チェック
    # いずれかの作業実績が1件でもあればOK
    if not work_summary:
        return None
    
    total_clean = work_summary['total_clean'] or 0
    total_air = work_summary['total_air'] or 0
    total_swap = work_summary['total_swap'] or 0
    total_minutes = work_summary['total_minutes'] or 0
    
    total_all = total_clean + total_air + total_swap
    if total_all == 0:
        return None  # 作業データがない場合はNoneを返す
    
    # データを要約文に整形する
    hours = int(total_minutes // 60)
    mins = int(total_minutes % 60)
    time_str = f"{hours}時間{mins}分" if hours > 0 else f"{mins}分"
    
    summary_text = f"対象期間: {start_date.strftime('%Y-%m-%d')} 〜 {target_date.strftime('%Y-%m-%d')}\n"
    summary_text += f"総作業時間: {time_str}\n"
    summary_text += f"【全体の作業実績】 筐体清掃:{total_clean:,}台 / エアー清掃:{total_air:,}台 / 筐体交換:{total_swap:,}台\n\n"
    
    summary_text += "【機種別の作業実績】\n"
    for row in model_summary:
        m_name = row['model_name']
        c_clean = row['clean_c'] or 0
        c_air = row['air_c'] or 0
        c_swap = row['swap_c'] or 0
        t = row['total_time'] or 0
        
        t_hours = int(t // 60)
        t_mins = int(t % 60)
        t_str = f"{t_hours}時間{t_mins}分" if t_hours > 0 else f"{t_mins}分"
        
        summary_text += f"- {m_name} : (筐体清掃:{c_clean:,}台, エアー:{c_air:,}台, 交換:{c_swap:,}台) [作業時間:{t_str}]\n"
        
    return summary_text

def generate_ai_report(worker_name, ai_tone, data_summary):
    """
    Ollamaにデータを渡して個人別分析レポートを生成させる
    """
    # 口調設定によるプロンプトの出し分け
    if ai_tone == '関西弁':
        tone_instruction = "コテコテの関西弁で、親しみやすくツッコミも交えながら話しかけてください。"
    elif ai_tone == '熱血コーチ':
        tone_instruction = "松岡修造のような熱血スポーツコーチ風に、熱く励ましてください。"
    elif ai_tone == '執事':
        tone_instruction = "お嬢様・お坊ちゃまに仕える優秀な執事のように、極めて丁寧で恭しい言葉遣いで話しかけてください。"

    else:
        tone_instruction = "非常に優しく、温かみのある、ですます調のトーンにしてください。"

    prompt = PROMPT_TEMPLATE.format(worker_name=worker_name, tone_instruction=tone_instruction, data_summary=data_summary)
    
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False
    }
    
    headers = {
        'Connection': 'close'
    }
    
    try:
        # 接続(10秒)と読み取り(300秒)のタイムアウトを厳密に設定し、TCPハングを防ぐ
        response = requests.post(OLLAMA_URL, json=payload, headers=headers, timeout=(10.0, 300.0))
        response.raise_for_status()
        result = response.json()
        return result.get("response", "AIからの応答が空でした。")
    except requests.exceptions.Timeout:
        print(f"[{worker_name}] ⚠️ タイムアウト（AIの応答に5分以上かかりました）")
        return None
    except Exception as e:
        print(f"[{worker_name}] ⚠️ Ollama呼び出しエラー: {e}")
        return None

def save_report_to_db(conn, target_date, worker_id, worker_name, report_text):
    """
    生成したレポートを MariaDB に保存する (1人1レコードで上書き)
    """
    cursor = conn.cursor()
    
    date_str = target_date.strftime("%Y-%m-%d")
    
    # 既存のレコードがあれば更新、なければ挿入
    cursor.execute("SELECT id FROM t_ai_reports WHERE worker_id = %s", (worker_id,))
    existing = cursor.fetchone()
    
    if existing:
        cursor.execute("""
            UPDATE t_ai_reports 
            SET target_date = %s, worker_name = %s, report_content = %s, created_at = NOW() 
            WHERE worker_id = %s
        """, (date_str, worker_name, report_text, worker_id))
    else:
        cursor.execute("""
            INSERT INTO t_ai_reports (target_date, worker_id, worker_name, report_content) 
            VALUES (%s, %s, %s, %s)
        """, (date_str, worker_id, worker_name, report_text))
        
    conn.commit()
    cursor.close()

def main():
    print("--- Local AI Analysis System (個人別レポート生成) ---")
    
    # コマンドライン引数で日付指定があれば取得、なければ今日
    if len(sys.argv) > 1:
        try:
            target_date = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%d").date()
        except ValueError:
            print("日付フォーマットが不正です。YYYY-MM-DD形式で指定してください。")
            sys.exit(1)
    else:
        # デフォルトは前日（昨日の実績に対してレポートを作成する）
        target_date = datetime.date.today() - datetime.timedelta(days=1)
        
    print(f"基準日: {target_date} (直近1ヶ月のデータを集計)")
    
    # メインDBコネクションの確立
    conn = get_db_connection()
    
    members = fetch_all_members(conn)
    print(f"全メンバー {len(members)} 名の処理を開始します...\\n")
    
    success_count = 0
    skip_count = 0
    error_count = 0
    
    for member in members:
        w_id = member['worker_id']
        w_name = member['worker_name']
        a_tone = member['ai_tone']
        print(f"▶ {w_name} さん ({w_id}) の処理を開始... (口調: {a_tone})")
        
        # 1. データの抽出・整形
        data_summary = fetch_worker_data(conn, w_id, target_date)
        
        if not data_summary:
            print(f"  -> 直近1ヶ月の作業データがないためスキップします。")
            skip_count += 1
            continue
            
        import time
        start_time = time.time()
        
        # 2. AIによる分析レポート生成
        report_text = generate_ai_report(w_name, a_tone, data_summary)
        
        elapsed = time.time() - start_time
        
        if report_text:
            # 見出しを追加して少し整形
            final_report = f"【AI分析レポート】\n{report_text.strip()}"
            
            # 3. DBへ保存
            save_report_to_db(conn, target_date, w_id, w_name, final_report)
            print(f"  -> レポート生成＆保存完了！ (処理時間: {elapsed:.1f}秒)")
            success_count += 1
        else:
            print(f"  -> ⚠️ レポートの生成に失敗しました。 (処理時間: {elapsed:.1f}秒)")
            error_count += 1
            
        # サーバー（Ollama）の負荷を下げるために少し待機する
        import time
        time.sleep(3)
            
    # 全員の処理が終わったら、Flutterアプリ(UI)側を自動リロードさせるためのフラグを立てる
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1")
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"UI更新フラグの更新に失敗しました: {e}")
            
    print("\\n--- 全ての処理が完了しました ---")
    print(f"成功: {success_count} 名, スキップ(実績なし): {skip_count} 名, エラー: {error_count} 名")

if __name__ == "__main__":
    main()
