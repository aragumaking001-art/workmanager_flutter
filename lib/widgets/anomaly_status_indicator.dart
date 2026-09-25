import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/data_provider.dart';

// ======================================================================
// 💡 共通で使えるオンライン・オフライン＋異常フラグ監視インジケーターUI
// ======================================================================
class ConnectionStatusIndicator extends StatelessWidget {
  final bool showAnomaly;
  const ConnectionStatusIndicator({super.key, this.showAnomaly = true});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final bool isOnline = data.isOnline;
    final bool isWhite = data.displayMode == DisplayMode.pureWhite;

    final Color activeColor = isOnline
        ? (isWhite ? const Color(0xFF008844) : Colors.greenAccent)
        : (isWhite ? const Color(0xFFCC0033) : Colors.redAccent);

    final onlineWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isWhite
            ? activeColor.withOpacity(0.12)
            : activeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withOpacity(isWhite ? 0.8 : 0.6),
          width: isWhite ? 2.0 : 1.5,
        ),
        boxShadow: isWhite
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: activeColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? "Online" : "Offline",
            style: TextStyle(
              color: activeColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );

    if (!showAnomaly) return onlineWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AnomalyStatusBadge(),
        const SizedBox(width: 10),
        onlineWidget,
      ],
    );
  }
}

// ======================================================================
// ⚠️ 異常フラグ常時監視バッジ（Online表示の隣に配置するインジケーター）
// ======================================================================
class AnomalyStatusBadge extends StatelessWidget {
  const AnomalyStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final int count = data.anomalyCount;
    final bool isWhite = data.displayMode == DisplayMode.pureWhite;

    // 異常件数に応じたテーマカラー
    final bool hasAnomaly = count > 0;
    final Color badgeColor = hasAnomaly
        ? (isWhite ? const Color(0xFFD97706) : const Color(0xFFFFB300)) // Amber / Orange
        : (isWhite ? const Color(0xFF059669) : const Color(0xFF34D399)); // Emerald Green

    final Color bgColor = hasAnomaly
        ? (isWhite ? const Color(0xFFFFFBEB) : const Color(0xFFFFB300).withOpacity(0.18))
        : (isWhite ? const Color(0xFFECFDF5) : const Color(0xFF34D399).withOpacity(0.15));

    final Color borderColor = hasAnomaly
        ? (isWhite ? const Color(0xFFF59E0B) : const Color(0xFFFFB300).withOpacity(0.7))
        : (isWhite ? const Color(0xFF10B981).withOpacity(0.6) : const Color(0xFF34D399).withOpacity(0.5));

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => const AnomalyLogsDialog(),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isWhite ? 2.0 : 1.5,
          ),
          boxShadow: [
            if (hasAnomaly)
              BoxShadow(
                color: (isWhite ? const Color(0xFFD97706) : Colors.orangeAccent).withOpacity(isWhite ? 0.15 : 0.25),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 1),
              )
            else if (isWhite)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnomaly ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: badgeColor,
              size: 19,
            ),
            const SizedBox(width: 7),
            Text(
              hasAnomaly ? "異常 $count件" : "異常なし",
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 📋 異常データ一覧ダイアログ
// ======================================================================
class AnomalyLogsDialog extends StatelessWidget {
  const AnomalyLogsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final List<Map<String, dynamic>> logs = data.anomalyLogs;
    final bool isWhite = data.displayMode == DisplayMode.pureWhite;
    final int count = logs.length;

    return Dialog(
      backgroundColor: data.currentCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 750,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ヘッダー ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (count > 0 ? Colors.orangeAccent : Colors.greenAccent).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    count > 0 ? Icons.warning_amber_rounded : Icons.verified_rounded,
                    color: count > 0 ? (isWhite ? const Color(0xFFD97706) : Colors.amberAccent) : (isWhite ? const Color(0xFF059669) : Colors.greenAccent),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "異常検知データ一覧 ($count件)",
                        style: TextStyle(
                          color: data.mainTextColor,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "作業時間（3分未満/12H以上）や清掃台数（上限超過）の異常疑いログを検知しています",
                        style: TextStyle(
                          color: data.subTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: data.subTextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: data.borderColor, height: 1),
            const SizedBox(height: 12),

            // --- コンテンツ一覧 ---
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 60,
                        color: isWhite ? const Color(0xFF059669) : Colors.greenAccent,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "現在、異常フラグの立っているデータはありません",
                        style: TextStyle(
                          color: data.mainTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "すべての清掃・整備データは正常基準内に収まっています。",
                        style: TextStyle(
                          color: data.subTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return _buildAnomalyCard(context, data, log, isWhite);
                  },
                ),
              ),

            const SizedBox(height: 12),
            Divider(color: data.borderColor, height: 1),
            const SizedBox(height: 12),

            // --- フッター ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "※ 各データをタップして「問題なし（フラグ解除）」または「修正」を行えます",
                  style: TextStyle(
                    color: data.subTextColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("閉じる", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: data.mainTextColor,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem({required String label, required Color color, required bool isWhite}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.7), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAnomalyCard(
    BuildContext context,
    DataProvider provider,
    Map<String, dynamic> log,
    bool isWhite,
  ) {
    final int id = int.tryParse(log['id']?.toString() ?? '0') ?? 0;
    final int flag = int.tryParse(log['anomaly_flag']?.toString() ?? '0') ?? 0;
    final double workMinutes = double.tryParse(log['work_minutes']?.toString() ?? '0.0') ?? 0.0;
    final String workerName = log['worker_name'] ?? log['worker_id'] ?? "不明";
    final String workDate = log['work_date'] ?? "";
    final String modelName = log['model_name'] ?? "不明";
    final String makerAbbr = log['maker_abbr'] ?? log['maker'] ?? "";

    final int airQty = int.tryParse(log['air_clean_qty']?.toString() ?? '0') ?? 0;
    final int cleanQty = int.tryParse(log['clean_qty']?.toString() ?? '0') ?? 0;
    final int swapQty = int.tryParse(log['swap_qty']?.toString() ?? '0') ?? 0;
    final int totalUnits = airQty + cleanQty + swapQty;

    final String timeRange = (log['start_time_str'] != null && log['end_time_str'] != null && log['start_time_str'].toString().isNotEmpty)
        ? "${log['start_time_str']} 〜 ${log['end_time_str']}"
        : "";

    // 異常種別の判定
    final double stdQty = double.tryParse(log['std_qty']?.toString() ?? '0.0') ?? 0.0;
    final double workHours = workMinutes > 0 ? (workMinutes / 60.0) : 7.0;
    final int maxAllowedUnits = stdQty > 0 ? max(3, (workHours * stdQty * 5.0).ceil()) : 9999;

    final bool isUnder3Min = flag == 1 || (workMinutes > 0 && workMinutes < 3.0);
    final bool isOver12h = flag == 2 || workMinutes >= 720.0;
    // 💡 3分未満（作業開始タッチ忘れ疑い）の場合は、台数が多くても台数超過ではなく「開始タッチ忘れ」単独として扱う
    final bool isExcessiveUnits = !isUnder3Min && (flag == 3 || (stdQty > 0 && totalUnits > maxAllowedUnits));

    // プライマリカラーと背景色
    Color primaryColor;
    Color cardBg;
    Color borderC;

    if (isExcessiveUnits) {
      primaryColor = isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7); // Violet
      cardBg = isWhite ? const Color(0xFFFAF5FF) : const Color(0xFF241038);
      borderC = isWhite ? const Color(0xFFD8B4FE) : Colors.purple.withOpacity(0.5);
    } else if (isOver12h) {
      primaryColor = isWhite ? const Color(0xFFDC2626) : Colors.redAccent;
      cardBg = isWhite ? const Color(0xFFFEF2F2) : const Color(0xFF331111);
      borderC = isWhite ? const Color(0xFFFCA5A5) : Colors.red.withOpacity(0.5);
    } else {
      primaryColor = isWhite ? const Color(0xFFD97706) : Colors.orangeAccent;
      cardBg = isWhite ? const Color(0xFFFFFDF5) : const Color(0xFF2A2005);
      borderC = isWhite ? const Color(0xFFFCD34D) : Colors.orange.withOpacity(0.5);
    }

    // 💡 推定原因のリスト作成
    final List<Map<String, String>> estimations = [];
    if (isExcessiveUnits) {
      estimations.add({
        "title": "清掃台数の入力間違い（桁間違い等）の可能性が高いです",
        "detail": "清掃台数の合計が $totalUnits台 に達しています（許容上限: $maxAllowedUnits台 [作業時間 ${workMinutes.toStringAsFixed(0)}分に対する標準の5倍]）。テンキー連打や桁数ミスの疑いがあります。",
      });
    }
    if (isUnder3Min) {
      estimations.add({
        "title": "作業開始タッチ（NFCカード）忘れの可能性が高いです",
        "detail": "作業時間が3分未満（${workMinutes.toStringAsFixed(1)}分）と極端に短いため、開始打刻の漏れの疑いがあります。",
      });
    }
    if (isOver12h) {
      estimations.add({
        "title": "作業終了タッチ（NFCカード）忘れの可能性が高いです",
        "detail": "作業時間が12時間以上（${workMinutes.toStringAsFixed(1)}分）と半日を超えているため、前日や終了打刻の漏れの疑いがあります。",
      });
    }
    if (estimations.isEmpty) {
      estimations.add({
        "title": "数値の異常疑いがあります",
        "detail": "作業時間または清掃台数の数値をご確認ください。",
      });
    }

    // バッジ群
    final List<Widget> badges = [];
    if (isExcessiveUnits) {
      badges.add(_buildBadgeItem(
        label: "⚠️ 台数過大",
        color: isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7),
        isWhite: isWhite,
      ));
    }
    if (isUnder3Min) {
      badges.add(_buildBadgeItem(
        label: "⚠️ 3分未満",
        color: isWhite ? const Color(0xFFD97706) : Colors.orangeAccent,
        isWhite: isWhite,
      ));
    }
    if (isOver12h) {
      badges.add(_buildBadgeItem(
        label: "🚨 12時間以上",
        color: isWhite ? const Color(0xFFDC2626) : Colors.redAccent,
        isWhite: isWhite,
      ));
    }
    if (badges.isEmpty) {
      badges.add(_buildBadgeItem(
        label: "⚠️ 異常検知",
        color: primaryColor,
        isWhite: isWhite,
      ));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _showActionChoiceModal(context, provider, log, isWhite, estimations.first['title']!);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderC, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上段: バッジ & 作業者 & 日付
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ...badges,
                      const SizedBox(width: 4),
                      Icon(Icons.person, size: 16, color: provider.subTextColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          workerName,
                          style: TextStyle(
                            color: provider.mainTextColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  workDate,
                  style: TextStyle(
                    color: provider.subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 中段: 機種・台数・数値ハイライト表示
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            modelName,
                            style: TextStyle(
                              color: isWhite ? const Color(0xFF007799) : const Color(0xFF00E5FF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (makerAbbr.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              "($makerAbbr)",
                              style: TextStyle(
                                color: provider.subTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "内訳: エアー $airQty台 / 清掃 $cleanQty台 / 交換 $swapQty台"
                        "${timeRange.isNotEmpty ? '  [$timeRange]' : ''}",
                        style: TextStyle(
                          color: provider.subTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // 台数過大の場合は台数を特別表示
                if (isExcessiveUnits) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7)).withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "合計台数",
                          style: TextStyle(
                            color: isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "$totalUnits台",
                          style: TextStyle(
                            color: isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // 作業時間表示
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "実働時間",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "${workMinutes.toStringAsFixed(1)}分",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 💡 推定原因アドバイスボックス（こうだと思うよ表示）
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isWhite ? Colors.amber.shade50.withOpacity(0.8) : Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWhite ? Colors.amber.shade400 : Colors.amber.withOpacity(0.45),
                  width: 1,
                ),
              ),
              child: Column(
                children: estimations.map((est) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          size: 18,
                          color: isWhite ? const Color(0xFFB45309) : Colors.amberAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "💡 推定原因: ${est['title']!}",
                                style: TextStyle(
                                  color: isWhite ? const Color(0xFF92400E) : Colors.amberAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                est['detail']!,
                                style: TextStyle(
                                  color: provider.subTextColor,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),

            // 下段: アクションボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. 問題なし（フラグ解除）
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text("問題なし（承認）", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isWhite ? const Color(0xFF059669) : Colors.greenAccent,
                    side: BorderSide(color: isWhite ? const Color(0xFF059669) : Colors.greenAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    _confirmResolveAnomaly(context, provider, id, workerName, modelName, totalUnits, workMinutes);
                  },
                ),
                const SizedBox(width: 10),

                // 2. 修正する
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text("修正する", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                    foregroundColor: isWhite ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AnomalyEditDialog(log: log),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// タップ時の処置選択モーダル
  void _showActionChoiceModal(
    BuildContext context,
    DataProvider provider,
    Map<String, dynamic> log,
    bool isWhite,
    String estimatedReason,
  ) {
    final int id = int.tryParse(log['id']?.toString() ?? '0') ?? 0;
    final String workerName = log['worker_name'] ?? log['worker_id'] ?? "不明";
    final String modelName = log['model_name'] ?? "不明";
    final int airQty = int.tryParse(log['air_clean_qty']?.toString() ?? '0') ?? 0;
    final int cleanQty = int.tryParse(log['clean_qty']?.toString() ?? '0') ?? 0;
    final int swapQty = int.tryParse(log['swap_qty']?.toString() ?? '0') ?? 0;
    final int totalUnits = airQty + cleanQty + swapQty;
    final double workMinutes = double.tryParse(log['work_minutes']?.toString() ?? '0.0') ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: provider.currentCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "データの処置を選択",
                  style: TextStyle(
                    color: provider.mainTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "対象: $workerName / $modelName (合計 $totalUnits台 / 実働 ${workMinutes.toStringAsFixed(1)}分)",
                  style: TextStyle(color: provider.subTextColor, fontSize: 14),
                ),
                const SizedBox(height: 8),

                // 推定原因の案内
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isWhite ? Colors.amber.shade50 : Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isWhite ? Colors.amber.shade300 : Colors.amber.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        size: 18,
                        color: isWhite ? const Color(0xFFB45309) : Colors.amberAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "💡 推定原因: $estimatedReason",
                          style: TextStyle(
                            color: isWhite ? const Color(0xFF92400E) : Colors.amberAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: provider.borderColor, height: 1),
                const SizedBox(height: 10),

                // 処置1: 問題なし
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check_circle_outline, color: isWhite ? const Color(0xFF059669) : Colors.greenAccent),
                  ),
                  title: Text("問題なし（異常フラグを解除）", style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold)),
                  subtitle: Text("この作業時間・台数を正常として承認し、異常フラグを消去します。", style: TextStyle(color: provider.subTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmResolveAnomaly(context, provider, id, workerName, modelName, totalUnits, workMinutes);
                  },
                ),
                const SizedBox(height: 6),

                // 処置2: 修正する
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)),
                  ),
                  title: Text("修正する（修正画面を開く）", style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold)),
                  subtitle: Text("適正な作業時間や台数を修正して保存し、異常フラグを解除します。", style: TextStyle(color: provider.subTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => AnomalyEditDialog(log: log),
                    );
                  },
                ),
                const SizedBox(height: 6),

                // 処置3: 削除する
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  title: Text("データを削除する", style: TextStyle(color: isWhite ? Colors.red.shade900 : Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: Text("この作業ログをデータベースから完全に削除します（元に戻せません）。", style: TextStyle(color: provider.subTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showDeleteModalDirect(context, provider, id, workerName, modelName, totalUnits);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 直接削除確認・実行ダイアログ
  void _showDeleteModalDirect(
    BuildContext context,
    DataProvider provider,
    int id,
    String workerName,
    String modelName,
    int totalUnits,
  ) {
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isWhite ? Colors.red.shade50 : const Color(0xFF331111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade900, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "データ削除の確認",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "本当に以下の異常データを削除してもよろしいですか？",
                style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "※この操作は元に戻すことができません！",
                style: TextStyle(color: Colors.red.shade600, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: provider.currentCardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("作業者: $workerName", style: TextStyle(color: provider.mainTextColor, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text("機種名: $modelName", style: TextStyle(color: provider.mainTextColor, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text("清掃台数: 合計 $totalUnits台", style: TextStyle(color: provider.mainTextColor, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("キャンセル", style: TextStyle(color: provider.subTextColor, fontSize: 15)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text("削除する", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              bool success = await provider.deleteLogData(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "🗑️ 異常データを削除しました" : "❌ データ削除に失敗しました"),
                    backgroundColor: success ? Colors.redAccent : Colors.grey.shade800,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 「問題なし」確認・実行ダイアログ
  void _confirmResolveAnomaly(
    BuildContext context,
    DataProvider provider,
    int id,
    String workerName,
    String modelName,
    int totalUnits,
    double workMinutes,
  ) {
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: provider.currentCardColor,
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: isWhite ? const Color(0xFF059669) : Colors.greenAccent),
              const SizedBox(width: 10),
              Text("異常フラグの解除確認", style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "対象データ（$workerName / $modelName\n合計: $totalUnits台 / 実働: ${workMinutes.toStringAsFixed(1)}分）を「問題なし」として承認し、異常フラグを解除しますか？\n\n解除すると異常データ一覧から除外されます。",
            style: TextStyle(color: provider.mainTextColor, fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              child: Text("キャンセル", style: TextStyle(color: provider.subTextColor)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWhite ? const Color(0xFF059669) : Colors.greenAccent,
                foregroundColor: isWhite ? Colors.white : Colors.black,
              ),
              child: const Text("問題なしとして解除", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                bool success = await provider.resolveAnomalyFlag(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? "✅ 異常フラグを解除しました" : "❌ フラグ解除に失敗しました"),
                      backgroundColor: success ? Colors.green : Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// ======================================================================
// ✏️ 異常データ修正ダイアログ（修正完了後に異常フラグを自動解除）
// ======================================================================
class AnomalyEditDialog extends StatefulWidget {
  final Map<String, dynamic> log;
  const AnomalyEditDialog({super.key, required this.log});

  @override
  State<AnomalyEditDialog> createState() => _AnomalyEditDialogState();
}

class _AnomalyEditDialogState extends State<AnomalyEditDialog> {
  late TextEditingController _workMinutesCtrl;
  late TextEditingController _airCtrl;
  late TextEditingController _cleanCtrl;
  late TextEditingController _swapCtrl;
  late TextEditingController _toCleanCtrl;
  late TextEditingController _toSwapCtrl;

  late DateTime _selectedDate;
  late String _workType;
  bool _isSaving = false;
  String? _startTimeStr;
  String? _endTimeStr;

  @override
  void initState() {
    super.initState();
    final log = widget.log;

    _workMinutesCtrl = TextEditingController(
      text: (double.tryParse(log['work_minutes']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(1),
    );
    _airCtrl = TextEditingController(text: (log['air_clean_qty'] ?? 0).toString());
    _cleanCtrl = TextEditingController(text: (log['clean_qty'] ?? 0).toString());
    _swapCtrl = TextEditingController(text: (log['swap_qty'] ?? 0).toString());
    _toCleanCtrl = TextEditingController(text: (log['to_clean_qty'] ?? 0).toString());
    _toSwapCtrl = TextEditingController(text: (log['to_swap_qty'] ?? 0).toString());

    _startTimeStr = log['start_time_str']?.toString();
    _endTimeStr = log['end_time_str']?.toString();

    // 作業区分の判定
    int aQty = int.tryParse(log['air_clean_qty']?.toString() ?? '0') ?? 0;
    int cQty = int.tryParse(log['clean_qty']?.toString() ?? '0') ?? 0;
    int sQty = int.tryParse(log['swap_qty']?.toString() ?? '0') ?? 0;
    if (sQty > 0 && sQty >= cQty && sQty >= aQty) {
      _workType = "筐体交換";
    } else if (aQty > 0 && aQty >= cQty) {
      _workType = "エアー清掃";
    } else {
      _workType = "清掃";
    }

    // 作業日のパース
    String wDateStr = log['work_date']?.toString() ?? '';
    _selectedDate = DateTime.tryParse(wDateStr.replaceAll('/', '-')) ?? DateTime.now();
  }

  @override
  void dispose() {
    _workMinutesCtrl.dispose();
    _airCtrl.dispose();
    _cleanCtrl.dispose();
    _swapCtrl.dispose();
    _toCleanCtrl.dispose();
    _toSwapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;
    final log = widget.log;
    final int id = int.tryParse(log['id']?.toString() ?? '0') ?? 0;
    final String workerName = log['worker_name'] ?? log['worker_id'] ?? "不明";
    final String modelName = log['model_name'] ?? "不明";
    final String makerAbbr = log['maker_abbr'] ?? log['maker'] ?? "";

    final int flag = int.tryParse(log['anomaly_flag']?.toString() ?? '0') ?? 0;
    final double origWorkMinutes = double.tryParse(log['work_minutes']?.toString() ?? '0.0') ?? 0.0;
    final int origAir = int.tryParse(log['air_clean_qty']?.toString() ?? '0') ?? 0;
    final int origClean = int.tryParse(log['clean_qty']?.toString() ?? '0') ?? 0;
    final int origSwap = int.tryParse(log['swap_qty']?.toString() ?? '0') ?? 0;
    final int origTotal = origAir + origClean + origSwap;

    final double stdQty = double.tryParse(log['std_qty']?.toString() ?? '0.0') ?? 0.0;
    final double workHours = origWorkMinutes > 0 ? (origWorkMinutes / 60.0) : 7.0;
    final int maxAllowedUnits = stdQty > 0 ? max(3, (workHours * stdQty * 5.0).ceil()) : 9999;

    final bool isUnder3Min = flag == 1 || (origWorkMinutes > 0 && origWorkMinutes < 3.0);
    final bool isOver12h = flag == 2 || origWorkMinutes >= 720.0;
    // 💡 3分未満（作業開始タッチ忘れ疑い）の場合は、台数超過ではなく「開始タッチ忘れ」単独として扱う
    final bool isExcessiveUnits = !isUnder3Min && (flag == 3 || (stdQty > 0 && origTotal > maxAllowedUnits));

    final Color bannerColor = isUnder3Min
        ? (isWhite ? const Color(0xFFD97706) : Colors.orangeAccent)
        : (isExcessiveUnits
            ? (isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7))
            : (isOver12h
                ? (isWhite ? const Color(0xFFDC2626) : Colors.redAccent)
                : (isWhite ? const Color(0xFFD97706) : Colors.orangeAccent)));

    final String bannerReason = isUnder3Min
        ? "検知理由: 作業時間が3分未満（${origWorkMinutes.toStringAsFixed(1)}分）と極端に短いです。"
        : (isExcessiveUnits
            ? "検知理由: 清掃台数（$origTotal台）が許容上限（$maxAllowedUnits台 [標準の5倍]）を超過しています。"
            : (isOver12h
                ? "検知理由: 作業時間が12時間以上（${origWorkMinutes.toStringAsFixed(1)}分）となっています。"
                : "検知理由: 異常疑いログを検知しています。"));

    final String bannerAdvice = isUnder3Min
        ? "💡 推定原因: 作業開始タッチ（NFCカード）忘れの可能性が高いです。\n正しい作業時間（分）を入力して保存すると、異常フラグが解除されます。"
        : (isExcessiveUnits
            ? "💡 推定原因: 清掃台数の入力間違い（桁間違い等）の可能性が高いです。\n適正な清掃台数に修正して保存すると、異常フラグが解除されます。"
            : (isOver12h
                ? "💡 推定原因: 作業終了タッチ（NFCカード）忘れの可能性が高いです。\n適正な作業時間（分）を入力して保存すると、異常フラグが解除されます。"
                : "💡 推定原因: 作業時間または清掃台数をご確認ください。"));

    return AlertDialog(
      backgroundColor: provider.currentCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)),
              const SizedBox(width: 10),
              Text(
                "異常データの修正",
                style: TextStyle(
                  color: provider.mainTextColor,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                tooltip: "このデータを削除",
                onPressed: _isSaving
                    ? null
                    : () => _confirmDelete(provider, id, workerName, modelName, origTotal),
              ),
              IconButton(
                icon: Icon(Icons.close, color: provider.subTextColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 理由ガイダンスバナー（推定原因と対処法）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bannerColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: bannerColor.withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      color: bannerColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bannerAdvice,
                            style: TextStyle(
                              color: isWhite ? bannerColor : bannerColor.withOpacity(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            bannerReason,
                            style: TextStyle(
                              color: provider.subTextColor,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 基本情報表示
              Row(
                children: [
                  Expanded(
                    child: _buildInfoTile("作業者", workerName, Icons.person, provider, isWhite),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoTile("機種名", "$modelName ${makerAbbr.isNotEmpty ? '($makerAbbr)' : ''}", Icons.devices, provider, isWhite),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 日付選択
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "作業日: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}",
                    style: TextStyle(
                      color: provider.mainTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text("日付を変更"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 作業時間（分）入力（最も重要）+ 入力忘れ用 & SV対応時間ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "作業時間 (分) ★",
                    style: TextStyle(
                      color: isWhite ? const Color(0xFF007799) : const Color(0xFF00E5FF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.more_time, size: 16),
                        label: const Text("入力忘れ用", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite ? Colors.blue.shade600 : Colors.lightBlue,
                          foregroundColor: isWhite ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _showForgotInputDialog(context, provider, isWhite);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.timer_off, size: 16),
                        label: const Text("SV対応時間を引く", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite ? Colors.orange.shade700 : Colors.orangeAccent,
                          foregroundColor: isWhite ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _showSVTimeDialog(context, provider, isWhite);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _workMinutesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: provider.mainTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "例: 15.0",
                  suffixText: "分",
                  suffixStyle: TextStyle(color: provider.subTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: provider.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (_startTimeStr != null && _startTimeStr!.isNotEmpty && _endTimeStr != null && _endTimeStr!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: provider.subTextColor),
                      const SizedBox(width: 4),
                      Text(
                        "打刻時刻: $_startTimeStr 〜 $_endTimeStr",
                        style: TextStyle(color: provider.subTextColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 作業区分
              Text(
                "作業区分",
                style: TextStyle(color: provider.subTextColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: provider.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _workType,
                    dropdownColor: provider.currentCardColor,
                    style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                    items: ["エアー清掃", "清掃", "筐体交換"].map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val, style: TextStyle(color: provider.mainTextColor)),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) {
                        setState(() => _workType = newVal);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 台数入力フィールド
              if (_workType == "エアー清掃") ...[
                Row(
                  children: [
                    Expanded(child: _buildCountField("エアー完了台数", _airCtrl, provider, isWhite)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCountField("通常清掃へ（仕掛）", _toCleanCtrl, provider, isWhite)),
                  ],
                ),
              ] else if (_workType == "清掃") ...[
                Row(
                  children: [
                    Expanded(child: _buildCountField("清掃完了台数", _cleanCtrl, provider, isWhite)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCountField("筐体交換へ（仕掛）", _toSwapCtrl, provider, isWhite)),
                  ],
                ),
              ] else ...[
                _buildCountField("筐体交換完了台数", _swapCtrl, provider, isWhite),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
              label: const Text(
                "データを削除",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: _isSaving
                  ? null
                  : () => _confirmDelete(provider, id, workerName, modelName, origTotal),
            ),
            Row(
              children: [
                TextButton(
                  child: Text("キャンセル", style: TextStyle(color: provider.subTextColor)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    _isSaving ? "保存中..." : "保存してフラグ解除",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                    foregroundColor: isWhite ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: _isSaving ? null : () => _saveAndResolve(provider, id),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, DataProvider provider, bool isWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isWhite ? Colors.grey.shade100 : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: provider.subTextColor),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: provider.subTextColor, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: provider.mainTextColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCountField(String label, TextEditingController ctrl, DataProvider provider, bool isWhite) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: provider.subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: provider.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: "台",
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: provider.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Future<void> _saveAndResolve(DataProvider provider, int id) async {
    setState(() => _isSaving = true);

    try {
      final double workMinutes = double.tryParse(_workMinutesCtrl.text) ?? 0.0;
      final int airQty = _workType == "エアー清掃" ? (int.tryParse(_airCtrl.text) ?? 0) : 0;
      final int toCleanQty = _workType == "エアー清掃" ? (int.tryParse(_toCleanCtrl.text) ?? 0) : 0;
      final int cleanQty = _workType == "清掃" ? (int.tryParse(_cleanCtrl.text) ?? 0) : 0;
      final int toSwapQty = _workType == "清掃" ? (int.tryParse(_toSwapCtrl.text) ?? 0) : 0;
      final int swapQty = _workType == "筐体交換" ? (int.tryParse(_swapCtrl.text) ?? 0) : 0;
      final int totalUnits = airQty + cleanQty + swapQty;

      // 💡 修正後も台数が許容上限を超過している場合は再確認ダイアログを表示
      final double stdQty = double.tryParse(widget.log['std_qty']?.toString() ?? '0.0') ?? 0.0;
      final double workHours = workMinutes > 0 ? (workMinutes / 60.0) : 7.0;
      final int maxAllowedUnits = stdQty > 0 ? max(3, (workHours * stdQty * 5.0).ceil()) : 9999;

      if (stdQty > 0 && totalUnits > maxAllowedUnits) {
        final bool isWhite = provider.displayMode == DisplayMode.pureWhite;
        bool? proceed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: provider.currentCardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7)),
                const SizedBox(width: 8),
                Text("台数過大の確認", style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              "清掃台数の合計が許容上限（$maxAllowedUnits台 [作業時間に対する標準の5倍]）を超える合計 $totalUnits台 になっています。\n桁間違いや入力ミスの可能性が高いですが、このまま保存しますか？",
              style: TextStyle(color: provider.mainTextColor, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                child: Text("戻って修正する", style: TextStyle(color: provider.subTextColor)),
                onPressed: () => Navigator.of(c).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWhite ? const Color(0xFF7C3AED) : const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                ),
                child: const Text("この台数で保存"),
                onPressed: () => Navigator.of(c).pop(true),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final String workDateStr = DateFormat('yyyy/MM/dd').format(_selectedDate);

      // 💡 修正完了後は必ず anomaly_flag = 0 で解除する
      Map<String, dynamic> updates = {
        "work_date": workDateStr,
        "work_minutes": workMinutes,
        "air_clean_qty": airQty,
        "to_clean_qty": toCleanQty,
        "clean_qty": cleanQty,
        "to_swap_qty": toSwapQty,
        "swap_qty": swapQty,
        "anomaly_flag": 0,
      };

      if (_startTimeStr != null && _startTimeStr!.isNotEmpty) {
        updates["start_time_str"] = _startTimeStr;
      }
      if (_endTimeStr != null && _endTimeStr!.isNotEmpty) {
        updates["end_time_str"] = _endTimeStr;
      }

      bool success = await provider.updateFullLogData(id, updates);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "✅ データを修正し、異常フラグを解除しました" : "❌ データ保存に失敗しました"),
            backgroundColor: success ? Colors.green : Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ エラーが発生しました: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    DataProvider provider,
    int id,
    String workerName,
    String modelName,
    int totalUnits,
  ) async {
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isWhite ? Colors.red.shade50 : const Color(0xFF331111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade900, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "データ削除の確認",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "本当に以下の異常データを削除してもよろしいですか？",
                style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "※この操作は元に戻すことができません！",
                style: TextStyle(color: Colors.red.shade600, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: provider.currentCardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("作業者: $workerName", style: TextStyle(color: provider.mainTextColor, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text("機種名: $modelName", style: TextStyle(color: provider.mainTextColor, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text("清掃台数: 合計 $totalUnits台", style: TextStyle(color: provider.mainTextColor, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("キャンセル", style: TextStyle(color: provider.subTextColor, fontSize: 15)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text("削除する", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      bool success = await provider.deleteLogData(id);
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop(); // 修正ダイアログを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "🗑️ 異常データを削除しました" : "❌ データ削除に失敗しました"),
            backgroundColor: success ? Colors.redAccent : Colors.grey.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  TimeOfDay? _parseTimeOfDay(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (!s.contains(':')) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _showForgotInputDialog(BuildContext context, DataProvider provider, bool isWhite) {
    TimeOfDay? startTime = _parseTimeOfDay(_startTimeStr);
    TimeOfDay? endTime = _parseTimeOfDay(_endTimeStr);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int? previewDiff;
            int previewBreak = 0;
            if (startTime != null && endTime != null) {
              int sMins = startTime!.hour * 60 + startTime!.minute;
              int eMins = endTime!.hour * 60 + endTime!.minute;
              if (eMins < sMins) eMins += 24 * 60;

              final breaks = [
                {'start': 11 * 60 + 55, 'duration': 50}, // 11:55 - 12:45
                {'start': 15 * 60 + 0, 'duration': 10},  // 15:00 - 15:10
                {'start': 18 * 60 + 30, 'duration': 10}, // 18:30 - 18:40
              ];
              for (var b in breaks) {
                int bStart = b['start']!;
                int bEnd = bStart + b['duration']!;
                int overlapStart = sMins > bStart ? sMins : bStart;
                int overlapEnd = eMins < bEnd ? eMins : bEnd;
                if (overlapStart < overlapEnd) {
                  previewBreak += (overlapEnd - overlapStart);
                }
              }
              previewDiff = (eMins - sMins) - previewBreak;
              if (previewDiff < 0) previewDiff = 0;
            }

            return AlertDialog(
              backgroundColor: provider.currentCardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.more_time, color: isWhite ? Colors.blue.shade600 : Colors.lightBlue),
                  const SizedBox(width: 8),
                  Text(
                    "入力忘れ用 (時間計算)",
                    style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "開始時間と終了時間を選択してください。\n休憩時間（昼休憩50分、午後休憩10分等）は自動控除されます。",
                    style: TextStyle(color: provider.subTextColor, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("開始時間:", style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.w600)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(
                          startTime != null
                              ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}"
                              : "選択",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite ? Colors.grey.shade200 : Colors.white12,
                          foregroundColor: provider.mainTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                            initialEntryMode: TimePickerEntryMode.dial,
                          );
                          if (picked != null) {
                            setDialogState(() => startTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("終了時間:", style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.w600)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.access_time_filled, size: 16),
                        label: Text(
                          endTime != null
                              ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}"
                              : "選択",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite ? Colors.grey.shade200 : Colors.white12,
                          foregroundColor: provider.mainTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime ?? const TimeOfDay(hour: 17, minute: 0),
                            initialEntryMode: TimePickerEntryMode.dial,
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  if (previewDiff != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isWhite ? Colors.blue.shade50 : Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isWhite ? Colors.blue.shade200 : Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("試算結果 (実働):", style: TextStyle(color: isWhite ? Colors.blue.shade900 : Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            "$previewDiff 分 (${previewDiff ~/ 60}時間 ${previewDiff % 60}分)",
                            style: TextStyle(color: isWhite ? Colors.blue.shade900 : Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("キャンセル", style: TextStyle(color: provider.subTextColor, fontSize: 15)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC),
                    foregroundColor: isWhite ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    if (startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("開始時間と終了時間の両方を選択してください")),
                      );
                      return;
                    }

                    int startMins = startTime!.hour * 60 + startTime!.minute;
                    int endMins = endTime!.hour * 60 + endTime!.minute;

                    if (endMins < startMins) {
                      endMins += 24 * 60;
                    }

                    int totalBreakMins = 0;
                    final breaks = [
                      {'start': 11 * 60 + 55, 'duration': 50},
                      {'start': 15 * 60 + 0, 'duration': 10},
                      {'start': 18 * 60 + 30, 'duration': 10},
                    ];

                    for (var b in breaks) {
                      int bStart = b['start']!;
                      int bEnd = bStart + b['duration']!;

                      int overlapStart = startMins > bStart ? startMins : bStart;
                      int overlapEnd = endMins < bEnd ? endMins : bEnd;

                      if (overlapStart < overlapEnd) {
                        totalBreakMins += (overlapEnd - overlapStart);
                      }
                    }

                    int diffMins = (endMins - startMins) - totalBreakMins;
                    if (diffMins < 0) diffMins = 0;

                    final String sStr = "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}";
                    final String eStr = "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}";

                    setState(() {
                      _workMinutesCtrl.text = diffMins.toString();
                      _startTimeStr = sStr;
                      _endTimeStr = eStr;
                    });

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("作業時間を反映しました ($diffMins分 / $sStr〜$eStr)"),
                        backgroundColor: isWhite ? Colors.teal.shade700 : Colors.teal,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text("反映する", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSVTimeDialog(BuildContext context, DataProvider provider, bool isWhite) {
    final TextEditingController svHoursCtrl = TextEditingController();
    final TextEditingController svMinutesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: provider.currentCardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.timer_off, color: isWhite ? Colors.orange.shade700 : Colors.orangeAccent),
              const SizedBox(width: 8),
              Text(
                "SV対応時間を引く",
                style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("現在の作業時間から控除する時間を入力してください。", style: TextStyle(color: provider.subTextColor, fontSize: 13)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: svHoursCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: provider.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "時間",
                        labelStyle: TextStyle(color: provider.subTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.borderColor)),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixText: "時間",
                        suffixStyle: TextStyle(color: provider.subTextColor, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: svMinutesCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: provider.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "分",
                        labelStyle: TextStyle(color: provider.subTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.borderColor)),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        suffixText: "分",
                        suffixStyle: TextStyle(color: provider.subTextColor, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("キャンセル", style: TextStyle(color: provider.subTextColor, fontSize: 15)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC),
                foregroundColor: isWhite ? Colors.white : Colors.black,
              ),
              onPressed: () {
                double currentMins = double.tryParse(_workMinutesCtrl.text) ?? 0.0;
                int svMins = (int.tryParse(svHoursCtrl.text) ?? 0) * 60 + (int.tryParse(svMinutesCtrl.text) ?? 0);

                double newMins = currentMins - svMins;
                if (newMins < 0) newMins = 0;

                setState(() {
                  _workMinutesCtrl.text = (newMins % 1 == 0) ? newMins.toInt().toString() : newMins.toStringAsFixed(1);
                });

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("作業時間からSV対応時間($svMins分)を引きました"),
                    backgroundColor: isWhite ? Colors.teal.shade700 : Colors.teal,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text("適用する", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }
}
