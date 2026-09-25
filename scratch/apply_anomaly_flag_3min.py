import pymysql

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

    # Check target records count
    cur.execute("SELECT COUNT(*) as cnt FROM unit_cleaning_logs WHERE work_minutes < 3 AND anomaly_flag = 0")
    count_before = cur.fetchone()['cnt']
    print(f"Update target records (work_minutes < 3 and anomaly_flag = 0): {count_before} records")

    # Perform update
    cur.execute("""
        UPDATE unit_cleaning_logs 
        SET anomaly_flag = 1 
        WHERE work_minutes < 3 AND anomaly_flag = 0
    """)
    updated_rows = cur.rowcount
    conn.commit()
    print(f"Updated {updated_rows} records to anomaly_flag = 1")

    # Update data_update_tracker so Flutter clients reload
    cur.execute("UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1")
    conn.commit()
    print("Updated data_update_tracker successfully!")

    # Verify distribution of anomaly_flags
    cur.execute("SELECT anomaly_flag, COUNT(*) as cnt FROM unit_cleaning_logs GROUP BY anomaly_flag ORDER BY anomaly_flag ASC")
    flags = cur.fetchall()
    print("\n--- Current anomaly_flag distribution in DB ---")
    for f in flags:
        print(f"anomaly_flag = {f['anomaly_flag']}: {f['cnt']} records")

    conn.close()

if __name__ == '__main__':
    main()
