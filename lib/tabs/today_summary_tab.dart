import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/data_provider.dart';

class TodaySummaryTab extends StatefulWidget {
  const TodaySummaryTab({super.key});

  @override
  State<TodaySummaryTab> createState() => _TodaySummaryTabState();
}

class _TodaySummaryTabState extends State<TodaySummaryTab> {
  final List<Map<String, String>> _cheerStaff = [
    {"name": "ネコ軍曹", "icon": "😸", "suffix": "ニャ！"},
    {"name": "イヌ隊長", "icon": "🐶", "suffix": "ワン！"},
    {"name": "ウサギ中尉", "icon": "🐰", "suffix": "ぴょん！"},
    {"name": "パンダ上等兵", "icon": "🐼", "suffix": "メエ"},
    {"name": "ライオン将軍", "icon": "🦁", "suffix": "ガオー！"}
  ];

  late Map<String, String> _todayStaff;

  @override
  void initState() {
    super.initState();
    int seed = int.parse(DateFormat('yyyyMMdd').format(DateTime.now()));
    var rand = Random(seed);
    _todayStaff = _cheerStaff[rand.nextInt(_cheerStaff.length)];
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    
    if (data.isLoading && data.todayModels.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1115),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00CCFF)),
              SizedBox(height: 20),
              Text(
                "システムデータ同期中...", 
                style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)
              ),
            ],
          ),
        ),
      );
    }

    DateTime now = DateTime.now();
    String todayStr = DateFormat('yyyy/MM/dd').format(now);
    String dateDisplay = DateFormat('yyyy年 MM月 dd日').format(now);
    List<String> weekdays = ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"];
    String weekdayDisplay = weekdays[now.weekday - 1];

    List<ModelSummary> models = List.from(data.todayModels);
    
    int totalAir = models.fold(0, (sum, item) => sum + item.air);
    int totalClean = models.fold(0, (sum, item) => sum + item.clean);
    int totalSwap = models.fold(0, (sum, item) => sum + item.swap);
    
    int totalTarget = data.airTarget + data.cleanTarget + data.swapTarget;
    int totalDone = totalAir + totalClean + totalSwap;
    double totalProg = totalTarget > 0 ? (totalDone / totalTarget).clamp(0.0, 1.0) : 0.0;

    String sfx = _todayStaff['suffix']!;
    String cheerMsg;
    Color cheerColor;
    if (totalProg == 0) {
      cheerMsg = "準備中$sfx";
      cheerColor = Colors.white70;
    } else if (totalProg < 0.3) {
      cheerMsg = "まずは1台！ここから$sfx";
      cheerColor = const Color(0xFF00CCFF);
    } else if (totalProg < 0.6) {
      cheerMsg = "いいペース$sfx その調子$sfx";
      cheerColor = const Color(0xFF00FFCC);
    } else if (totalProg < 0.9) {
      cheerMsg = "スゴい$sfx 目標まであと少し$sfx";
      cheerColor = Colors.amber;
    } else {
      cheerMsg = "爆速$sfx センター最強$sfx";
      cheerColor = Colors.purpleAccent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateDisplay, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Color(0xFF00CCFF)),
                      const SizedBox(width: 8),
                      Text(weekdayDisplay, style: const TextStyle(fontSize: 18, color: Color(0xFF00CCFF), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 💡 左側：幅を固定(width:350)せず、比率(flex: 3)で全体の3割に設定
                  Expanded(
                    flex: 3, 
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF23262F),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFF33363F)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(_todayStaff['icon']!, style: const TextStyle(fontSize: 32)), 
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text("応援担当: ${_todayStaff['name']}", 
                                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                            Text("${(totalProg * 100).toInt()}%", 
                                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        // 💡 はみ出し防止：FittedBoxで自動縮小
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(cheerMsg, 
                                            style: TextStyle(color: cheerColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: totalProg,
                                backgroundColor: Colors.white10,
                                color: const Color(0xFF00FFCC),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 10),

                        Expanded(child: _buildGiantCard("エアー", totalAir, data.airTarget, const Color(0xFF00CCFF), Icons.air)),
                        const SizedBox(height: 8),
                        Expanded(child: _buildGiantCard("通常清掃", totalClean, data.cleanTarget, const Color(0xFF00FFCC), Icons.cleaning_services)),
                        const SizedBox(height: 8),
                        Expanded(child: _buildGiantCard("筐体交換", totalSwap, data.swapTarget, Colors.amber, Icons.settings_outlined)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // 💡 右側：比率(flex: 7)で全体の7割を割り当て
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1C23),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF33363F)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.list_alt, color: Color(0xFF00FFCC), size: 28),
                              SizedBox(width: 10),
                              Text("本日機種別 詳細内訳", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          // 💡 ヘッダー行：SizedBox(width: 80)などの固定ピクセルをやめ、全てExpanded(flex)で比率分割
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: const [
                                Expanded(flex: 4, child: Text("機種 (メーカー)", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("エアー", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("清掃", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("筐体交換", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("合計台数", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const Divider(color: Color(0xFF33363F), thickness: 1, height: 20),
                          
                          // リスト本体
                          Expanded(
                            child: ListView.builder(
                              itemCount: models.length,
                              itemBuilder: (context, index) {
                                var m = models[index];
                                String displayName = m.maker.isNotEmpty ? "${m.name} (${m.maker})" : m.name;
                                int total = m.totalFinished;

                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFF2D3039), width: 1)),
                                  ),
                                  // 💡 ここもヘッダーと同じ比率(flex)で分割して完璧に縦を揃える
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                      Expanded(
                                        flex: 2, 
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("${m.air}", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: m.air > 0 ? const Color(0xFF00CCFF) : Colors.white38)))
                                      ),
                                      Expanded(
                                        flex: 2, 
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("${m.clean}", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: m.clean > 0 ? const Color(0xFF00FFCC) : Colors.white38)))
                                      ),
                                      Expanded(
                                        flex: 2, 
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("${m.swap}", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: m.swap > 0 ? Colors.amber : Colors.white38)))
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center( // はみ出し防止のためCenter経由で配置
                                          child: Container(
                                            width: double.infinity,
                                            constraints: const BoxConstraints(maxWidth: 100), // 最大幅だけ制限
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2D3243),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF444B63), width: 2),
                                            ),
                                            alignment: Alignment.center,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown, 
                                              child: Text("$total", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white))
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 巨大カード生成ウィジェット
  Widget _buildGiantCard(String label, int value, int target, Color color, IconData icon) {
    double prog = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    String targetType = label == "通常清掃" ? "清掃" : label; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF33363F), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18), 
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              InkWell(
                onTap: () => _showTargetDialog(targetType, target),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("目標 ", style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                      Text(
                        _formatNumber(target), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // 💡 実績数値：はみ出し防止のため Expanded と FittedBox でラップ
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "$value",
                      style: const TextStyle(
                        fontSize: 58, 
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "台",
                  style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          Column( 
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(), 
                  Text(
                    "${(prog * 100).toInt()}%",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: prog,
                  backgroundColor: const Color(0xFF2D3039),
                  color: color,
                  minHeight: 6, 
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
  
  void _showTargetDialog(String type, int currentTarget) {
    TextEditingController ctrl = TextEditingController(text: currentTarget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C23),
        title: Text("$type 目標台数の変更", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: "新しい目標台数", 
            labelStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            suffixText: "台", 
            suffixStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), foregroundColor: Colors.black),
            onPressed: () {
              int? newTarget = int.tryParse(ctrl.text);
              if (newTarget != null && newTarget >= 0) {
                Provider.of<DataProvider>(context, listen: false).updateDailyTarget(type, newTarget);
              }
              Navigator.pop(context);
            },
            child: const Text("確定", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[ 1 ]},',
    );
  }
}