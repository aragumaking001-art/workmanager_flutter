import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// 💡 サイネージ／スライドショーに表示するアイテムのモデル
class SignageItem {
  final String title;
  final String subtitle;
  final String tag;
  final String? imagePath;
  final String? videoPath;
  final Duration duration;
  final Color accentColor;
  final BoxFit fit;
  final bool showTextOverlay;

  const SignageItem({
    required this.title,
    required this.subtitle,
    this.tag = "INFOMATION",
    this.imagePath,
    this.videoPath,
    this.duration = const Duration(seconds: 6),
    this.accentColor = const Color(0xFF00CCFF),
    this.fit = BoxFit.cover,
    this.showTextOverlay = true,
  });
}

/// 💡 飲食店のタブレット風スクリーンセーバー・デジタルサイネージ画面
class DigitalSignageScreen extends StatefulWidget {
  final VoidCallback? onDismiss;

  const DigitalSignageScreen({super.key, this.onDismiss});

  @override
  State<DigitalSignageScreen> createState() => _DigitalSignageScreenState();
}

class _DigitalSignageScreenState extends State<DigitalSignageScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _slideTimer;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  /// サンプルスライドリスト（画像・動画・メッセージのサンプル）
  final List<SignageItem> _items = const [
    SignageItem(
      tag: "SYSTEM INTRO",
      title: "和気センター 統合生産管理システム",
      subtitle: "WorkManager — 現場ファーストのリアルタイム生産性可視化",
      imagePath: "assets/signage_integrated_system.jpg",
      duration: Duration(seconds: 8),
      accentColor: Color(0xFF00E5FF),
      fit: BoxFit.contain,
      showTextOverlay: false, // 💡 画像自体にタイトル等が入っているためオーバーレイ文字を非表示に
    ),
    SignageItem(
      tag: "SAFETY FIRST",
      title: "今日も一日 安全第一！",
      subtitle: "整理・整頓・清掃・清潔の徹底で、安全で快適な作業環境を保ちましょう",
      imagePath: "assets/mascot_fight.jpg",
      duration: Duration(seconds: 6),
      accentColor: Color(0xFFFF9100),
    ),
    SignageItem(
      tag: "TODAY TARGET",
      title: "本日の目標達成に向けて稼働中",
      subtitle: "エアー清掃・通常清掃・筐体交換を丁寧かつ確実に進めましょう",
      imagePath: "assets/bg_tech_abstract.jpg",
      duration: Duration(seconds: 6),
      accentColor: Color(0xFF00E676),
    ),
    SignageItem(
      tag: "HEALTH CARE",
      title: "ナイスペース！ こまめな水分補給を",
      subtitle: "定期的な休憩とストレッチを取り入れて、疲労をリフレッシュしましょう",
      imagePath: "assets/mascot_good_pace.jpg",
      duration: Duration(seconds: 6),
      accentColor: Color(0xFFFFD600),
    ),
    SignageItem(
      tag: "QUALITY & SPEED",
      title: "めざせ！エクセレント優秀",
      subtitle: "カードタッチで個人ダッシュボードを開き、今日の達成度や経験値を確認！",
      imagePath: "assets/signage_aim_for_excellent.jpg",
      duration: Duration(seconds: 8),
      accentColor: Color(0xFFFFD700),
      fit: BoxFit.contain,
      showTextOverlay: false, // 💡 画像自体にタイトルやタッチ演出が入っているため文字被りを防止
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // 最初のスライドの動画準備
    _checkAndPlayVideo(0);

    // スライドショー開始
    _startSlideTimer();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// スライド自動送りのタイマー制御（アニメーションコントローラー不要の超省エネ設計）
  void _startSlideTimer() {
    _slideTimer?.cancel();
    final currentItem = _items[_currentIndex];

    _slideTimer = Timer(currentItem.duration, () {
      if (!mounted) return;
      int nextIndex = (_currentIndex + 1) % _items.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  /// スライド変更時の動画初期化・再生
  Future<void> _checkAndPlayVideo(int index) async {
    final item = _items[index];

    // デスクトップ(Windows等)はvideo_playerプラグイン非対応のためスキップ
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return;
    }

    if (item.videoPath != null) {
      try {
        _videoController?.dispose();
        _videoController = VideoPlayerController.asset(item.videoPath!);
        await _videoController!.initialize();
        await _videoController!.setLooping(true);
        await _videoController!.setVolume(0.0); // ミュート再生
        await _videoController!.play();
        if (mounted) {
          setState(() => _isVideoInitialized = true);
        }
      } catch (e) {
        debugPrint("サイネージ動画再生エラー: $e");
        if (mounted) {
          setState(() => _isVideoInitialized = false);
        }
      }
    } else {
      _videoController?.pause();
      if (_isVideoInitialized) {
        setState(() => _isVideoInitialized = false);
      }
    }
  }

  /// 画面タップでメインメニューへ復帰
  void _dismissScreensaver() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissScreensaver,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- 🖼️ 1. メインのスライドショー (PageView) ---
            PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _checkAndPlayVideo(index);
                _startSlideTimer();
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                final bool isVideoSlide = item.videoPath != null &&
                    _isVideoInitialized &&
                    _videoController != null &&
                    _videoController!.value.isInitialized;

                return RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 背景メディア（動画または画像）
                      if (isVideoSlide)
                        Center(
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                        )
                      else if (item.imagePath != null)
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            // 💡 contain表示時の背景アンビエントブラー（低解像度プレビューでGPU負荷を激減）
                            if (item.fit == BoxFit.contain) ...[
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Transform.scale(
                                  scale: 1.15,
                                  child: Image.asset(
                                    item.imagePath!,
                                    cacheWidth: 320, // 💡 320pxのサムネイルをぼかすことでGPU計算量を1/36に激減！
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(color: const Color(0xFF0B101B)),
                                  ),
                                ),
                              ),
                              Container(color: Colors.black.withValues(alpha: 0.40)),
                            ],
                            Center(
                              child: Image.asset(
                                item.imagePath!,
                                fit: item.fit,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFF0B101B),
                                  child: Center(
                                    child: Icon(Icons.slideshow_rounded,
                                        size: 80, color: item.accentColor.withValues(alpha: 0.5)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(color: const Color(0xFF0F172A)),

                    // 💡 テキストオーバーレイ（ポスター画像など自前で文字が入っている場合は非表示）
                    if (item.showTextOverlay) ...[
                      // グラデーションオーバーレイ（文字可読性＆シネマティック感）
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.40),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.25, 0.65, 1.0],
                          ),
                        ),
                      ),

                      // スライドテキスト情報（左下）
                      Positioned(
                        left: 36,
                        bottom: 80,
                        right: 36,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // カテゴリタグ
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: item.accentColor.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: item.accentColor.withValues(alpha: 0.8),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                item.tag,
                                style: TextStyle(
                                  color: item.accentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // メインタイトル
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 16,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // サブテキスト
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            ),

            // --- ⏱️ 2. 上部ヘッダー（デジタル時計 ＆ ロゴ） ---
            Positioned(
              top: 24,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左側: アプリロゴと施設名
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 28,
                          height: 28,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.precision_manufacturing_rounded,
                              color: Color(0xFF00CCFF),
                              size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "WorkManager",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            "和気センター",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 右側: デジタル時計（独立ウィジェットで局所更新し親画面リビルドを完全防止）
                  _SignageClockWidget(accentColor: currentItem.accentColor),
                ],
              ),
            ),

            // --- 👆 3. 画面最下部: 「画面をタッチしてください」の案内（完全静止・低発熱仕様） ---
            Positioned(
              bottom: 22,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentItem.accentColor.withValues(alpha: 0.20),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: currentItem.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "画面をタッチするとメインメニューに戻ります",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- ⚪ 5. 右下のページネーションドット ---
            Positioned(
              right: 36,
              bottom: 30,
              child: Row(
                children: List.generate(_items.length, (idx) {
                  bool isActive = _currentIndex == idx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? currentItem.accentColor : Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 💡 独立して1秒毎に更新するデジタル時計（親画面全体の再描画を防止しCPU使用率を激減）
class _SignageClockWidget extends StatefulWidget {
  final Color accentColor;
  const _SignageClockWidget({required this.accentColor});

  @override
  State<_SignageClockWidget> createState() => _SignageClockWidgetState();
}

class _SignageClockWidgetState extends State<_SignageClockWidget> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: widget.accentColor),
            const SizedBox(width: 8),
            Text(
              DateFormat('yyyy/MM/dd (E)  HH:mm:ss', 'ja').format(_currentTime),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
