import math

def evaluate_anomaly(work_minutes, total_units, std_qty, current_flag=0):
    # 1. Flutter側の判定ロジック
    work_hours = work_minutes / 60.0 if work_minutes > 0 else 7.0
    max_allowed = max(3, math.ceil(work_hours * std_qty * 5.0)) if std_qty > 0 else 9999
    
    is_under_3min = (current_flag == 1) or (0 < work_minutes < 3.0)
    is_over_12h = (current_flag == 2) or (work_minutes >= 720.0)
    # 修正後: is_under_3min のときは台数過大を抑止
    is_excessive_units = (not is_under_3min) and ((current_flag == 3) or (std_qty > 0 and total_units > max_allowed))
    
    badges = []
    if is_excessive_units:
        badges.append("⚠️ 台数過大")
    if is_under_3min:
        badges.append("⚠️ 3分未満")
    if is_over_12h:
        badges.append("🚨 12時間以上")
        
    estimations = []
    if is_excessive_units:
        estimations.append("清掃台数の入力間違い（桁間違い等）の可能性が高いです")
    if is_under_3min:
        estimations.append("作業開始タッチ（NFCカード）忘れの可能性が高いです")
    if is_over_12h:
        estimations.append("作業終了タッチ（NFCカード）忘れの可能性が高いです")

    # 2. 保存時 / フラグ判定ロジック (work_app.py / dashboard_workplace.py / data_edit_tab.dart)
    new_flag = 0
    if work_minutes < 3.0:
        new_flag = 1
    elif std_qty > 0 and total_units > max_allowed:
        new_flag = 3
    elif work_minutes >= 720.0:
        new_flag = 2
        
    return {
        "work_minutes": work_minutes,
        "total_units": total_units,
        "max_allowed": max_allowed,
        "new_flag": new_flag,
        "is_under_3min": is_under_3min,
        "is_excessive_units": is_excessive_units,
        "badges": badges,
        "estimations": estimations
    }

# テストケース1: 2分、50台完了（今回のリクエスト対象）
r1 = evaluate_anomaly(2.0, 50, 10.0)
print("=== ケース1: 2分 50台 ===")
print("新フラグ:", r1['new_flag'])
print("表示バッジ:", r1['badges'])
print("推定原因:", r1['estimations'])

# テストケース2: 1分、10台完了
r2 = evaluate_anomaly(1.0, 10, 10.0)
print("\n=== ケース2: 1分 10台 ===")
print("新フラグ:", r2['new_flag'])
print("表示バッジ:", r2['badges'])
print("推定原因:", r2['estimations'])

# テストケース3: 30分、200台完了（本来の台数過大）
r3 = evaluate_anomaly(30.0, 200, 10.0)
print("\n=== ケース3: 30分 200台 (通常作業での過大台数) ===")
print("新フラグ:", r3['new_flag'])
print("表示バッジ:", r3['badges'])
print("推定原因:", r3['estimations'])

# テストケース4: 30分、5台完了（正常）
r4 = evaluate_anomaly(30.0, 5, 10.0)
print("\n=== ケース4: 30分 5台 (正常) ===")
print("新フラグ:", r4['new_flag'])
print("表示バッジ:", r4['badges'])
print("推定原因:", r4['estimations'])
