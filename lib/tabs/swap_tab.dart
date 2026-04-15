import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/data_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class SwapTab extends StatefulWidget {
  const SwapTab({super.key});

  @override
  State<SwapTab> createState() => _SwapTabState();
}

class _SwapTabState extends State<SwapTab> {
  String _rankMode = "Week";
  int _targetCount = 50; 

  DateTime? _customStart;
  DateTime? _customEnd;
  bool _isFirstFrame = true;

  final List<Map<String, dynamic>> _charList = [
    {"name": "ネコ軍曹", "emojis": ["🐱💤", "🐈🐾", "😸✨", "😼🔥", "😻🏆"], "msgs": ["日向ぼっこ中ニャ", "筐体を入れ替えるニャ！", "ネジの締め忘れ注意ニャ！", "職人技だニャ！", "完璧な交換作業ニャ！"]},
    {"name": "情熱のライオン", "emojis": ["🦁💤", "🦁🔥", "🦁📢", "🦁💪", "🦁👑"], "msgs": ["王はまだ眠っている…", "パワーで入れ替えろ！", "集中しろ！ミスは許されん！", "魂を込めて組み上げろ！", "伝説のエンジニア誕生だ！"]},
    {"name": "癒やしのパンダ", "emojis": ["🐼💤", "🐼🍃", "🐼✨", "🐼💝", "🐼🎊"], "msgs": ["まだ夢の中だよ…", "ゆっくり丁寧にね〜", "部品を大切に扱おうね", "その調子、いい感じだよ", "お疲れ様！ピカピカになったね"]},
    {"name": "爆走ウサギ", "emojis": ["🐰💤", "🐰🥕", "🐇💨", "🐇💥", "🐇🚀"], "msgs": ["耳だけ起きてるよ", "スピード交換！ぴょんぴょん！", "電光石火の組み換え！", "音速を超えていけ！", "神速の50台達成！"]}
  ];
  late Map<String, dynamic> _todayChar;

  @override
  void initState() {
    super.initState();
    final seed = int.parse(DateFormat('yyyyMMdd').format(DateTime.now()));
    _todayChar = _charList[ Random(seed).nextInt(_charList.length) ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRankingRange();
      if (mounted) {
        setState(() => _isFirstFrame = false);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    DateTime _focusedDay = DateTime.now();
    DateTime? _start = _customStart;
    DateTime? _end = _customEnd;

    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Container(
                width: 550,
                height: 700,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C23),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      const Text(
                        "ランキング期間選択",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 15),
                      TableCalendar(
                        locale: 'ja_JP',
                        firstDay: DateTime(2024),
                        lastDay: DateTime(2030),
                        focusedDay: _focusedDay,
                        rangeStartDay: _start,
                        rangeEndDay: _end,
                        rangeSelectionMode: RangeSelectionMode.enforced,
                        onRangeSelected: (start, end, focusedDay) {
                          setDialogState(() {
                            _start = start;
                            _end = end;
                            _focusedDay = focusedDay;
                          });
                        },
                        calendarStyle: const CalendarStyle(
                          rangeStartDecoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          rangeEndDecoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          rangeHighlightColor: Color(0x33FFC107),
                          todayDecoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                          defaultTextStyle: TextStyle(color: Colors.white, fontSize: 22),
                          outsideTextStyle: TextStyle(color: Colors.white24, fontSize: 22),
                          weekendTextStyle: TextStyle(color: Colors.redAccent, fontSize: 22),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.amber, size: 40),
                          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.amber, size: 40),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("キャンセル", style: TextStyle(color: Colors.white54, fontSize: 20)),
                          ),
                          const SizedBox(width: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            ),
                            onPressed: () {
                              if (_start != null && _end != null) {
                                Navigator.pop(context, {"start": _start, "end": _end});
                              }
                            },
                            child: const Text("決定", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _rankMode = "Custom";
        _customStart = result[ "start" ];
        _customEnd = result[ "end" ];
      });
      Provider.of<DataProvider>(context, listen: false).setRankingPeriod(_customStart!, _customEnd!);
    }
  }

  void _updateRankingRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); 
    DateTime? start;
    DateTime? end;

    if (_rankMode == "Day") { 
      start = today; 
      end = today; 
    } else if (_rankMode == "Week") {
      int daysSinceSunday = (today.weekday % 7);
      start = today.subtract(Duration(days: daysSinceSunday + 7)); 
      end = start.add(const Duration(days: 6));
    } else if (_rankMode == "Month") {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0);
    }

    if (start != null && end != null) {
      Provider.of<DataProvider>(context, listen: false).setRankingPeriod(start, end);
    }
  }

  Map<String, String> _getCheerContent(double progress) {
    List<String> emojis = List<String>.from(_todayChar[ "emojis" ]);
    List<String> msgs = List<String>.from(_todayChar[ "msgs" ]);
    if (progress <= 0) return {"emoji": emojis[ 0 ], "msg": msgs[ 0 ]};
    if (progress < 0.4) return {"emoji": emojis[ 1 ], "msg": msgs[ 1 ]};
    if (progress < 0.8) return {"emoji": emojis[ 2 ], "msg": msgs[ 2 ]};
    if (progress < 1.0) return {"emoji": emojis[ 3 ], "msg": msgs[ 3 ]};
    return {"emoji": emojis[ 4 ], "msg": msgs[ 4 ]};
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final bool isBusy = _isFirstFrame || dataProvider.isLoading;

    final workerRanks = isBusy ? <WorkerRank>[] : dataProvider.swapWorkerRanks;
    final cleanedModels = dataProvider.todayModels.where((m) => m.swap > 0).toList();

    int todayTotal = 0;
    for (var model in cleanedModels) {
      todayTotal += model.swap;
    }

    double progressVal = _targetCount > 0 ? (todayTotal / _targetCount) : 0.0;
    if (progressVal > 1.0) progressVal = 1.0;
    final cheer = _getCheerContent(progressVal);

    const accentColor = Colors.amber; 

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C23),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.published_with_changes_rounded, color: accentColor, size: 30),
                    const SizedBox(width: 10),
                    const Text("筐体交換 ランキング", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 15),
                    Text(_getPeriodLabel(), style: const TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: "Day", label: Text("当日")),
                        ButtonSegment(value: "Week", label: Text("週間")),
                        ButtonSegment(value: "Month", label: Text("月間")),
                        ButtonSegment(value: "Custom", label: Text("期間")),
                      ],
                      selected: {_rankMode},
                      onSelectionChanged: (Set<String> newSelection) {
                        String mode = newSelection.first;
                        if (mode == "Custom") { _pickCustomRange(); }
                        else {
                          setState(() { _rankMode = mode; _updateRankingRange(); });
                        }
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) return accentColor;
                          return Colors.transparent;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) return Colors.black;
                          return Colors.white;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildRankingColumn(0, workerRanks, accentColor)),
                      const VerticalDivider(color: Color(0xFF33363F), width: 30),
                      Expanded(child: _buildRankingColumn(10, workerRanks, accentColor)),
                      const VerticalDivider(color: Color(0xFF33363F), width: 30),
                      Expanded(child: _buildRankingColumn(20, workerRanks, accentColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF23262F),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note, color: accentColor, size: 28),
                  const SizedBox(width: 10),
                  Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const Divider(color: Color(0xFF33363F), height: 20),
              Text("応援担当: ${_todayChar[ 'name' ]}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 5),
              Text(cheer[ "emoji" ]!, style: const TextStyle(fontSize: 60)),
              Text(cheer[ "msg" ]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
              const Divider(color: Color(0xFF33363F), height: 20),
              const Text("🏁 本日目標 (筐体交換)", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(todayTotal.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: accentColor)),
                  const Text(" / ", style: TextStyle(fontSize: 20, color: Colors.white54)),
                  InkWell(
                    onTap: _showTargetDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)),
                      child: Text(_targetCount.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor)),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("本日進捗: ", style: TextStyle(color: Colors.white70)),
                  Text("${(progressVal * 100).toInt()}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressVal,
                  minHeight: 15,
                  backgroundColor: const Color(0xFF2D3039),
                  color: const Color(0xFFFFD700),
                ),
              ),
              const Divider(color: Color(0xFF33363F), height: 30),
              Row(
                children: const [
                  Text("♻️ ", style: TextStyle(fontSize: 20)),
                  Text("本日交換実績", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: cleanedModels.isEmpty
                    ? const Center(child: Text("実績待ちニャ...", style: TextStyle(color: Colors.white24)))
                    : ListView.builder(
                        itemCount: cleanedModels.length,
                        itemBuilder: (context, index) {
                          final m = cleanedModels[ index ];
                          String displayAbbr = (m.maker.isNotEmpty && m.maker != "null") ? "(${m.maker})" : "";
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D3039)))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(child: Text(m.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 6),
                                      Text(displayAbbr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                Text("${m.swap}台", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTargetDialog() {
    TextEditingController ctrl = TextEditingController(text: _targetCount.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C23),
        title: const Text("目標の変更", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl, 
          keyboardType: TextInputType.number, 
          style: const TextStyle(color: Colors.white), 
          decoration: const InputDecoration(labelText: "目標台数", suffixText: "台", border: OutlineInputBorder())
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            // 💡 修正：accentColor ではなく Colors.amber を使う
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), 
            onPressed: () {
              int? newTarget = int.tryParse(ctrl.text);
              if (newTarget != null && newTarget > 0) { setState(() => _targetCount = newTarget); }
              Navigator.pop(context);
            }, 
            child: const Text("確定")
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    if (_rankMode == "Day") return "(当日: ${DateFormat('MM/dd').format(now)})";
    if (_rankMode == "Week") {
      final start = now.subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 5));
      return "(${DateFormat('MM/dd').format(start)} ～ ${DateFormat('MM/dd').format(end)})";
    }
    if (_rankMode == "Month") {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      return "(${DateFormat('MM/dd').format(start)} ～ ${DateFormat('MM/dd').format(end)})";
    }
    if (_rankMode == "Custom" && _customStart != null && _customEnd != null) return "(${DateFormat('MM/dd').format(_customStart!)} ～ ${DateFormat('MM/dd').format(_customEnd!)})";
    return "";
  }

  Widget _buildRankingColumn(int startIndex, List<WorkerRank> ranks, Color color) {
    if (ranks.isEmpty) {
      if (startIndex == 0) return const Center(child: Text("データがありません", style: TextStyle(color: Colors.white24)));
      return const SizedBox.shrink();
    }
    double maxPt = ranks[ 0 ].points;
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        int actualIndex = startIndex + index;
        if (actualIndex >= ranks.length) return const SizedBox.shrink();
        var worker = ranks[ actualIndex ];
        String rankEmoji = ""; Color barColor = color; Color nameColor = Colors.white;
        String displayName = worker.name.isNotEmpty ? worker.name : "ID: ${worker.id}";
        if (worker.isLucky) { rankEmoji = "✨"; nameColor = const Color(0xFFFFD700); }
        if (actualIndex == 0) { rankEmoji = "🥇 "; barColor = const Color(0xFFFFD700); }
        else if (actualIndex == 1) { rankEmoji = "🥈 "; barColor = const Color(0xC0C0C0); }
        else if (actualIndex == 2) { rankEmoji = "🥉 "; barColor = const Color(0xCD7F32); }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildNeonBar(actualIndex + 1, displayName, worker.points, maxPt, barColor, rankEmoji, nameColor),
        );
      },
    );
  }

  Widget _buildNeonBar(int rank, String name, double pt, double maxPt, Color color, String emoji, Color nameColor) {
    double percent = maxPt > 0 ? (pt / maxPt) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              Text(name, style: TextStyle(fontSize: name.length > 6 ? 16 : 20, fontWeight: FontWeight.bold, color: nameColor)),
              const Text(" さん", style: TextStyle(fontSize: 14, color: Colors.white38)),
            ]),
            Text("${pt.toStringAsFixed(1)}pt", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(builder: (context, constraints) {
          return Stack(children: [
            Container(height: 18, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10))),
            AnimatedContainer(duration: const Duration(milliseconds: 1000), curve: Curves.easeOutExpo, height: 18, width: constraints.maxWidth * percent, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)])),
          ]);
        }),
      ],
    );
  }
}