import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'dart:math' as math;
import 'dart:async'; 
import '../providers/data_provider.dart';

class PersonalStatsTab extends StatefulWidget {
  final String? initialWorkerId;
  final bool isKioskMode;

  const PersonalStatsTab({
    super.key, 
    this.initialWorkerId, 
    this.isKioskMode = false, 
  });

  @override
  State<PersonalStatsTab> createState() => _PersonalStatsTabState();
}

class _PersonalStatsTabState extends State<PersonalStatsTab> with SingleTickerProviderStateMixin {
  String? _selectedWorker;
  String _selectedFloor = "4F"; 

  late AnimationController _animController;
  late Animation<double> _animValue;
  Timer? _kioskTimer; 

  @override
  void initState() {
    super.initState();
    _selectedWorker = widget.initialWorkerId;

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animValue = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);

    if (widget.isKioskMode && _selectedWorker != null) {
      _animController.forward(from: 0.0);
      _kioskTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) {
          Navigator.pop(context); 
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _kioskTimer?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final isWhite = dataProvider.displayMode == DisplayMode.pureWhite;
    final workers = dataProvider.workerStatsMap.values.toList();
    workers.sort((a, b) => b.level.compareTo(a.level));

    return Scaffold(
      backgroundColor: dataProvider.currentBgColor,
      appBar: AppBar(
        backgroundColor: dataProvider.currentCardColor,
        elevation: isWhite ? 2 : 0,
        iconTheme: IconThemeData(color: dataProvider.mainTextColor),
        title: Text(
          widget.isKioskMode ? "あなたの実績ステータス" : "個人別実績ステータス", 
          style: TextStyle(fontWeight: FontWeight.bold, color: dataProvider.mainTextColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dataProvider.mainTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 💡 このファイル専用のオンラインインジケーターを配置
          const Center(child: _ConnectionStatusIndicator()), 
          const SizedBox(width: 20),
          
          if (widget.isKioskMode) ...[
            TextButton.icon(
              icon: Icon(Icons.close, color: dataProvider.mainTextColor),
              label: Text("閉じる", style: TextStyle(color: dataProvider.mainTextColor, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
      body: Row(
        children: [
          if (!widget.isKioskMode)
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: dataProvider.currentCardColor,
                  border: Border(right: BorderSide(color: dataProvider.borderColor)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.people_alt_outlined, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("作業者を選択", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dataProvider.mainTextColor))
                            )
                          ),
                        ],
                      ),
                    ),
                    Divider(color: dataProvider.borderColor, height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          var worker = workers[index];
                          bool isSelected = _selectedWorker == worker.id;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedWorker = worker.id;
                                _selectedFloor = "4F"; 
                              });
                              _animController.forward(from: 0.0); 
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: isSelected ? (isWhite ? const Color(0xFF007799).withOpacity(0.12) : const Color(0xFF00CCFF).withOpacity(0.15)) : (isWhite ? Colors.grey.shade100 : Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? (isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)) : dataProvider.borderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected ? (isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)) : (isWhite ? Colors.grey.shade300 : Colors.white24),
                                    child: Text(worker.name.isNotEmpty ? worker.name.substring(0, 1) : "?", style: TextStyle(color: isSelected && isWhite ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(worker.name, style: TextStyle(color: dataProvider.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                        Text("Lv.${worker.level} - ${worker.title}", style: TextStyle(color: dataProvider.subTextColor, fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            flex: widget.isKioskMode ? 10 : 7,
            child: Container(
              color: dataProvider.currentBgColor,
              child: _selectedWorker == null 
                  ? Center(child: Text("左のリストから作業者を選択してください", style: TextStyle(color: dataProvider.subTextColor, fontSize: 20, fontWeight: FontWeight.bold)))
                  : _buildMainContent(dataProvider, isWhite), 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(DataProvider provider, bool isWhite) {
    var worker = provider.workerStatsMap[_selectedWorker];
    if (worker == null) {
      return Center(child: Text("該当する作業者のデータがありません", style: TextStyle(color: provider.mainTextColor, fontSize: 24, fontWeight: FontWeight.bold)));
    }

    return Column(
      children: [
        if (!widget.isKioskMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: provider.currentCardColor,
              border: Border(bottom: BorderSide(color: provider.borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.layers, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
                const SizedBox(width: 15),
                Expanded(child: _floorTabButton("1F", "入荷", Icons.warehouse, isWhite ? Colors.blueGrey.shade700 : Colors.blueGrey, provider, isWhite)),
                const SizedBox(width: 10),
                Expanded(child: _floorTabButton("2F", "梱包", Icons.inventory_2, isWhite ? Colors.blueGrey.shade700 : Colors.blueGrey, provider, isWhite)),
                const SizedBox(width: 10),
                Expanded(child: _floorTabButton("3F", "検品", Icons.fact_check, isWhite ? Colors.blueGrey.shade700 : Colors.blueGrey, provider, isWhite)),
                const SizedBox(width: 10),
                Expanded(child: _floorTabButton("4F", "清掃", Icons.cleaning_services, isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), provider, isWhite)),
              ],
            ),
          ),

        Expanded(
          child: _selectedFloor == "4F"
              ? _build4FStatsView(worker, provider, isWhite) 
              : _buildComingSoonView(provider),   
        ),
      ],
    );
  }

  Widget _floorTabButton(String floor, String label, IconData icon, Color activeColor, DataProvider provider, bool isWhite) {
    bool isSelected = _selectedFloor == floor;

    return InkWell(
      onTap: () {
        setState(() => _selectedFloor = floor);
        if (floor == "4F") {
          _animController.forward(from: 0.0); 
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : provider.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && !isWhite ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? activeColor : provider.subTextColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "$floor $label",
                style: TextStyle(
                  color: isSelected ? provider.mainTextColor : provider.subTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonView(DataProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, color: provider.subTextColor, size: 80),
          const SizedBox(height: 20),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("$_selectedFloor の実績データは現在システム構築中です", style: TextStyle(color: provider.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold))
            )
          ),
        ],
      ),
    );
  }

  Widget _build4FStatsView(WorkerStats worker, DataProvider provider, bool isWhite) {
    int safePoints = (worker.earnedPoints.isNaN || worker.earnedPoints.isInfinite) ? 0 : worker.earnedPoints.toInt();
    double safeQuality = (worker.qualityScore.isNaN || worker.qualityScore.isInfinite) ? 0.0 : worker.qualityScore;
    int safeFinished = (worker.totalFinished.isNaN || worker.totalFinished.isInfinite) ? 0 : worker.totalFinished;

    List<double> stats = [
      worker.speedScore.isNaN || worker.speedScore.isInfinite ? 0.0 : worker.speedScore,
      safeQuality, 
      worker.techScore.isNaN || worker.techScore.isInfinite ? 0.0 : worker.techScore,
      worker.staminaScore.isNaN || worker.staminaScore.isInfinite ? 0.0 : worker.staminaScore,
      worker.contributionScore.isNaN || worker.contributionScore.isInfinite ? 0.0 : worker.contributionScore,
    ];
    List<String> labels = ["作業速度\n(SPEED)", "品質スコア\n(QUALITY)", "対応力\n(TECH)", "稼働力\n(CAPACITY)", "貢献度\n(CONTRIB)"];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: provider.currentCardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF).withOpacity(0.5), width: isWhite ? 2.5 : 2),
              boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))] : [BoxShadow(color: const Color(0xFF00CCFF).withOpacity(0.1), blurRadius: 20)],
            ),
            child: Row(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), width: 3),
                    gradient: LinearGradient(colors: isWhite ? [const Color(0xFF007799).withOpacity(0.2), const Color(0xFF008855).withOpacity(0.2)] : [const Color(0xFF00CCFF), const Color(0xFF00FFCC)]),
                  ),
                  child: Center(child: Text("Lv.${worker.level}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: provider.mainTextColor))),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(fit: BoxFit.scaleDown, child: Text(worker.title, style: TextStyle(color: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2))),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(worker.name, style: TextStyle(color: provider.mainTextColor, fontSize: 40, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text("EXP", style: TextStyle(color: provider.subTextColor, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: worker.expProgress.isNaN || worker.expProgress.isInfinite ? 0.0 : worker.expProgress, 
                                backgroundColor: isWhite ? Colors.grey.shade200 : Colors.white10,
                                color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                                minHeight: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("NEXT: ${worker.nextExp} pt", style: TextStyle(color: provider.subTextColor, fontWeight: FontWeight.bold))
                            )
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 40),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: provider.currentCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: provider.borderColor),
                    boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))] : null,
                  ),
                  child: AnimatedBuilder(
                    animation: _animValue,
                    builder: (context, child) {
                      List<double> animStats = stats.map((e) => e * _animValue.value).toList();
                      return CustomPaint(
                        painter: RadarChartPainter(animStats, stats, labels, isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), provider.mainTextColor, isWhite),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 30),
              
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statRow("累計完了台数", NumberFormat('#,##0').format(safeFinished), "台", isWhite ? const Color(0xFF008855) : Colors.greenAccent, provider, isWhite),
                    _statRow("獲得ポイント", NumberFormat('#,##0').format(safePoints), "pt", isWhite ? Colors.amber.shade800 : Colors.amberAccent, provider, isWhite),
                    _statRow("対応済み機種数", NumberFormat('#,##0').format(worker.uniqueModels), "機種", isWhite ? const Color(0xFFD45500) : Colors.orangeAccent, provider, isWhite),
                    _statRow("品質評価スコア", (safeQuality * 100).toStringAsFixed(0), "pt", isWhite ? Colors.purple.shade700 : Colors.purpleAccent, provider, isWhite),
                    
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isWhite ? Colors.grey.shade100 : Colors.black26,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: provider.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("💡 システム分析", style: TextStyle(color: provider.subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(
                            _getSystemComment(worker), 
                            style: TextStyle(color: provider.mainTextColor, fontSize: 16, height: 1.5)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  String _getSystemComment(WorkerStats w) {
    if (w.level > 50) return "熟練の技術により、すべての指標でトップクラスの成績を叩き出しています。引き続きフロアの牽引をお願いします！";
    if (w.speedScore > 0.8 && w.qualityScore > 0.8) return "圧倒的な作業スピードと高い完結力を両立しています。素晴らしいパフォーマンスです。";
    if (w.speedScore > 0.8) return "非常に速いペースで作業を行っています。このスピードを維持しつつ、さらに様々な機種を触ることで総合力がアップします。";
    if (w.qualityScore > 0.9) return "丁寧な作業で、自分の工程でしっかり完結させる割合が非常に高いです。品質の高さはピカイチです。";
    if (w.techScore > 0.5) return "幅広い機種に対応できる柔軟性があります。特定の機種に偏らないバランスの良いスキルセットを持っています。";
    if (w.contributionScore > 0.7) return "難易度の高い作業を積極的にこなし、フロアのポイント稼ぎ頭として大きく貢献しています！";
    return "着実に経験を積んでいます。まずは作業台数をこなし、レベルアップを目指しましょう！";
  }

  Widget _statRow(String label, String value, String unit, Color color, DataProvider provider, bool isWhite) {
    return Container(
      constraints: const BoxConstraints(minHeight: 85),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : provider.currentCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWhite ? Colors.grey.shade300 : provider.borderColor,
          width: 1.5,
        ),
        boxShadow: isWhite
            ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label, 
                    style: TextStyle(color: provider.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "$value $unit", 
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<double> targetValues;
  final List<String> labels;
  final Color color;
  final Color textColor;
  final bool isWhite;

  RadarChartPainter(this.values, this.targetValues, this.labels, this.color, this.textColor, this.isWhite);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 40;
    final int sides = values.length;
    final angle = (2 * math.pi) / sides;

    final paintBg = Paint()
      ..color = isWhite ? Colors.grey.withOpacity(0.35) : Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintValueFill = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final paintValueStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (int i = 1; i <= 5; i++) {
      final r = radius * (i / 5);
      final path = Path();
      for (int j = 0; j < sides; j++) {
        final x = center.dx + r * math.cos(angle * j - math.pi / 2);
        final y = center.dy + r * math.sin(angle * j - math.pi / 2);
        if (j == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paintBg);
    }

    for (int j = 0; j < sides; j++) {
      final x = center.dx + radius * math.cos(angle * j - math.pi / 2);
      final y = center.dy + radius * math.sin(angle * j - math.pi / 2);
      canvas.drawLine(center, Offset(x, y), paintBg);
    }

    final valuePath = Path();
    for (int j = 0; j < sides; j++) {
      final r = radius * values[j];
      final x = center.dx + r * math.cos(angle * j - math.pi / 2);
      final y = center.dy + r * math.sin(angle * j - math.pi / 2);
      if (j == 0) valuePath.moveTo(x, y);
      else valuePath.lineTo(x, y);
      
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = isWhite ? textColor : Colors.white);
      canvas.drawCircle(Offset(x, y), 8, Paint()..color = color.withOpacity(0.5));
    }
    valuePath.close();
    canvas.drawPath(valuePath, paintValueFill);
    canvas.drawPath(valuePath, paintValueStroke);

    final textPainter = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    for (int j = 0; j < sides; j++) {
      final r = radius + 35;
      final x = center.dx + r * math.cos(angle * j - math.pi / 2);
      final y = center.dy + r * math.sin(angle * j - math.pi / 2);

      int score = (targetValues[j] * 100).round();
      textPainter.text = TextSpan(
        children: [
          TextSpan(text: "${labels[j]}\n", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          TextSpan(text: "$score", style: TextStyle(color: isWhite ? const Color(0xFF007799) : Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      );
      textPainter.layout();
      
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ----------------------------------------------------------------------
// 💡 このファイル専用のオンライン/オフライン バッジ
// ----------------------------------------------------------------------
class _ConnectionStatusIndicator extends StatelessWidget {
  const _ConnectionStatusIndicator();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final bool isOnline = data.isOnline;
    final bool isWhite = data.displayMode == DisplayMode.pureWhite;

    final Color activeColor = isOnline 
        ? (isWhite ? const Color(0xFF008844) : Colors.greenAccent)
        : (isWhite ? const Color(0xFFCC0033) : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isWhite ? activeColor.withOpacity(0.12) : activeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withOpacity(isWhite ? 0.8 : 0.6), width: isWhite ? 2.0 : 1.5),
        boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : null,
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
  }
}