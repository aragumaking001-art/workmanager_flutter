import pymysql
import math
from datetime import datetime

def main():
    conn = pymysql.connect(
        host='192.168.10.101',
        port=3306,
        user='work_user',
        password='work1234',
        database='work_manager_db',
        charset='utf8mb4'
    )
    cur = conn.cursor(pymysql.cursors.DictCursor)

    # 1. 対象レコードの取得
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, maker_abbr,
               air_clean_qty, clean_qty, swap_qty,
               (air_clean_qty + clean_qty + swap_qty) as total_qty,
               work_minutes, std_qty, anomaly_flag
        FROM unit_cleaning_logs
        WHERE anomaly_flag = 0
    ''')
    rows = cur.fetchall()

    target_records = []
    for r in rows:
        work_min = r['work_minutes'] or 0
        std = r['std_qty'] or 10.0
        tot = r['total_qty'] or 0

        # 実作業時間(h) × 標準台数 × 5.0倍 (最低保証3台)
        limit = max(3, math.ceil((work_min / 60.0) * std * 5.0))
        if tot > limit:
            r['limit'] = limit
            target_records.append(r)

    print(f"検出件数: {len(target_records)} 件")
    for r in target_records:
        print(f"ID: {r['id']} | 日付: {r['work_date']} | 作業者: {r['worker_id']} | 機種: {r['model_name']} | 作業時間: {r['work_minutes']}分 | 実績: {r['total_qty']}台 (上限: {r['limit']}台, std: {r['std_qty']})")

    if not target_records:
        print("更新対象はありません。")
        conn.close()
        return

    # 2. anomaly_flag = 3 に更新
    target_ids = [r['id'] for r in target_records]
    placeholders = ', '.join(['%s'] * len(target_ids))
    sql = f"UPDATE unit_cleaning_logs SET anomaly_flag = 3 WHERE id IN ({placeholders})"
    cur.execute(sql, target_ids)
    conn.commit()
    print(f"✅ {len(target_ids)} 件のレコードを anomaly_flag = 3 に更新しました。")

    # 3. data_update_tracker を更新してFlutterアプリ等へ同期通知
    try:
        cur.execute("UPDATE data_update_tracker SET last_updated = %s WHERE id = 1", (datetime.now(),))
        conn.commit()
        print("✅ data_update_tracker を更新しました。")
    except Exception as e:
        print(f"tracker update error: {e}")

    conn.close()

if __name__ == '__main__':
    main()
