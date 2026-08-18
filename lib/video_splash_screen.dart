import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'main.dart'; // メイン画面（MainLayout, AppModeなど）が定義されているファイル
import 'tabs/kiosk_screen.dart';

class VideoSplashScreen extends StatefulWidget {
  // 💡 main.dart から受け取る変数
  final AppMode appMode;
  final String ipAddress;

  const VideoSplashScreen({
    super.key,
    required this.appMode,
    required this.ipAddress,
  });

  @override
  _VideoSplashScreenState createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  VideoPlayerController? _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();

    // 💡 Windowsなどのデスクトップ環境ではvideo_playerプラグインがサポートされていないためスキップする
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToNextScreen();
      });
      return;
    }

    // 安全装置：もし10秒経っても動画が終わらなければ（エラー等で真っ暗なら）強制的に次へ
    // タブレット等で読み込みに3秒以上かかる場合があるため長めに設定
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isReady == false) {
        _navigateToNextScreen();
      }
    });

    // 動画の初期化を別メソッドで行う
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/splash_logo.mp4');
      await _controller!.initialize();
      
      if (!mounted) return;
      
      setState(() {
        _isReady = true;
      });
      
      // リスナーの追加
      _controller!.addListener(() {
        if (!_controller!.value.isInitialized) return;
        if (_controller!.value.position.inMilliseconds < 1000) return;

        final bool isNearEnd =
            _controller!.value.position >=
            (_controller!.value.duration - const Duration(milliseconds: 50));

        if (isNearEnd) {
          if (!_isReady) return;
          setState(() {
            _isReady = false;
          });
          _navigateToNextScreen();
        }
      });
      
      await _controller!.play();
      
    } catch (e) {
      print("Video init exception: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("動画再生エラー: $e"), duration: const Duration(seconds: 5))
        );
        // エラーを読めるように3秒待ってから遷移
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _navigateToNextScreen();
        });
      }
    }
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    Widget nextScreen;
    if (widget.appMode == AppMode.kiosk) {
      nextScreen = const KioskScreen();
    } else {
      nextScreen = MainLayout(appMode: widget.appMode);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1115),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Center(
        child: _controller!.value.isInitialized
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            : Container(),
      ),
    );
  }
}
