import mysql.connector

def run():
    try:
        conn = mysql.connector.connect(host='192.168.10.101', user='work_user', password='work1234', database='work_manager_db')
        cursor = conn.cursor()
        
        sql = """
        UPDATE unit_cleaning_logs 
        SET model_name = 'V-ONU MK E', maker_abbr = '' 
        WHERE model_name = 'V-ONU MK' AND maker = 'PMC' AND maker_abbr = 'E';
        """
        print("Executing update...")
        cursor.execute(sql)
        conn.commit()
        print(f"Update completed successfully. Rows affected: {cursor.rowcount}")
        
    except Exception as e:
        print("Error:", e)
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    run()
