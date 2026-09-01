import pymysql

def fix_makers():
    conn = pymysql.connect(
        host='192.168.10.101',
        port=3306,
        user='work_user',
        password='work1234',
        database='work_manager_db',
        charset='utf8mb4'
    )
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    
    # Check affected records
    cursor.execute("""
        SELECT id, work_date, model_name, maker
        FROM unit_cleaning_logs
        WHERE work_date LIKE '2026/08/25%' AND maker = '不明'
    """)
    records = cursor.fetchall()
    
    print(f"Found {len(records)} records with maker='不明' on 2026/08/25.")
    
    # Get master data
    cursor.execute("SELECT model_name, maker FROM m_models")
    masters = cursor.fetchall()
    maker_map = {m['model_name']: m['maker'] for m in masters if m['maker'] and m['maker'] != '不明'}
    
    update_count = 0
    for r in records:
        correct_maker = maker_map.get(r['model_name'])
        if correct_maker:
            print(f"Updating ID {r['id']} ({r['model_name']}): '不明' -> '{correct_maker}'")
            cursor.execute("UPDATE unit_cleaning_logs SET maker = %s WHERE id = %s", (correct_maker, r['id']))
            update_count += 1
        else:
            print(f"Could not find correct maker for {r['model_name']} in master.")
            
    conn.commit()
    print(f"Successfully updated {update_count} records.")
    
    conn.close()

if __name__ == "__main__":
    fix_makers()
