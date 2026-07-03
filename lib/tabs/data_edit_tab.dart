import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mysql_client/mysql_client.dart';
import '../providers/data_provider.dart';

enum EditMode { menu, today, past }

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
          CAST(NULLIF(csv_id, '') AS UNSIGNED) as sort_id
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

  Future<void> _fetchTodayLogs() async {
    setState(() {
      _isFetching = true;
      _currentMode = EditMode.today;
    });
    
    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db',
    );
    try {
      await conn.connect();
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var result = await conn.execute('''
        SELECT 
          l.id, l.model_name, l.maker, l.maker_abbr, l.worker_id, l.clean_qty, l.air_clean_qty, 
          l.swap_qty, l.to_clean_qty, l.to_swap_qty, l.std_qty, l.work_minutes,
          mem.worker_name
        FROM unit_cleaning_logs l
        LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
        WHERE DATE(l.work_date) = :d 
        ORDER BY l.id DESC
      ''', {"d": today});
      
      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc());
      }
      _dayLogs = temp;
    } catch (e) {
      print("当日ログ取得エラー: $e");
    } finally {
      await conn.close();
      setState(() => _isFetching = false);
    }
  }

  void _showConfirmUpdateDialog(Map<String, dynamic> oldLog, Map<String, dynamic> newData, int id, String targetWorkType) {
    final provider = Provider.of<DataProvider>(context, listen: false);
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
          backgroundColor: const Color(0xFF1A1C23),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 36),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Text("修正内容の最終確認", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
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
                  Text("作業者: $workerName", style: const TextStyle(color: Color(0xFF00CCFF), fontSize: 20, fontWeight: FontWeight.bold)), 
                  const SizedBox(height: 20),
                  
                  Row(
                    children: const [
                      Expanded(flex: 3, child: SizedBox()), 
                      Expanded(flex: 4, child: Center(child: Text("修正前", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)))),
                      Expanded(flex: 1, child: SizedBox()),
                      Expanded(flex: 4, child: Center(child: Text("修正後", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 25),

                  _buildCompareRow("作業区分", oldWorkType, targetWorkType, isText: true),
                  _buildCompareRow("機種名", oldModelDisplay, newModelDisplay, isText: true),
                  _buildCompareRow("作業時間(分)", double.tryParse(oldLog['work_minutes']?.toString() ?? '0') ?? 0, newData['work_minutes']),
                  
                  if (targetWorkType == "エアー清掃") ...[
                    _buildCompareRow("エアー清掃", int.tryParse(oldLog['air_clean_qty'] ?? '0') ?? 0, newData['air_clean_qty']),
                    _buildCompareRow("清掃行き", int.tryParse(oldLog['to_clean_qty'] ?? '0') ?? 0, newData['to_clean_qty']),
                  ] else if (targetWorkType == "清掃") ...[
                    _buildCompareRow("通常清掃", int.tryParse(oldLog['clean_qty'] ?? '0') ?? 0, newData['clean_qty']),
                    _buildCompareRow("筐体交換行き", int.tryParse(oldLog['to_swap_qty'] ?? '0') ?? 0, newData['to_swap_qty']),
                  ] else if (targetWorkType == "筐体交換") ...[
                    _buildCompareRow("交換完了", int.tryParse(oldLog['swap_qty'] ?? '0') ?? 0, newData['swap_qty']),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text("入力に戻る", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
              )
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC), 
                foregroundColor: Colors.black,
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
                    _fetchTodayLogs();
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

  Widget _buildCompareRow(String label, dynamic oldVal, dynamic newVal, {bool isText = false}) {
    bool isChanged = oldVal.toString() != newVal.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3, 
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)) 
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10, 
                borderRadius: BorderRadius.circular(8)
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(oldVal.toString(), style: TextStyle(fontSize: isText ? 16 : 24, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                ),
              ),
            )
          ),
          Expanded(
            flex: 1,
            child: Icon(Icons.arrow_forward_rounded, size: 24, color: isChanged ? Colors.orangeAccent : Colors.white54), 
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isChanged ? Colors.green.withOpacity(0.2) : Colors.white10,
                border: Border.all(color: isChanged ? Colors.greenAccent : Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(newVal.toString(), style: TextStyle(fontSize: isText ? 16 : 24, fontWeight: FontWeight.bold, color: isChanged ? Colors.greenAccent : Colors.white), textAlign: TextAlign.center)
                ),
              ),
            )
          )
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> log) {
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
              backgroundColor: const Color(0xFF1A1C23),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("実績データの修正", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("作業者: $workerName ", style: const TextStyle(color: Color(0xFF00CCFF), fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("作業区分: $targetWorkType", style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
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
                      const Text("作業区分", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: targetWorkType,
                            dropdownColor: const Color(0xFF1A1C23),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00CCFF), size: 30),
                            items: ["エアー清掃", "清掃", "筐体交換"].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
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
                      const Text("機種名", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)), 
                      const SizedBox(height: 8),
                      
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true, 
                            backgroundColor: const Color(0xFF1A1C23),
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
                                              const Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text("機種を選択", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text("全機種を表示", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                                                    Switch(
                                                      value: showAll,
                                                      activeColor: const Color(0xFF00FFCC),
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
                                        const Divider(color: Colors.white10, height: 1),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: displayList.length,
                                            itemBuilder: (context, index) {
                                              var m = displayList[index];
                                              String dName = m['maker']!.isNotEmpty ? "${m['name']} (${m['maker']})" : m['name']!;
                                              
                                              return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8), 
                                                title: Text(dName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), 
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
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(selectedDisplay, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF00CCFF), size: 30),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      if (targetWorkType == "エアー清掃") ...[
                        const Divider(color: Colors.white10, height: 40),
                        _buildEditField("エアー清掃台数", airCtrl),
                        _buildEditField("清掃行き台数", toCleanCtrl),
                      ] else if (targetWorkType == "清掃") ...[
                        const Divider(color: Colors.white10, height: 40),
                        _buildEditField("通常清掃台数", cleanCtrl),
                        _buildEditField("筐体交換行き台数", toSwapCtrl),
                      ] else if (targetWorkType == "筐体交換") ...[
                        const Divider(color: Colors.white10, height: 40),
                        _buildEditField("交換完了台数", swapCtrl), 
                      ],
                      const Divider(color: Colors.white10, height: 40),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text("作業時間", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildTimeField("時間", hoursCtrl)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildTimeField("分", minutesCtrl)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text("キャンセル", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
                  )
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC), 
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15) 
                  ),
                  onPressed: () {
                    Map<String, dynamic> newData = {
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

  Widget _buildEditField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), 
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold), 
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00CCFF), width: 2)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), 
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold), 
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00CCFF), width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        suffixText: label,
        suffixStyle: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = "データ修正メニュー";
    if (_currentMode == EditMode.today) title = "当日データ修正";
    if (_currentMode == EditMode.past) title = "過去データ修正";

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1C23),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
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
      case EditMode.today: return _buildTodayView();
      case EditMode.past: return const Center(child: Text("過去データ修正は準備中です", style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold))); 
    }
  }

  Widget _buildMenuView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit_note_rounded, size: 100, color: Color(0xFF00CCFF)), 
          const SizedBox(height: 25),
          const Text("修正モードを選択してください", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)), 
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: _menuButton("当日データ修正", Icons.today, Colors.teal, _fetchTodayLogs)),
              if (widget.isAdmin) ...[
                SizedBox(width: MediaQuery.of(context).size.width * 0.05), 
                Flexible(child: _menuButton("過去データ修正", Icons.history, Colors.blueGrey, () => setState(() => _currentMode = EditMode.past))),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _menuButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        width: double.infinity, 
        height: 200, 
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color), 
            const SizedBox(height: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))
            ), 
          ],
        ),
      ),
    );
  }

  Widget _buildTodayView() {
    if (_isFetching) return const Center(child: CircularProgressIndicator(color: Color(0xFF00CCFF)));
    if (_dayLogs.isEmpty) return const Center(child: Text("本日の実績データはまだありません", style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
          color: const Color(0xFF1A1C23),
          child: Row(
            children: [
              Expanded(
                flex: 2, 
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("作業者", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list_rounded, color: Colors.cyanAccent, size: 20),
                      color: const Color(0xFF1A1C23),
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
                            child: Text(w, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          );
                        }).toList();
                      },
                    ),
                  ],
                ),
              ),
              const Expanded(flex: 3, child: Text("機種名", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
              const Expanded(flex: 2, child: Text("作業区分", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
              const Expanded(flex: 2, child: Text("内容１", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
              const Expanded(flex: 2, child: Text("内容２", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))),
              const Expanded(flex: 1, child: Align(alignment: Alignment.center, child: Text("作業時間", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)))),
              const Expanded(flex: 1, child: Align(alignment: Alignment.center, child: Text("編集", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)))),
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
              Color accentColor = const Color(0xFF00CCFF);

              if (airQty > 0) {
                mainLabel = "エアー清掃"; mainQty = airQty;
                subLabel = "清掃行き"; subQty = toCleanQty;
                accentColor = const Color(0xFF00CCFF);
              } else if (cleanQty > 0) {
                mainLabel = "通常清掃"; mainQty = cleanQty;
                subLabel = "交換行き"; subQty = toSwapQty;
                accentColor = const Color(0xFF00FFCC);
              } else {
                mainLabel = "筐体交換"; mainQty = int.tryParse(log['swap_qty'] ?? '0') ?? 0;
                subLabel = "その他"; subQty = 0;
                accentColor = Colors.amber;
              }

              bool isEven = index % 2 == 0;

              return Container(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFF0F1115) : const Color(0xFF14161C),
                  border: const Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: InkWell(
                  onTap: () => _showEditDialog(log),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0), 
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2, 
                          child: Text(workerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis), 
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(displayModelName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis), 
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
                                    (subLabel == "清掃行き") ? Colors.cyanAccent : Colors.orangeAccent,
                                  ) 
                                : const SizedBox(),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(timeDisplay, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))
                          ), 
                        ),
                        const Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.center,
                            child: Icon(Icons.edit, color: Colors.white70, size: 28)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)))), 
          const SizedBox(width: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(countOrText.toString(), style: TextStyle(color: color, fontSize: isText ? 16 : 20, fontWeight: FontWeight.bold))), 
        ],
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOnline ? Colors.greenAccent : Colors.redAccent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? "Online" : "Offline",
            style: TextStyle(
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}