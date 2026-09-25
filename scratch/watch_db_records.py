import pymysql
import time

conn = pymysql.connect(
    host='192.168.10.101',
    port=3306,
    user='work_user',
    password='work1234',
    database='work_manager_db',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

print("Watching MariaDB for new records...")
last_id = 3903

with conn.cursor() as cur:
    cur.execute("SELECT MAX(id) as mid FROM unit_cleaning_logs")
    mid = cur.fetchone()['mid']
    if mid:
        last_id = mid
    print(f"Current MAX ID: {last_id}")

    cur.execute("SELECT COUNT(*) as cnt FROM unit_cleaning_logs WHERE IFNULL(anomaly_flag, 0) != 0")
    print(f"Current Anomaly Count: {cur.fetchone()['cnt']}")
