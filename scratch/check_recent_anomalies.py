import pymysql

conn = pymysql.connect(
    host='192.168.10.101',
    port=3306,
    user='work_user',
    password='work1234',
    database='work_manager_db',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

with conn.cursor() as cur:
    cur.execute('''
        SELECT id, work_date, worker_id, model_name, air_clean_qty, clean_qty, swap_qty, 
               work_minutes, edit_count, anomaly_flag, created_at
        FROM unit_cleaning_logs
        ORDER BY id DESC LIMIT 10
    ''')
    for r in cur.fetchall():
        print(f"ID:{r['id']} Date:{r['work_date']} Worker:{r['worker_id']} Model:{r['model_name']} Mins:{r['work_minutes']} Flag:{r['anomaly_flag']} Created:{r.get('created_at')}")

    # Check total anomaly count in entire DB
    cur.execute("SELECT COUNT(*) as cnt FROM unit_cleaning_logs WHERE IFNULL(anomaly_flag, 0) != 0")
    print(f"\nTotal unprocessed anomaly count: {cur.fetchone()['cnt']}")
