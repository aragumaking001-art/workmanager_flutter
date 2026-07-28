import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:table_calendar/table_calendar.dart';
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
    {"name": "ライオン将軍", "icon": "🦁", "suffix": "ガオー！"},
  ];

  late Map<String, String> _todayStaff;
  DateTime _selectedDate = DateTime.now();
  List<ModelSummary> _customModels = [];
  bool _isFetchingCustom = false;

  bool get _isToday {
    DateTime now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    int seed = int.parse(DateFormat('yyyyMMdd').format(DateTime.now()));
    var rand = Random(seed);
    _todayStaff = _cheerStaff[rand.nextInt(_cheerStaff.length)];
  }

  Future<void> _fetchCustomDateData(DateTime date) async {
    setState(() {
      _isFetchingCustom = true;
    });
    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );
      await conn.connect();
      String targetHyphen = DateFormat('yyyy-MM-dd').format(date);
      String targetSlash = DateFormat('yyyy/MM/dd').format(date);

      var results = await conn.execute('''
        SELECT l.model_name, CAST(SUM(l.clean_qty) AS SIGNED) AS total_clean, MAX(IFNULL(l.maker_abbr, '')) AS maker_abbr, CAST(SUM(l.air_clean_qty) AS SIGNED) AS total_air, CAST(SUM(l.swap_qty) AS SIGNED) AS total_swap, MIN(l.id) AS first_id
        FROM unit_cleaning_logs l
        WHERE (l.work_date LIKE '$targetHyphen%' OR l.work_date LIKE '$targetSlash%')
        GROUP BY l.model_name, l.maker_abbr
      ''');

      List<ModelSummary> temp = [];
      for (var row in results.rows) {
        var d = row.assoc();
        String rawName = d['model_name'] ?? "不明";
        String cleanName = rawName.contains(':')
            ? rawName.split(':').last.replaceAll('}', '').trim()
            : rawName;
        var m = ModelSummary(cleanName);

        m.clean = double.tryParse(d['total_clean'] ?? '0')?.toInt() ?? 0;
        m.maker = d['maker_abbr'] ?? "";
        m.air = double.tryParse(d['total_air'] ?? '0')?.toInt() ?? 0;
        m.swap = double.tryParse(d['total_swap'] ?? '0')?.toInt() ?? 0;
        m.sortId = int.tryParse(d['first_id'] ?? '9999999') ?? 9999999;

        if (m.clean > 0 || m.air > 0 || m.swap > 0) temp.add(m);
      }
      temp.sort((a, b) => a.sortId.compareTo(b.sortId));
      await conn.close();
      if (mounted) {
        setState(() {
          _customModels = temp;
          _isFetchingCustom = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingCustom = false;
        });
      }
    }
  }

  Future<void> _showCalendarDialog() async {
    DateTime focusedDay = _selectedDate;
    DateTime? selectedDay = _selectedDate;
    final data = Provider.of<DataProvider>(context, listen: false);
    final isWhite = data.displayMode == DisplayMode.pureWhite;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        final dp = context.watch<DataProvider>();
        final isWhiteDialog = dp.displayMode == DisplayMode.pureWhite;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<int> years = List.generate(
              10,
              (i) => DateTime.now().year - 5 + i,
            );
            List<int> months = List.generate(12, (i) => i + 1);

            Color accentColor = isWhiteDialog
                ? const Color(0xFF008855)
                : const Color(0xFF00FFCC);
            Color dropdownBg = isWhiteDialog
                ? const Color(0xFFF0F3F8)
                : const Color(0xFF1E2128);

            return AlertDialog(
              backgroundColor: dp.currentCardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isWhiteDialog
                      ? const Color(0xFF008855)
                      : const Color(0xFF00FFCC).withOpacity(0.6),
                  width: isWhiteDialog ? 2 : 1.5,
                ),
              ),
              elevation: isWhiteDialog ? 8 : 4,
              shadowColor: isWhiteDialog
                  ? Colors.black26
                  : const Color(0xFF00FFCC).withOpacity(0.2),
              title: Row(
                children: [
                  Icon(Icons.calendar_month, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "日付を選択",
                    style: TextStyle(
                      color: dp.mainTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 520,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: dropdownBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isWhiteDialog
                                  ? Colors.grey.shade300
                                  : Colors.white24,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              dropdownColor: isWhiteDialog
                                  ? Colors.white
                                  : const Color(0xFF252832),
                              value: focusedDay.year,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: accentColor,
                                size: 28,
                              ),
                              style: TextStyle(
                                color: dp.mainTextColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              items: years
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text("$y年"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (newYear) {
                                if (newYear != null) {
                                  setDialogState(() {
                                    focusedDay = DateTime(
                                      newYear,
                                      focusedDay.month,
                                      1,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: dropdownBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isWhiteDialog
                                  ? Colors.grey.shade300
                                  : Colors.white24,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              dropdownColor: isWhiteDialog
                                  ? Colors.white
                                  : const Color(0xFF252832),
                              value: focusedDay.month,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: accentColor,
                                size: 28,
                              ),
                              style: TextStyle(
                                color: dp.mainTextColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              items: months
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text("$m月"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (newMonth) {
                                if (newMonth != null) {
                                  setDialogState(() {
                                    focusedDay = DateTime(
                                      focusedDay.year,
                                      newMonth,
                                      1,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: SingleChildScrollView(
                        child: TableCalendar(
                          locale: 'ja_JP',
                          firstDay: DateTime(2020),
                          lastDay: DateTime.now(),
                          focusedDay: focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(selectedDay, day),
                          onDaySelected: (newSelectedDay, newFocusedDay) {
                            setDialogState(() {
                              selectedDay = newSelectedDay;
                              focusedDay = newFocusedDay;
                            });
                          },
                          calendarStyle: CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: TextStyle(
                              color: isWhiteDialog
                                  ? Colors.white
                                  : Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            todayDecoration: BoxDecoration(
                              color: isWhiteDialog
                                  ? accentColor.withOpacity(0.2)
                                  : Colors.white10,
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            todayTextStyle: TextStyle(
                              color: isWhiteDialog ? accentColor : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            defaultTextStyle: TextStyle(
                              color: dp.mainTextColor,
                              fontSize: 22,
                            ),
                            outsideTextStyle: TextStyle(
                              color: isWhiteDialog
                                  ? Colors.black26
                                  : Colors.white24,
                              fontSize: 22,
                            ),
                            weekendTextStyle: TextStyle(
                              color: isWhiteDialog
                                  ? Colors.red.shade700
                                  : Colors.redAccent,
                              fontSize: 22,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            dowBuilder: (context, day) {
                              if (day.weekday == DateTime.saturday) {
                                return Center(
                                  child: Text(
                                    '土',
                                    style: TextStyle(
                                      color: isWhiteDialog
                                          ? Colors.blue.shade700
                                          : Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                );
                              }
                              if (day.weekday == DateTime.sunday) {
                                return Center(
                                  child: Text(
                                    '日',
                                    style: TextStyle(
                                      color: isWhiteDialog
                                          ? Colors.red.shade700
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                            defaultBuilder: (context, day, newFocusedDay) {
                              if (day.weekday == DateTime.saturday) {
                                return Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: isWhiteDialog
                                          ? Colors.blue.shade700
                                          : Colors.blueAccent,
                                      fontSize: 22,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                          daysOfWeekHeight: 50,
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              color: dp.mainTextColor,
                              size: 30,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              color: dp.mainTextColor,
                              size: 30,
                            ),
                            titleTextStyle: TextStyle(
                              color: dp.mainTextColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "キャンセル",
                    style: TextStyle(
                      color: dp.subTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: isWhiteDialog
                        ? Colors.white
                        : Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isWhiteDialog ? 3 : 0,
                  ),
                  onPressed: () {
                    if (selectedDay != null) {
                      Navigator.pop(context, selectedDay);
                    }
                  },
                  child: const Text(
                    "確定",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedDate = result;
      });
      if (!_isToday) {
        _fetchCustomDateData(_selectedDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isWhite = data.displayMode == DisplayMode.pureWhite;

    if (data.isLoading && data.todayModels.isEmpty && _isToday) {
      return Scaffold(
        backgroundColor: data.currentBgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isWhite
                    ? const Color(0xFF007799)
                    : const Color(0xFF00CCFF),
              ),
              const SizedBox(height: 20),
              Text(
                "システムデータ同期中...",
                style: TextStyle(
                  color: data.subTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    DateTime targetDate = _selectedDate;
    String todayStr = DateFormat('yyyy/MM/dd').format(targetDate);
    String dateDisplay = DateFormat('yyyy年 MM月 dd日').format(targetDate);
    List<String> weekdays = ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"];
    String weekdayDisplay = weekdays[targetDate.weekday - 1];

    List<ModelSummary> models = List.from(
      _isToday ? data.todayModels : _customModels,
    );

    int totalAir = models.fold(0, (sum, item) => sum + item.air);
    int totalClean = models.fold(0, (sum, item) => sum + item.clean);
    int totalSwap = models.fold(0, (sum, item) => sum + item.swap);

    int totalTarget = data.airTarget + data.cleanTarget + data.swapTarget;
    int totalDone = totalAir + totalClean + totalSwap;
    double totalProg = totalTarget > 0
        ? (totalDone / totalTarget).clamp(0.0, 1.0)
        : 0.0;

    String sfx = _todayStaff['suffix']!;
    String cheerMsg;
    Color cheerColor;
    if (totalProg == 0) {
      cheerMsg = _isToday ? "準備中$sfx" : "実績記録なし$sfx";
      cheerColor = data.subTextColor;
    } else if (totalProg < 0.3) {
      cheerMsg = _isToday ? "まずは1台！ここから$sfx" : "スタートダッシュ$sfx";
      cheerColor = isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF);
    } else if (totalProg < 0.6) {
      cheerMsg = _isToday ? "いいペース$sfx その調子$sfx" : "順調な推移$sfx";
      cheerColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
    } else if (totalProg < 0.9) {
      cheerMsg = _isToday ? "スゴい$sfx 目標まであと少し$sfx" : "高い目標到達率$sfx";
      cheerColor = isWhite ? Colors.amber.shade800 : Colors.amber;
    } else {
      cheerMsg = _isToday ? "爆速$sfx センター最強$sfx" : "最高の達成実績$sfx";
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
              padding: const EdgeInsets.only(left: 10, bottom: 20, right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dateDisplay,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: data.mainTextColor,
                            ),
                          ),
                          if (!_isToday) ...[
                            const SizedBox(width: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isWhite
                                    ? const Color(0xFFD45500)
                                    : Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "指定日 表示中",
                                style: TextStyle(
                                  color: isWhite ? Colors.white : Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: isWhite
                                ? const Color(0xFF007799)
                                : const Color(0xFF00CCFF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            weekdayDisplay,
                            style: TextStyle(
                              fontSize: 18,
                              color: isWhite
                                  ? const Color(0xFF007799)
                                  : const Color(0xFF00CCFF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!_isToday) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isWhite
                                ? const Color(0xFFE2F7EB)
                                : const Color(0xFF0E3B27),
                            foregroundColor: isWhite
                                ? const Color(0xFF006B33)
                                : const Color(0xFF33FF99),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isWhite
                                  ? const Color(0xFF00994C)
                                  : const Color(0xFF00E673),
                              width: 1.5,
                            ),
                            elevation: isWhite ? 2 : 0,
                          ),
                          icon: const Icon(Icons.today, size: 24),
                          label: const Text(
                            "今日のデータに戻る",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime.now();
                            });
                          },
                        ),
                        const SizedBox(width: 15),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite
                              ? const Color(0xFFD4EFFC)
                              : const Color(0xFF0E384C),
                          foregroundColor: isWhite
                              ? const Color(0xFF005580)
                              : const Color(0xFF33D9FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isWhite
                                ? const Color(0xFF0077AA)
                                : const Color(0xFF00BAFF),
                            width: 1.5,
                          ),
                          elevation: isWhite ? 2 : 0,
                        ),
                        icon: const Icon(Icons.calendar_month, size: 24),
                        label: const Text(
                          "日付指定",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _showCalendarDialog,
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: data.currentCardColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: data.borderColor),
                            boxShadow: isWhite
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _todayStaff['icon']!,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "応援担当: ${_todayStaff['name']}",
                                              style: TextStyle(
                                                color: data.subTextColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "${(totalProg * 100).toInt()}%",
                                              style: TextStyle(
                                                color: data.subTextColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            cheerMsg,
                                            style: TextStyle(
                                              color: cheerColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: totalProg,
                                backgroundColor: isWhite
                                    ? Colors.grey.shade200
                                    : Colors.white10,
                                color: isWhite
                                    ? const Color(0xFF008855)
                                    : const Color(0xFF00FFCC),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Expanded(
                          child: _buildGiantCard(
                            "エアー",
                            totalAir,
                            data.airTarget,
                            isWhite
                                ? const Color(0xFF007799)
                                : const Color(0xFF00CCFF),
                            Icons.air,
                            data,
                            isWhite,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildGiantCard(
                            "通常清掃",
                            totalClean,
                            data.cleanTarget,
                            isWhite
                                ? const Color(0xFF008855)
                                : const Color(0xFF00FFCC),
                            Icons.cleaning_services,
                            data,
                            isWhite,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildGiantCard(
                            "筐体交換",
                            totalSwap,
                            data.swapTarget,
                            isWhite ? Colors.amber.shade800 : Colors.amber,
                            Icons.settings_outlined,
                            data,
                            isWhite,
                          ),
                        ),
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
                        boxShadow: isWhite
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.list_alt,
                                    color: isWhite
                                        ? const Color(0xFF008855)
                                        : const Color(0xFF00FFCC),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isToday ? "本日機種別 詳細内訳" : "指定日 機種別 詳細内訳",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: data.mainTextColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isWhite
                                        ? [
                                            const Color(0xFFD47A00),
                                            const Color(0xFFE65A00),
                                          ]
                                        : [
                                            const Color(0xFFFF9D00),
                                            const Color(0xFFFF4000),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isWhite
                                                  ? Colors.orange
                                                  : Colors.deepOrange)
                                              .withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "合計完了台数 :",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatNumber(totalDone),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "台",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    "機種 (メーカー)",
                                    style: TextStyle(
                                      color: data.subTextColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "エアー",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: data.subTextColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "清掃",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: data.subTextColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "筐体交換",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: data.subTextColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    "合計台数",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: data.mainTextColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            color: data.borderColor,
                            thickness: 1,
                            height: 20,
                          ),

                          Expanded(
                            child: _isFetchingCustom
                                ? Center(
                                    child: CircularProgressIndicator(
                                      color: isWhite
                                          ? const Color(0xFF008855)
                                          : const Color(0xFF00FFCC),
                                    ),
                                  )
                                : models.isEmpty
                                ? Center(
                                    child: Text(
                                      "該当する日の出来高データはありません",
                                      style: TextStyle(
                                        color: data.subTextColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: models.length,
                                    itemBuilder: (context, index) {
                                      var m = models[index];
                                      String displayName = m.maker.isNotEmpty
                                          ? "${m.name} (${m.maker})"
                                          : m.name;
                                      int total = m.totalFinished;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isWhite
                                                  ? Colors.grey.shade200
                                                  : const Color(0xFF2D3039),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                displayName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: data.mainTextColor,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "${m.air}",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: m.air > 0
                                                        ? (isWhite
                                                              ? const Color(
                                                                  0xFF007799,
                                                                )
                                                              : const Color(
                                                                  0xFF00CCFF,
                                                                ))
                                                        : data.subTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "${m.clean}",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: m.clean > 0
                                                        ? (isWhite
                                                              ? const Color(
                                                                  0xFF008855,
                                                                )
                                                              : const Color(
                                                                  0xFF00FFCC,
                                                                ))
                                                        : data.subTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "${m.swap}",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: m.swap > 0
                                                        ? (isWhite
                                                              ? Colors
                                                                    .amber
                                                                    .shade800
                                                              : Colors.amber)
                                                        : data.subTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Center(
                                                child: Container(
                                                  width: double.infinity,
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxWidth: 100,
                                                      ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isWhite
                                                        ? Colors.grey.shade100
                                                        : const Color(
                                                            0xFF2D3243,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: isWhite
                                                          ? Colors.grey.shade400
                                                          : const Color(
                                                              0xFF444B63,
                                                            ),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      "$total",
                                                      style: TextStyle(
                                                        fontSize: 26,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            data.mainTextColor,
                                                      ),
                                                    ),
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

  Widget _buildGiantCard(
    String label,
    int value,
    int target,
    Color color,
    IconData icon,
    DataProvider data,
    bool isWhite,
  ) {
    double prog = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    String targetType = label == "通常清掃" ? "清掃" : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: data.currentCardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isWhite ? color.withOpacity(0.5) : const Color(0xFF33363F),
          width: 2,
        ),
        boxShadow: isWhite
            ? [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
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
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () =>
                    _showTargetDialog(targetType, target, data, isWhite),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isWhite
                        ? Colors.grey.shade100
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isWhite ? Colors.grey.shade300 : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "目標 ",
                        style: TextStyle(
                          fontSize: 14,
                          color: data.subTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatNumber(target),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: data.mainTextColor,
                        ),
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
                  style: TextStyle(
                    fontSize: 18,
                    color: data.subTextColor,
                    fontWeight: FontWeight.bold,
                  ),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: prog,
                  backgroundColor: isWhite
                      ? Colors.grey.shade200
                      : const Color(0xFF2D3039),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTargetDialog(
    String type,
    int currentTarget,
    DataProvider data,
    bool isWhite,
  ) {
    TextEditingController ctrl = TextEditingController(
      text: currentTarget.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: data.currentCardColor,
        title: Text(
          "$type 目標台数の変更",
          style: TextStyle(
            color: data.mainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: data.mainTextColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: "新しい目標台数",
            labelStyle: TextStyle(
              color: data.subTextColor,
              fontWeight: FontWeight.bold,
            ),
            suffixText: "台",
            suffixStyle: TextStyle(
              color: data.subTextColor,
              fontWeight: FontWeight.bold,
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "キャンセル",
              style: TextStyle(
                color: data.mainTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isWhite
                  ? const Color(0xFF008855)
                  : const Color(0xFF00FFCC),
              foregroundColor: isWhite ? Colors.white : Colors.black,
            ),
            onPressed: () {
              int? newTarget = int.tryParse(ctrl.text);
              if (newTarget != null && newTarget >= 0) {
                Provider.of<DataProvider>(
                  context,
                  listen: false,
                ).updateDailyTarget(type, newTarget);
              }
              Navigator.pop(context);
            },
            child: const Text(
              "確定",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
