import csv
import os

CSV_PATH = r"C:\src\python\model_name.csv"
OUTPUT_SQL = r"C:\src\python\m_models_import.sql"
OUTPUT_SQL_SJIS = r"C:\src\python\m_models_import_sjis.sql"
OUTPUT_CLEAN_CSV = r"C:\src\python\m_models_import.csv"
OUTPUT_CLEAN_CSV_SJIS = r"C:\src\python\m_models_import_sjis.csv"

rows = []

with open(CSV_PATH, mode="r", encoding="utf-8-sig", errors="replace") as f:
    reader = csv.DictReader(f)
    for row in reader:
        # ヘッダー: 機種番号,機種名,メーカー,メーカー略称,分類,作業内容,1時間標準作業台数,ID
        mid = str(row.get("機種番号", "")).strip()
        mname = str(row.get("機種名", "")).strip()
        maker = str(row.get("メーカー", "")).strip()
        abbr = str(row.get("メーカー略称", "")).strip()
        cat = str(row.get("分類", "")).strip()
        wtype = str(row.get("作業内容", "")).strip()
        std = str(row.get("1時間標準作業台数", "")).strip()
        cid = str(row.get("ID", "")).strip()
        
        # 💡 先ほど同様、万一マスター自体に B-100E(N/S) 等が残っていた場合のクレンジング保険！
        if "B-100E" in mname and ("(N)" in mname or "（N）" in mname or maker == "(N)"):
            mname = "B-100E"
            maker = "NEC"
            abbr = "N"
        elif "B-100E" in mname and ("(S)" in mname or "（S）" in mname or maker == "(S)"):
            mname = "B-100E"
            maker = "住友"
            abbr = "S"
            
        try:
            std_f = float(std) if std != "" else 0.0
        except ValueError:
            std_f = 0.0

        rows.append({
            "model_id": mid,
            "model_name": mname,
            "maker": maker,
            "maker_abbr": abbr,
            "category": cat,
            "work_type": wtype,
            "std_qty": std_f,
            "csv_id": cid
        })

print(f"✅ 機種マスター (model_name.csv) ロード＆整合チェック完遂: 計 {len(rows)} 件")

target_cols = ["model_id", "model_name", "maker", "maker_abbr", "category", "work_type", "std_qty", "csv_id"]

# 1. きれいなCSVを書き出す
def save_csv(out_path, enc):
    with open(out_path, mode="w", newline="", encoding=enc, errors="replace") as f:
        writer = csv.DictWriter(f, fieldnames=target_cols)
        writer.writeheader()
        for r in rows:
            writer.writerow(r)
    print(f"📄 クリーンな機種CSV作成完了: {out_path} ({enc})")

save_csv(OUTPUT_CLEAN_CSV, "utf-8-sig")
save_csv(OUTPUT_CLEAN_CSV_SJIS, "cp932")

# 2. 安全無敵の SQLファイルを書く
def format_val(val, col):
    if col == "std_qty":
        return str(val)
    if val is None or val == "":
        return "''" if col != "csv_id" else "NULL"
    esc = str(val).replace("'", "''").replace("\\", "\\\\")
    return f"'{esc}'"

def save_sql(out_path, enc):
    with open(out_path, mode="w", encoding=enc, errors="replace") as f:
        f.write("-- MariaDB 機種マスタ(m_models) 自動一括投入SQLスクリプト\n")
        f.write("SET NAMES utf8mb4;\n\n")
        f.write("CREATE TABLE IF NOT EXISTS m_models (\n")
        f.write("    model_id VARCHAR(50),\n")
        f.write("    model_name VARCHAR(255),\n")
        f.write("    maker VARCHAR(100),\n")
        f.write("    maker_abbr VARCHAR(50),\n")
        f.write("    category VARCHAR(100),\n")
        f.write("    work_type VARCHAR(100),\n")
        f.write("    std_qty DOUBLE,\n")
        f.write("    csv_id VARCHAR(50)\n")
        f.write(") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n\n")
        
        # 300件ずつ一括挿入
        batch_size = 300
        for i in range(0, len(rows), batch_size):
            chunk = rows[i:i + batch_size]
            cols_str = ", ".join(target_cols)
            sql = f"INSERT IGNORE INTO m_models ({cols_str}) VALUES\n"
            val_strings = []
            for r in chunk:
                v_list = [format_val(r.get(c), c) for c in target_cols]
                val_strings.append("(" + ", ".join(v_list) + ")")
            sql += ",\n".join(val_strings) + ";\n\n"
            f.write(sql)
            
    print(f"⚡ 確実無比な SQL ファイル作成完遂: {out_path} ({enc})")

save_sql(OUTPUT_SQL, "utf-8-sig")
save_sql(OUTPUT_SQL_SJIS, "cp932")

print("\n🚀 機種マスタ(m_models)の全ファイル生成が大成功で終了しました！")
