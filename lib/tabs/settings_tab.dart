import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return Scaffold(
      backgroundColor: dp.currentBgColor,
      appBar: AppBar(
        backgroundColor: dp.currentCardColor,
        elevation: isWhite ? 2 : 0,
        iconTheme: IconThemeData(color: dp.mainTextColor),
        title: Text("画面表示・カラーモード設定", style: TextStyle(color: dp.mainTextColor, fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 28, color: dp.mainTextColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isWhite ? Icons.wb_sunny_rounded : Icons.nightlight_round_rounded, 
                  size: 80, 
                  color: isWhite ? Colors.amber.shade700 : const Color(0xFF00FFCC)
                ),
                const SizedBox(height: 20),
                Text(
                  "背景カラーモード（白・黒）の変更",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dp.mainTextColor, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  "ご使用の環境や明るさのお好みに合わせて、見やすい方のモードをタップしてください。\n※選択したカラーに合わせて、画面内の文字色・カード枠などが全自動で見やすく調整されます。",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: dp.subTextColor, fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 40),

                // 🌟 超直感的な 2大モード選択カード (白 mode vs 黒 mode) - IntrinsicHeightでオーバーフロー絶滅設計！
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ① 🤍 白モード (光反射撃退仕様)
                      Expanded(
                        child: _buildModeCard(
                          title: "☀️ 白モード\n(明るい背景)",
                          subtitle: "【おすすめの場面・特長】\n• 強い照明や蛍光灯による光の反射を防ぎたい場合\n• 紙の書類と同じような見え方で確認したい場合\n• 日中や工場内などの明るい場所での利用に最適",
                          icon: Icons.wb_sunny,
                          accentColor: Colors.amber.shade700,
                          cardColor: Colors.white,
                          textColor: const Color(0xFF0F172A),
                          isSelected: isWhite,
                          onTap: () => dp.setDisplayMode(DisplayMode.pureWhite),
                        ),
                      ),
                      const SizedBox(width: 28),
                      // ② 🌙 黒モード (従来のダーク背景)
                      Expanded(
                        child: _buildModeCard(
                          title: "🌙 黒モード\n(暗い背景・ダーク)",
                          subtitle: "【おすすめの場面・特長】\n• 目を疲れにくくして長時間作業したい場合\n• 従来の引き締まったダーク色の画面が良い場合\n• 夜間や少し暗がりでの使用や節電に最適",
                          icon: Icons.nightlight_round,
                          accentColor: const Color(0xFF00FFCC),
                          cardColor: const Color(0xFF1A1C23),
                          textColor: Colors.white,
                          isSelected: !isWhite,
                          onTap: () => dp.setDisplayMode(DisplayMode.pureDark),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 45),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                    decoration: BoxDecoration(
                      color: isWhite ? const Color(0xFF007799).withOpacity(0.08) : Colors.white10,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isWhite ? const Color(0xFF007799).withOpacity(0.4) : Colors.white24, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: isWhite ? const Color(0xFF007799) : Colors.amberAccent, size: 26),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Text(
                            "ヒント：どちらを選んでも、メニューや集計表の文字がくっきり読める最適な色へ自動切り替えされます。",
                            style: TextStyle(color: dp.mainTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color cardColor,
    required Color textColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withOpacity(0.4),
            width: isSelected ? 3.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? accentColor.withOpacity(0.25) : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 18 : 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Icon(icon, size: 56, color: isSelected ? accentColor : Colors.grey.shade500),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: textColor.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                isSelected ? "✅ 現在選択中" : "このモードに変更する",
                style: TextStyle(
                  color: isSelected ? (accentColor == Colors.white ? Colors.black : Colors.black87) : textColor.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
