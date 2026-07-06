import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class PersonalProductivityPage extends StatefulWidget {
  const PersonalProductivityPage({super.key});

  @override
  State<PersonalProductivityPage> createState() => _PersonalProductivityPageState();
}

class _PersonalProductivityPageState extends State<PersonalProductivityPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isAllTime = false;

  List<String> _workers = [];
  String? _selectedWorker;

  bool _isFetching = false;
  List<Map<String, dynamic>> _aggregatedData = [];

  bool _isFetchingRanking = false;
  List<Map<String, dynamic>> _rankingData = [];
  DateTime _rankingMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // 月末
    _fetchWorkers().then((_) {
      if (_workers.isNotEmpty) {
        _selectedWorker = _workers.first;
        _fetchProductivityData();
      }
    });
    _fetchRankingData();
  }

  Future<MySQLConnection> _getConnection() async {
    return await MySQLConnection.createConnection(
      host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db',
    );
  }

  Future<void> _fetchWorkers() async {
    final conn = await _getConnection();
    try {
      await conn.connect();
      var result = await conn.execute('SELECT worker_id, worker_name FROM m_members ORDER BY worker_name ASC');
      List<String> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc()['worker_name'] ?? row.assoc()['worker_id']!);
      }
      setState(() {
        _workers = temp.toSet().toList(); // 重複排除
        if (_selectedWorker != null && !_workers.contains(_selectedWorker)) {
          _selectedWorker = _workers.isNotEmpty ? _workers.first : null;
        }
      });
    } catch (e) {
      print("担当者取得エラー: $e");
    } finally {
      await conn.close();
    }
  }

  Future<void> _fetchRankingData() async {
    setState(() => _isFetchingRanking = true);

    MySQLConnection? conn;
    try {
      conn = await _getConnection();
      await conn.connect();

      String sDate = DateFormat('yyyy-MM-dd').format(DateTime(_rankingMonth.year, _rankingMonth.month, 1));
      String eDate = DateFormat('yyyy-MM-dd').format(DateTime(_rankingMonth.year, _rankingMonth.month + 1, 0));
      
      var result = await conn.execute('''
        SELECT 
          mem.worker_name,
          l.model_name, l.maker_abbr, l.std_qty as log_std_qty, 
          l.clean_qty, l.air_clean_qty, l.swap_qty, l.work_minutes,
          m.std_air, m.std_clean, m.std_swap
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        LEFT JOIN (
          SELECT model_name,
            MAX(CASE WHEN work_type = 'エアー清掃' THEN std_qty END) as std_air,
            MAX(CASE WHEN work_type = '清掃' THEN std_qty END) as std_clean,
            MAX(CASE WHEN work_type = '筐体交換' THEN std_qty END) as std_swap
          FROM m_models 
          GROUP BY model_name
        ) m ON l.model_name = m.model_name
        WHERE DATE(l.work_date) >= :s AND DATE(l.work_date) <= :e
      ''', {
        "s": sDate,
        "e": eDate,
      });

      Map<String, Map<String, dynamic>> agg = {};
      
      for (var row in result.rows) {
        var data = row.assoc();
        String workerName = data['worker_name']?.toString() ?? "不明な担当者";
        String rawModel = data['model_name']?.toString() ?? "不明";
        String cleanModel = rawModel.contains(':') ? rawModel.split(':').last.replaceAll('}', '').trim() : rawModel;
        String makerAbbr = data['maker_abbr']?.toString() ?? "";
        String modelDisplay = makerAbbr.isNotEmpty ? "$cleanModel ($makerAbbr)" : cleanModel;

        int c = int.tryParse(data['clean_qty']?.toString() ?? '0') ?? 0;
        int a = int.tryParse(data['air_clean_qty']?.toString() ?? '0') ?? 0;
        int s = int.tryParse(data['swap_qty']?.toString() ?? '0') ?? 0;
        double minutes = double.tryParse(data['work_minutes']?.toString() ?? '0') ?? 0;
        
        int logStdQty = int.tryParse(data['log_std_qty']?.toString() ?? '0') ?? 0;
        int mStdAir = double.tryParse(data['std_air']?.toString() ?? '0')?.toInt() ?? 0;
        int mStdClean = double.tryParse(data['std_clean']?.toString() ?? '0')?.toInt() ?? 0;
        int mStdSwap = double.tryParse(data['std_swap']?.toString() ?? '0')?.toInt() ?? 0;

        String workType = "不明";
        int qty = 0;
        int stdQty = logStdQty;

        if (c > 0) {
          workType = "清掃";
          qty = c;
          if (mStdClean > 0) stdQty = mStdClean;
        } else if (a > 0) {
          workType = "エアー清掃";
          qty = a;
          if (mStdAir > 0) stdQty = mStdAir;
        } else if (s > 0) {
          workType = "筐体交換";
          qty = s;
          if (mStdSwap > 0) stdQty = mStdSwap;
        } else {
          continue; 
        }

        String aggKey = workerName;

        if (!agg.containsKey(aggKey)) {
          agg[aggKey] = {
            "worker_name": workerName,
            "total_minutes": 0.0,
            "earned_minutes": 0.0, 
          };
        }
        
        double earned = 0;
        if (stdQty > 0) {
          earned = (qty / stdQty) * 60.0;
        }

        agg[aggKey]!["earned_minutes"] += earned;
        agg[aggKey]!["total_minutes"] += minutes;
      }

      List<Map<String, dynamic>> finalList = agg.values.toList();
      
      finalList.forEach((e) {
        double totalMin = e["total_minutes"];
        double earnedMin = e["earned_minutes"];
        double achievePercent = totalMin > 0 ? (earnedMin / totalMin) * 100 : 0.0;
        e["achieve_percent"] = achievePercent;
      });

      finalList.sort((a, b) => b["achieve_percent"].compareTo(a["achieve_percent"]));

      List<Map<String, dynamic>> top10 = finalList.where((e) {
        return e["achieve_percent"] > 0;
      }).take(10).toList();

      if (mounted) {
        setState(() {
          _rankingData = top10;
        });
      }
    } catch (e, stack) {
      print("ランキングデータ取得エラー: $e");
      print(stack);
    } finally {
      try {
        if (conn != null) await conn.close();
      } catch (_) {}
      if (mounted) {
        setState(() => _isFetchingRanking = false);
      }
    }
  }

  Future<void> _fetchProductivityData() async {
    if (_selectedWorker == null) return;
    setState(() => _isFetching = true);

    MySQLConnection? conn;
    try {
      conn = await _getConnection();
      await conn.connect();
      String sDate = _isAllTime ? '2000-01-01' : DateFormat('yyyy-MM-dd').format(_startDate);
      String eDate = _isAllTime ? '2099-12-31' : DateFormat('yyyy-MM-dd').format(_endDate);
      
      var result = await conn.execute('''
        SELECT 
          l.model_name, l.maker_abbr, l.std_qty as log_std_qty, 
          l.clean_qty, l.air_clean_qty, l.swap_qty, l.work_minutes,
          m.std_air, m.std_clean, m.std_swap
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        LEFT JOIN (
          SELECT model_name,
            MAX(CASE WHEN work_type = 'エアー清掃' THEN std_qty END) as std_air,
            MAX(CASE WHEN work_type = '清掃' THEN std_qty END) as std_clean,
            MAX(CASE WHEN work_type = '筐体交換' THEN std_qty END) as std_swap
          FROM m_models 
          GROUP BY model_name
        ) m ON l.model_name = m.model_name
        WHERE DATE(l.work_date) >= :s AND DATE(l.work_date) <= :e
        AND (mem.worker_name = :w OR l.worker_id = :w)
      ''', {
        "s": sDate,
        "e": eDate,
        "w": _selectedWorker
      });

      Map<String, Map<String, dynamic>> agg = {};
      
      for (var row in result.rows) {
        var data = row.assoc();
        String rawModel = data['model_name']?.toString() ?? "不明";
        String cleanModel = rawModel.contains(':') ? rawModel.split(':').last.replaceAll('}', '').trim() : rawModel;
        String makerAbbr = data['maker_abbr']?.toString() ?? "";
        String modelDisplay = makerAbbr.isNotEmpty ? "$cleanModel ($makerAbbr)" : cleanModel;

        int c = int.tryParse(data['clean_qty']?.toString() ?? '0') ?? 0;
        int a = int.tryParse(data['air_clean_qty']?.toString() ?? '0') ?? 0;
        int s = int.tryParse(data['swap_qty']?.toString() ?? '0') ?? 0;
        double minutes = double.tryParse(data['work_minutes']?.toString() ?? '0') ?? 0;
        
        int logStdQty = int.tryParse(data['log_std_qty']?.toString() ?? '0') ?? 0;
        int mStdAir = double.tryParse(data['std_air']?.toString() ?? '0')?.toInt() ?? 0;
        int mStdClean = double.tryParse(data['std_clean']?.toString() ?? '0')?.toInt() ?? 0;
        int mStdSwap = double.tryParse(data['std_swap']?.toString() ?? '0')?.toInt() ?? 0;

        String workType = "不明";
        int qty = 0;
        int stdQty = logStdQty;

        if (c > 0) {
          workType = "清掃";
          qty = c;
          if (mStdClean > 0) stdQty = mStdClean;
        } else if (a > 0) {
          workType = "エアー清掃";
          qty = a;
          if (mStdAir > 0) stdQty = mStdAir;
        } else if (s > 0) {
          workType = "筐体交換";
          qty = s;
          if (mStdSwap > 0) stdQty = mStdSwap;
        } else {
          continue; 
        }

        String aggKey = "${modelDisplay}_$workType";

        if (!agg.containsKey(aggKey)) {
          agg[aggKey] = {
            "model_name": modelDisplay,
            "work_type": workType,
            "total_qty": 0,
            "total_minutes": 0.0,
            "std_qty": stdQty, 
          };
        }
        agg[aggKey]!["total_qty"] += qty;
        agg[aggKey]!["total_minutes"] += minutes;
      }

      List<Map<String, dynamic>> finalList = agg.values.toList();
      
      finalList.sort((a, b) {
        double aProd = a["total_minutes"] > 0 ? (a["total_qty"] / (a["total_minutes"] / 60)) : 0;
        double bProd = b["total_minutes"] > 0 ? (b["total_qty"] / (b["total_minutes"] / 60)) : 0;
        return bProd.compareTo(aProd); 
      });

      if (mounted) {
        setState(() {
          _aggregatedData = finalList;
        });
      }
    } catch (e, stack) {
      print("生産性データ取得エラー: $e");
      print(stack);
    } finally {
      try {
        if (conn != null) await conn.close();
      } catch (_) {}
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    DateTime _focusedDay = _startDate;
    DateTime? _start = _startDate;
    DateTime? _end = _endDate;

    List<int> years = List.generate(11, (index) => 2020 + index);
    List<int> months = List.generate(12, (index) => index + 1);

    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.9,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C23),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "集計期間の選択",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.year,
                              dropdownColor: const Color(0xFF252830),
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text("$y年"))).toList(),
                              onChanged: (newYear) {
                                if (newYear != null) setDialogState(() => _focusedDay = DateTime(newYear, _focusedDay.month, 1));
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.month,
                              dropdownColor: const Color(0xFF252830),
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              items: months.map((m) => DropdownMenuItem(value: m, child: Text("$m月"))).toList(),
                              onChanged: (newMonth) {
                                if (newMonth != null) setDialogState(() => _focusedDay = DateTime(_focusedDay.year, newMonth, 1));
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
                            calendarStyle: const CalendarStyle(
                              rangeStartDecoration: BoxDecoration(color: Color(0xFF00FFCC), shape: BoxShape.circle),
                              rangeEndDecoration: BoxDecoration(color: Color(0xFF00FFCC), shape: BoxShape.circle),
                              rangeHighlightColor: Color(0x3300CCFF),
                              todayDecoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                              defaultTextStyle: TextStyle(color: Colors.white, fontSize: 22),
                              outsideTextStyle: TextStyle(color: Colors.white24, fontSize: 22),
                              weekendTextStyle: TextStyle(color: Colors.redAccent, fontSize: 22),
                            ),
                            calendarBuilders: CalendarBuilders(
                              dowBuilder: (context, day) {
                                if (day.weekday == DateTime.saturday) return const Center(child: Text('土', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 20)));
                                if (day.weekday == DateTime.sunday) return const Center(child: Text('日', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 20)));
                                return null;
                              },
                              defaultBuilder: (context, day, focusedDay) {
                                if (day.weekday == DateTime.saturday) return Center(child: Text('${day.day}', style: const TextStyle(color: Colors.blueAccent, fontSize: 22)));
                                return null;
                              },
                            ),
                            daysOfWeekHeight: 50,
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(fontSize: 0), 
                              leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF00FFCC), size: 40),
                              rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF00FFCC), size: 40),
                              headerMargin: EdgeInsets.only(bottom: 5),
                            ),
                            onPageChanged: (focusedDay) {
                               setDialogState(() => _focusedDay = focusedDay);
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
                            child: const Text("キャンセル", style: TextStyle(color: Colors.white54, fontSize: 20)),
                          ),
                          const SizedBox(width: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        _isAllTime = false;
        _startDate = result["start"]!;
        _endDate = result["end"]!;
      });
      _fetchProductivityData();
    }
  }

  Future<void> _pickMonth() async {
    DateTime now = DateTime.now();
    int selectedYear = _isAllTime ? now.year : _startDate.year;
    int selectedMonth = _isAllTime ? now.month : _startDate.month;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1C23),
              title: const Text("月を選択", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      dropdownColor: const Color(0xFF252830),
                      value: selectedYear,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      items: List.generate(10, (index) => now.year - 5 + index)
                          .map((y) => DropdownMenuItem(value: y, child: Text("$y年")))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedYear = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      dropdownColor: const Color(0xFF252830),
                      value: selectedMonth,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      items: List.generate(12, (index) => index + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text("$m月")))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedMonth = val);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("キャンセル", style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("決定", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );

    if (confirmed == true) {
      setState(() {
        _isAllTime = false;
        _startDate = DateTime(selectedYear, selectedMonth, 1);
        _endDate = DateTime(selectedYear, selectedMonth + 1, 0); // 月末日
      });
      _fetchProductivityData();
    }
  }

  Future<void> _pickRankingMonth() async {
    int selectedYear = _rankingMonth.year;
    int selectedMonth = _rankingMonth.month;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1C23),
              title: const Text("ランキング対象月を選択", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      dropdownColor: const Color(0xFF252830),
                      value: selectedYear,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      items: List.generate(10, (index) => DateTime.now().year - 5 + index)
                          .map((y) => DropdownMenuItem(value: y, child: Text("$y年")))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedYear = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      dropdownColor: const Color(0xFF252830),
                      value: selectedMonth,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      items: List.generate(12, (index) => index + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text("$m月")))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedMonth = val);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("キャンセル", style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("決定", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );

    if (confirmed == true) {
      setState(() {
        _rankingMonth = DateTime(selectedYear, selectedMonth, 1);
      });
      _fetchRankingData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1C23),
          title: const Text("個人別生産性確認", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: Center(child: ConnectionStatusIndicator()),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.orangeAccent,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.orangeAccent,
            tabs: [
              Tab(icon: Icon(Icons.person), text: "個人別詳細"),
              Tab(icon: Icon(Icons.leaderboard), text: "今月 TOP10"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPersonalTab(),
            _buildRankingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
          children: [
            // フィルターエリア
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C23),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.orangeAccent, size: 28),
                  const SizedBox(width: 10),
                  const Text("担当者:", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF252830),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.orangeAccent),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          value: _selectedWorker,
                          items: _workers.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedWorker = val);
                              _fetchProductivityData();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  const Icon(Icons.calendar_month, color: Color(0xFF00CCFF), size: 28),
                  const SizedBox(width: 10),
                  const Text("対象期間:", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00CCFF).withOpacity(0.1),
                        foregroundColor: const Color(0xFF00CCFF),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFF00CCFF)),
                      ),
                      onPressed: _pickDateRange,
                      child: Text(
                        _isAllTime ? "全期間" : "${DateFormat('yyyy/MM/dd').format(_startDate)} ～ ${DateFormat('yyyy/MM/dd').format(_endDate)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _pickMonth,
                    child: const Text("月選択", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAllTime ? const Color(0xFF00CCFF) : Colors.white10,
                      foregroundColor: _isAllTime ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        _isAllTime = true;
                      });
                      _fetchProductivityData();
                    },
                    child: const Text("全期間", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // データ表示エリア
            Expanded(
              child: _isFetching 
                ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                : _aggregatedData.isEmpty
                  ? const Center(child: Text("指定された条件のデータはありません", style: TextStyle(color: Colors.white54, fontSize: 20)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3.3,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                      itemCount: _aggregatedData.length,
                      itemBuilder: (context, index) {
                        var item = _aggregatedData[index];
                        int totalQty = item['total_qty'];
                        double totalMinutes = item['total_minutes'];
                        int stdQty = item['std_qty'];

                        double currentProd = totalMinutes > 0 ? (totalQty / (totalMinutes / 60)) : 0;
                        double achieveRate = stdQty > 0 ? (currentProd / stdQty) : 0;
                        double achievePercent = achieveRate * 100;

                        Color progressColor = Colors.redAccent;
                        if (achievePercent >= 100) {
                          progressColor = Colors.greenAccent;
                        } else if (achievePercent >= 80) {
                          progressColor = Colors.orangeAccent;
                        }

                        String workType = item['work_type'] ?? "不明";
                        Color typeColor = Colors.grey;
                        if (workType == "清掃") {
                          typeColor = Colors.greenAccent;
                        } else if (workType == "エアー清掃") {
                          typeColor = const Color(0xFF00CCFF);
                        } else if (workType == "筐体交換") {
                          typeColor = Colors.orangeAccent;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: typeColor.withOpacity(0.8), width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: typeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: typeColor),
                                          ),
                                          child: Text(workType, style: TextStyle(color: typeColor, fontSize: 14, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(item['model_name'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "達成率: ${achievePercent.toStringAsFixed(1)}%",
                                    style: TextStyle(color: progressColor, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currentProd.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 4, left: 2),
                                    child: Text("台/1H", style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      "(目標: $stdQty)",
                                      style: const TextStyle(fontSize: 16, color: Colors.white54, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text("処理数: $totalQty台", style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text("時間: ${totalMinutes.toStringAsFixed(0)}分", style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  )
                                ],
                              ),
                              const Spacer(),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: achieveRate.clamp(0.0, 1.5) / 1.5, // 150%をMAXとして描画
                                  backgroundColor: Colors.white10,
                                  color: progressColor,
                                  minHeight: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("0%", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text("100%", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text("150%+", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
  }

  Widget _buildRankingTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // 月選択エリア
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C23),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Color(0xFF00CCFF), size: 28),
                const SizedBox(width: 10),
                const Text("対象月:", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00CCFF).withOpacity(0.1),
                      foregroundColor: const Color(0xFF00CCFF),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF00CCFF)),
                    ),
                    onPressed: _pickRankingMonth,
                    child: Text(
                      DateFormat('yyyy年MM月').format(_rankingMonth),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isFetchingRanking
                ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                : _rankingData.isEmpty
                    ? const Center(child: Text("該当月のデータがありません", style: TextStyle(color: Colors.white, fontSize: 18)))
                    : ListView.builder(
        itemCount: _rankingData.length,
        itemBuilder: (context, index) {
          var item = _rankingData[index];
          double achievePercent = item['achieve_percent']?.toDouble() ?? 0.0;
          double totalMinutes = item['total_minutes']?.toDouble() ?? 0.0;

          Color typeColor = Colors.orangeAccent;

          Color progressColor = Colors.redAccent;
          if (achievePercent >= 100) progressColor = const Color(0xFF00FFCC);
          else if (achievePercent >= 80) progressColor = Colors.orangeAccent;

          // ランキングアイコン
          Widget rankWidget;
          if (index == 0) {
            rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 40);
          } else if (index == 1) {
            rankWidget = const Icon(Icons.emoji_events, color: Colors.grey, size: 40);
          } else if (index == 2) {
            rankWidget = const Icon(Icons.emoji_events, color: Colors.brown, size: 40);
          } else {
            rankWidget = Container(
              width: 40,
              alignment: Alignment.center,
              child: Text("${index + 1}", style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: typeColor.withOpacity(0.5), width: 1),
            ),
            child: Row(
              children: [
                rankWidget,
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['worker_name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("総作業時間: ${(totalMinutes / 60).toStringAsFixed(1)}時間", style: const TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("総合達成率: ${achievePercent.toStringAsFixed(1)}%", style: TextStyle(color: progressColor, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
