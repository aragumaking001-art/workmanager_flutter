import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

/// 💡 WorkManager Pro 統一グラスモーフィズム背景ラッパー
/// 近未来的なテック背景（assets/bg_tech_abstract.jpg）に、
/// モード（ピュアホワイト / ダーク）に応じたブラーと半透明オーバーレイを施し、
/// 視認性とリッチな世界観の連続性を両立します。
class AppBackgroundWrapper extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double? whiteAlpha;
  final double? darkAlpha;

  const AppBackgroundWrapper({
    super.key,
    required this.child,
    this.blurSigma = 10.0,
    this.whiteAlpha,
    this.darkAlpha,
  });

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    final effectiveWhiteAlpha = whiteAlpha ?? 0.78;
    final effectiveDarkAlpha = darkAlpha ?? 0.72;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/bg_tech_abstract.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              color: isWhite
                  ? Colors.white.withValues(alpha: effectiveWhiteAlpha)
                  : Colors.black.withValues(alpha: effectiveDarkAlpha),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
