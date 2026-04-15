import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final workers = dataProvider.workerStatsMap.values.toList();
    workers.sort((a, b) => b.level.compareTo(a.level));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1C23),
        title: Text(
          widget.isKioskMode ? "あなたの実績ステータス" : "個人別実績ステータス", 
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 💡 このファイル専用のオンラインインジケーターを配置
          const Center(child: _ConnectionStatusIndicator()), 
          const SizedBox(width: 20),
          
          if (widget.isKioskMode) ...[
            TextButton.icon(
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text("閉じる", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF14161E),
                  border: Border(right: BorderSide(color: Color(0xFF33363F))),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: const [
                          Icon(Icons.people_alt_outlined, color: Color(0xFF00CCFF), size: 28),
                          SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("作業者を選択", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))
                            )
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFF33363F), height: 1),
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
                                color: isSelected ? const Color(0xFF00CCFF).withOpacity(0.15) : Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF00CCFF) : Colors.white10,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected ? const Color(0xFF00CCFF) : Colors.white24,
                                    child: Text(worker.name.isNotEmpty ? worker.name.substring(0, 1) : "?", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(worker.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                        Text("Lv.${worker.level} - ${worker.title}", style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
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
              color: const Color(0xFF0F1115),
              child: _selectedWorker == null 
                  ? const Center(child: Text("左のリストから作業者を選択してください", style: TextStyle(color: Colors.white38, fontSize: 20, fontWeight: FontWeight.bold)))
                  : _buildMainContent(dataProvider), 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(DataProvider provider) {
    var worker = provider.workerStatsMap[_selectedWorker];
    if (worker == null) {
      return const Center(child: Text("該当する作業者のデータがありません", style: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)));
    }

    return Column(
      children: [
        if (!widget.isKioskMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xFF14161E),
              border: Border(bottom: BorderSide(color: Color(0xFF33363F))),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers, color: Color(0xFF00CCFF), size: 28),
                const SizedBox(width: 15),
                Expanded(child: _floorTabButton("1F", "入荷", Icons.warehouse, Colors.blueGrey)),
                const SizedBox(width: 10),
                Expanded(child: _floorTabButton("2F", "梱包", Icons.inventory_2, Colors.blueGrey)),
                const SizedBox(width: 10),
                Expanded(child: _floorTabButton("3F", "検品", Icons.fact_check, Colors.blueGrey)),
                const SizedBox(width: 10),
                Expanded(child: _floorTabButton("4F", "清掃", Icons.cleaning_services, const Color(0xFF00FFCC))),
              ],
            ),
          ),

        Expanded(
          child: _selectedFloor == "4F"
              ? _build4FStatsView(worker) 
              : _buildComingSoonView(),   
        ),
      ],
    );
  }

  Widget _floorTabButton(String floor, String label, IconData icon, Color activeColor) {
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
            color: isSelected ? activeColor : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? activeColor : Colors.white38, size: 20),
              const SizedBox(width: 8),
              Text(
                "$floor $label",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
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

  Widget _buildComingSoonView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, color: Colors.white24, size: 80),
          const SizedBox(height: 20),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("$_selectedFloor の実績データは現在システム構築中です", style: const TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.bold))
            )
          ),
        ],
      ),
    );
  }

  Widget _build4FStatsView(WorkerStats worker) {
    List<double> stats = [
      worker.speedScore,
      worker.qualityScore, 
      worker.techScore,
      worker.staminaScore,
      worker.contributionScore 
    ];
    List<String> labels = ["作業速度\n(SPEED)", "品質スコア\n(QUALITY)", "対応力\n(TECH)", "スタミナ\n(STAMINA)", "貢献度\n(CONTRIB)"];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF14161E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00CCFF).withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFF00CCFF).withOpacity(0.1), blurRadius: 20)],
            ),
            child: Row(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FFCC), width: 3),
                    gradient: const LinearGradient(colors: [Color(0xFF00CCFF), Color(0xFF00FFCC)]),
                  ),
                  child: Center(child: Text("Lv.${worker.level}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black))),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(fit: BoxFit.scaleDown, child: Text(worker.title, style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2))),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(worker.name, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("EXP", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: worker.expProgress, 
                                backgroundColor: Colors.white10,
                                color: const Color(0xFF00CCFF),
                                minHeight: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("NEXT: ${worker.nextExp} pt", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))
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
                    color: const Color(0xFF111319),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF252830)),
                  ),
                  child: AnimatedBuilder(
                    animation: _animValue,
                    builder: (context, child) {
                      List<double> animStats = stats.map((e) => e * _animValue.value).toList();
                      return CustomPaint(
                        painter: RadarChartPainter(animStats, labels, const Color(0xFF00FFCC)),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 30),
              
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _statRow("累計完了台数", "${worker.totalFinished}", "台", Colors.greenAccent),
                    _statRow("獲得ポイント", "${worker.earnedPoints.toInt()}", "pt", Colors.amberAccent),
                    _statRow("対応済み機種数", "${worker.uniqueModels}", "機種", Colors.orangeAccent),
                    _statRow("品質評価スコア", (worker.qualityScore * 100).toStringAsFixed(0), "pt", Colors.purpleAccent),
                    
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("💡 システム分析", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(
                            _getSystemComment(worker), 
                            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)
                          ),
                        ],
                      ),
                    )
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

  Widget _statRow(String label, String value, String unit, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF14161E),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 💡 レーダーチャートを自作描画する CustomPainter
// ----------------------------------------------------
class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;

  RadarChartPainter(this.values, this.labels, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.5; 
    final int sides = values.length;
    final angle = (2 * math.pi) / sides;

    final paintBg = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintValueFill = Paint()
      ..color = color.withOpacity(0.3)
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
      
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.white);
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

      textPainter.text = TextSpan(
        text: labels[j],
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOnline ? Colors.greenAccent : Colors.redAccent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? "Online" : "Offline",
            style: TextStyle(
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}