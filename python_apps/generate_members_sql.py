import csv
import os

CSV_PATH = r"C:\src\python\members.csv"
OUTPUT_SQL = r"C:\src\python\m_members_import.sql"
OUTPUT_SQL_SJIS = r"C:\src\python\m_members_import_sjis.sql"
OUTPUT_CLEAN_CSV = r"C:\src\python\m_members_import.csv"
OUTPUT_CLEAN_CSV_SJIS = r"C:\src\python\m_members_import_sjis.csv"

valid_members = []
skipped_members = []

with open(CSV_PATH, mode="r", encoding="utf-8-sig", errors="replace") as f:
    # 最初の数バイト等でのエンコーディングやセパレータ問題対策
    reader = csv.DictReader(f)
    for row in reader:
        # 社員番号、氏名を取り出し
        wid = str(row.get("社員番号", "")).strip()
        wname = str(row.get("氏名", "")).strip()
        
        if wid and wname:
            valid_members.append({"worker_id": wid, "worker_name": wname})
        elif wname:
            # 社員番号（ID）が空欄の方（マスタ登録時に不具合を招きやすいため分けて記録）
            skipped_members.append(f"氏名: {wname} (社員番号なし)")
        else:
            # 空行など
            pass

print(f"✅ ロード終了 - 有効メンバー: {len(valid_members)}名 / ID空白スキップ: {len(skipped_members)}名")
if skipped_members:
    print(f"⚠️ 以下の社員は「社員番号（ID）」が空欄だったため、結合エラー防止の目的で登録スキップとしています:\n   {skipped_members}")

# 1. きれいなCSVとして出力 (UTF-8, SJIS)
def save_csv(out_path, enc):
    with open(out_path, mode="w", newline="", encoding=enc, errors="replace") as f:
        writer = csv.DictWriter(f, fieldnames=["worker_id", "worker_name"])
        writer.writeheader()
        for r in valid_members:
            writer.writerow(r)
    print(f"📄 クリーンなCSV作成完遂: {out_path} ({enc})")

save_csv(OUTPUT_CLEAN_CSV, "utf-8-sig")
save_csv(OUTPUT_CLEAN_CSV_SJIS, "cp932")

# 2. SQLファイルとして出力
def save_sql(out_path, enc):
    with open(out_path, mode="w", encoding=enc, errors="replace") as f:
        f.write("-- MariaDB メンバー(社員マスタ) 自動投入SQLスクリプト\n")
        f.write("SET NAMES utf8mb4;\n\n")
        f.write("CREATE TABLE IF NOT EXISTS m_members (\n")
        f.write("    worker_id VARCHAR(50) PRIMARY KEY,\n")
        f.write("    worker_name VARCHAR(100)\n")
        f.write(") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n\n")
        
        f.write("INSERT IGNORE INTO m_members (worker_id, worker_name) VALUES\n")
        
        val_list = []
        for r in valid_members:
            wid_esc = r["worker_id"].replace("'", "''").replace("\\", "\\\\")
            wname_esc = r["worker_name"].replace("'", "''").replace("\\", "\\\\")
            val_list.append(f"('{wid_esc}', '{wname_esc}')")
            
        f.write(",\n".join(val_list) + ";\n")
        
    print(f"⚡ 確実・強力なSQLファイル作成完遂: {out_path} ({enc})")

save_sql(OUTPUT_SQL, "utf-8-sig")
save_sql(OUTPUT_SQL_SJIS, "cp932")

print("\n🚀 メンバーマスタの SQL 化があっさりと美しく完了しました！")
