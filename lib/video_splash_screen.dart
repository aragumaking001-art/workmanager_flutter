import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'main.dart'; // メイン画面（MainLayout, KioskWaitScreen, AppModeなど）が定義されているファイル

class VideoSplashScreen extends StatefulWidget {
  // 💡 main.dart から受け取る変数
  final AppMode appMode;
  final String ipAddress;

  const VideoSplashScreen({
    super.key, 
    required this.appMode, 
    required this.ipAddress
  });

  @override
  _VideoSplashScreenState createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // 動画の初期化
    _controller = VideoPlayerController.asset('assets/videos/splash_logo.mp4')
      ..initialize().then((_) {
        setState(() {
          _isReady = true; 
        });
        _controller.play();
      });

    // 再生完了後のリスナー
    _controller.addListener(() {
      // 💡 エラー回避のため、初期化されているかどうかのチェックを追加
      if (!_controller.value.isInitialized) return;

      // 💡 durationから少し（例：50ミリ秒）引いた時間を基準にする
      final bool isNearEnd = _controller.value.position >= 
          (_controller.value.duration - const Duration(milliseconds: 50));

      if (isNearEnd) {
        // すでに遷移開始していれば何もしないためのガード
        if (!_isReady) return; 

        setState(() {
          _isReady = false; 
        });

        // 💡 ① モード判定：受け取ったモードによって行き先を変える！
        Widget nextScreen;
        if (widget.appMode == AppMode.kiosk) {
          // 現場用（キオスク）モードならNFC待機画面へ
          nextScreen = KioskWaitScreen(ipAddress: widget.ipAddress);
        } else {
          // 監理者・マネージャモードなら今まで通りダッシュボードへ
          nextScreen = MainLayout(appMode: widget.appMode);
        }

        // 💡 ② 画面遷移を実行
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 100), // ふんわり切り替わるように少し長めに
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115), 
      body: Center(
        child: (_isReady && _controller.value.isPlaying)
            ? SizedBox.expand( // 💡 画面いっぱいに広げる
                child: FittedBox(
                  fit: BoxFit.cover, // 💡 隙間なく埋める（比率を保ちつつ切り抜き）
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : Container(), 
      ),
    );
  }
}