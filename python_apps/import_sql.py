import mysql.connector

def run():
    try:
        conn = mysql.connector.connect(host='192.168.10.101', user='work_user', password='work1234', database='work_manager_db')
        cursor = conn.cursor()
        
        with open(r"C:\src\python\unit_cleaning_logs_full_insert_utf8.sql", "r", encoding="utf8") as f:
            sql_file = f.read()

        sql_commands = sql_file.split(";")

        for command in sql_commands:
            if command.strip():
                print("Executing:", command.strip()[:50], "...")
                cursor.execute(command)

        conn.commit()
        print("Import completed successfully.")
        
    except Exception as e:
        print("Error:", e)
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals() and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    run()
