import sqlite3
import csv
import os

DB_PATH = r"C:\src\python\work_data_old.db"
CSV_PATH = r"C:\src\python\model_name.csv"

OUTPUT_CSV = r"C:\src\python\mariadb_import_logs.csv"
OUTPUT_CSV_SJIS = r"C:\src\python\mariadb_import_logs_sjis.csv"
OUTPUT_SQL = r"C:\src\python\mariadb_import_logs.sql"
OUTPUT_SQL_SJIS = r"C:\src\python\mariadb_import_logs_sjis.sql"
OUTPUT_CLEAN_SQL = r"C:\src\python\mariadb_clean_empty_abbr.sql"

# 1. model_name.csv から厳正なマップを作成 (空欄は絶対に空欄として維持する守護神のリスト)
map_exact = {}
empty_abbr_models = set()

encodings = ["utf-8-sig", "cp932", "shift_jis", "utf-8"]
for enc in encodings:
    try:
        if os.path.exists(CSV_PATH):
            with open(CSV_PATH, mode="r", encoding=enc) as f:
                reader = csv.reader(f)
                headers = next(reader)
                for row in reader:
                    if len(row) >= 4:
                        model = str(row[1]).strip()
                        maker = str(row[2]).strip()
                        abbr = str(row[3]).strip()
                        
                        if model:
                            map_exact[(model, maker)] = abbr
                            map_exact[model] = abbr
                            if abbr == "":
                                empty_abbr_models.add(model)
            break
    except Exception:
        continue

print(f"[OK] マスターロード成功。略称が元々空欄である機種の数: 計 {len(empty_abbr_models)} 機種")

# 2. SQLite の読み込み
conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()
cursor.execute("SELECT * FROM unit_cleaning_logs ORDER BY id ASC")
rows = cursor.fetchall()

target_columns = [
    "id", "location", "work_date", "worker_id", "model_name",
    "maker", "maker_abbr", "category", "air_clean_qty",
    "to_clean_qty", "clean_qty", "to_swap_qty", "swap_qty",
    "start_time_str", "end_time_str", "work_minutes",
    "created_at", "sync_flag", "std_qty", "lucky_flag",
    "edit_count", "reserve_3", "reserve_4", "reserve_5"
]

converted_rows = []
fixed_empty_count = 0

for r in rows:
    model = str(r["model_name"] if r["model_name"] is not None else "").strip()
    maker = str(r["maker"] if r["maker"] is not None else "").strip()
    
    if "B-100E" in model and ("(N)" in model or "（N）" in model or maker == "(N)" or maker == "（N）"):
        model = "B-100E"
        maker = "NEC"
        maker_abbr = "N"
    elif "B-100E" in model and ("(S)" in model or "（S）" in model or maker == "(S)" or maker == "（S）"):
        model = "B-100E"
        maker = "住友"
        maker_abbr = "S"
    elif "(N)" in model:
        model = model.replace("(N)", "").replace("（N）", "").strip()
        maker = "NEC"
        maker_abbr = "N"
    elif "(S)" in model:
        model = model.replace("(S)", "").replace("（S）", "").strip()
        maker = "住友"
        maker_abbr = "S"
    else:
        # マスター側で「空欄(なし)」と定義されていた機種(RX-600KI等)は、
        # 決して推測せず確実に「空文字('')」を守り通す！
        if model in empty_abbr_models or (model, maker) in empty_abbr_models:
            maker_abbr = ""
            fixed_empty_count += 1
        elif (model, maker) in map_exact and isinstance(map_exact[(model, maker)], str):
            maker_abbr = map_exact[(model, maker)]
        elif model in map_exact and isinstance(map_exact[model], str):
            maker_abbr = map_exact[model]
        else:
            maker_abbr = ""
            
    # さらに '(0)' や '0' 等の誤記が混じり込んできても粉砕
    if maker_abbr in ("(0)", "0", "nan", "None", "NULL"):
        maker_abbr = ""
        
    record = {
        "id": r["id"],
        "location": "A",
        "work_date": r["work_date"],
        "worker_id": r["worker_id"],
        "model_name": model,
        "maker": maker,
        "maker_abbr": maker_abbr,
        "category": r["category"],
        "air_clean_qty": r["air_clean_qty"],
        "to_clean_qty": r["to_clean_qty"],
        "clean_qty": r["clean_qty"],
        "to_swap_qty": r["to_swap_qty"],
        "swap_qty": r["swap_qty"],
        "start_time_str": r["start_time_str"],
        "end_time_str": r["end_time_str"],
        "work_minutes": r["work_minutes"],
        "created_at": r["created_at"],
        "sync_flag": r["sync_flag"] if r["sync_flag"] is not None else 0,
        "std_qty": r["std_qty"],
        "lucky_flag": r["lucky_flag"],
        "edit_count": 0,
        "reserve_3": r["reserve_3"] if "reserve_3" in r.keys() else None,
        "reserve_4": r["reserve_4"] if "reserve_4" in r.keys() else None,
        "reserve_5": r["reserve_5"] if "reserve_5" in r.keys() else None,
    }
    converted_rows.append(record)

print(f"[SUCCESS] RX-600KI 等のログを純白の空欄へと正常防御した件数: 計 {fixed_empty_count} レコード")

def save_csv(out_path, enc):
    with open(out_path, mode="w", newline="", encoding=enc, errors="replace") as f:
        writer = csv.DictWriter(f, fieldnames=target_columns)
        writer.writeheader()
        for r in converted_rows:
            writer.writerow(r)
    print(f"[OK] クリーンなログCSV出力完了: {out_path} ({enc})")

save_csv(OUTPUT_CSV, "utf-8-sig")
save_csv(OUTPUT_CSV_SJIS, "cp932")

def format_value(val):
    if val is None:
        return "NULL"
    if isinstance(val, (int, float)):
        return str(val)
    esc = str(val).replace("'", "''").replace("\\", "\\\\")
    return f"'{esc}'"

def save_sql(out_path, enc):
    with open(out_path, mode="w", encoding=enc, errors="replace") as f:
        f.write("-- MariaDB 過去実績(unit_cleaning_logs) 正常空欄維持・修復済みインポートSQL\n")
        f.write("SET NAMES utf8mb4;\n\n")
        
        batch_size = 300
        for i in range(0, len(converted_rows), batch_size):
            chunk = converted_rows[i:i + batch_size]
            cols_str = ", ".join(target_columns)
            sql = f"INSERT IGNORE INTO unit_cleaning_logs ({cols_str}) VALUES\n"
            val_strings = []
            for r in chunk:
                v_list = [format_value(r[c]) for c in target_columns]
                val_strings.append("(" + ", ".join(v_list) + ")")
            sql += ",\n".join(val_strings) + ";\n\n"
            f.write(sql)
    print(f"[OK] 修正済 SQLファイル書き出し完遂: {out_path} ({enc})")

save_sql(OUTPUT_SQL, "utf-8")
save_sql(OUTPUT_SQL_SJIS, "cp932")

# 3. 既にデータベースへインポート済みだった場合の「お掃除一括リセットSQL」
with open(OUTPUT_CLEAN_SQL, mode="w", encoding="utf-8") as f:
    f.write("-- 【 MariaDB 機種マスタ及び実績ログの空欄誤入力 (0) 一括クリーンナップ SQL 】\n")
    f.write("SET NAMES utf8mb4;\n\n")
    f.write("-- 1. 機種マスタ(m_models) で (0) や 0、あるいは RX-600 等の誤記を空欄(' ')にクリア\n")
    f.write("UPDATE m_models SET maker_abbr = '' WHERE maker_abbr IN ('(0)', '0', 'nan', 'None', 'NULL') OR model_name LIKE 'RX-600%' OR model_name LIKE 'RT-500%' OR model_name LIKE 'XG-100%';\n\n")
    f.write("-- 2. 実績ログ(unit_cleaning_logs) のメーカー略称も、同じく空文字へと修復\n")
    f.write("UPDATE unit_cleaning_logs SET maker_abbr = '' WHERE maker_abbr IN ('(0)', '0', 'nan', 'None', 'NULL');\n")
    for m in sorted(list(empty_abbr_models)):
        esc_m = m.replace("'", "''")
        f.write(f"UPDATE unit_cleaning_logs SET maker_abbr = '' WHERE model_name = '{esc_m}' AND maker_abbr != '';\n")

print(f"[COMPLETE] 既存データベース用・修復SQLの自動生成完了: {OUTPUT_CLEAN_SQL}")
