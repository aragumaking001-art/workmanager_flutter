import sqlite3
import pandas as pd
import mysql.connector

try:
    print("Connecting to MariaDB...")
    conn = mysql.connector.connect(
        host="192.168.10.101",
        user="work_user",
        password="work1234",
        database="work_manager_db",
        charset="utf8mb4",
        connection_timeout=5
    )
    print("Connected.")
    
    df_m_members = pd.read_sql_query("SELECT * FROM m_members", conn)
    print(f"Loaded {len(df_m_members)} members from MariaDB.")
    
    conn_sl = sqlite3.connect("work_data.db", timeout=10.0)
    df_m_members.to_sql("m_members", conn_sl, if_exists="replace", index=False)
    conn_sl.close()
    conn.close()
    print("Saved to work_data.db successfully.")
    
except Exception as e:
    print(f"Error: {e}")
