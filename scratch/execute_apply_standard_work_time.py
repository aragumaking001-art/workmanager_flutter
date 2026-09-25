import pymysql

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

    # 1. 変更対象レコードの取得
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, maker, maker_abbr,
               air_clean_qty, clean_qty, swap_qty, std_qty,
               work_minutes, edit_count, anomaly_flag
        FROM unit_cleaning_logs
        WHERE anomaly_flag != 0
        ORDER BY id ASC
    ''')
    anomaly_logs = cur.fetchall()
    
    target_logs = []
    skipped_logs = []
    
    for r in anomaly_logs:
        a = r['air_clean_qty'] or 0
        c = r['clean_qty'] or 0
        s = r['swap_qty'] or 0
        total_qty = a + c + s
        if total_qty > 0:
            target_logs.append(r)
        else:
            skipped_logs.append(r)
            
    print(f"Total anomaly logs: {len(anomaly_logs)}")
    print(f"Target logs (qty > 0): {len(target_logs)}")
    print(f"Skipped logs (qty == 0): {len(skipped_logs)}")
    for s in skipped_logs:
        print(f"  Skipped ID: {s['id']}, Model: {s['model_name']}, Date: {s['work_date']}")

    # 2. 更新の実行
    updated_count = 0
    for r in target_logs:
        a = r['air_clean_qty'] or 0
        c = r['clean_qty'] or 0
        s = r['swap_qty'] or 0
        total_qty = a + c + s
        std = r['std_qty'] or 10.0
        
        # 標準時間の計算: round((total_qty / std_qty) * 60)
        calc_min = round((total_qty / std) * 60.0)
        if calc_min < 3:
            calc_min = 3
            
        cur.execute('''
            UPDATE unit_cleaning_logs
            SET work_minutes = %s,
                anomaly_flag = 0,
                edit_count = 1
            WHERE id = %s
        ''', (calc_min, r['id']))
        updated_count += 1

    conn.commit()
    print(f"\nSuccessfully updated {updated_count} records!")

    # 3. data_update_tracker の更新
    cur.execute("UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1")
    conn.commit()
    print("data_update_tracker updated successfully!")

    # 4. 更新後の検証
    cur.execute('''
        SELECT anomaly_flag, COUNT(*) as cnt 
        FROM unit_cleaning_logs 
        GROUP BY anomaly_flag 
        ORDER BY anomaly_flag ASC
    ''')
    print("\n--- anomaly_flag distribution ---")
    for f in cur.fetchall():
        print(f"  anomaly_flag = {f['anomaly_flag']}: {f['cnt']} records")

    cur.execute('''
        SELECT id, work_date, worker_id, model_name, 
               air_clean_qty, clean_qty, swap_qty, std_qty,
               work_minutes, edit_count, anomaly_flag
        FROM unit_cleaning_logs
        WHERE id IN (57, 93, 217, 410, 2961)
        ORDER BY id ASC
    ''')
    print("\n--- Sample updated records ---")
    for r in cur.fetchall():
        print(f"  ID:{r['id']} {r['work_date']} {r['model_name']} 時間:{r['work_minutes']}分 修正:{r['edit_count']} flag:{r['anomaly_flag']}")

    cur.execute('''
        SELECT id, work_date, worker_id, model_name, 
               air_clean_qty, clean_qty, swap_qty, std_qty,
               work_minutes, edit_count, anomaly_flag
        FROM unit_cleaning_logs
        WHERE anomaly_flag != 0
    ''')
    print("\n--- Remaining anomaly records ---")
    for r in cur.fetchall():
        print(f"  ID:{r['id']} {r['work_date']} {r['model_name']} 台数:0 時間:{r['work_minutes']}分 修正:{r['edit_count']} flag:{r['anomaly_flag']}")

    conn.close()

if __name__ == '__main__':
    main()
