import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/data_provider.dart';

class ModelAnalysisPage extends StatefulWidget {
  const ModelAnalysisPage({super.key});

  @override
  State<ModelAnalysisPage> createState() => _ModelAnalysisPageState();
}

class _ModelAnalysisPageState extends State<ModelAnalysisPage> {
  ModelSummary? _selectedModel;
  MakerDetails? _selectedMaker;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickCustomRange(DataProvider provider) async {
    DateTime _focusedDay = provider.summaryStartDate; 
    DateTime? _start = provider.summaryStartDate;
    DateTime? _end = provider.summaryEndDate;

    List<int> years = List.generate(11, (index) => 2020 + index);
    List<int> months = List.generate(12, (index) => index + 1);

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
                  border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      const Text(
                        "集計期間の選択",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
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
                              items: years.map((y) {
                                return DropdownMenuItem(value: y, child: Text("$y年"));
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
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _focusedDay.month,
                              dropdownColor: const Color(0xFF252830),
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              items: months.map((m) {
                                return DropdownMenuItem(value: m, child: Text("$m月"));
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

                      TableCalendar(
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
                          defaultTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), 
                          outsideTextStyle: TextStyle(color: Colors.white38, fontSize: 22, fontWeight: FontWeight.bold), 
                          weekendTextStyle: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold), 
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
                              return Center(child: Text('${day.day}', style: const TextStyle(color: Colors.blueAccent, fontSize: 22, fontWeight: FontWeight.bold)));
                            }
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
                           setDialogState(() {
                             _focusedDay = focusedDay;
                           });
                        },
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("キャンセル", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), 
                          ),
                          const SizedBox(width: 30),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC),
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

    if (result != null && result["start"] != null && result["end"] != null) {
      provider.setSummaryMode(false, start: result["start"], end: result["end"]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final _modelDataMap = dataProvider.modelDataMap;
    final _isLoading = dataProvider.isLoading;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00CCFF)));
    }

    ModelSummary? currentModel = _selectedModel != null ? _modelDataMap[_selectedModel!.name] : null;
    MakerDetails? currentMaker = (currentModel != null && _selectedMaker != null) 
        ? currentModel.makerDetailsMap[_selectedMaker!.name] 
        : null;

    return Row(
      children: [
        // 💡 左側：幅350の固定をやめ、比率(flex: 3)で全体の30%を割り当て
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF14161E),
              border: Border(right: BorderSide(color: Color(0xFF33363F))),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: Color(0xFF00CCFF)),
                      SizedBox(width: 10),
                      Text("機種・メーカー選択", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF33363F), height: 1),
                
                _buildFilterUI(context, dataProvider),
                
                const Divider(color: Color(0xFF33363F), height: 1),
                
                Expanded(
                  child: ListView(
                    children: (() {
                      final sortedList = _modelDataMap.values.toList()
                        ..sort((a, b) => a.sortId.compareTo(b.sortId));
                        
                      return sortedList.map((summary) {
                        bool isModelSelected = currentModel?.name == summary.name;

                        bool overallHasWarning = 
                            (summary.air > 0 && summary.airSpeed < summary.stdAir) ||
                            (summary.clean > 0 && summary.cleanSpeed < summary.stdClean) ||
                            (summary.swap > 0 && summary.swapSpeed < summary.stdSwap);

                        Color baseColor = summary.totalFinished > 0 ? Colors.green.shade900 : Colors.blueGrey.shade900;
                        
                        bool needsExpansion = false;
                        MakerDetails? singleMaker = summary.makerDetailsMap.isNotEmpty ? summary.makerDetailsMap.values.first : null;
                        
                        if (summary.makerDetailsMap.length > 1) {
                          needsExpansion = true;
                        } else if (singleMaker != null) {
                          String abbr = singleMaker.abbr; 
                          bool hasAbbr = abbr.isNotEmpty && abbr != singleMaker.name && singleMaker.name != "不明" && singleMaker.name != "null";
                          needsExpansion = hasAbbr;
                        }

                        Widget leadingIcon = Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: overallHasWarning ? Colors.orange : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            overallHasWarning ? Icons.priority_high_rounded : Icons.check_rounded,
                            color: overallHasWarning ? Colors.black : Colors.greenAccent,
                            size: 20,
                          ),
                        );

                        Widget titleText = Text(
                          summary.name, 
                          style: TextStyle(
                            color: Colors.white, 
                            fontWeight: overallHasWarning ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        );

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                baseColor.withOpacity(0.5),
                                isModelSelected ? Colors.blue.withOpacity(0.4) : Colors.black26,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: overallHasWarning ? Colors.orangeAccent : (isModelSelected ? Colors.blue : Colors.white10),
                              width: overallHasWarning ? 2 : 1,
                            ),
                            boxShadow: overallHasWarning ? [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.15),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ] : [],
                          ),
                          child: needsExpansion 
                            ? Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: isModelSelected,
                                  collapsedIconColor: Colors.white70, 
                                  iconColor: Colors.white,
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: leadingIcon,
                                  title: titleText,
                                  children: summary.makerDetailsMap.values.map((md) {
                                    bool isMakerSelected = isModelSelected && currentMaker?.name == md.name;
                                    
                                    String abbr = md.abbr; 
                                    String displayName = abbr.isNotEmpty ? abbr : md.name;
                                    if (displayName.isEmpty) displayName = "不明";

                                    double makerAirSpeed = md.airWorkMinutes > 0 ? (md.air / (md.airWorkMinutes / 60)) : 0;
                                    double makerCleanSpeed = md.cleanWorkMinutes > 0 ? (md.clean / (md.cleanWorkMinutes / 60)) : 0;
                                    double makerSwapSpeed = md.swapWorkMinutes > 0 ? (md.swap / (md.swapWorkMinutes / 60)) : 0;

                                    bool makerHasWarning = 
                                        (md.air > 0 && makerAirSpeed < summary.stdAir) ||
                                        (md.clean > 0 && makerCleanSpeed < summary.stdClean) ||
                                        (md.swap > 0 && makerSwapSpeed < summary.stdSwap);

                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedModel = summary;
                                          _selectedMaker = md;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isMakerSelected 
                                              ? Colors.blue.withOpacity(0.3) 
                                              : (makerHasWarning ? Colors.orange.withOpacity(0.15) : Colors.transparent),
                                          border: Border(
                                            left: BorderSide(
                                              color: isMakerSelected 
                                                  ? Colors.blueAccent 
                                                  : (makerHasWarning ? Colors.orangeAccent : Colors.transparent), 
                                              width: 4
                                            )
                                          )
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 40),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isMakerSelected 
                                                    ? Colors.blueAccent 
                                                    : (makerHasWarning ? Colors.orange.shade700 : Colors.white24),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                "メーカー",
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  // 💡 機種名が長い場合のはみ出し防止
                                                  Flexible(
                                                    child: Text(
                                                      displayName,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: makerHasWarning && !isMakerSelected ? Colors.orange.shade300 : Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 1.0,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  if (makerHasWarning && !isMakerSelected) ...[
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                                                  ]
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            : ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: leadingIcon,
                                title: titleText,
                                trailing: const Icon(Icons.expand_more, color: Colors.transparent), 
                                onTap: () {
                                  setState(() {
                                    _selectedModel = summary;
                                    _selectedMaker = singleMaker;
                                  });
                                },
                              ),
                        );
                      }).toList();
                    })(),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 💡 右側：比率(flex: 7)で全体の70%を割り当て
        Expanded(
          flex: 7,
          child: (currentModel == null || currentMaker == null)
              ? const Center(child: Text("左のリストから機種を選択してください", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))) 
              : _buildDetailView(currentModel, currentMaker, dataProvider),
        ),
      ],
    );
  }

  Widget _buildFilterUI(BuildContext context, DataProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFF1A1C23),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _customToggleButton(
                  title: "全期間 (累計)", 
                  isSelected: provider.isSummaryCumulative, 
                  onTap: () => provider.setSummaryMode(true)
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _customToggleButton(
                  title: "期間指定", 
                  isSelected: !provider.isSummaryCumulative, 
                  onTap: () {
                    provider.setSummaryMode(false);
                  }
                ),
              ),
            ],
          ),
          if (!provider.isSummaryCumulative) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickCustomRange(provider),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF33363F)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.date_range, color: Color(0xFF00CCFF), size: 18),
                    const SizedBox(width: 10),
                    // 💡 小さい画面での日付はみ出し防止
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "${DateFormat('yyyy/MM/dd').format(provider.summaryStartDate)} 〜 ${DateFormat('yyyy/MM/dd').format(provider.summaryEndDate)}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.edit, color: Colors.white70, size: 16), 
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _customToggleButton({required String title, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00CCFF).withOpacity(0.2) : Colors.black12,
          border: Border.all(color: isSelected ? const Color(0xFF00CCFF) : Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00CCFF) : Colors.white70, 
              fontWeight: FontWeight.bold, 
              fontSize: 14
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(ModelSummary m, MakerDetails md, DataProvider provider) {
    double airSpeed = md.airWorkMinutes > 0 ? (md.air / (md.airWorkMinutes / 60)) : 0;
    double cleanSpeed = md.cleanWorkMinutes > 0 ? (md.clean / (md.cleanWorkMinutes / 60)) : 0;
    double swapSpeed = md.swapWorkMinutes > 0 ? (md.swap / (md.swapWorkMinutes / 60)) : 0;

    String abbr = md.abbr; 
    bool hasAbbr = abbr.isNotEmpty && abbr != md.name && md.name != "不明" && md.name != "null";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ヘッダー部分 ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 💡 左側のタイトル部分をExpandedで囲み、長い機種名がはみ出ないようにする
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasAbbr ? "機種名 / メーカー" : "機種名", style: const TextStyle(color: Color(0xFF00CCFF), fontWeight: FontWeight.bold)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(m.name, style: const TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                        if (hasAbbr) ...[
                          const SizedBox(width: 15),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24)
                              ),
                              child: Text(abbr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), 
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("メーカー完了合計", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${md.totalFinished}", style: const TextStyle(fontSize: 65, fontWeight: FontWeight.w900, color: Color(0xFFFFD700))),
                      const Text("台", style: TextStyle(fontSize: 24, color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFF33363F), height: 20),

          // --- 作業効率セクション ---
          const Row(
            children: [
              Icon(Icons.speed_rounded, color: Color(0xFF00CCFF), size: 28),
              SizedBox(width: 10),
              Text("作業効率", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), 
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _speedCard("エアー清掃", airSpeed, m.stdAir, const Color(0xFF00CCFF), Icons.air_rounded),
              const SizedBox(width: 15),
              _speedCard("通常清掃", cleanSpeed, m.stdClean, const Color(0xFF00FFCC), Icons.cleaning_services_rounded),
              const SizedBox(width: 15),
              _speedCard("筐体交換", swapSpeed, m.stdSwap, Colors.amber, Icons.settings_outlined),
            ],
          ),

          // --- 実績フロー ＆ 品質セクション ---
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: Color(0xFF00FFCC), size: 28),
              SizedBox(width: 10),
              Text("実績フロー ＆ 品質", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), 
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111319),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF252830)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 💡 幅を固定せずExpandedで均等に割り当てるように修正
                        _buildFlowItem("エアー清掃", md.air, Icons.air_rounded, const Color(0xFF00CCFF), false),
                        _buildFlowItem("清掃行き", md.toClean, Icons.forward_rounded, Colors.blueGrey, true),
                        _buildFlowItem("通常清掃", md.clean, Icons.cleaning_services_rounded, const Color(0xFF00FFCC), true),
                        _buildFlowItem("交換行き", md.toSwap, Icons.report_problem_outlined, Colors.orangeAccent, true),
                        _buildFlowItem("交換完了", md.swap, Icons.settings_outlined, Colors.amber, true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1C23),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF33363F)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.query_stats_rounded, size: 16, color: Colors.white70), 
                            SizedBox(width: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("発生率概要", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70))
                            ), 
                          ],
                        ),
                        const Divider(color: Color(0xFF33363F), height: 12),
                        _rateGauge("エアー清掃率", md.airRate, const Color(0xFF00CCFF)),
                        const SizedBox(height: 8),
                        _rateGauge("筐体交換発生率", md.swapRate, Colors.redAccent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 💡 固定の width: 95 を廃止し、Expandedで伸縮するように変更
  Widget _buildFlowItem(String label, int count, IconData icon, Color color, bool showArrow) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showArrow) 
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right_rounded, color: Color(0xFF33363F), size: 16), // 矢印を少し縮小
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: color),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "$count", 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), 
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label, 
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold), 
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedCard(String label, double actual, double std, Color color, IconData icon) {
    final bool isZero = actual <= 0.0;
    final bool isEfficient = actual >= std;

    Color mainColor;
    List<Color> gradientColors;
    
    if (isZero) {
      mainColor = Colors.grey;
      gradientColors = [const Color(0xFF1A1A1A), const Color(0xFF111111)];
    } else if (isEfficient) {
      mainColor = Colors.greenAccent;
      gradientColors = [const Color(0xFF0D3211), const Color(0xFF051506)];
    } else {
      mainColor = Colors.orangeAccent;
      gradientColors = [const Color(0xFF4D3300), const Color(0xFF261900)];
    }

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isZero ? Colors.white10 : mainColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: !isZero ? [
            BoxShadow(
              color: mainColor.withOpacity(isEfficient ? 0.05 : 0.15),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isZero ? Colors.white54 : color, size: 32), 
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label, 
                style: TextStyle(
                  fontSize: 18, 
                  color: isZero ? Colors.white54 : color, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2
                )
              ),
            ),
            const SizedBox(height: 4),
            // 💡 数値が大きくなってもはみ出さないようにFittedBox追加
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                actual.toStringAsFixed(1), 
                style: TextStyle(
                  fontSize: 42, 
                  fontWeight: FontWeight.w900, 
                  color: isZero ? Colors.white54 : Colors.white, 
                  fontFamily: 'monospace',
                )
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              // 💡 目標テキストのはみ出し防止
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "目標: ${std.toStringAsFixed(1)}台/1H", 
                  style: TextStyle(
                    color: isZero ? Colors.white54 : Colors.white, 
                    fontSize: 14,
                    fontWeight: FontWeight.bold 
                  )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateGauge(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))
              )
            ), 
            Text("${value.toStringAsFixed(1)}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100, 
            color: color, 
            backgroundColor: Colors.white10, 
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}