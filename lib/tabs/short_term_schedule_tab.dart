import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class ShortTermScheduleTab extends StatefulWidget {
  const ShortTermScheduleTab({Key? key}) : super(key: key);

  @override
  State<ShortTermScheduleTab> createState() => _ShortTermScheduleTabState();
}

class _PriorityItem {
  final String model;
  final String maker;
  final int remain;
  final DateTime date;
  final String category;
  final int sortId;

  _PriorityItem({
    required this.model,
    required this.maker,
    required this.remain,
    required this.date,
    required this.category,
    required this.sortId,
  });
}

class _ShortTermScheduleTabState extends State<ShortTermScheduleTab> {
  DateTime _selectedDate = DateTime.now();
  final weekDays = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final dp = Provider.of<DataProvider>(context);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;
    final bgColor = isWhite ? Colors.white : const Color(0xFF1E1E2C);
    final textColor = isWhite ? Colors.black87 : Colors.white;
    final cardColor = isWhite ? Colors.grey.shade100 : const Color(0xFF2A2D3E);
    final headerColor = isWhite ? Colors.grey.shade300 : const Color(0xFF3B3F54);

    bool hasPlanOnDate(DateTime d) {
      return dp.scheduleList.any((s) => 
        s.targetDate.year == d.year &&
        s.targetDate.month == d.month &&
        s.targetDate.day == d.day &&
        (s.planCount > 0 || s.actualCount > 0)
      );
    }

    List<DateTime> dates = [];
    DateTime curr = _selectedDate;
    
    // 予定がある日を最大60日先まで探して3日分ピックアップする
    for (int i = 0; i < 60; i++) {
      if (hasPlanOnDate(curr)) {
        dates.add(curr);
      }
      if (dates.length == 3) {
        break;
      }
      curr = curr.add(const Duration(days: 1));
    }
    
    // 万が一3日分見つからなかった場合は、選択日からの連日で埋める（UI崩れ防止）
    curr = _selectedDate;
    while (dates.length < 3) {
      if (!dates.contains(curr)) {
        dates.add(curr);
      }
      curr = curr.add(const Duration(days: 1));
    }
    dates.sort();
    
    final dateStrings = dates.map((d) => "${d.month}/${d.day}(${weekDays[d.weekday - 1]})").toList();

    // データの抽出と集計
    Map<String, Map<String, List<int>>> scheduleData = {};
    Map<String, String> makerMap = {};
    Map<String, String> modelNameMap = {};
    Map<String, int> sortIdMap = {};

    for (var s in dp.scheduleList) {
      String uniqueKey = "${s.makerName}_${s.modelName}";
      makerMap[uniqueKey] = s.makerName;
      modelNameMap[uniqueKey] = s.modelName;
      sortIdMap[uniqueKey] = s.sortId;

      String dayStr = "${s.targetDate.month}/${s.targetDate.day}(${weekDays[s.targetDate.weekday - 1]})";
      
      if (!scheduleData.containsKey(uniqueKey)) scheduleData[uniqueKey] = {};
      if (!scheduleData[uniqueKey]!.containsKey(dayStr)) scheduleData[uniqueKey]![dayStr] = [0, 0];
      
      scheduleData[uniqueKey]![dayStr]![0] += s.actualCount;
      scheduleData[uniqueKey]![dayStr]![1] += s.planCount;
    }

    // マスターデータからも情報を補完
    for (var m in dp.masterModelsList) {
      String maker = m['maker_name']?.toString() ?? '';
      String model = m['model_name']?.toString() ?? '';
      String uniqueKey = "${maker}_${model}";
      int sortId = int.tryParse(m['csv_id']?.toString() ?? '999999') ?? 999999;
      
      if (!modelNameMap.containsKey(uniqueKey)) {
        modelNameMap[uniqueKey] = model;
        makerMap[uniqueKey] = maker;
        sortIdMap[uniqueKey] = sortId;
      }
    }

    // 対象の3日間に plan > 0 または actual > 0 のデータが存在する機種のみを抽出
    List<String> activeKeys = [];
    for (var key in modelNameMap.keys) {
      bool hasData = false;
      var modelSchedule = scheduleData[key];
      if (modelSchedule != null) {
        for (var dateStr in dateStrings) {
          var item = modelSchedule[dateStr];
          if (item != null && (item[0] > 0 || item[1] > 0)) {
            hasData = true;
            break;
          }
        }
      }
      if (hasData) {
        activeKeys.add(key);
      }
    }

    // ソート (sort_id -> 機種名)
    activeKeys.sort((a, b) {
      int sortA = sortIdMap[a] ?? 999999;
      int sortB = sortIdMap[b] ?? 999999;
      int cmp = sortA.compareTo(sortB);
      if (cmp != 0) return cmp;
      String modelA = modelNameMap[a] ?? '';
      String modelB = modelNameMap[b] ?? '';
      return modelA.compareTo(modelB);
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("直近スケジュール", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: headerColor,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: textColor),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: isWhite
                          ? const ColorScheme.light(primary: Colors.blue)
                          : const ColorScheme.dark(primary: Colors.blue),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // メインのスケジュール表
          Expanded(
            child: Column(
              children: [
                // ヘッダー行
                Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: isWhite ? Colors.grey.shade300 : Colors.black54)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text("機種名", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 20, color: textColor),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                for (var ds in dateStrings)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        ds, 
                        style: TextStyle(
                          color: ds.contains('土') ? (isWhite ? Colors.blue : Colors.lightBlueAccent) : 
                                 ds.contains('日') ? (isWhite ? Colors.red : Colors.redAccent) : textColor, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 20
                        )
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 20, color: textColor),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),
          ),
          // リスト
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: activeKeys.length,
              itemBuilder: (context, index) {
                final key = activeKeys[index];
                final modelName = modelNameMap[key] ?? '';
                final makerName = makerMap[key] ?? '';
                final modelSchedule = scheduleData[key] ?? {};

                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        // 機種名
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                makerName.isNotEmpty ? "$modelName ($makerName)" : modelName,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                        // 3日分のデータ
                        for (int i = 0; i < 3; i++)
                          Expanded(
                            flex: 2,
                            child: _buildDayCell(
                              modelName,
                              makerName,
                              dates[i],
                              dateStrings[i],
                              modelSchedule[dateStrings[i]],
                              isWhite,
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
            ),
          ),
          // 優先機種サイドバー (右側)
          _buildPrioritySidebar(isWhite, textColor, headerColor, cardColor, dp, dates),
        ],
      ),
    );
  }

  Widget _buildDayCell(String model, String maker, DateTime date, String dateStr, List<int>? data, bool isWhite) {
    int actual = data != null ? data[0] : 0;
    int plan = data != null ? data[1] : 0;

    if (plan == 0 && actual == 0) {
      return InkWell(
        onTap: () => _showEditDialog(model, maker, date, dateStr, actual, plan),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isWhite ? Colors.white : const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text("-", style: TextStyle(color: Colors.grey, fontSize: 18)),
        ),
      );
    }

    double progress = plan > 0 ? (actual / plan).clamp(0.0, 1.0) : 0.0;
    bool isComplete = actual >= plan && plan > 0;
    bool isOver = actual > plan;

    Color barColor = isComplete ? Colors.green : (isWhite ? Colors.blue : Colors.lightBlueAccent);
    if (isOver) barColor = Colors.orange;

    return InkWell(
      onTap: () => _showEditDialog(model, maker, date, dateStr, actual, plan),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isComplete ? Colors.green.withOpacity(0.5) : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text("$actual", style: TextStyle(color: isWhite ? Colors.black : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(" / $plan", style: TextStyle(color: isWhite ? Colors.black54 : Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isWhite ? Colors.grey.shade200 : Colors.grey.shade800,
                color: barColor,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String model, String maker, DateTime targetDate, String dateStr, int currentActual, int currentPlan) {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final bool isWhite = dp.displayMode == DisplayMode.pureWhite;
    final Color dialogBgColor = isWhite ? Colors.white : const Color(0xFF252832);
    final Color textColor = isWhite ? Colors.black87 : Colors.white;

    final TextEditingController actualController = TextEditingController(text: currentActual.toString());
    final TextEditingController planController = TextEditingController(text: currentPlan.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          title: Text("$model\n$dateStr の予定・実績編集", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("予定と実績の台数を入力して保存してください", style: TextStyle(color: isWhite ? Colors.black54 : Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: planController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "予定台数",
                  labelStyle: TextStyle(color: isWhite ? Colors.black54 : Colors.grey),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: actualController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "完了（実績）台数",
                  labelStyle: TextStyle(color: isWhite ? Colors.black54 : Colors.grey),
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () async {
                int finalActual = int.tryParse(actualController.text) ?? 0;
                int finalPlan = int.tryParse(planController.text) ?? 0;

                await dp.updateSchedule(model, maker, targetDate, finalPlan, finalActual);
                if (mounted) setState(() {});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrioritySidebar(bool isWhite, Color textColor, Color headerColor, Color cardColor, DataProvider dp, List<DateTime> activeDates) {
    Map<String, String> categoryMap = {};
    for (var m in dp.masterModelsList) {
      String maker = m['maker_name']?.toString() ?? '';
      String model = m['model_name']?.toString() ?? '';
      String uniqueKey = "${maker}_${model}";
      categoryMap[uniqueKey] = m['category']?.toString() ?? '';
    }

    Map<String, _PriorityItem> priorityMap = {};
    for (var s in dp.scheduleList) {
      if (s.planCount > s.actualCount) {
        // 左側に表示されている「予定のある3日間」のデータのみを対象とする
        bool isActiveDate = activeDates.any((d) => 
            d.year == s.targetDate.year && 
            d.month == s.targetDate.month && 
            d.day == s.targetDate.day);
        
        if (!isActiveDate) continue;

        String uniqueKey = "${s.makerName}_${s.modelName}";
        String cat = categoryMap[uniqueKey] ?? '';
        int remain = s.planCount - s.actualCount;
        
        if (priorityMap.containsKey(uniqueKey)) {
           var existing = priorityMap[uniqueKey]!;
           int newRemain = existing.remain + remain;
           DateTime earliestDate = s.targetDate.isBefore(existing.date) ? s.targetDate : existing.date;
           
           priorityMap[uniqueKey] = _PriorityItem(
             model: existing.model,
             maker: existing.maker,
             remain: newRemain,
             date: earliestDate,
             category: existing.category,
             sortId: existing.sortId,
           );
        } else {
           priorityMap[uniqueKey] = _PriorityItem(
             model: s.modelName,
             maker: s.makerName,
             remain: remain,
             date: s.targetDate,
             category: cat,
             sortId: s.sortId,
           );
        }
      }
    }
    
    int getCategoryScore(String c) {
      if (c == "一体型") return 1;
      if (c == "情報機器") return 2;
      return 3;
    }

    List<_PriorityItem> finalPriorities = priorityMap.values.toList();
    finalPriorities.sort((a, b) {
      // 1. 日付で一番近い日
      int cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      
      // 2. Category
      int catA = getCategoryScore(a.category);
      int catB = getCategoryScore(b.category);
      cmp = catA.compareTo(catB);
      if (cmp != 0) return cmp;
      
      // 3. 台数の多いもの
      cmp = b.remain.compareTo(a.remain);
      if (cmp != 0) return cmp;
      
      // 4. sort_order
      return a.sortId.compareTo(b.sortId);
    });

    final topPriorities = finalPriorities.take(5).toList();

    return Container(
      width: 340, // 右サイドバーの幅
      decoration: BoxDecoration(
        color: isWhite ? Colors.blue.shade50 : const Color(0xFF2A2D3E).withOpacity(0.5),
        border: Border(left: BorderSide(color: isWhite ? Colors.blue.shade200 : Colors.blueGrey.shade700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: isWhite ? Colors.grey.shade300 : Colors.black54)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.orangeAccent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "次に作業するべき機種",
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: topPriorities.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                return Card(
                  color: cardColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: index == 0 ? Colors.orangeAccent : Colors.transparent, width: 1.5),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: index == 0 ? Colors.orangeAccent : Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${index + 1}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.maker.isNotEmpty ? "${item.model} (${item.maker})" : item.model,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "残り: ${item.remain} 台",
                          style: TextStyle(color: index == 0 ? Colors.orange : (isWhite ? Colors.blue : Colors.lightBlueAccent), fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}