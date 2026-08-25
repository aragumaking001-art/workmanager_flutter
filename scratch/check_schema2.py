import sqlite3
import pandas as pd

try:
    conn = sqlite3.connect('C:/src/python/work_data.db')
    
    print("--- m_members ---")
    df_mem = pd.read_sql_query("SELECT * FROM m_members LIMIT 1", conn)
    print(df_mem.columns.tolist())
    
    print("\n--- m_models ---")
    df_mod = pd.read_sql_query("SELECT * FROM m_models LIMIT 1", conn)
    print(df_mod.columns.tolist())
    
    conn.close()
except Exception as e:
    print(e)
