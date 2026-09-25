import pymysql
import sys

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

    # 1. Total records
    cur.execute("SELECT COUNT(*) as total FROM unit_cleaning_logs")
    total = cur.fetchone()['total']

    # 2. Distribution up to 10 minutes
    cur.execute('''
        SELECT work_minutes, COUNT(*) as cnt 
        FROM unit_cleaning_logs 
        WHERE work_minutes <= 10 
        GROUP BY work_minutes 
        ORDER BY work_minutes ASC
    ''')
    dist = cur.fetchall()

    # 3. Work minutes < 3 (i.e. 0, 1, 2)
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, maker, air_clean_qty, clean_qty, swap_qty, 
               start_time_str, end_time_str, work_minutes, anomaly_flag, edit_count
        FROM unit_cleaning_logs
        WHERE work_minutes < 3
        ORDER BY id DESC
    ''')
    records_under_3 = cur.fetchall()

    # 4. Work minutes == 3
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, maker, air_clean_qty, clean_qty, swap_qty, 
               start_time_str, end_time_str, work_minutes, anomaly_flag, edit_count
        FROM unit_cleaning_logs
        WHERE work_minutes = 3
        ORDER BY id DESC
    ''')
    records_3 = cur.fetchall()

    with open('scratch/short_work_report.txt', 'w', encoding='utf-8') as f:
        f.write(f"総レコード数: {total} 件\n\n")
        f.write("=== 作業時間 (work_minutes) 10分以下の件数分布 ===\n")
        for r in dist:
            f.write(f"  {r['work_minutes']:>2} 分: {r['cnt']:>4} 件\n")
        
        f.write(f"\n=== 3分未満 (work_minutes < 3: 0分, 1分, 2分) のデータ全件: 合計 {len(records_under_3)} 件 ===\n")
        for r in records_under_3:
            total_qty = (r['air_clean_qty'] or 0) + (r['clean_qty'] or 0) + (r['swap_qty'] or 0)
            f.write(f"ID:{r['id']:<5} 日付:{r['work_date']} 作業者:{r['worker_id']:<15} 機種:{r['model_name']:<18} "
                    f"台数:{total_qty:>3} (A:{r['air_clean_qty'] or 0}/C:{r['clean_qty'] or 0}/S:{r['swap_qty'] or 0}) "
                    f"時間:{r['work_minutes']:>2}分 ({r['start_time_str']}~{r['end_time_str']}) "
                    f"フラグ:{r['anomaly_flag']} 修正:{r['edit_count']}\n")

        f.write(f"\n=== ちょうど3分 (work_minutes = 3) のデータ: 合計 {len(records_3)} 件 (最新20件) ===\n")
        for r in records_3[:20]:
            total_qty = (r['air_clean_qty'] or 0) + (r['clean_qty'] or 0) + (r['swap_qty'] or 0)
            f.write(f"ID:{r['id']:<5} 日付:{r['work_date']} 作業者:{r['worker_id']:<15} 機種:{r['model_name']:<18} "
                    f"台数:{total_qty:>3} (A:{r['air_clean_qty'] or 0}/C:{r['clean_qty'] or 0}/S:{r['swap_qty'] or 0}) "
                    f"時間:{r['work_minutes']:>2}分 ({r['start_time_str']}~{r['end_time_str']}) "
                    f"フラグ:{r['anomaly_flag']} 修正:{r['edit_count']}\n")

    print(f"Report written to scratch/short_work_report.txt successfully! Total under 3 min: {len(records_under_3)} records.")
    conn.close()

if __name__ == '__main__':
    main()
