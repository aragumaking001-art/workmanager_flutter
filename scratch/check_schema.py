import sqlite3
conn = sqlite3.connect('C:\\src\\python\\work_data.db')
cursor = conn.cursor()
cursor.execute('SELECT name, sql FROM sqlite_master WHERE type="table"')
tables = cursor.fetchall()
for t in tables:
    print(t[0], ':', t[1])
conn.close()
