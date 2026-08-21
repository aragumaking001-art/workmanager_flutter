import sqlite3
import csv
import os

DB_PATH = r"C:\src\python\work_data_old.db"
CSV_PATH = r"C:\src\python\model_name.csv"

OUT_SQL_UTF8 = r"C:\src\python\unit_cleaning_logs_full_insert_utf8.sql"
OUT_SQL_SJIS = r"C:\src\python\unit_cleaning_logs_full_insert_sjis.sql"

# 1. model_name.csv から正確なマップ作成
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

print("[INFO] Empty maker_abbr model count:", len(empty_abbr_models))

# 2. SQLite の読み出し
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
for r in rows:
    model = str(r["model_name"] if r["model_name"] is not None else "").strip()
    maker = str(r["maker"] if r["maker"] is not None else "").strip()
    
    # B-100E (N) の美化: 完全に NEC と N へ！
    if "B-100" in model and ("(N)" in model or "（N）" in model or "N" in model or maker == "(N)" or maker == "N"):
        if "B-100" in model and ("N" in model or maker == "N" or maker == "NEC" or maker == "(N)"):
            model = "B-100E"
            maker = "NEC"
            maker_abbr = "N"
    # B-100E (S) の美化: 完全に 住友 と S へ！
    elif "B-100" in model and ("(S)" in model or "（S）" in model or "S" in model or maker == "(S)" or maker == "S" or maker == "住友"):
        if "B-100" in model and ("S" in model or maker == "S" or maker == "住友" or maker == "(S)"):
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
        # RX-600KI などの空欄であるべき機種は 1000% 空文字('') に統一！
        if model in empty_abbr_models or (model, maker) in empty_abbr_models or model.startswith("RX-600") or model.startswith("RT-500"):
            maker_abbr = ""
        elif (model, maker) in map_exact and isinstance(map_exact[(model, maker)], str):
            maker_abbr = map_exact[(model, maker)]
        elif model in map_exact and isinstance(map_exact[model], str):
            maker_abbr = map_exact[model]
        else:
            maker_abbr = ""
            
    # 怪しいゴミを完全粉砕
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

def format_value(val):
    if val is None:
        return "NULL"
    if isinstance(val, (int, float)):
        return str(val)
    esc = str(val).replace("'", "''").replace("\\", "\\\\")
    return f"'{esc}'"

def save_clean_sql(out_path, enc, use_set_names=True):
    # 日本語のコメントを一滴も入れない、世界最高のピュアな SQL
    with open(out_path, mode="w", encoding=enc, errors="replace", newline="\n") as f:
        if use_set_names:
            if enc == "cp932":
                f.write("SET NAMES sjis;\n")
            else:
                f.write("SET NAMES utf8mb4;\n")
        
        # テーブルを確実に「空(空っぽ)にする」究極お掃除指令
        f.write("TRUNCATE TABLE unit_cleaning_logs;\n\n")
        
        # 300件ずつバルク・インサートで超高速投入
        batch_size = 300
        for i in range(0, len(converted_rows), batch_size):
            chunk = converted_rows[i:i + batch_size]
            cols_str = ", ".join(target_columns)
            sql = f"INSERT INTO unit_cleaning_logs ({cols_str}) VALUES\n"
            val_strings = []
            for r in chunk:
                v_list = [format_value(r[c]) for c in target_columns]
                val_strings.append("(" + ", ".join(v_list) + ")")
            sql += ",\n".join(val_strings) + ";\n\n"
            f.write(sql)
    print(f"[SUCCESS] Clean SQL file generated: {out_path} (encoding={enc})")

save_clean_sql(OUT_SQL_UTF8, "utf-8")
save_clean_sql(OUT_SQL_SJIS, "cp932")
