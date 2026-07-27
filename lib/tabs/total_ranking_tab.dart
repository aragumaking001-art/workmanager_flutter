import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; 
import '../providers/data_provider.dart';

class TotalRankingTab extends StatefulWidget {
  const TotalRankingTab({super.key});

  @override
  State<TotalRankingTab> createState() => _TotalRankingTabState();
}

class _TotalRankingTabState extends State<TotalRankingTab> {
  String _rankMode = "Week";
  
  late DateTime _startDate;
  late DateTime _endDate;

  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _startDate = now.subtract(Duration(days: now.weekday - 1)); // 月曜日
    _endDate = _startDate.add(const Duration(days: 5));         // 土曜日
  }

  Future<void> _pickCustomRange() async {
    DateTime _focusedDay = _customStart ?? DateTime.now();
    DateTime? _start = _customStart;
    DateTime? _end = _customEnd;

    List<int> years = List.generate(11, (index) => 2020 + index);
    List<int> months = List.generate(12, (index) => index + 1);

    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (context) {
        final data = context.watch<DataProvider>();
        final isWhite = data.displayMode == DisplayMode.pureWhite;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.9,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: data.currentCardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "ランキング期間選択",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: data.mainTextColor),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.grey.shade200 : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.year,
                              dropdownColor: isWhite ? Colors.white : const Color(0xFF252830),
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC)),
                              style: TextStyle(color: data.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                              items: years.map((y) {
                                return DropdownMenuItem(value: y, child: Text("$y年", style: TextStyle(color: data.mainTextColor)));
                              }).toList(),
                              onChanged: (newYear) {
                                if (newYear != null) {
                                  setDialogState(() {
                                    _focusedDay = DateTime(newYear, _focusedDay.month, 1);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.grey.shade200 : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.month,
                              dropdownColor: isWhite ? Colors.white : const Color(0xFF252830),
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC)),
                              style: TextStyle(color: data.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                              items: months.map((m) {
                                return DropdownMenuItem(value: m, child: Text("$m月", style: TextStyle(color: data.mainTextColor)));
                              }).toList(),
                              onChanged: (newMonth) {
                                if (newMonth != null) {
                                  setDialogState(() {
                                    _focusedDay = DateTime(_focusedDay.year, newMonth, 1);
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: SingleChildScrollView(
                          child: TableCalendar(
                            locale: 'ja_JP',
                            firstDay: DateTime(2020),
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
                            calendarStyle: CalendarStyle(
                              rangeStartDecoration: BoxDecoration(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), shape: BoxShape.circle),
                              rangeEndDecoration: BoxDecoration(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), shape: BoxShape.circle),
                              rangeHighlightColor: isWhite ? const Color(0xFF007799).withOpacity(0.15) : const Color(0x3300CCFF),
                              todayDecoration: BoxDecoration(color: isWhite ? Colors.grey.shade300 : Colors.white10, shape: BoxShape.circle),
                              defaultTextStyle: TextStyle(color: data.mainTextColor, fontSize: 22),
                              outsideTextStyle: TextStyle(color: data.subTextColor, fontSize: 22),
                              weekendTextStyle: const TextStyle(color: Colors.redAccent, fontSize: 22),
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
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: const TextStyle(fontSize: 0), 
                              leftChevronIcon: Icon(Icons.chevron_left, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), size: 40),
                              rightChevronIcon: Icon(Icons.chevron_right, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), size: 40),
                              headerMargin: const EdgeInsets.only(bottom: 5),
                            ),
                            onPageChanged: (focusedDay) {
                               setDialogState(() {
                                 _focusedDay = focusedDay;
                               });
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("キャンセル", style: TextStyle(color: data.subTextColor, fontSize: 20)),
                          ),
                          const SizedBox(width: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC),
                              foregroundColor: isWhite ? Colors.white : Colors.black,
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

    if (result != null && result["start"] != null && result["end"] != null) {
      setState(() {
        _rankMode = "Custom";
        _customStart = result["start"];
        _customEnd = result["end"];
        _startDate = _customStart!;
        _endDate = _customEnd!;
      });
      if (mounted) {
        Provider.of<DataProvider>(context, listen: false).setRankingPeriod(_startDate, _endDate);
      }
    }
  }

  Future<void> _changeMode(String mode) async {
    if (mode == "Custom") {
      await _pickCustomRange();
      return; 
    }

    DateTime now = DateTime.now();
    DateTime s = now;
    DateTime e = now;

    if (mode == "Day") {
      s = now;
      e = now;
    } else if (mode == "Week") {
      s = now.subtract(Duration(days: now.weekday - 1));
      e = s.add(const Duration(days: 5));
    } else if (mode == "Month") {
      s = DateTime(now.year, now.month, 1);
      e = DateTime(now.year, now.month + 1, 0); 
    }

    setState(() {
      _rankMode = mode;
      _startDate = s;
      _endDate = e;
    });

    if (mounted) {
      Provider.of<DataProvider>(context, listen: false).setRankingPeriod(s, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isWhite = data.displayMode == DisplayMode.pureWhite;
    String periodStr = "(${DateFormat('MM/dd').format(_startDate)} ～ ${DateFormat('MM/dd').format(_endDate)})";

    Map<String, WorkerRank> combinedMap = {};
    for (var list in [data.workerRanks, data.airWorkerRanks, data.swapWorkerRanks]) {
      for (var r in list) {
        var existing = combinedMap.putIfAbsent(r.id, () => WorkerRank(r.id)..name = r.name);
        existing.points += r.points;
        if (r.isLucky) existing.isLucky = true; 
      }
    }

    List<WorkerRank> allRanks = combinedMap.values.toList()..sort((a, b) => b.points.compareTo(a.points));
    double maxPt = allRanks.isNotEmpty ? allRanks.first.points : 10.0;
    if (maxPt <= 0) maxPt = 10.0;

    List<List<WorkerRank>> columnsData = [[], [], []];
    for (int i = 0; i < allRanks.length; i++) {
      if (i < 10) {
        columnsData[ 0 ].add(allRanks[i]);
      } else if (i < 20) {
        columnsData[ 1 ].add(allRanks[i]);
      } else if (i < 30) {
        columnsData[ 2 ].add(allRanks[i]);
      }
    }

    return Scaffold(
      backgroundColor: data.currentBgColor,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: data.currentCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: data.borderColor),
            boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text("4F 作業ランキング", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: data.mainTextColor)),
                          const SizedBox(width: 10),
                          Text(periodStr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: data.subTextColor)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: "Day", label: Text("当日")),
                        ButtonSegment(value: "Week", label: Text("週間")),
                        ButtonSegment(value: "Month", label: Text("月間")),
                        ButtonSegment(value: "Custom", label: Text("期間指定")),
                      ],
                      selected: {_rankMode},
                      onSelectionChanged: (Set<String> newSelection) {
                        _changeMode(newSelection.first);
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) return isWhite ? const Color(0xFF007799).withOpacity(0.15) : const Color(0xFF00CCFF).withOpacity(0.2);
                          return Colors.transparent;
                        }),
                        foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) return isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF);
                          return data.subTextColor;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              Expanded(
                child: data.isLoading
                    ? Center(child: CircularProgressIndicator(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRankColumn(columnsData[ 0 ], 0, maxPt, data, isWhite)),
                          VerticalDivider(color: data.borderColor, width: 30, thickness: 1),
                          Expanded(child: _buildRankColumn(columnsData[ 1 ], 10, maxPt, data, isWhite)),
                          VerticalDivider(color: data.borderColor, width: 30, thickness: 1),
                          Expanded(child: _buildRankColumn(columnsData[ 2 ], 20, maxPt, data, isWhite)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankColumn(List<WorkerRank> ranks, int startIndex, double maxPt, DataProvider data, bool isWhite) {
    return ListView.separated(
      itemCount: ranks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        var r = ranks[index];
        int globalIndex = startIndex + index;
        
        String emoji = "";
        Color barColor = isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF);
        
        if (globalIndex == 0) { emoji = "🥇 "; barColor = isWhite ? Colors.amber.shade800 : const Color(0xFFFFD700); } 
        else if (globalIndex == 1) { emoji = "🥈 "; barColor = isWhite ? Colors.blueGrey.shade500 : const Color(0xFFC0C0C0); } 
        else if (globalIndex == 2) { emoji = "🥉 "; barColor = isWhite ? const Color(0xFFB06020) : const Color(0xFFCD7F32); }

        double percent = (r.points / maxPt).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(r.name, overflow: TextOverflow.ellipsis, 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: data.mainTextColor)),
                      ),
                      Text(" さん", style: TextStyle(fontSize: 14, color: data.subTextColor)),
                      if (r.isLucky)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 4),
                          child: Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        )
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(maxWidth: 90),
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("${r.points.toStringAsFixed(1)}pt", 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: barColor)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Stack(
              children: [
                Container(height: 18, decoration: BoxDecoration(color: isWhite ? Colors.grey.shade200 : Colors.white10, borderRadius: BorderRadius.circular(10))),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: percent),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}