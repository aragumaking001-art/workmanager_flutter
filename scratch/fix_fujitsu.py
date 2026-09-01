import pymysql

def fix_fujitsu():
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
        SELECT id, work_date, model_name, maker_abbr, maker
        FROM unit_cleaning_logs
        WHERE work_date LIKE '2026/08/25%' AND maker_abbr = 'FA'
    """)
    records = cursor.fetchall()
    
    print(f"Found {len(records)} records with maker_abbr='FA' on 2026/08/25.")
    for r in records:
        print(f"ID: {r['id']}, Model: {r['model_name']}, Maker: {r['maker']}")
        
    update_count = 0
    for r in records:
        if r['maker'] != '富士通':
            cursor.execute("UPDATE unit_cleaning_logs SET maker = '富士通' WHERE id = %s", (r['id'],))
            update_count += 1
            
    conn.commit()
    print(f"Successfully updated {update_count} records to '富士通'.")
    
    conn.close()

if __name__ == "__main__":
    fix_fujitsu()
