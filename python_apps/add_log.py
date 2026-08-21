import os

file_path = r'c:\Users\yamada\.gemini\antigravity-ide\scratch\workmanager_flutter\python_apps\work_app.py'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "print(f\"DB Load Error (m_members): {e}. Fallback to CSV.\")" in line:
        new_lines.append("""            import traceback
            import sys
            import os
            try:
                log_path = os.path.join(os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__)), 'db_error.log')
                with open(log_path, 'w', encoding='utf-8') as f:
                    f.write(traceback.format_exc())
            except:
                pass
""")
    new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
