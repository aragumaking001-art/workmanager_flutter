import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/data_provider.dart';
import '../widgets/app_background_wrapper.dart';
import '../widgets/anomaly_status_indicator.dart';

class PersonalProductivityPage extends StatefulWidget {
  final String? initialWorkerId;
  final bool isKioskMode;

  const PersonalProductivityPage({
    super.key,
    this.initialWorkerId,
    this.isKioskMode = false,
  });

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
    
    // Kioskモード時もデフォルトは当月表示とするため、_isAllTime の上書きを削除しました

    // Kioskモード時は初期ワーカーID（NFC IDなど）を名前に変換してセット
    if (widget.initialWorkerId != null) {
      // DataProviderのインスタンスをビルド前なので context.read または後で取得する
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final dp = Provider.of<DataProvider>(context, listen: false);
        // NFC IDがworkerStatsMapにある場合、その名前を取得
        if (dp.workerStatsMap.containsKey(widget.initialWorkerId)) {
          setState(() {
            _selectedWorker = dp.workerStatsMap[widget.initialWorkerId!]?.name ?? widget.initialWorkerId;
          });
        } else {
          setState(() {
            _selectedWorker = widget.initialWorkerId;
          });
        }
        _fetchProductivityData();
      });
    }

    _fetchWorkers().then((_) {
      if (_workers.isNotEmpty) {
        // もし_selectedWorkerが設定されていなければ最初のワーカーを選択
        if (_selectedWorker == null) {
          setState(() {
            _selectedWorker = _workers.first;
          });
          if (widget.initialWorkerId == null) {
             _fetchProductivityData();
          }
        }
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
          l.clean_qty, l.air_clean_qty, l.swap_qty, l.to_swap_qty, l.work_minutes,
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
        int toSwap = int.tryParse(data['to_swap_qty']?.toString() ?? '0') ?? 0;
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
        } else if (toSwap > 0) {
          // 清掃数が0でも交換行きが記録されている場合のセーフティ
        } else {
          continue; 
        }

        String aggKey = workerName;

        if (!agg.containsKey(aggKey)) {
          agg[aggKey] = {
            "worker_name": workerName,
            "total_minutes": 0.0,
            "earned_minutes": 0.0, 
            "total_air": 0,
            "total_clean": 0,
            "total_swap": 0,
            "total_to_swap": 0,
          };
        }
        
        double earned = 0;
        if (stdQty > 0 && qty > 0) {
          earned = (qty / stdQty) * 60.0;
        }

        agg[aggKey]!["earned_minutes"] += earned;
        agg[aggKey]!["total_minutes"] += minutes;
        agg[aggKey]!["total_air"] = (agg[aggKey]!["total_air"] as int) + a;
        agg[aggKey]!["total_clean"] = (agg[aggKey]!["total_clean"] as int) + c;
        agg[aggKey]!["total_swap"] = (agg[aggKey]!["total_swap"] as int) + s;
        agg[aggKey]!["total_to_swap"] = (agg[aggKey]!["total_to_swap"] as int) + toSwap;
      }

      List<Map<String, dynamic>> finalList = agg.values.toList();
      
      finalList.forEach((e) {
        double totalMin = e["total_minutes"];
        double earnedMin = e["earned_minutes"];
        double achievePercent = totalMin > 0 ? (earnedMin / totalMin) * 100 : 0.0;
        e["achieve_percent"] = achievePercent;

        int totAir = e["total_air"] ?? 0;
        int totClean = e["total_clean"] ?? 0;
        int totToSwap = e["total_to_swap"] ?? 0;
        int cleanBase = totClean + totToSwap;
        double swapRate = cleanBase > 0 ? (totToSwap / cleanBase * 100.0) : 0.0;
        e["swap_rate"] = swapRate;
      });

      finalList.sort((a, b) => b["achieve_percent"].compareTo(a["achieve_percent"]));

      // ⭐ 一人の取りこぼしもなく「実績・データがある全作業者」を順位表へエントリー！ (.take(10)足切り全廃)
      List<Map<String, dynamic>> allRankings = finalList.where((e) {
        return (e["achieve_percent"] > 0 || (e["total_minutes"] != null && e["total_minutes"] > 0) || (e["total_to_swap"] != null && e["total_to_swap"] > 0));
      }).toList();

      if (mounted) {
        setState(() {
          _rankingData = allRankings;
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
          l.clean_qty, l.air_clean_qty, l.swap_qty, l.to_swap_qty, l.work_minutes,
          m.std_air, m.std_clean, m.std_swap, m.sort_id
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        LEFT JOIN (
          SELECT model_name,
            MIN(sort_order) as sort_id,
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
        int toSwap = int.tryParse(data['to_swap_qty']?.toString() ?? '0') ?? 0;
        double minutes = double.tryParse(data['work_minutes']?.toString() ?? '0') ?? 0;
        
        int logStdQty = int.tryParse(data['log_std_qty']?.toString() ?? '0') ?? 0;
        int mStdAir = double.tryParse(data['std_air']?.toString() ?? '0')?.toInt() ?? 0;
        int mStdClean = double.tryParse(data['std_clean']?.toString() ?? '0')?.toInt() ?? 0;
        int mStdSwap = double.tryParse(data['std_swap']?.toString() ?? '0')?.toInt() ?? 0;
        int sortId = int.tryParse(data['sort_id']?.toString() ?? '999999') ?? 999999;

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
        } else if (toSwap > 0) {
          // 清掃実績なしで交換行きのみ記録された場合の処置
          workType = "清掃";
          qty = 0;
        } else {
          continue; 
        }

        String aggKey = "${modelDisplay}_$workType";

        if (!agg.containsKey(aggKey)) {
          agg[aggKey] = {
            "model_name": modelDisplay,
            "work_type": workType,
            "sort_id": sortId,
            "total_qty": 0,
            "total_minutes": 0.0,
            "total_to_swap": 0,
            "std_qty": stdQty, 
          };
        }
        agg[aggKey]!["total_qty"] += qty;
        agg[aggKey]!["total_minutes"] += minutes;
        agg[aggKey]!["total_to_swap"] = (agg[aggKey]!["total_to_swap"] ?? 0) + toSwap;
      }

      List<Map<String, dynamic>> finalList = agg.values.toList();
      
      Map<String, int> typeOrder = {
        "エアー清掃": 0,
        "清掃": 1,
        "筐体交換": 2,
      };

      finalList.sort((a, b) {
        int orderA = typeOrder[a["work_type"]] ?? 99;
        int orderB = typeOrder[b["work_type"]] ?? 99;
        
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }

        int idA = a["sort_id"] ?? 999999;
        int idB = b["sort_id"] ?? 999999;
        return idA.compareTo(idB);
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
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    if (widget.isKioskMode) {
      // Kioskモードの時は、親のKioskDetailScreenのAppBackgroundWrapperを透過して表示
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildPersonalTab(),
          ),
        ),
      );
    }

    return AppBackgroundWrapper(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: dp.currentCardColor.withValues(alpha: isWhite ? 0.85 : 0.65),
            elevation: isWhite ? 2 : 0,
            iconTheme: IconThemeData(color: dp.mainTextColor),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: dp.mainTextColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text("個人別生産性確認", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: dp.mainTextColor)),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 20.0),
                child: Center(child: ConnectionStatusIndicator()),
              ),
            ],
            bottom: TabBar(
              labelColor: isWhite ? const Color(0xFFD45500) : Colors.orangeAccent,
              unselectedLabelColor: isWhite ? Colors.black38 : Colors.white54,
              indicatorColor: isWhite ? const Color(0xFFD45500) : Colors.orangeAccent,
              tabs: const [
                Tab(icon: Icon(Icons.person), text: "個人別詳細"),
                Tab(icon: Icon(Icons.leaderboard), text: "月別生産性ランキング"),
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
      ),
    );
  }

  double get _totalAchievementRate {
    if (_aggregatedData.isEmpty) return 0.0;
    
    double totalWeightedAchieve = 0.0;
    double totalTime = 0.0;
    
    for (var item in _aggregatedData) {
      int totalQty = item['total_qty'] ?? 0;
      double totalMinutes = (item['total_minutes'] ?? 0.0).toDouble();
      int stdQty = item['std_qty'] ?? 0;
      
      if (totalMinutes > 0 && stdQty > 0) {
        double currentProd = totalQty / (totalMinutes / 60);
        double achieveRate = currentProd / stdQty;
        totalWeightedAchieve += achieveRate * 100 * totalMinutes;
        totalTime += totalMinutes;
      }
    }
    
    if (totalTime == 0) return 0.0;
    return totalWeightedAchieve / totalTime;
  }

  double get _totalWorkMinutes {
    if (_aggregatedData.isEmpty) return 0.0;
    double totalTime = 0.0;
    for (var item in _aggregatedData) {
      totalTime += (item['total_minutes'] ?? 0.0).toDouble();
    }
    return totalTime;
  }

  String get _totalWorkTimeDisplay {
    int totalMin = _totalWorkMinutes.round();
    if (totalMin <= 0) return "0分";

    // 1年 = 12か月 = 240日 = 1680時間 = 100800分 (現場勤務時間ベース: 1日7時間)
    if (totalMin >= 100800) {
      int years = totalMin ~/ 100800;
      int remMin = totalMin % 100800;
      int months = remMin ~/ 8400;
      if (months > 0) {
        return "約$years年$monthsか月";
      } else {
        return "約$years年";
      }
    }

    // 1か月 = 20日 = 140時間 = 8400分 (現場勤務時間ベース: 1日7時間)
    if (totalMin >= 8400) {
      double months = totalMin / 8400.0;
      String mStr = months.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      return "約$mStrか月";
    }

    // 1日 = 7時間 = 420分
    if (totalMin >= 420) {
      int days = totalMin ~/ 420;
      int remMin = totalMin % 420;
      int hours = remMin ~/ 60;
      if (hours > 0) {
        return "約$days日$hours時間";
      } else {
        return "約$days日";
      }
    }

    // 1日未満 (7時間未満)
    int h = totalMin ~/ 60;
    int m = totalMin % 60;
    if (h > 0) {
      return m > 0 ? "$h時間$m分" : "$h時間";
    } else {
      return "$m分";
    }
  }

  double get _totalSwapRate {
    if (_aggregatedData.isEmpty) return 0.0;
    int totClean = 0;
    int totToSwap = 0;
    for (var item in _aggregatedData) {
      String type = item['work_type'] ?? '';
      int qty = item['total_qty'] ?? 0;
      int ts = item['total_to_swap'] ?? 0;
      if (type == '清掃') totClean += qty;
      totToSwap += ts;
    }
    int cleanBase = totClean + totToSwap;
    if (cleanBase == 0) return 0.0;
    return (totToSwap / cleanBase) * 100.0;
  }

  String get _dominantWorkType {
    if (_aggregatedData.isEmpty) return "清掃";

    Map<String, int> qtyMap = {
      "清掃": 0,
      "エアー清掃": 0,
      "筐体交換": 0,
    };
    Map<String, double> minMap = {
      "清掃": 0.0,
      "エアー清掃": 0.0,
      "筐体交換": 0.0,
    };

    for (var item in _aggregatedData) {
      String wt = item['work_type'] ?? "清掃";
      int q = (item['total_qty'] as num?)?.toInt() ?? 0;
      double m = (item['total_minutes'] as num?)?.toDouble() ?? 0.0;
      qtyMap[wt] = (qtyMap[wt] ?? 0) + q;
      minMap[wt] = (minMap[wt] ?? 0.0) + m;
    }

    String topType = "清掃";
    int maxQty = -1;
    double maxMinutes = -1.0;

    for (var entry in qtyMap.entries) {
      String type = entry.key;
      int q = entry.value;
      double m = minMap[type] ?? 0.0;

      // 台数(total_qty)が多い区分を優先。同数の場合は作業時間(total_minutes)で判定
      if (q > maxQty || (q == maxQty && m > maxMinutes)) {
        maxQty = q;
        maxMinutes = m;
        topType = type;
      }
    }
    return topType;
  }

  Widget _buildPersonalTab() {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
          children: [
            // フィルターエリア
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: dp.currentCardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: dp.borderColor),
                boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
              ),
              child: Row(
                children: [
                  if (!widget.isKioskMode) ...[
                    Icon(Icons.person, color: isWhite ? const Color(0xFFD45500) : Colors.orangeAccent, size: 28),
                    const SizedBox(width: 10),
                    Text("担当者:", style: TextStyle(color: dp.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: isWhite ? const Color(0xFFEAEEF6) : const Color(0xFF222736),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isWhite ? const Color(0xFF7D8AB2) : const Color(0xFF546394), width: 1.3),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: dp.currentCardColor,
                            icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFFD45500) : Colors.orangeAccent),
                            style: TextStyle(color: dp.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                            value: _selectedWorker,
                            items: _workers.map((w) => DropdownMenuItem(value: w, child: Text(w, style: TextStyle(color: dp.mainTextColor)))).toList(),
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
                  ],
                  Icon(Icons.calendar_month, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
                  const SizedBox(width: 10),
                  Text("対象期間:", style: TextStyle(color: dp.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isWhite ? const Color(0xFFD4EFFC) : const Color(0xFF0E384C),
                        foregroundColor: isWhite ? const Color(0xFF005580) : const Color(0xFF33D9FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isWhite ? const Color(0xFF0077AA) : const Color(0xFF00BAFF), width: 1.5),
                        elevation: isWhite ? 2 : 0,
                      ),
                      onPressed: _pickDateRange,
                      child: Text(
                        _isAllTime ? "全期間 表示中" : "${DateFormat('yyyy/MM/dd').format(_startDate)} ～ ${DateFormat('yyyy/MM/dd').format(_endDate)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWhite ? const Color(0xFFE2F7EB) : const Color(0xFF0E3B27),
                      foregroundColor: isWhite ? const Color(0xFF006B33) : const Color(0xFF33FF99),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: isWhite ? const Color(0xFF00994C) : const Color(0xFF00E673), width: 1.5),
                      elevation: isWhite ? 2 : 0,
                    ),
                    onPressed: _pickMonth,
                    child: const Text("月選択", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAllTime ? (isWhite ? const Color(0xFFD45500) : Colors.orangeAccent) : (isWhite ? const Color(0xFFFEECE2) : const Color(0xFF42210B)),
                      foregroundColor: _isAllTime ? (isWhite ? Colors.white : Colors.black) : (isWhite ? const Color(0xFFB53D00) : const Color(0xFFFF9A5C)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: _isAllTime ? Colors.transparent : (isWhite ? const Color(0xFFD45500) : Colors.orangeAccent), width: 1.5),
                      elevation: isWhite ? 2 : 0,
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
            const SizedBox(height: 12),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左側: 総合達成率の縦長パネル
                  if (!_isFetching && _aggregatedData.isNotEmpty && _selectedWorker != null)
                    Builder(
                      builder: (context) {
                        String dominantWorkType = _dominantWorkType;
                        Color dominantTypeColor = isWhite ? Colors.grey.shade700 : Colors.grey;
                        Color panelBgColor;

                        if (dominantWorkType == "清掃") {
                          dominantTypeColor = isWhite ? const Color(0xFF008855) : Colors.greenAccent;
                          panelBgColor = isWhite ? const Color(0xFFEDF8F2) : const Color(0xFF00FF88).withOpacity(0.14);
                        } else if (dominantWorkType == "エアー清掃") {
                          dominantTypeColor = isWhite ? const Color(0xFF006688) : const Color(0xFF00CCFF);
                          panelBgColor = isWhite ? const Color(0xFFEBF7FC) : const Color(0xFF00CCFF).withOpacity(0.16);
                        } else if (dominantWorkType == "筐体交換") {
                          dominantTypeColor = isWhite ? const Color(0xFFD45500) : Colors.orangeAccent;
                          panelBgColor = isWhite ? const Color(0xFFFFF4EB) : const Color(0xFFFF8800).withOpacity(0.16);
                        } else {
                          panelBgColor = isWhite ? const Color(0xFF008855).withOpacity(0.12) : const Color(0xFF00FFCC).withOpacity(0.1);
                          dominantTypeColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
                        }

                        return Container(
                          width: 255,
                          margin: const EdgeInsets.only(right: 16, bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: panelBgColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isWhite ? dominantTypeColor.withOpacity(0.7) : dominantTypeColor.withOpacity(0.8),
                              width: 2.0,
                            ),
                            boxShadow: isWhite ? [
                              BoxShadow(
                                color: dominantTypeColor.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ] : null,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double targetHeight = constraints.maxHeight > 460 ? constraints.maxHeight : 460;

                              return Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 235,
                                    height: targetHeight,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        // 1. タイトル ＋ 作業区分バッジ
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.stars, color: dominantTypeColor, size: 26),
                                                const SizedBox(width: 8),
                                                Text("総合達成率", style: TextStyle(color: dp.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "最多作業:",
                                                  style: TextStyle(
                                                    color: isWhite ? const Color(0xFF4B5563) : dp.subTextColor,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: isWhite ? Colors.white.withOpacity(0.9) : dominantTypeColor.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: dominantTypeColor, width: 1.5),
                                                  ),
                                                  child: Text(
                                                    dominantWorkType,
                                                    style: TextStyle(color: dominantTypeColor, fontSize: 13, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // 2. マスコットキャラクター（どーんと大きく！）
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.35),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              _totalAchievementRate >= 100 
                                                  ? 'assets/mascot_excellent.jpg' 
                                                  : (_totalAchievementRate >= 80 
                                                      ? 'assets/mascot_good_pace.jpg' 
                                                      : 'assets/mascot_fight.jpg'),
                                              width: 140,
                                              height: 140,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),

                                        // 3. 達成率数値 ＋ 作業時間チップ
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "${_totalAchievementRate.toStringAsFixed(1)}%",
                                              style: TextStyle(
                                                color: _totalAchievementRate >= 100 
                                                    ? (isWhite ? const Color(0xFF008855) : Colors.greenAccent) 
                                                    : (_totalAchievementRate >= 80 
                                                        ? (isWhite ? const Color(0xFFD45500) : Colors.orangeAccent) 
                                                        : (isWhite ? Colors.red.shade700 : Colors.redAccent)),
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: isWhite ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isWhite ? dominantTypeColor.withOpacity(0.4) : dominantTypeColor.withOpacity(0.3),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.schedule,
                                                      size: 17,
                                                      color: isWhite ? dominantTypeColor : const Color(0xFF00CCFF),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "作業時間: $_totalWorkTimeDisplay",
                                                      style: TextStyle(
                                                        color: dp.mainTextColor,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // 4. 区切り線
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Container(height: 1.5, width: double.infinity, color: dp.borderColor),
                                        ),

                                        // 5. 筐体交換行き率表示
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.verified_outlined, color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent, size: 22),
                                                  const SizedBox(width: 6),
                                                  Text("筐体交換行き率", style: TextStyle(color: dp.mainTextColor, fontSize: 17, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${_totalSwapRate.toStringAsFixed(1)}%",
                                              style: TextStyle(
                                                color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent,
                                                fontSize: 34,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                  // 右側: データ表示エリア (GridView)
                  Expanded(
                    child: _isFetching 
                      ? Center(child: CircularProgressIndicator(color: isWhite ? const Color(0xFFD45500) : Colors.orangeAccent))
                : _aggregatedData.isEmpty
                  ? Center(child: Text("指定された条件のデータはありません", style: TextStyle(color: dp.subTextColor, fontSize: 20)))
                  : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
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

                        Color progressColor = isWhite ? Colors.red.shade700 : Colors.redAccent;
                        if (achievePercent >= 100) {
                          progressColor = isWhite ? const Color(0xFF008855) : Colors.greenAccent;
                        } else if (achievePercent >= 80) {
                          progressColor = isWhite ? const Color(0xFFD45500) : Colors.orangeAccent;
                        }
                        
                        String timeDisplay = "";
                        int h = (totalMinutes / 60).floor();
                        int m = (totalMinutes % 60).round();
                        if (h > 0) {
                          timeDisplay = "$h時間$m分";
                        } else {
                          timeDisplay = "$m分";
                        }

                        String workType = item['work_type'] ?? "不明";
                        Color typeColor = isWhite ? Colors.grey.shade700 : Colors.grey;
                        Color cardBgColor;

                        if (workType == "清掃") {
                          typeColor = isWhite ? const Color(0xFF008855) : Colors.greenAccent;
                          cardBgColor = isWhite ? const Color(0xFFEDF8F2) : const Color(0xFF00FF88).withOpacity(0.14);
                        } else if (workType == "エアー清掃") {
                          typeColor = isWhite ? const Color(0xFF006688) : const Color(0xFF00CCFF);
                          cardBgColor = isWhite ? const Color(0xFFEBF7FC) : const Color(0xFF00CCFF).withOpacity(0.16);
                        } else if (workType == "筐体交換") {
                          typeColor = isWhite ? const Color(0xFFD45500) : Colors.orangeAccent;
                          cardBgColor = isWhite ? const Color(0xFFFFF4EB) : const Color(0xFFFF8800).withOpacity(0.16);
                        } else {
                          cardBgColor = isWhite ? Colors.white : dp.currentCardColor;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isWhite ? typeColor.withOpacity(0.7) : typeColor.withOpacity(0.8), 
                              width: 2.0,
                            ),
                            boxShadow: isWhite ? [
                              BoxShadow(color: typeColor.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isWhite ? Colors.white.withOpacity(0.9) : typeColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: typeColor, width: 1.5),
                                          ),
                                          child: Text(workType, style: TextStyle(color: typeColor, fontSize: 14, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(item['model_name'], style: TextStyle(color: dp.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currentProd.toStringAsFixed(1),
                                          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: dp.mainTextColor),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4, left: 3),
                                          child: Text("台/1H", style: TextStyle(fontSize: 14, color: dp.subTextColor, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 14),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            "(目標: $stdQty)",
                                            style: TextStyle(fontSize: 16, color: dp.subTextColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text("処理数: $totalQty台", style: TextStyle(fontSize: 13, color: dp.mainTextColor, fontWeight: FontWeight.bold)),
                                            Text("時間: $timeDisplay", style: TextStyle(fontSize: 13, color: dp.mainTextColor, fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      ],
                                    ),
                                    const Spacer(),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: achieveRate.clamp(0.0, 1.5) / 1.5,
                                        backgroundColor: isWhite ? Colors.grey.shade200 : Colors.white10,
                                        color: progressColor,
                                        minHeight: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Stack(
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text("0%", style: TextStyle(color: dp.subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        Align(
                                          alignment: const Alignment(0.333, 0),
                                          child: Text("100%", style: TextStyle(color: dp.subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text("150%+", style: TextStyle(color: dp.subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        achievePercent >= 100 
                                            ? 'assets/mascot_excellent.jpg' 
                                            : (achievePercent >= 80 
                                                ? 'assets/mascot_good_pace.jpg' 
                                                : 'assets/mascot_fight.jpg'),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "達成率\n${achievePercent.toStringAsFixed(1)}%",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: progressColor, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                                  ),
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
            ),
          ],
        ),
      );
  }

  Widget _buildRankingTab() {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // 月選択エリア
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: dp.currentCardColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: dp.borderColor),
              boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
                const SizedBox(width: 10),
                Text("対象月:", style: TextStyle(color: dp.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWhite ? const Color(0xFFD4EFFC) : const Color(0xFF0E384C),
                      foregroundColor: isWhite ? const Color(0xFF005580) : const Color(0xFF33D9FF),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: isWhite ? const Color(0xFF0077AA) : const Color(0xFF00BAFF), width: 1.5),
                      elevation: isWhite ? 2 : 0,
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
                ? Center(child: CircularProgressIndicator(color: isWhite ? const Color(0xFFD45500) : Colors.orangeAccent))
                : _rankingData.isEmpty
                    ? Center(child: Text("該当月のデータがありません", style: TextStyle(color: dp.mainTextColor, fontSize: 18)))
                    : ListView.builder(
                        itemCount: _rankingData.length,
                        itemBuilder: (context, index) {
                          var item = _rankingData[index];
                          double achievePercent = item['achieve_percent']?.toDouble() ?? 0.0;
                          double swapRate = item['swap_rate']?.toDouble() ?? 0.0;
                          double totalMinutes = item['total_minutes']?.toDouble() ?? 0.0;

                          int totAir = item['total_air'] ?? 0;
                          int totClean = item['total_clean'] ?? 0;
                          int totSwap = item['total_swap'] ?? 0;
                          String workerDomType = "清掃";
                          if (totAir > totClean && totAir > totSwap) {
                            workerDomType = "エアー清掃";
                          } else if (totSwap > totClean && totSwap > totAir) {
                            workerDomType = "筐体交換";
                          }

                          Color typeColor;
                          Color cardBgColor;
                          if (workerDomType == "エアー清掃") {
                            typeColor = isWhite ? const Color(0xFF006688) : const Color(0xFF00CCFF);
                            cardBgColor = isWhite ? const Color(0xFFEBF7FC) : const Color(0xFF00CCFF).withOpacity(0.12);
                          } else if (workerDomType == "筐体交換") {
                            typeColor = isWhite ? const Color(0xFFD45500) : Colors.orangeAccent;
                            cardBgColor = isWhite ? const Color(0xFFFFF4EB) : const Color(0xFFFF8800).withOpacity(0.12);
                          } else {
                            typeColor = isWhite ? const Color(0xFF008855) : Colors.greenAccent;
                            cardBgColor = isWhite ? const Color(0xFFEDF8F2) : const Color(0xFF00FF88).withOpacity(0.12);
                          }

                          // 作業比率に応じた「くっきり帯グラフ風」背景グラデーションの構築 (エアー -> 清掃 -> 筐体交換)
                          Color airBg = isWhite ? const Color(0xFFEBF7FC) : const Color(0xFF00CCFF).withOpacity(0.12);
                          Color cleanBg = isWhite ? const Color(0xFFEDF8F2) : const Color(0xFF00FF88).withOpacity(0.12);
                          Color swapBg = isWhite ? const Color(0xFFFFF4EB) : const Color(0xFFFF8800).withOpacity(0.12);

                          int totalWorkUnits = totAir + totClean + totSwap;
                          List<Color> gradientColors = [];
                          List<double> gradientStops = [];

                          if (totalWorkUnits > 0) {
                            final workSegments = [
                              if (totAir > 0) {'color': airBg, 'ratio': totAir / totalWorkUnits},
                              if (totClean > 0) {'color': cleanBg, 'ratio': totClean / totalWorkUnits},
                              if (totSwap > 0) {'color': swapBg, 'ratio': totSwap / totalWorkUnits},
                            ];

                            // 💡 割合(%)が大きい作業区分を左側から順に並べる (降順ソート)
                            workSegments.sort((a, b) => (b['ratio'] as double).compareTo(a['ratio'] as double));

                            if (workSegments.length > 1) {
                              double currentPos = 0.0;
                              for (int i = 0; i < workSegments.length; i++) {
                                Color segColor = workSegments[i]['color'] as Color;
                                double segRatio = workSegments[i]['ratio'] as double;
                                double nextPos = (i == workSegments.length - 1) ? 1.0 : (currentPos + segRatio).clamp(0.0, 1.0);

                                gradientColors.add(segColor);
                                gradientStops.add(currentPos);
                                gradientColors.add(segColor);
                                gradientStops.add(nextPos);

                                currentPos = nextPos;
                              }
                            }
                          }

                          Color progressColor = isWhite ? Colors.red.shade700 : Colors.redAccent;
                          if (achievePercent >= 100) progressColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
                          else if (achievePercent >= 80) progressColor = isWhite ? const Color(0xFFD45500) : Colors.orangeAccent;

                          // ランキングアイコン
                          Widget rankWidget;
                          if (index == 0) {
                            rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 42);
                          } else if (index == 1) {
                            rankWidget = const Icon(Icons.emoji_events, color: Colors.blueGrey, size: 40);
                          } else if (index == 2) {
                            rankWidget = const Icon(Icons.emoji_events, color: Colors.brown, size: 40);
                          } else {
                            rankWidget = Container(
                              width: 42,
                              alignment: Alignment.center,
                              child: Text("${index + 1}", style: TextStyle(color: dp.subTextColor, fontSize: 24, fontWeight: FontWeight.bold)),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedWorker = item['worker_name'];
                              });
                              _fetchProductivityData();
                              DefaultTabController.of(context)?.animateTo(0);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: gradientColors.isEmpty ? cardBgColor : null,
                                gradient: gradientColors.isNotEmpty
                                    ? LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: gradientColors,
                                        stops: gradientStops,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: typeColor.withOpacity(isWhite ? 0.7 : 0.6), width: isWhite ? 2 : 1.5),
                                boxShadow: isWhite ? [BoxShadow(color: typeColor.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))] : null,
                              ),
                              child: Row(
                              children: [
                                rankWidget,
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(item['worker_name'], style: TextStyle(color: dp.mainTextColor, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isWhite ? Colors.white.withOpacity(0.9) : typeColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: typeColor, width: 1.2),
                                            ),
                                            child: Text(
                                              "最多: $workerDomType",
                                              style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text("総作業時間: ${(totalMinutes / 60).toStringAsFixed(1)}時間", style: TextStyle(color: dp.subTextColor, fontSize: 16)),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isWhite ? Colors.grey.shade100 : Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isWhite ? Colors.purple.shade300 : Colors.purpleAccent.withOpacity(0.5), width: 1.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_outlined, color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent, size: 22),
                                          const SizedBox(width: 8),
                                          Text("筐体交換行き率:", style: TextStyle(color: dp.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Text("${swapRate.toStringAsFixed(1)}%", style: TextStyle(color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 28),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              achievePercent >= 100 
                                                  ? 'assets/mascot_excellent.jpg' 
                                                  : (achievePercent >= 80 
                                                      ? 'assets/mascot_good_pace.jpg' 
                                                      : 'assets/mascot_fight.jpg'),
                                              width: 55,
                                              height: 55,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text("総合達成率: ${achievePercent.toStringAsFixed(1)}%", style: TextStyle(color: progressColor, fontSize: 26, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
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
