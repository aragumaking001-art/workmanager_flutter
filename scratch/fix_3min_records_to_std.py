import pymysql
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

    # 1. 作業時間3分のレコードを取得
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, maker_abbr,
               air_clean_qty, clean_qty, swap_qty,
               (air_clean_qty + clean_qty + swap_qty) as total_qty,
               work_minutes, std_qty, anomaly_flag, edit_count
        FROM unit_cleaning_logs
        WHERE work_minutes = 3
    ''')
    rows = cur.fetchall()
    print(f"対象件数: {len(rows)} 件")

    for r in rows:
        tot = r['total_qty'] or 0
        std = r['std_qty'] or 10.0
        calc_min = round((tot / std) * 60.0)
        if calc_min < 3:
            calc_min = 3

        print(f"更新前: ID={r['id']} {r['model_name']} 台数={tot} 作業時間={r['work_minutes']}分 std={std} flag={r['anomaly_flag']}")
        print(f"更新後: 作業時間={calc_min}分 flag=0 edit_count=1")

        cur.execute('''
            UPDATE unit_cleaning_logs
            SET work_minutes = %s,
                anomaly_flag = 0,
                edit_count = 1
            WHERE id = %s
        ''', (calc_min, r['id']))

    conn.commit()
    print("DB更新完了")

    # 2. data_update_tracker を更新
    cur.execute("UPDATE data_update_tracker SET last_updated = %s WHERE id = 1", (datetime.now(),))
    conn.commit()
    print("tracker更新完了")

    # 3. 更新後の確認
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, work_minutes, std_qty, anomaly_flag, edit_count
        FROM unit_cleaning_logs
        WHERE id IN (663, 1060)
    ''')
    print("--- 更新後レコード ---")
    for r in cur.fetchall():
        print(r)

    conn.close()

if __name__ == '__main__':
    main()
