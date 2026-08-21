import sqlite3
import pandas as pd
import os

try:
    members = {}
    df_members = None
    conn = sqlite3.connect('C:/src/python/work_data.db')
    df_members = pd.read_sql_query("SELECT * FROM m_members", conn)
    conn.close()
    print(f"Read from DB: {len(df_members)} records")
    
    if df_members is not None and not df_members.empty:
        id_col = next((c for c in ['社員番号', '従業員ID', 'worker_id', 'id'] if c in df_members.columns), None)
        print(f"id_col identified as: {id_col}")
        if id_col:
            for _, row in df_members.iterrows():
                m_id = str(row[id_col]).strip()
                name_col = '氏名' if '氏名' in df_members.columns else ('name' if 'name' in df_members.columns else df_members.columns[1])
                members[m_id] = str(row[name_col]).strip()
            
    print(f"Loaded members from DB: {len(members)} members")
    for i, (k, v) in enumerate(members.items()):
        print(f"ID: {k}, Name: {v}")
        if i >= 2: break
except Exception as e:
    import traceback
    traceback.print_exc()
