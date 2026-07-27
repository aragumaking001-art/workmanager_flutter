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
    final isWhite = data.displayMode == DisplayMode.pureWhite;
    
    if (data.isLoading && data.todayModels.isEmpty) {
      return Scaffold(
        backgroundColor: data.currentBgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)),
              const SizedBox(height: 20),
              Text(
                "システムデータ同期中...", 
                style: TextStyle(color: data.subTextColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)
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
      cheerColor = data.subTextColor;
    } else if (totalProg < 0.3) {
      cheerMsg = "まずは1台！ここから$sfx";
      cheerColor = isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF);
    } else if (totalProg < 0.6) {
      cheerMsg = "いいペース$sfx その調子$sfx";
      cheerColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
    } else if (totalProg < 0.9) {
      cheerMsg = "スゴい$sfx 目標まであと少し$sfx";
      cheerColor = isWhite ? Colors.amber.shade800 : Colors.amber;
    } else {
      cheerMsg = "爆速$sfx センター最強$sfx";
      cheerColor = isWhite ? Colors.purple.shade700 : Colors.purpleAccent;
    }

    return Scaffold(
      backgroundColor: data.currentBgColor,
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
                  Text(dateDisplay, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: data.mainTextColor)),
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)),
                      const SizedBox(width: 8),
                      Text(weekdayDisplay, style: TextStyle(fontSize: 18, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3, 
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: data.currentCardColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: data.borderColor),
                            boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))] : null,
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
                                              style: TextStyle(color: data.subTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                            Text("${(totalProg * 100).toInt()}%", 
                                              style: TextStyle(color: data.subTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
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
                                backgroundColor: isWhite ? Colors.grey.shade200 : Colors.white10,
                                color: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 10),

                        Expanded(child: _buildGiantCard("エアー", totalAir, data.airTarget, isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), Icons.air, data, isWhite)),
                        const SizedBox(height: 8),
                        Expanded(child: _buildGiantCard("通常清掃", totalClean, data.cleanTarget, isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), Icons.cleaning_services, data, isWhite)),
                        const SizedBox(height: 8),
                        Expanded(child: _buildGiantCard("筐体交換", totalSwap, data.swapTarget, isWhite ? Colors.amber.shade800 : Colors.amber, Icons.settings_outlined, data, isWhite)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: data.currentCardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: data.borderColor),
                        boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))] : null,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.list_alt, color: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), size: 28),
                              const SizedBox(width: 10),
                              Text("本日機種別 詳細内訳", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: data.mainTextColor)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text("機種 (メーカー)", style: TextStyle(color: data.subTextColor, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("エアー", textAlign: TextAlign.center, style: TextStyle(color: data.subTextColor, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("清掃", textAlign: TextAlign.center, style: TextStyle(color: data.subTextColor, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("筐体交換", textAlign: TextAlign.center, style: TextStyle(color: data.subTextColor, fontSize: 18, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text("合計台数", textAlign: TextAlign.center, style: TextStyle(color: data.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          Divider(color: data.borderColor, thickness: 1, height: 20),
                          
                          Expanded(
                            child: ListView.builder(
                              itemCount: models.length,
                              itemBuilder: (context, index) {
                                var m = models[index];
                                String displayName = m.maker.isNotEmpty ? "${m.name} (${m.maker})" : m.name;
                                int total = m.totalFinished;

                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: isWhite ? Colors.grey.shade200 : const Color(0xFF2D3039), width: 1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(displayName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: data.mainTextColor)),
                                      ),
                                      Expanded(
                                        flex: 2, 
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("${m.air}", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: m.air > 0 ? (isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)) : data.subTextColor)))
                                      ),
                                      Expanded(
                                        flex: 2, 
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("${m.clean}", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: m.clean > 0 ? (isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC)) : data.subTextColor)))
                                      ),
                                      Expanded(
                                        flex: 2, 
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("${m.swap}", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: m.swap > 0 ? (isWhite ? Colors.amber.shade800 : Colors.amber) : data.subTextColor)))
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            width: double.infinity,
                                            constraints: const BoxConstraints(maxWidth: 100),
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isWhite ? Colors.grey.shade100 : const Color(0xFF2D3243),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isWhite ? Colors.grey.shade400 : const Color(0xFF444B63), width: 2),
                                            ),
                                            alignment: Alignment.center,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown, 
                                              child: Text("$total", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: data.mainTextColor))
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

  Widget _buildGiantCard(String label, int value, int target, Color color, IconData icon, DataProvider data, bool isWhite) {
    double prog = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    String targetType = label == "通常清掃" ? "清掃" : label; 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: data.currentCardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isWhite ? color.withOpacity(0.5) : const Color(0xFF33363F), width: 2),
        boxShadow: isWhite ? [BoxShadow(color: color.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))] : null,
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
                onTap: () => _showTargetDialog(targetType, target, data, isWhite),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWhite ? Colors.grey.shade100 : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isWhite ? Colors.grey.shade300 : Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("目標 ", style: TextStyle(fontSize: 14, color: data.subTextColor, fontWeight: FontWeight.bold)),
                      Text(
                        _formatNumber(target), 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: data.mainTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
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
                      style: TextStyle(
                        fontSize: 58, 
                        fontWeight: FontWeight.w900,
                        color: data.mainTextColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "台",
                  style: TextStyle(fontSize: 18, color: data.subTextColor, fontWeight: FontWeight.bold),
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
                  backgroundColor: isWhite ? Colors.grey.shade200 : const Color(0xFF2D3039),
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
  
  void _showTargetDialog(String type, int currentTarget, DataProvider data, bool isWhite) {
    TextEditingController ctrl = TextEditingController(text: currentTarget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: data.currentCardColor,
        title: Text("$type 目標台数の変更", style: TextStyle(color: data.mainTextColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: data.mainTextColor, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: "新しい目標台数", 
            labelStyle: TextStyle(color: data.subTextColor, fontWeight: FontWeight.bold),
            suffixText: "台", 
            suffixStyle: TextStyle(color: data.subTextColor, fontWeight: FontWeight.bold),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("キャンセル", style: TextStyle(color: data.mainTextColor, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), foregroundColor: isWhite ? Colors.white : Colors.black),
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