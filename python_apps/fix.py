import os

file_path = r'c:\Users\yamada\.gemini\antigravity-ide\scratch\workmanager_flutter\python_apps\work_app.py'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if "df_members = None" in line and "target_val = row.get(" in lines[i-1]:
        skip = True
        new_lines.append("                    std_qty = float(target_val) if pd.notnull(target_val) else 10.0\n")
    if skip:
        if "Fallback to CSV" in line:
            skip = False
        continue
    new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
