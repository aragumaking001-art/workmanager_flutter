import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/data_provider.dart';
import '../widgets/app_background_wrapper.dart';
import 'personal_stats_tab.dart';
import '../pages/personal_productivity_page.dart';

class KioskDetailScreen extends StatefulWidget {
  final String workerId;

  const KioskDetailScreen({super.key, required this.workerId});

  @override
  State<KioskDetailScreen> createState() => _KioskDetailScreenState();
}

class _KioskDetailScreenState extends State<KioskDetailScreen> {
  Timer? _kioskTimer;
  final int _timeoutSeconds = 60; // 1分

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _kioskTimer?.cancel();
    _kioskTimer = Timer(Duration(seconds: _timeoutSeconds), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _resetTimer() {
    _startTimer();
  }

  @override
  void dispose() {
    _kioskTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = Provider.of<DataProvider>(context);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return Listener(
      // 画面上のあらゆるタップやスワイプを検知してタイマーをリセットする
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: AppBackgroundWrapper(
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor:
                  dp.currentCardColor.withValues(alpha: isWhite ? 0.85 : 0.65),
              elevation: isWhite ? 2 : 0,
            automaticallyImplyLeading: false, // 戻るボタンは自前で右側に置く
            title: Text(
              "個人の実績・生産性ステータス",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: dp.mainTextColor,
                fontSize: 22,
              ),
            ),
            actions: [
              TextButton.icon(
                icon: Icon(Icons.close, color: dp.mainTextColor, size: 28),
                label: Text(
                  "閉じる",
                  style: TextStyle(
                    color: dp.mainTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 20),
            ],
            bottom: TabBar(
              indicatorColor: isWhite
                  ? const Color(0xFF007799)
                  : const Color(0xFF00CCFF),
              indicatorWeight: 4,
              labelColor: isWhite
                  ? const Color(0xFF007799)
                  : const Color(0xFF00CCFF),
              unselectedLabelColor: dp.subTextColor,
              labelStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 20),
              tabs: const [
                Tab(text: "ステータス", icon: Icon(Icons.radar)),
                Tab(text: "生産性データ", icon: Icon(Icons.calendar_month)),
              ],
            ),
          ),
          body: TabBarView(
            // スワイプで切り替え可能
            physics: const BouncingScrollPhysics(),
            children: [
              // タブ1: 既存のレーダーチャート画面
              PersonalStatsTab(
                initialWorkerId: widget.workerId,
                isKioskMode: true,
              ),
              // タブ2: 生産性カレンダー詳細画面
              PersonalProductivityPage(
                initialWorkerId: widget.workerId,
                isKioskMode: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
