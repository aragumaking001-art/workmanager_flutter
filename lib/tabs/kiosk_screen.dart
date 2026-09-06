import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kiosk_provider.dart';
import '../providers/data_provider.dart';
import '../widgets/app_background_wrapper.dart';
import 'kiosk_detail_screen.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;
  
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // 背景のゆったりしたアニメーション
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToDetail(BuildContext context, String workerId) async {
    if (_isNavigating) return;
    _isNavigating = true;

    // DataProviderから名前に該当するワーカーを探す確認（あれば遷移）
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    if (!dataProvider.workerStatsMap.containsKey(workerId)) {
      // 登録されていないカード
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未登録のカードです: $workerId', style: const TextStyle(fontSize: 20))),
      );
      
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Provider.of<KioskProvider>(context, listen: false).resetToStandby();
      }
      _isNavigating = false;
      return;
    }

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => KioskDetailScreen(
          workerId: workerId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    // KioskDetailScreenから戻ってきたらリセット
    if (mounted) {
      Provider.of<KioskProvider>(context, listen: false).resetToStandby();
      _isNavigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kiosk = Provider.of<KioskProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final isWhite = dataProvider.displayMode == DisplayMode.pureWhite;

    if (kiosk.currentWorkerId != null && !_isNavigating) {
      // 少し遅らせて遷移させる（UI構築中のナビゲーションエラー防止）
      Future.microtask(() => _navigateToDetail(context, kiosk.currentWorkerId!));
    }

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
        children: [
          // 戻るボタン (キオスクモード終了用)
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: dataProvider.subTextColor, size: 30),
              onPressed: () => exit(0), // アプリ自体を完全に終了する
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isWhite ? const Color(0xFFD4EFFC) : const Color(0xFF0E384C),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isWhite ? const Color(0xFF007799).withOpacity(0.3) : const Color(0xFF00CCFF).withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ]
                    ),
                    child: Icon(
                      Icons.contactless_outlined,
                      size: 120,
                      color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                Text(
                  "担当者カードを\nかざしてください",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: dataProvider.mainTextColor,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "カードリーダーにしっかりタッチしてください",
                  style: TextStyle(
                    fontSize: 24,
                    color: dataProvider.subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
