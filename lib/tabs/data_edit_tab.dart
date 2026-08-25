import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/data_provider.dart';

enum EditMode { menu, today, previousDay, past }

class DataEditTab extends StatefulWidget {
  final bool isAdmin; 

  const DataEditTab({super.key, this.isAdmin = false});

  @override
  State<DataEditTab> createState() => _DataEditTabState();
}

class _DataEditTabState extends State<DataEditTab> {
  EditMode _currentMode = EditMode.menu;
  List<Map<String, dynamic>> _dayLogs = [];
  bool _isFetching = false;
  DateTime? _selectedPastDate;
  DateTime? _selectedPrevDate;

  String? _selectedWorkerFilter;

  List<String> get _uniqueWorkers {
    Set<String> workers = {};
    for (var log in _dayLogs) {
      workers.add(log['worker_name'] ?? log['worker_id'] ?? "不明");
    }
    List<String> sorted = workers.toList()..sort();
    return ["すべて", ...sorted];
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_selectedWorkerFilter == null || _selectedWorkerFilter == "すべて") {
      return _dayLogs;
    }
    return _dayLogs.where((log) {
      String name = log['worker_name'] ?? log['worker_id'] ?? "不明";
      return name == _selectedWorkerFilter;
    }).toList();
  }

  List<Map<String, dynamic>> _allModelsMaster = [];

  @override
  void initState() {
    super.initState();
    _fetchAllModels(); 
  }

  Future<void> _fetchAllModels() async {
    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db',
    );
    try {
      await conn.connect();
      var result = await conn.execute('''
        SELECT 
          model_name, 
          maker,
          maker_abbr,
          work_type,
          std_qty,
          sort_order as sort_id
        FROM m_models 
        ORDER BY sort_id ASC
      ''');
      
      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add({
          "name": row.assoc()['model_name'] ?? "",
          "maker_full": row.assoc()['maker'] ?? "", 
          "maker": row.assoc()['maker_abbr'] ?? "",
          "work_type": row.assoc()['work_type'] ?? "",
          "std_qty": double.tryParse(row.assoc()['std_qty'] ?? '10.0') ?? 10.0, 
          "sort_id": int.tryParse(row.assoc()['sort_id'] ?? '9999') ?? 9999
        });
      }
      setState(() => _allModelsMaster = temp);
    } catch (e) {
      print("マスタ取得エラー: $e");
    } finally {
      await conn.close();
    }
  }

  Future<void> _fetchLogs(DateTime targetDate) async {
    setState(() {
      _isFetching = true;
    });
    
    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db',
    );
    try {
      await conn.connect();
      String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      var result = await conn.execute('''
        SELECT 
          l.id, l.work_date, l.model_name, l.maker, l.maker_abbr, l.worker_id, l.clean_qty, l.air_clean_qty, 
          l.swap_qty, l.to_clean_qty, l.to_swap_qty, l.std_qty, l.work_minutes,
          mem.worker_name
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        WHERE DATE(l.work_date) = :d 
        ORDER BY l.id DESC
      ''', {"d": dateStr});
      
      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc());
      }
      _dayLogs = temp;
    } catch (e) {
      print("ログ取得エラー: $e");
    } finally {
      await conn.close();
      setState(() => _isFetching = false);
    }
  }

  void _showConfirmUpdateDialog(Map<String, dynamic> oldLog, Map<String, dynamic> newData, int id, String targetWorkType) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;
    String workerName = oldLog['worker_name'] ?? oldLog['worker_id'] ?? "不明";

    int oldAir = int.tryParse(oldLog['air_clean_qty'] ?? '0') ?? 0;
    int oldClean = int.tryParse(oldLog['clean_qty'] ?? '0') ?? 0;
    String oldWorkType = oldAir > 0 ? "エアー清掃" : (oldClean > 0 ? "清掃" : "筐体交換");

    String oldRawModel = oldLog['model_name'] ?? "不明";
    String oldCleanModel = oldRawModel.contains(':') ? oldRawModel.split(':').last.replaceAll('}', '').trim() : oldRawModel;
    String oldMakerAbbr = oldLog['maker_abbr'] ?? "";
    String oldModelDisplay = oldMakerAbbr.isNotEmpty ? "$oldCleanModel ($oldMakerAbbr)" : oldCleanModel;

    String newModelDisplay = newData['maker_abbr'].isNotEmpty ? "${newData['model_name']} (${newData['maker_abbr']})" : newData['model_name'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: provider.currentCardColor,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: isWhite ? Colors.orange.shade800 : Colors.orangeAccent, size: 36),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("修正内容の最終確認", style: TextStyle(color: provider.mainTextColor, fontSize: 26, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              width: MediaQuery.of(context).size.width * 0.85, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("作業者: $workerName", style: TextStyle(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), fontSize: 20, fontWeight: FontWeight.bold)), 
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()), 
                      Expanded(flex: 4, child: Center(child: Text("修正前", style: TextStyle(color: provider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)))),
                      const Expanded(flex: 1, child: SizedBox()),
                      Expanded(flex: 4, child: Center(child: Text("修正後", style: TextStyle(color: isWhite ? const Color(0xFF008040) : Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                  Divider(color: provider.borderColor, height: 25),

                  _buildCompareRow("作業区分", oldWorkType, targetWorkType, provider, isWhite, isText: true),
                  _buildCompareRow("作業日", oldLog['work_date'] ?? '不明', newData['work_date'] ?? '不明', provider, isWhite, isText: true),
                  _buildCompareRow("機種名", oldModelDisplay, newModelDisplay, provider, isWhite, isText: true),
                  _buildCompareRow("作業時間(分)", double.tryParse(oldLog['work_minutes']?.toString() ?? '0') ?? 0, newData['work_minutes'], provider, isWhite),
                  
                  if (targetWorkType == "エアー清掃") ...[
                    _buildCompareRow("エアー清掃", int.tryParse(oldLog['air_clean_qty'] ?? '0') ?? 0, newData['air_clean_qty'], provider, isWhite),
                    _buildCompareRow("清掃行き", int.tryParse(oldLog['to_clean_qty'] ?? '0') ?? 0, newData['to_clean_qty'], provider, isWhite),
                  ] else if (targetWorkType == "清掃") ...[
                    _buildCompareRow("通常清掃", int.tryParse(oldLog['clean_qty'] ?? '0') ?? 0, newData['clean_qty'], provider, isWhite),
                    _buildCompareRow("筐体交換行き", int.tryParse(oldLog['to_swap_qty'] ?? '0') ?? 0, newData['to_swap_qty'], provider, isWhite),
                  ] else if (targetWorkType == "筐体交換") ...[
                    _buildCompareRow("交換完了", int.tryParse(oldLog['swap_qty'] ?? '0') ?? 0, newData['swap_qty'], provider, isWhite),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text("入力に戻る", style: TextStyle(color: provider.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold)), 
              )
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC), 
                foregroundColor: isWhite ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15) 
              ),
              onPressed: () async {
                bool success = await provider.updateFullLogData(id, newData);
                
                if (success) {
                  if (!mounted) return;
                  
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pop(); 

                  showGeneralDialog(
                    context: context,
                    barrierDismissible: false, 
                    barrierColor: Colors.green.shade700, 
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (BuildContext popupContext, animation, secondaryAnimation) {
                      
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        if (popupContext.mounted) {
                          Navigator.of(popupContext).pop();
                        }
                      });

                      return Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.white, size: 150), 
                              const SizedBox(height: 20),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  "修正完了！", 
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 50, 
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4.0
                                  )
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ).then((_) {
                    if (_currentMode == EditMode.today) {
                      _fetchLogs(DateTime.now());
                    } else if (_currentMode == EditMode.previousDay && _selectedPrevDate != null) {
                      _fetchLogs(_selectedPrevDate!);
                    } else if (_currentMode == EditMode.past && _selectedPastDate != null) {
                      _fetchLogs(_selectedPastDate!);
                    }
                  });
                }
              },
              child: const Text("本当に保存する", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildCompareRow(String label, dynamic oldVal, dynamic newVal, DataProvider provider, bool isWhite, {bool isText = false}) {
    bool isChanged = oldVal.toString() != newVal.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3, 
            child: Text(label, style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)) 
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWhite ? Colors.grey.shade100 : Colors.white10, 
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: provider.borderColor),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(oldVal.toString(), style: TextStyle(fontSize: isText ? 16 : 24, color: provider.mainTextColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                ),
              ),
            )
          ),
          Expanded(
            flex: 1,
            child: Icon(Icons.arrow_forward_rounded, size: 24, color: isChanged ? (isWhite ? Colors.orange.shade700 : Colors.orangeAccent) : provider.borderColor), 
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isChanged ? (isWhite ? const Color(0xFFE8F5E9) : Colors.green.withOpacity(0.2)) : (isWhite ? Colors.grey.shade100 : Colors.white10),
                border: Border.all(color: isChanged ? (isWhite ? const Color(0xFF008040) : Colors.greenAccent) : provider.borderColor, width: isChanged ? 2 : 1),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(newVal.toString(), style: TextStyle(fontSize: isText ? 16 : 24, fontWeight: FontWeight.bold, color: isChanged ? (isWhite ? const Color(0xFF007A3D) : Colors.greenAccent) : provider.mainTextColor), textAlign: TextAlign.center)
                ),
              ),
            )
          )
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> log) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;
    int id = int.parse(log['id']!);
    String workerName = log['worker_name'] ?? log['worker_id'] ?? "不明";
    
    String rawModel = log['model_name'] ?? "不明";
    String cleanModel = rawModel.contains(':') ? rawModel.split(':').last.replaceAll('}', '').trim() : rawModel;
    
    String selectedModel = cleanModel;
    String makerAbbr = log['maker_abbr'] ?? "";
    String makerFull = log['maker'] ?? ""; 
    double stdQty = double.tryParse(log['std_qty']?.toString() ?? '10.0') ?? 10.0;

    TextEditingController airCtrl = TextEditingController(text: log['air_clean_qty']);
    TextEditingController toCleanCtrl = TextEditingController(text: log['to_clean_qty']);
    TextEditingController cleanCtrl = TextEditingController(text: log['clean_qty']);
    TextEditingController toSwapCtrl = TextEditingController(text: log['to_swap_qty']);
    TextEditingController swapCtrl = TextEditingController(text: log['swap_qty']); 
    double totalMinutes = double.tryParse(log['work_minutes']?.toString() ?? '0') ?? 0.0;
    int hours = (totalMinutes / 60).floor();
    int minutes = (totalMinutes % 60).round();
    TextEditingController hoursCtrl = TextEditingController(text: hours > 0 ? hours.toString() : '');
    TextEditingController minutesCtrl = TextEditingController(text: minutes.toString());

    int airQty = int.tryParse(log['air_clean_qty'] ?? '0') ?? 0;
    int cleanQty = int.tryParse(log['clean_qty'] ?? '0') ?? 0;

    String targetWorkType = "筐体交換"; 
    if (airQty > 0) {
      targetWorkType = "エアー清掃";
    } else if (cleanQty > 0) {
      targetWorkType = "清掃";
    }

    dynamic oldDateVal = log['work_date'];
    DateTime initDate = DateTime.now();
    if (oldDateVal != null) {
      if (oldDateVal is DateTime) {
        initDate = oldDateVal;
      } else {
        try {
          String oldDateStr = oldDateVal.toString();
          if (oldDateStr.isNotEmpty) {
            initDate = DateTime.parse(oldDateStr.replaceAll('/', '-'));
          }
        } catch (e) {
          initDate = DateTime.now();
        }
      }
    }
    DateTime selectedDate = initDate;

    List<Map<String, dynamic>> availableModels = [];
    Set<String> addedKeys = {}; 

    availableModels.add({
      "name": cleanModel, 
      "maker": makerAbbr, 
      "maker_full": makerFull, 
      "std_qty": stdQty
    });
    addedKeys.add("${cleanModel}_$makerAbbr");

    for (var dLog in _dayLogs) {
      String rName = dLog['model_name'] ?? "不明";
      String cName = rName.contains(':') ? rName.split(':').last.replaceAll('}', '').trim() : rName;
      String mAbbr = dLog['maker_abbr'] ?? "";
      String mFull = dLog['maker'] ?? "";
      double sQty = double.tryParse(dLog['std_qty']?.toString() ?? '10.0') ?? 10.0;
      String key = "${cName}_$mAbbr";

      int aQty = int.tryParse(dLog['air_clean_qty'] ?? '0') ?? 0;
      int cQty = int.tryParse(dLog['clean_qty'] ?? '0') ?? 0;
      int sQtyVal = int.tryParse(dLog['swap_qty'] ?? '0') ?? 0;
      
      bool matchWork = false;
      if (targetWorkType == "エアー清掃" && aQty > 0) matchWork = true;
      if (targetWorkType == "清掃" && cQty > 0) matchWork = true;
      if (targetWorkType == "筐体交換" && sQtyVal > 0) matchWork = true;

      if (matchWork && !addedKeys.contains(key)) {
        availableModels.add({
          "name": cName, 
          "maker": mAbbr,
          "maker_full": mFull,
          "std_qty": sQty
        });
        addedKeys.add(key);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            String selectedDisplay = makerAbbr.isNotEmpty ? "$selectedModel ($makerAbbr)" : selectedModel;

            return AlertDialog(
              backgroundColor: provider.currentCardColor,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("実績データの修正", style: TextStyle(color: provider.mainTextColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("作業者: $workerName ", style: TextStyle(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("作業区分: $targetWorkType", style: TextStyle(color: provider.subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: isWhite ? Colors.grey.shade300 : Colors.white24, size: 24),
                    tooltip: "データを削除",
                    onPressed: () {
                      _showDeleteConfirmDialog(log, id, targetWorkType, selectedDate);
                    },
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 550),
                  width: MediaQuery.of(context).size.width * 0.9, 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "作業日: ${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}", 
                            style: TextStyle(color: provider.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 20),
                            label: const Text("日付を変更", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                              foregroundColor: isWhite ? Colors.white : Colors.black,
                            ),
                            onPressed: () async {
                              final picked = await _showCustomDatePickerDialog(selectedDate);
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      Divider(color: provider.borderColor, height: 1),
                      const SizedBox(height: 15),

                      Text("作業区分", style: TextStyle(color: provider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWhite ? Colors.grey.shade100 : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: provider.borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: targetWorkType,
                            dropdownColor: provider.currentCardColor,
                            style: TextStyle(color: provider.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                            icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 30),
                            items: ["エアー清掃", "清掃", "筐体交換"].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(color: provider.mainTextColor)),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setDialogState(() {
                                  targetWorkType = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text("機種名", style: TextStyle(color: provider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)), 
                      const SizedBox(height: 8),
                      
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true, 
                            backgroundColor: provider.currentBgColor,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (BuildContext context) {
                              bool showAll = false; 
                              
                              return StatefulBuilder(
                                builder: (context, setSheetState) {
                                  List<Map<String, dynamic>> displayList = [];
                                  
                                  if (showAll) {
                                    displayList = _allModelsMaster.where((m) {
                                      return targetWorkType.isEmpty || m['work_type'] == targetWorkType;
                                    }).toList();
                                  } else {
                                    displayList = List.from(availableModels);
                                  }

                                  return FractionallySizedBox(
                                    heightFactor: 0.75, 
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(25, 20, 20, 15),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text("機種を選択", style: TextStyle(color: provider.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold)))),
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text("全機種を表示", style: TextStyle(color: provider.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)))),
                                                    Switch(
                                                      value: showAll,
                                                      activeColor: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC),
                                                      onChanged: (val) {
                                                        setSheetState(() => showAll = val);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                        Divider(color: provider.borderColor, height: 1),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: displayList.length,
                                            itemBuilder: (context, index) {
                                              var m = displayList[index];
                                              String dName = m['maker']!.isNotEmpty ? "${m['name']} (${m['maker']})" : m['name']!;
                                              
                                              return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8), 
                                                title: Text(dName, style: TextStyle(color: provider.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold)), 
                                                onTap: () {
                                                  setDialogState(() {
                                                    selectedModel = m['name']!;
                                                    makerAbbr = m['maker']!;
                                                    makerFull = m['maker_full']!;
                                                    stdQty = m['std_qty']!;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              );
                            },
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
                          decoration: BoxDecoration(
                            color: isWhite ? Colors.grey.shade100 : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: provider.borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(selectedDisplay, style: TextStyle(color: provider.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 30),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      if (targetWorkType == "エアー清掃") ...[
                        Divider(color: provider.borderColor, height: 40),
                        _buildEditField("エアー清掃台数", airCtrl, provider, isWhite),
                        _buildEditField("清掃行き台数", toCleanCtrl, provider, isWhite),
                      ] else if (targetWorkType == "清掃") ...[
                        Divider(color: provider.borderColor, height: 40),
                        _buildEditField("通常清掃台数", cleanCtrl, provider, isWhite),
                        _buildEditField("筐体交換行き台数", toSwapCtrl, provider, isWhite),
                      ] else if (targetWorkType == "筐体交換") ...[
                        Divider(color: provider.borderColor, height: 40),
                        _buildEditField("交換完了台数", swapCtrl, provider, isWhite), 
                      ],
                      Divider(color: provider.borderColor, height: 40),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text("作業時間", style: TextStyle(color: provider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildTimeField("時間", hoursCtrl, provider, isWhite)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildTimeField("分", minutesCtrl, provider, isWhite)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text("キャンセル", style: TextStyle(color: provider.mainTextColor, fontSize: 18, fontWeight: FontWeight.bold)), 
                  )
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC), 
                    foregroundColor: isWhite ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15) 
                  ),
                  onPressed: () {
                    Map<String, dynamic> newData = {
                      "work_date": "${selectedDate.year}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}",
                      "model_name": selectedModel,
                      "maker": makerFull,       
                      "maker_abbr": makerAbbr,  
                      "std_qty": stdQty,        
                      "air_clean_qty": targetWorkType == "エアー清掃" ? (int.tryParse(airCtrl.text) ?? 0) : 0,
                      "to_clean_qty": targetWorkType == "エアー清掃" ? (int.tryParse(toCleanCtrl.text) ?? 0) : 0,
                      "clean_qty": targetWorkType == "清掃" ? (int.tryParse(cleanCtrl.text) ?? 0) : 0,
                      "to_swap_qty": targetWorkType == "清掃" ? (int.tryParse(toSwapCtrl.text) ?? 0) : 0,
                      "swap_qty": targetWorkType == "筐体交換" ? (int.tryParse(swapCtrl.text) ?? 0) : 0, 
                      "work_minutes": ((int.tryParse(hoursCtrl.text) ?? 0) * 60 + (int.tryParse(minutesCtrl.text) ?? 0)).toDouble(),
                    };
                    
                    _showConfirmUpdateDialog(log, newData, id, targetWorkType);
                  },
                  child: const Text("確認画面へ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, DataProvider provider, bool isWhite) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: TextStyle(color: provider.mainTextColor, fontSize: 24, fontWeight: FontWeight.bold), 
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: provider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold), 
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.borderColor)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), width: 2)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> log, int id, String targetWorkType, DateTime workDate) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final bool isWhite = provider.displayMode == DisplayMode.pureWhite;
    String workerName = log['worker_name'] ?? log['worker_id'] ?? "不明";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isWhite ? Colors.red.shade50 : const Color(0xFF330000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade900, width: 4)
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700, size: 48),
              const SizedBox(width: 15),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "データ削除の確認", 
                    style: TextStyle(color: Colors.red.shade700, fontSize: 32, fontWeight: FontWeight.bold)
                  ),
                )
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("本当に以下の作業データを削除してもよろしいですか？", style: TextStyle(color: provider.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("※この操作は元に戻すことができません！", style: TextStyle(color: Colors.red.shade600, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: provider.currentCardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("作業日: ${workDate.year}/${workDate.month}/${workDate.day}", style: TextStyle(color: provider.mainTextColor, fontSize: 18)),
                      Text("作業者: $workerName", style: TextStyle(color: provider.mainTextColor, fontSize: 18)),
                      Text("作業区分: $targetWorkType", style: TextStyle(color: provider.mainTextColor, fontSize: 18)),
                      Text("機種名: ${log['model_name']}", style: TextStyle(color: provider.mainTextColor, fontSize: 18)),
                    ]
                  )
                )
              ]
            )
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text("キャンセル", style: TextStyle(color: provider.subTextColor, fontSize: 20, fontWeight: FontWeight.bold)), 
              )
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15) 
              ),
              onPressed: () async {
                bool success = await provider.deleteLogData(id);
                if (mounted) {
                  Navigator.pop(context); // 削除確認ダイアログを閉じる
                  Navigator.pop(context); // 編集ダイアログも閉じる
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("データを削除しました"), backgroundColor: Colors.red),
                    );
                    if (_currentMode == EditMode.today) {
                      _fetchLogs(DateTime.now());
                    } else if (_currentMode == EditMode.previousDay && _selectedPrevDate != null) {
                      _fetchLogs(_selectedPrevDate!);
                    } else if (_currentMode == EditMode.past && _selectedPastDate != null) {
                      _fetchLogs(_selectedPastDate!);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("削除に失敗しました"), backgroundColor: Colors.orange),
                    );
                  }
                }
              },
              child: const Text("完全に削除する", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildTimeField(String label, TextEditingController ctrl, DataProvider provider, bool isWhite) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(color: provider.mainTextColor, fontSize: 24, fontWeight: FontWeight.bold), 
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: provider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold), 
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: provider.borderColor)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        suffixText: label,
        suffixStyle: TextStyle(color: provider.subTextColor, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = "データ修正メニュー";
    if (_currentMode == EditMode.today) title = "当日データ修正";
    if (_currentMode == EditMode.previousDay) title = _selectedPrevDate != null ? "前日データ修正 (${DateFormat('MM/dd').format(_selectedPrevDate!)})" : "前日データ修正";
    if (_currentMode == EditMode.past) title = "過去データ修正";
    final dp = context.watch<DataProvider>();

    return Scaffold(
      backgroundColor: dp.currentBgColor,
      appBar: AppBar(
        backgroundColor: dp.currentCardColor,
        elevation: dp.displayMode == DisplayMode.pureWhite ? 2 : 0,
        iconTheme: IconThemeData(color: dp.mainTextColor),
        title: Text(
          title, 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: dp.mainTextColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 28, color: dp.mainTextColor),
          onPressed: () {
            if (_currentMode == EditMode.menu) {
              Navigator.pop(context);
            } else {
              setState(() => _currentMode = EditMode.menu);
            }
          },
        ),
        actions: const [
          // 💡 ここに追加：画面右上のオンライン・オフラインインジケーター
          Center(child: _ConnectionStatusIndicator()), 
          SizedBox(width: 20),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentMode) {
      case EditMode.menu: return _buildMenuView();
      case EditMode.today:
      case EditMode.previousDay: return _buildLogsView(isPastMode: false);
      case EditMode.past: return _buildPastView(); 
    }
  }

  Widget _buildPastView() {
    final dp = Provider.of<DataProvider>(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          color: dp.currentCardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("対象日: ", style: TextStyle(color: dp.subTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CCFF).withOpacity(0.2),
                  foregroundColor: dp.displayMode == DisplayMode.pureWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  side: BorderSide(color: dp.displayMode == DisplayMode.pureWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), width: 1.5),
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 28),
                label: Text(
                  _selectedPastDate == null ? "日付を選択" : DateFormat('yyyy年MM月dd日').format(_selectedPastDate!),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await _pickCustomDate();
                },
              ),
            ],
          ),
        ),
        if (_selectedPastDate == null)
          Expanded(child: Center(child: Text("上部のボタンから修正したい日付を選択してください", style: TextStyle(color: dp.subTextColor, fontSize: 20, fontWeight: FontWeight.bold))))
        else
          Expanded(child: _buildLogsView(isPastMode: true)),
      ],
    );
  }

  Future<DateTime?> _showCustomDatePickerDialog(DateTime initialDate) async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final bool isWhite = dp.displayMode == DisplayMode.pureWhite;
    DateTime _focusedDay = initialDate;
    DateTime? _selectedDay = initialDate;

    List<int> years = List.generate(11, (index) => 2020 + index);
    List<int> months = List.generate(12, (index) => index + 1);

    final result = await showDialog<DateTime?>(
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
                  color: dp.currentCardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC), width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "修正する日付を選択",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: dp.mainTextColor),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.grey.shade100 : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: dp.borderColor),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.year,
                              dropdownColor: dp.currentCardColor,
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
                              items: years.map((y) => DropdownMenuItem<int>(
                                value: y,
                                child: Text("$y年", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dp.mainTextColor)),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    _focusedDay = DateTime(val, _focusedDay.month, _focusedDay.day);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.grey.shade100 : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: dp.borderColor),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.month,
                              dropdownColor: dp.currentCardColor,
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
                              items: months.map((m) => DropdownMenuItem<int>(
                                value: m,
                                child: Text("$m月", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dp.mainTextColor)),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    int maxDay = DateTime(_focusedDay.year, val + 1, 0).day;
                                    int d = _focusedDay.day > maxDay ? maxDay : _focusedDay.day;
                                    _focusedDay = DateTime(_focusedDay.year, val, d);
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
                            lastDay: DateTime.now(),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) {
                              return isSameDay(_selectedDay, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setDialogState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            calendarStyle: CalendarStyle(
                              selectedDecoration: BoxDecoration(color: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC), shape: BoxShape.circle),
                              todayDecoration: BoxDecoration(color: isWhite ? Colors.black12 : Colors.white10, shape: BoxShape.circle),
                              defaultTextStyle: TextStyle(color: dp.mainTextColor, fontSize: 22),
                              outsideTextStyle: TextStyle(color: isWhite ? Colors.black26 : Colors.white24, fontSize: 22),
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
                              leftChevronIcon: Icon(Icons.chevron_left, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 40),
                              rightChevronIcon: Icon(Icons.chevron_right, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 40),
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
                            child: Text("キャンセル", style: TextStyle(color: dp.subTextColor, fontSize: 20)),
                          ),
                          const SizedBox(width: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isWhite ? const Color(0xFF00AA66) : const Color(0xFF00FFCC),
                              foregroundColor: isWhite ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              if (_selectedDay != null) {
                                Navigator.pop(context, _selectedDay);
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

    return result;
  }

  Future<void> _pickCustomDate() async {
    DateTime initial = _selectedPastDate ?? DateTime.now().subtract(const Duration(days: 1));
    final result = await _showCustomDatePickerDialog(initial);
    if (result != null) {
      setState(() {
        _selectedPastDate = result;
      });
      _fetchLogs(result);
    }
  }

  // ⭐ 土日や休業日を完全スキップ！「実際に作業データが存在する一番最近の過去日」を自動判別して開く秘技！
  Future<void> _openPreviousWorkDay() async {
    DateTime now = DateTime.now();
    String todayStr = DateFormat('yyyy-MM-dd').format(now);
    DateTime prevDate = now.subtract(const Duration(days: 1)); // デフォルトの安心保険(前日)

    MySQLConnection? conn;
    try {
      conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );
      await conn.connect();
      
      // 当日(今日)よりも前の作業ログの中で最も新しく実績が存在している日付をハイフン統一フォーマットで 1撃スナイプ！
      var res = await conn.execute(
        '''SELECT DATE_FORMAT(DATE(REPLACE(work_date, '/', '-')), '%Y-%m-%d') as clean_date 
           FROM unit_cleaning_logs 
           WHERE DATE(REPLACE(work_date, '/', '-')) < DATE(:today) 
             AND work_date IS NOT NULL AND work_date != "" 
           ORDER BY DATE(REPLACE(work_date, '/', '-')) DESC 
           LIMIT 1''',
        {"today": todayStr}
      );
      if (res.rows.isNotEmpty) {
        String cleanDateStr = res.rows.first.assoc()['clean_date'] ?? '';
        if (cleanDateStr.isNotEmpty) {
          cleanDateStr = cleanDateStr.replaceAll('/', '-').split(' ')[0].trim();
          try {
            prevDate = DateTime.parse(cleanDateStr);
            print("🌟 実務の存在確認完了！直近稼働日を発見: $cleanDateStr を前日対象に適用！");
          } catch (e) {
            print("日付変換例外の回避: $e");
          }
        }
      }
    } catch (e) {
      print("前日実績日照会時の警告: $e (デフォルトの1日前を適用)");
    } finally {
      try { if (conn != null) await conn.close(); } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _currentMode = EditMode.previousDay;
        _selectedPrevDate = prevDate;
      });
      _fetchLogs(prevDate);
    }
  }

  Widget _buildMenuView() {
    final dp = Provider.of<DataProvider>(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_rounded, size: 90, color: dp.displayMode == DisplayMode.pureWhite ? Colors.teal.shade600 : const Color(0xFF00CCFF)), 
            const SizedBox(height: 20),
            Text("修正モードを選択してください", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: dp.mainTextColor)), 
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _menuButton("当日データ修正", Icons.today, Colors.teal, () {
                  setState(() => _currentMode = EditMode.today);
                  _fetchLogs(DateTime.now());
                })),
                SizedBox(width: MediaQuery.of(context).size.width * 0.04), 
                // ⭐ フロアマネージャをはじめ誰もがワンタッチで「直近の過去実績日(前日)」を修正できる黄金ボタン！！
                Flexible(child: _menuButton("前日データ修正", Icons.event_repeat, Colors.orange.shade700, () {
                  _openPreviousWorkDay();
                })),
                if (widget.isAdmin) ...[
                  SizedBox(width: MediaQuery.of(context).size.width * 0.04), 
                  Flexible(child: _menuButton("過去データ修正", Icons.history, Colors.blueGrey, () {
                    setState(() {
                      _currentMode = EditMode.past;
                      _selectedPastDate = null;
                      _dayLogs = [];
                    });
                  })),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(String title, IconData icon, Color color, VoidCallback onTap) {
    final dp = Provider.of<DataProvider>(context);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        width: double.infinity, 
        height: 200, 
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(isWhite ? 0.8 : 0.5), width: isWhite ? 2.5 : 2),
          boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color), 
            const SizedBox(height: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dp.mainTextColor))
            ), 
          ],
        ),
      ),
    );
  }

  Widget _buildLogsView({required bool isPastMode}) {
    final dp = Provider.of<DataProvider>(context);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    if (_isFetching) return const Center(child: CircularProgressIndicator(color: Color(0xFF00CCFF)));
    if (_dayLogs.isEmpty) {
      String msg = "本日の実績データはまだありません";
      if (_currentMode == EditMode.previousDay) {
        msg = "前日の実績データは見つかりませんでした\n(照会日: ${DateFormat('yyyy/MM/dd').format(_selectedPrevDate ?? DateTime.now().subtract(const Duration(days: 1)))})";
      } else if (isPastMode) {
        msg = "この日の実績データはありません";
      }
      return Center(
        child: Text(
          msg, 
          textAlign: TextAlign.center,
          style: TextStyle(color: dp.subTextColor, fontSize: 20, fontWeight: FontWeight.bold, height: 1.5),
        ),
      );
    }

    Color headerColor = isWhite ? const Color(0xFF006666) : Colors.cyanAccent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
          color: dp.currentCardColor,
          child: Row(
            children: [
              Expanded(
                flex: 2, 
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("作業者", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.filter_list_rounded, color: headerColor, size: 20),
                      color: dp.currentCardColor,
                      tooltip: "作業者で絞り込み",
                      onSelected: (val) {
                        setState(() {
                          _selectedWorkerFilter = val == "すべて" ? null : val;
                        });
                      },
                      itemBuilder: (context) {
                        return _uniqueWorkers.map((w) {
                          bool isSelected = (w == "すべて" && _selectedWorkerFilter == null) || w == _selectedWorkerFilter;
                          return PopupMenuItem<String>(
                            value: w,
                            child: Text(w, style: TextStyle(color: isSelected ? headerColor : dp.mainTextColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          );
                        }).toList();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(flex: 3, child: Text("機種名", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("作業区分", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("内容１", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("内容２", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Align(alignment: Alignment.center, child: Text("作業時間", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold)))),
              Expanded(flex: 1, child: Align(alignment: Alignment.center, child: Text("編集", style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            itemCount: _filteredLogs.length,
            itemBuilder: (context, index) {
              var log = _filteredLogs[index];
              
              String workerName = log['worker_name'] ?? log['worker_id'] ?? "不明";
              String rawModelName = log['model_name'] ?? "不明";
              String cleanModelName = rawModelName.contains(':') ? rawModelName.split(':').last.replaceAll('}', '').trim() : rawModelName;
              
              String makerAbbr = log['maker_abbr'] ?? ""; 
              String displayModelName = makerAbbr.isNotEmpty ? "$cleanModelName ($makerAbbr)" : cleanModelName;
              
              int airQty = int.tryParse(log['air_clean_qty'] ?? '0') ?? 0;
              int cleanQty = int.tryParse(log['clean_qty'] ?? '0') ?? 0;
              int toCleanQty = int.tryParse(log['to_clean_qty'] ?? '0') ?? 0;
              int toSwapQty = int.tryParse(log['to_swap_qty'] ?? '0') ?? 0;
              double workMinutes = double.tryParse(log['work_minutes']?.toString() ?? '0') ?? 0.0;
              int totalMin = workMinutes.round();
              int h = totalMin ~/ 60;
              int m = totalMin % 60;
              String timeDisplay = h > 0 ? "${h}時間${m}分" : "${m}分";

              String mainLabel = "";
              int mainQty = 0;
              String subLabel = "";
              int subQty = 0;
              Color accentColor = isWhite ? const Color(0xFF006688) : const Color(0xFF00CCFF);

              if (airQty > 0) {
                mainLabel = "エアー清掃"; mainQty = airQty;
                subLabel = "清掃行き"; subQty = toCleanQty;
                accentColor = isWhite ? const Color(0xFF006688) : const Color(0xFF00CCFF);
              } else if (cleanQty > 0) {
                mainLabel = "通常清掃"; mainQty = cleanQty;
                subLabel = "交換行き"; subQty = toSwapQty;
                accentColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
              } else {
                mainLabel = "筐体交換"; mainQty = int.tryParse(log['swap_qty'] ?? '0') ?? 0;
                subLabel = "その他"; subQty = 0;
                accentColor = isWhite ? Colors.orange.shade800 : Colors.amber;
              }

              bool isEven = index % 2 == 0;
              Color rowBg = isWhite 
                  ? (isEven ? Colors.white : const Color(0xFFF2F6F9))
                  : (isEven ? const Color(0xFF0F1115) : const Color(0xFF14161C));

              return Container(
                decoration: BoxDecoration(
                  color: rowBg,
                  border: Border(bottom: BorderSide(color: dp.borderColor)),
                ),
                child: InkWell(
                  onTap: () => _showEditDialog(log),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0), 
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2, 
                          child: Text(workerName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dp.mainTextColor), overflow: TextOverflow.ellipsis), 
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(displayModelName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dp.mainTextColor), overflow: TextOverflow.ellipsis), 
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(mainLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _compactInfoChip("台数", mainQty, accentColor),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: subLabel != "その他" 
                                ? _compactInfoChip(
                                    subLabel, 
                                    subQty, 
                                    (subLabel == "清掃行き") ? (isWhite ? Colors.teal.shade700 : Colors.cyanAccent) : (isWhite ? Colors.deepOrange : Colors.orangeAccent),
                                  ) 
                                : const SizedBox(),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(timeDisplay, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dp.mainTextColor))
                          ), 
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.center,
                            child: Icon(Icons.edit, color: dp.subTextColor, size: 28)
                          ), 
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _compactInfoChip(String label, dynamic countOrText, Color color, {bool isText = false}) {
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
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: dp.mainTextColor, fontSize: 14, fontWeight: FontWeight.bold)))), 
          const SizedBox(width: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(countOrText.toString(), style: TextStyle(color: color, fontSize: isText ? 16 : 20, fontWeight: FontWeight.bold))), 
        ]
      ),
    );
  }
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
    final bool isWhite = data.displayMode == DisplayMode.pureWhite;

    final Color activeColor = isOnline 
        ? (isWhite ? const Color(0xFF008844) : Colors.greenAccent)
        : (isWhite ? const Color(0xFFCC0033) : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isWhite ? activeColor.withOpacity(0.12) : activeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withOpacity(isWhite ? 0.8 : 0.6), width: isWhite ? 2.0 : 1.5),
        boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : null,
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