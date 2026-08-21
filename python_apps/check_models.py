import mysql.connector

def run():
    try:
        conn = mysql.connector.connect(host='192.168.10.101', user='work_user', password='work1234', database='work_manager_db')
        cursor = conn.cursor(dictionary=True)
        
        check_sql = """
        SELECT DISTINCT u.model_name, u.maker, u.maker_abbr
        FROM unit_cleaning_logs u
        LEFT JOIN m_models m ON u.model_name = m.model_name AND u.maker = m.maker
        WHERE m.model_name IS NULL
        """
        cursor.execute(check_sql)
        unmatched = cursor.fetchall()
        
        print("\n--- Unmatched Models ---")
        for r in unmatched:
            print(f"Model: {r['model_name']}, Maker: {r['maker']}, Abbr: {r['maker_abbr']}")
        
        if not unmatched:
            print("No unmatched models found.")

    except Exception as e:
        print("Error:", e)
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    run()
