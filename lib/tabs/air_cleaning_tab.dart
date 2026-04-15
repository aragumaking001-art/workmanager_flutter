import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/data_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class AirCleaningTab extends StatefulWidget {
  const AirCleaningTab({super.key});

  @override
  State<AirCleaningTab> createState() => _AirCleaningTabState();
}

class _AirCleaningTabState extends State<AirCleaningTab> {
  String _rankMode = "Week";
  int _targetCount = 1500; 

  DateTime? _customStart;
  DateTime? _customEnd;

  bool _isFirstFrame = true;

  // キャラクターのメッセージもエアー用に微調整
  final List<Map<String, dynamic>> _charList = [
    {"name": "ネコ軍曹", "emojis": ["🐱💤", "🐈🐾", "😸✨", "😼🔥", "😻🏆"], "msgs": ["日向ぼっこ中ニャ", "エアーでホコリを飛ばすニャ！", "いいリズムだニャ！", "奥までしっかり吹くニャ！", "目標達成！ピカピカニャ！"]},
    {"name": "情熱のライオン", "emojis": ["🦁💤", "🦁🔥", "🦁📢", "🦁💪", "🦁👑"], "msgs": ["王はまだ眠っている…", "エアー全開！吼えろ！", "熱い！現場の熱気が伝わるぞ！", "限界を超えろ！一気に飛ばせ！", "完全制覇！君こそ真の王（MVP）だ！"]},
    {"name": "癒やしのパンダ", "emojis": ["🐼💤", "🐼🍃", "🐼✨", "🐼💝", "🐼🎊"], "msgs": ["まだ夢の中だよ…", "笹を食べて準備万端！", "エアーの音が心地いいね〜", "もうすぐ終わるよ、ファイト！", "目標達成！今日はゆっくり休もうね"]},
    {"name": "爆走ウサギ", "emojis": ["🐰💤", "🐰🥕", "🐇💨", "🐇💥", "🐇🚀"], "msgs": ["耳だけ起きてるよ", "栄養補給（人参）完了！", "風を感じる速さだ！ぴょんぴょん！", "加速装置オン！ホコリを置き去りに！", "1500台突破！光の速さだったね！"]}
  ];
  late Map<String, dynamic> _todayChar;

  @override
  void initState() {
    super.initState();
    final seed = int.parse(DateFormat('yyyyMMdd').format(DateTime.now()));
    _todayChar = _charList[ Random(seed).nextInt(_charList.length) ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRankingRange();
      // 💡 追加：最初の描画指令が終わったらフラグを下ろす
      if (mounted) {
        setState(() {
          _isFirstFrame = false;
        });
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
                  border: Border.all(color: const Color(0xFF00CCFF), width: 2), // 💡 エアーは青（シアン）
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
                          rangeStartDecoration: BoxDecoration(color: Color(0xFF00CCFF), shape: BoxShape.circle),
                          rangeEndDecoration: BoxDecoration(color: Color(0xFF00CCFF), shape: BoxShape.circle),
                          rangeHighlightColor: Color(0x3300CCFF),
                          todayDecoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                          defaultTextStyle: TextStyle(color: Colors.white, fontSize: 22),
                          outsideTextStyle: TextStyle(color: Colors.white24, fontSize: 22),
                          weekendTextStyle: TextStyle(color: Colors.redAccent, fontSize: 22),
                        ),
                        calendarBuilders: CalendarBuilders(
                          dowBuilder: (context, day) {
                            if (day.weekday == DateTime.saturday) {
                              return const Center(child: Text('土', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 20)));
                            }
                            if (day.weekday == DateTime.sunday) {
                              return const Center(child: Text('日', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 20)));
                            }
                            return null;
                          },
                          defaultBuilder: (context, day, focusedDay) {
                            if (day.weekday == DateTime.saturday) {
                              return Center(child: Text('${day.day}', style: const TextStyle(color: Colors.blueAccent, fontSize: 22)));
                            }
                            return null;
                          },
                        ),
                        daysOfWeekHeight: 50,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF00CCFF), size: 40),
                          rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF00CCFF), size: 40),
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
                              backgroundColor: const Color(0xFF00CCFF),
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
      // 💡 日曜日（weekday=7）を週の始まりとして 3/29 を含めるロジック
      // 今日が日曜ならその日を起点に。それ以外なら前の月曜まで遡る
      int daysSinceSunday = (today.weekday % 7); // 日=0, 月=1, ... 土=6
      start = today.subtract(Duration(days: daysSinceSunday)); // これで 4/5(日) なら 4/5 が起点
      
      // 💡 もし「今日(4/5)が開いた時に 3/29 からの1週間が見たい」なら以下
      start = start.subtract(const Duration(days: 7)); // 強制的に1週間前から表示
      
      end = start.add(const Duration(days: 6)); // 日〜土の7日間
    }

    if (start != null && end != null) {
      Provider.of<DataProvider>(context, listen: false).setRankingPeriod(start, end);
    }
  }

  Map<String, String> _getCheerContent(double progress) {
    List<String> emojis = List<String>.from(_todayChar["emojis"]);
    List<String> msgs = List<String>.from(_todayChar["msgs"]);
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

    // 💡 左側のランキング用：忙しい時は「空っぽ」にして残像を防ぐ
    final workerRanks = isBusy ? <WorkerRank>[] : dataProvider.airWorkerRanks; 

    // 💡 右側の本日実績用：チカチカを防ぐため、常に現在の貯金箱の中身をそのまま使う
    // (DataProvider側でクリア処理を消していれば、これで残像が残りつつチカチカしなくなります)
    final cleanedModels = dataProvider.todayModels.where((m) => m.air > 0).toList(); 

    int todayTotal = 0;
    for (var model in cleanedModels) {
      todayTotal += model.air; 
    }

    double progressVal = _targetCount > 0 ? (todayTotal / _targetCount) : 0.0;
    if (progressVal > 1.0) progressVal = 1.0;
    final cheer = _getCheerContent(progressVal);

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
                    const Icon(Icons.air_rounded, color: Color(0xFF00CCFF), size: 30),
                    const SizedBox(width: 10),
                    const Text("エアー清掃 ランキング", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
                          if (states.contains(WidgetState.selected)) return const Color(0xFF00CCFF);
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
                      Expanded(child: _buildRankingColumn(0, workerRanks)),
                      const VerticalDivider(color: Color(0xFF33363F), width: 30),
                      Expanded(child: _buildRankingColumn(10, workerRanks)),
                      const VerticalDivider(color: Color(0xFF33363F), width: 30),
                      Expanded(child: _buildRankingColumn(20, workerRanks)),
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
                  const Icon(Icons.event_note, color: Color(0xFF00CCFF), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('yyyy/MM/dd').format(DateTime.now()), 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                ],
              ),
              const Divider(color: Color(0xFF33363F), height: 20),
              Text("応援担当: ${_todayChar['name']}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 5),
              Text(cheer["emoji"]!, style: const TextStyle(fontSize: 60)),
              Text(cheer["msg"]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00CCFF))),
              const Divider(color: Color(0xFF33363F), height: 20),
              const Text("🏁 本日目標 (エアー)", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(todayTotal.toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF00CCFF))),
                  const Text(" / ", style: TextStyle(fontSize: 20, color: Colors.white54)),
                  InkWell(
                    onTap: _showTargetDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5)),
                      child: Text(_targetCount.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00CCFF))),
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
                  Text("🌬️ ", style: TextStyle(fontSize: 20)),
                  Text("本日エアー実績", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00CCFF))),
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
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D3039)))),
                            child: Row(
                              children: [
                                Expanded(child: Text(m.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 6),
                                Text(m.maker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                const Spacer(),
                                Text("${m.air}台", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00CCFF))),
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
        title: const Text("エアー清掃 目標の変更", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "目標台数", suffixText: "台", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00CCFF), foregroundColor: Colors.black),
            onPressed: () {
              int? newTarget = int.tryParse(ctrl.text);
              if (newTarget != null && newTarget > 0) { setState(() => _targetCount = newTarget); }
              Navigator.pop(context);
            },
            child: const Text("確定"),
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
    if (_rankMode == "Custom" && _customStart != null && _customEnd != null) {
      return "(${DateFormat('MM/dd').format(_customStart!)} ～ ${DateFormat('MM/dd').format(_customEnd!)})";
    }
    return "";
  }

  Widget _buildRankingColumn(int startIndex, List<WorkerRank> ranks) {
    // 💡 超重要：DataProviderが読み込み中の時は、古いデータを無視して空を返す
    // これにより、タブ切り替え時の「残像」が100%消えます。
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    if (dataProvider.isLoading) {
      return const SizedBox.shrink(); 
    }

    // ポイントが 0 より大きい人だけに絞り込む
    final activeRanks = ranks.where((r) => r.points > 0).toList();

    if (activeRanks.isEmpty) {
      if (startIndex == 0) return const Center(child: Text("データがありません", style: TextStyle(color: Colors.white24)));
      return const SizedBox.shrink();
    }

    // 💡 以下、activeRanks を使うように書き換え
    double maxPt = activeRanks[ 0 ].points;
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        int actualIndex = startIndex + index;
        if (actualIndex >= activeRanks.length) return const SizedBox.shrink();
        
        var worker = activeRanks[ actualIndex ];
        String rankEmoji = "";
        Color barColor = const Color(0xFF00CCFF);
        Color nameColor = Colors.white;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                Text(name, style: TextStyle(fontSize: name.length > 6 ? 16 : 20, fontWeight: FontWeight.bold, color: nameColor)),
                const Text(" さん", style: TextStyle(fontSize: 14, color: Colors.white38)),
              ],
            ),
            Text("${pt.toStringAsFixed(1)}pt", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(height: 18, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutExpo,
                  height: 18,
                  width: constraints.maxWidth * percent,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)],
                  ),
                ),
              ],
            );
          }
        ),
      ],
    );
  }
}