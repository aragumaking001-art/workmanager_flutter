import sys

filepath = r'C:\src\python\dashboard_workplace.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                # --- 💡 アクティブセッション(稼働状況)の同期 ---
                try:
                    sl_cur.execute("SELECT worker_id, start_time, is_paused, paused_at FROM active_sessions")
                    active_rows = sl_cur.fetchall()
                    if active_rows:
                        replace_sql = """
                            REPLACE INTO t_active_workers (worker_id, start_time, is_paused, paused_at, last_update)
                            VALUES (%s, %s, %s, %s, NOW())
                        """
                        for r in active_rows:
                            my_cur.execute(replace_sql, (r["worker_id"], r["start_time"], r["is_paused"], r["paused_at"]))
                        my_conn.commit()
                except Exception as ex:'''

replacement = '''                # --- 💡 アクティブセッション(稼働状況)の同期 ---
                try:
                    sl_cur.execute("SELECT worker_id, start_time, is_paused, paused_at FROM active_sessions")
                    active_rows = sl_cur.fetchall()
                    if active_rows:
                        active_ids = [r["worker_id"] for r in active_rows]
                        format_strings = ','.join(['%s'] * len(active_ids))
                        delete_sql = f"DELETE FROM t_active_workers WHERE worker_id NOT IN ({format_strings})"
                        my_cur.execute(delete_sql, tuple(active_ids))
                        
                        replace_sql = """
                            REPLACE INTO t_active_workers (worker_id, start_time, is_paused, paused_at, last_update)
                            VALUES (%s, %s, %s, %s, NULL)
                        """
                        for r in active_rows:
                            my_cur.execute(replace_sql, (r["worker_id"], r["start_time"], r["is_paused"], r["paused_at"]))
                    else:
                        my_cur.execute("DELETE FROM t_active_workers")
                        
                    my_conn.commit()
                except Exception as ex:'''

if target in content:
    content = content.replace(target, replacement)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Replacement successful.')
else:
    print('Target not found.')
