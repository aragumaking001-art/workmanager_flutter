import pymysql
import math

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

    cur.execute('''
        SELECT l.id, l.work_date, l.worker_id, l.model_name, l.maker, l.maker_abbr,
               l.air_clean_qty, l.clean_qty, l.swap_qty, l.std_qty,
               l.start_time_str, l.end_time_str, l.work_minutes, l.anomaly_flag
        FROM unit_cleaning_logs l
        WHERE l.anomaly_flag != 0
        ORDER BY l.id ASC
    ''')
    logs = cur.fetchall()

    print(f"Total anomaly logs: {len(logs)}")
    
    with open('scratch/simulate_standard_time_report.txt', 'w', encoding='utf-8') as f:
        f.write("ID    日付       作業者            機種               台数(A/C/S)      現在時間  標準台数/h  計算標準時間(分)  新flag\n")
        f.write("-" * 110 + "\n")
        
        for r in logs:
            a = r['air_clean_qty'] or 0
            c = r['clean_qty'] or 0
            s = r['swap_qty'] or 0
            total_qty = a + c + s
            std = r['std_qty'] or 10.0
            
            if total_qty == 0:
                f.write(f"{r['id']:<5} {r['work_date']} {r['worker_id']:<15} {r['model_name']:<18} 0台              {r['work_minutes']}分     {std:<10} (台数0のため対象外/維持)\n")
                continue
                
            # 標準時間の計算: (台数 / 標準台数) * 60分
            raw_min = (total_qty / std) * 60.0
            calc_min = round(raw_min)
            # 最低でも3分以上（台数があれば）
            if calc_min < 3:
                calc_min = 3
                
            new_flag = 0
            if total_qty >= 1001:
                new_flag = 3
            elif calc_min < 3:
                new_flag = 1
            elif calc_min >= 720:
                new_flag = 2
                
            f.write(f"{r['id']:<5} {r['work_date']} {r['worker_id']:<15} {r['model_name']:<18} "
                    f"{total_qty:>3}台(A:{a}/C:{c}/S:{s})   {r['work_minutes']:>2}分 ->  "
                    f"{std:>4.1f}台/h ->  {calc_min:>4}分 ({raw_min:.1f}分)   flag:{new_flag}\n")

    print("Simulation report written to scratch/simulate_standard_time_report.txt")
    conn.close()

if __name__ == '__main__':
    main()
