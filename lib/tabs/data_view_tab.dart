import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../widgets/app_background_wrapper.dart';

enum SearchMode { date, worker }

class DataViewTab extends StatefulWidget {
  const DataViewTab({super.key});

  @override
  State<DataViewTab> createState() => _DataViewTabState();
}

class _DataViewTabState extends State<DataViewTab> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _logs = [];
  bool _isFetching = false;
  String? _selectedWorkerFilter;
  SearchMode _currentMode = SearchMode.date;
  String? _selectedWorkerForSearch;
  List<Map<String, dynamic>> _allWorkers = [];

  List<String> get _uniqueWorkers {
    Set<String> workers = {};
    for (var log in _logs) {
      workers.add(log['worker_name'] ?? log['worker_id'] ?? "不明");
    }
    List<String> sorted = workers.toList()..sort();
    sorted.insert(0, "すべて");
    return sorted;
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_selectedWorkerFilter == null || _selectedWorkerFilter == "すべて") {
      return _logs;
    }
    return _logs.where((log) {
      String w = log['worker_name'] ?? log['worker_id'] ?? "不明";
      return w == _selectedWorkerFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
    _fetchLogs(_selectedDate);
  }

  Future<void> _fetchLogs(DateTime targetDate) async {
    setState(() {
      _isFetching = true;
    });

    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101',
      port: 3306,
      userName: 'work_user',
      password: 'work1234',
      databaseName: 'work_manager_db',
    );
    try {
      await conn.connect();
      String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      var result = await conn.execute(
        '''
        SELECT 
          l.id, l.work_date, l.model_name, l.maker, l.maker_abbr, l.worker_id, 
          l.clean_qty, l.air_clean_qty, l.swap_qty, l.to_clean_qty, l.to_swap_qty, l.std_qty,
          l.start_time_str, l.end_time_str, l.work_minutes, l.edit_count,
          mem.worker_name
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        WHERE DATE(l.work_date) = :d 
        ORDER BY l.id DESC
      ''',
        {"d": dateStr},
      );

      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc());
      }
      _logs = temp;
    } catch (e) {
      print("ログ取得エラー: $e");
    } finally {
      await conn.close();
      setState(() => _isFetching = false);
    }
  }

  Future<void> _fetchWorkers() async {
    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101',
      port: 3306,
      userName: 'work_user',
      password: 'work1234',
      databaseName: 'work_manager_db',
    );
    try {
      await conn.connect();
      var result = await conn.execute('SELECT worker_id, worker_name FROM m_members ORDER BY worker_id ASC');
      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc());
      }
      setState(() {
        _allWorkers = temp;
      });
    } catch (e) {
      print("作業者マスター取得エラー: $e");
    } finally {
      await conn.close();
    }
  }

  Future<void> _fetchLogsByWorker(String workerId) async {
    setState(() {
      _isFetching = true;
    });

    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101',
      port: 3306,
      userName: 'work_user',
      password: 'work1234',
      databaseName: 'work_manager_db',
    );
    try {
      await conn.connect();
      var result = await conn.execute(
        '''
        SELECT 
          l.id, l.work_date, l.model_name, l.maker, l.maker_abbr, l.worker_id, 
          l.clean_qty, l.air_clean_qty, l.swap_qty, l.to_clean_qty, l.to_swap_qty, l.std_qty,
          l.start_time_str, l.end_time_str, l.work_minutes, l.edit_count,
          mem.worker_name
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        WHERE l.worker_id = :w 
        ORDER BY l.id DESC
      ''',
        {"w": workerId},
      );

      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc());
      }
      _logs = temp;
    } catch (e) {
      print("ログ取得エラー: $e");
    } finally {
      await conn.close();
      setState(() => _isFetching = false);
    }
  }

  Future<void> _showCalendarDialog() async {
    DateTime focusedDay = _selectedDate;
    DateTime? selectedDay = _selectedDate;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        final dp = context.watch<DataProvider>();
        final isWhite = dp.displayMode == DisplayMode.pureWhite;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<int> years = List.generate(
              10,
              (i) => DateTime.now().year - 5 + i,
            );
            List<int> months = List.generate(12, (i) => i + 1);

            Color accentColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
            Color dropdownBg = isWhite ? const Color(0xFFF0F3F8) : const Color(0xFF1E2128);

            return AlertDialog(
              backgroundColor: dp.currentCardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC).withOpacity(0.6),
                  width: isWhite ? 2 : 1.5,
                ),
              ),
              elevation: isWhite ? 8 : 4,
              shadowColor: isWhite ? Colors.black26 : const Color(0xFF00FFCC).withOpacity(0.2),
              title: Row(
                children: [
                  Icon(Icons.calendar_month, color: accentColor, size: 28),
                  const SizedBox(width: 12),
                  Text("日付を選択", style: TextStyle(color: dp.mainTextColor, fontWeight: FontWeight.bold, fontSize: 22)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: dropdownBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isWhite ? Colors.grey.shade300 : Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              dropdownColor: isWhite ? Colors.white : const Color(0xFF252832),
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
                              items: years.map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text("$y年"),
                                );
                              }).toList(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: dropdownBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isWhite ? Colors.grey.shade300 : Colors.white24),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              dropdownColor: isWhite ? Colors.white : const Color(0xFF252832),
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
                              items: months.map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text("$m月"),
                                );
                              }).toList(),
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
                          selectedDayPredicate: (day) {
                            return isSameDay(selectedDay, day);
                          },
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
                              color: isWhite ? Colors.white : Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            todayDecoration: BoxDecoration(
                              color: isWhite ? accentColor.withOpacity(0.2) : Colors.white10,
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            todayTextStyle: TextStyle(
                              color: isWhite ? accentColor : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            defaultTextStyle: TextStyle(
                              color: dp.mainTextColor,
                              fontSize: 22,
                            ),
                            outsideTextStyle: TextStyle(
                              color: isWhite ? Colors.black26 : Colors.white24,
                              fontSize: 22,
                            ),
                            weekendTextStyle: TextStyle(
                              color: isWhite ? Colors.red.shade700 : Colors.redAccent,
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
                                      color: isWhite ? Colors.blue.shade700 : Colors.blueAccent,
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
                                      color: isWhite ? Colors.red.shade700 : Colors.redAccent,
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
                                      color: isWhite ? Colors.blue.shade700 : Colors.blueAccent,
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
              actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "キャンセル",
                    style: TextStyle(color: dp.subTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: isWhite ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: isWhite ? 3 : 0,
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
      _fetchLogs(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor:
              dp.currentCardColor.withValues(alpha: isWhite ? 0.85 : 0.65),
          elevation: isWhite ? 2 : 0,
        iconTheme: IconThemeData(color: dp.mainTextColor),
        title: Text(
          "データ確認",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: dp.mainTextColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 28, color: dp.mainTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SegmentedButton<SearchMode>(
              segments: const [
                ButtonSegment<SearchMode>(
                  value: SearchMode.date,
                  label: Text('日付で検索'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment<SearchMode>(
                  value: SearchMode.worker,
                  label: Text('作業者で検索'),
                  icon: Icon(Icons.person_search),
                ),
              ],
              selected: <SearchMode>{_currentMode},
              onSelectionChanged: (Set<SearchMode> newSelection) {
                setState(() {
                  _currentMode = newSelection.first;
                  if (_currentMode == SearchMode.date) {
                    _fetchLogs(_selectedDate);
                  } else {
                    if (_selectedWorkerForSearch != null) {
                      _fetchLogsByWorker(_selectedWorkerForSearch!);
                    } else {
                      _logs = [];
                    }
                  }
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF);
                  }
                  return dp.currentCardColor;
                }),
                foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return isWhite ? Colors.white : Colors.black;
                  }
                  return dp.mainTextColor;
                }),
              ),
            ),
          ),
          if (_currentMode == SearchMode.date)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showCalendarDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isWhite ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month, size: 20, color: isWhite ? Colors.white : Colors.black),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('yyyy年MM月dd日').format(_selectedDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isWhite ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_currentMode == SearchMode.worker)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: dp.currentCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      isDense: true,
                      iconSize: 20,
                      dropdownColor: dp.currentCardColor,
                      hint: Text("作業者を選択", style: TextStyle(color: dp.subTextColor, fontSize: 14)),
                      value: _selectedWorkerForSearch,
                      icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)),
                      style: TextStyle(color: dp.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                      items: _allWorkers.map((w) {
                        return DropdownMenuItem<String>(
                          value: w['worker_id'].toString(),
                          child: Text(w['worker_name']?.toString() ?? w['worker_id']?.toString() ?? '不明'),
                        );
                      }).toList(),
                      onChanged: (newWorkerId) {
                        if (newWorkerId != null) {
                          setState(() {
                            _selectedWorkerForSearch = newWorkerId;
                          });
                          _fetchLogsByWorker(newWorkerId);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          const Center(child: _ConnectionStatusIndicator()),
          const SizedBox(width: 20),
        ],
      ),
      body: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _isFetching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00CCFF),
                      ),
                    )
                  : _logs.isEmpty
                  ? Center(
                      child: Text(
                        "データがありません",
                        style: TextStyle(color: dp.subTextColor, fontSize: 18),
                      ),
                    )
                  : Builder(
                      builder: (ctx) {
                        final isWhite = dp.displayMode == DisplayMode.pureWhite;
                        final headerColor = isWhite
                            ? const Color(0xFF006666)
                            : Colors.cyanAccent;

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: dp.currentCardColor.withValues(
                                  alpha: isWhite ? 0.9 : 0.8,
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isWhite
                                        ? const Color(0xFF006666)
                                        : const Color(0xFF00CCFF),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _currentMode == SearchMode.worker ? "作業日" : "作業者",
                                          style: TextStyle(
                                            color: headerColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (_currentMode == SearchMode.date)
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.filter_list_rounded,
                                              color: headerColor,
                                              size: 20,
                                            ),
                                          color: dp.currentCardColor,
                                          tooltip: "作業者で絞り込み",
                                          onSelected: (val) {
                                            setState(() {
                                              _selectedWorkerFilter =
                                                  val == "すべて" ? null : val;
                                            });
                                          },
                                          itemBuilder: (context) {
                                            return _uniqueWorkers.map((w) {
                                              bool isSelected =
                                                  (w == "すべて" &&
                                                      _selectedWorkerFilter ==
                                                          null) ||
                                                  w == _selectedWorkerFilter;
                                              return PopupMenuItem<String>(
                                                value: w,
                                                child: Text(
                                                  w,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? headerColor
                                                        : dp.mainTextColor,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      "機種名",
                                      style: TextStyle(
                                        color: headerColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "作業区分",
                                      style: TextStyle(
                                        color: headerColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "内容１",
                                      style: TextStyle(
                                        color: headerColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "内容２",
                                      style: TextStyle(
                                        color: headerColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "時間(開始-終了)",
                                        style: TextStyle(
                                          color: headerColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "作業時間",
                                        style: TextStyle(
                                          color: headerColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        "生産性",
                                        style: TextStyle(
                                          color: headerColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _filteredLogs.length,
                                itemBuilder: (context, index) {
                                  var log = _filteredLogs[index];
                                  bool isEven = index % 2 == 0;

                                  String workerName =
                                      log['worker_name'] ??
                                      log['worker_id'] ??
                                      "不明";

                                  String workDateStr = "-";
                                  if (log['work_date'] != null) {
                                    try {
                                      DateTime wd = log['work_date'] is DateTime ? log['work_date'] : DateTime.parse(log['work_date'].toString());
                                      workDateStr = DateFormat('MM/dd').format(wd);
                                    } catch (e) {
                                      workDateStr = log['work_date'].toString().split(' ').first;
                                    }
                                  }

                                  String rawModelName =
                                      log['model_name']?.toString() ?? "不明";
                                  String cleanModelName =
                                      rawModelName.contains(':')
                                      ? rawModelName
                                            .split(':')
                                            .last
                                            .replaceAll('}', '')
                                            .trim()
                                      : rawModelName;
                                  String makerAbbr =
                                      log['maker_abbr']?.toString() ?? "";
                                  String displayModelName =
                                      makerAbbr.isNotEmpty &&
                                          makerAbbr != "null"
                                      ? "$cleanModelName ($makerAbbr)"
                                      : cleanModelName;

                                  int airQty =
                                      int.tryParse(
                                        log['air_clean_qty']?.toString() ?? '0',
                                      ) ??
                                      0;
                                  int cleanQty =
                                      int.tryParse(
                                        log['clean_qty']?.toString() ?? '0',
                                      ) ??
                                      0;
                                  int toCleanQty =
                                      int.tryParse(
                                        log['to_clean_qty']?.toString() ?? '0',
                                      ) ??
                                      0;
                                  int toSwapQty =
                                      int.tryParse(
                                        log['to_swap_qty']?.toString() ?? '0',
                                      ) ??
                                      0;

                                  String mainLabel = "";
                                  int mainQty = 0;
                                  String subLabel = "";
                                  int subQty = 0;
                                  Color accentColor = isWhite
                                      ? const Color(0xFF006688)
                                      : const Color(0xFF00CCFF);

                                  if (airQty > 0) {
                                    mainLabel = "エアー清掃";
                                    mainQty = airQty;
                                    subLabel = "清掃行き";
                                    subQty = toCleanQty;
                                    accentColor = isWhite
                                        ? const Color(0xFF006688)
                                        : const Color(0xFF00CCFF);
                                  } else if (cleanQty > 0) {
                                    mainLabel = "通常清掃";
                                    mainQty = cleanQty;
                                    subLabel = "交換行き";
                                    subQty = toSwapQty;
                                    accentColor = isWhite
                                        ? const Color(0xFF008855)
                                        : const Color(0xFF00FFCC);
                                  } else {
                                    mainLabel = "筐体交換";
                                    mainQty =
                                        int.tryParse(
                                          log['swap_qty']?.toString() ?? '0',
                                        ) ??
                                        0;
                                    subLabel = "その他";
                                    subQty = 0;
                                    accentColor = isWhite
                                        ? Colors.orange.shade800
                                        : Colors.amber;
                                  }

                                  double workMinutes =
                                      double.tryParse(
                                        log['work_minutes']?.toString() ?? '0',
                                      ) ??
                                      0.0;
                                  int stdQty =
                                      int.tryParse(
                                        log['std_qty']?.toString() ?? '0',
                                      ) ??
                                      0;

                                  int totalMin = workMinutes.round();
                                  int h = totalMin ~/ 60;
                                  int m = totalMin % 60;
                                  String timeDisplay = h > 0
                                      ? "${h}時間\n${m}分"
                                      : "${m}分";

                                  String startTime =
                                      log['start_time_str']?.toString() ?? "-";
                                  String endTime =
                                      log['end_time_str']?.toString() ?? "-";
                                  String timeRange = "$startTime\n- $endTime";

                                  Widget productivityWidget = Text(
                                    "-",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: dp.subTextColor,
                                    ),
                                  );
                                  if (workMinutes > 0 &&
                                      stdQty > 0 &&
                                      mainQty > 0) {
                                    double hours = workMinutes / 60.0;
                                    double actualPerHour = mainQty / hours;
                                    int prodPercent =
                                        (actualPerHour / stdQty * 100).round();

                                    Color prodColor;
                                    IconData prodIcon;
                                    if (prodPercent >= 100) {
                                      prodColor = isWhite
                                          ? Colors.green.shade700
                                          : Colors.greenAccent;
                                      prodIcon = Icons.trending_up;
                                    } else if (prodPercent >= 80) {
                                      prodColor = isWhite
                                          ? Colors.amber.shade800
                                          : Colors.yellowAccent;
                                      prodIcon = Icons.trending_flat;
                                    } else {
                                      prodColor = isWhite
                                          ? Colors.red.shade700
                                          : Colors.redAccent;
                                      prodIcon = Icons.trending_down;
                                    }

                                    productivityWidget = Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          prodIcon,
                                          color: prodColor,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "実績: ${actualPerHour.toStringAsFixed(1)}",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: prodColor,
                                              ),
                                            ),
                                            Text(
                                              "目標: $stdQty.0",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: dp.subTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  Color rowBg = isWhite
                                      ? (isEven
                                            ? Colors.white.withValues(alpha: 0.85)
                                            : const Color(0xFFF2F6F9).withValues(alpha: 0.85))
                                      : (isEven
                                            ? const Color(0xFF0F1115).withValues(alpha: 0.75)
                                            : const Color(0xFF14161C).withValues(alpha: 0.75));

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: rowBg,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: dp.borderColor,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0,
                                        vertical: 16.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _currentMode == SearchMode.worker ? workDateStr : workerName,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: dp.mainTextColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              displayModelName,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: dp.mainTextColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              mainLabel,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: _compactInfoChip(
                                                "台数",
                                                mainQty,
                                                accentColor,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: subLabel != "その他"
                                                  ? _compactInfoChip(
                                                      subLabel,
                                                      subQty,
                                                      (subLabel == "清掃行き")
                                                          ? (isWhite
                                                                ? Colors
                                                                      .teal
                                                                      .shade700
                                                                : Colors
                                                                      .cyanAccent)
                                                          : (isWhite
                                                                ? Colors
                                                                      .deepOrange
                                                                : Colors
                                                                      .orangeAccent),
                                                    )
                                                  : const SizedBox(),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Text(
                                                timeRange,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: dp.mainTextColor,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Text(
                                                timeDisplay,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: dp.mainTextColor,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: productivityWidget,
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _compactInfoChip(
    String label,
    dynamic countOrText,
    Color color, {
    bool isText = false,
  }) {
    final dp = Provider.of<DataProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: dp.mainTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              countOrText.toString(),
              style: TextStyle(
                color: color,
                fontSize: isText ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        color: isWhite
            ? activeColor.withOpacity(0.12)
            : activeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withOpacity(isWhite ? 0.8 : 0.6),
          width: isWhite ? 2.0 : 1.5,
        ),
        boxShadow: isWhite
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
