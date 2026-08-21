import mysql.connector
import datetime
conn = mysql.connector.connect(host='192.168.10.101', user='work_user', password='work1234', database='work_manager_db')
cursor = conn.cursor(dictionary=True)
cursor.execute("SELECT worker_name, created_at FROM t_ai_reports WHERE DATE(created_at) = CURDATE() ORDER BY created_at DESC LIMIT 5")
rows = cursor.fetchall()
for r in rows:
    print(f"[{r['worker_name']}] - Last Time: {r['created_at']}")
