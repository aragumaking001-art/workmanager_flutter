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
    final isWhite = provider.displayMode == DisplayMode.pureWhite;

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
                  color: provider.currentCardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Text(
                        "集計期間の選択",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: provider.mainTextColor),
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
                              style: TextStyle(color: provider.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                              items: years.map((y) {
                                return DropdownMenuItem(value: y, child: Text("$y年", style: TextStyle(color: provider.mainTextColor)));
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
                              style: TextStyle(color: provider.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                              items: months.map((m) {
                                return DropdownMenuItem(value: m, child: Text("$m月", style: TextStyle(color: provider.mainTextColor)));
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
                        calendarStyle: CalendarStyle(
                          rangeStartDecoration: BoxDecoration(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), shape: BoxShape.circle),
                          rangeEndDecoration: BoxDecoration(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00FFCC), shape: BoxShape.circle),
                          rangeHighlightColor: isWhite ? const Color(0xFF007799).withOpacity(0.15) : const Color(0x3300CCFF),
                          todayDecoration: BoxDecoration(color: isWhite ? Colors.grey.shade300 : Colors.white10, shape: BoxShape.circle),
                          defaultTextStyle: TextStyle(color: provider.mainTextColor, fontSize: 22, fontWeight: FontWeight.bold), 
                          outsideTextStyle: TextStyle(color: provider.subTextColor, fontSize: 22, fontWeight: FontWeight.bold), 
                          weekendTextStyle: const TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold), 
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
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("キャンセル", style: TextStyle(color: provider.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold)), 
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
      provider.setSummaryMode(false, start: result["start"], end: result["end"]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final isWhite = dataProvider.displayMode == DisplayMode.pureWhite;
    final _modelDataMap = dataProvider.modelDataMap;
    final _isLoading = dataProvider.isLoading;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)));
    }

    ModelSummary? currentModel = _selectedModel != null ? _modelDataMap[_selectedModel!.name] : null;
    MakerDetails? currentMaker = (currentModel != null && _selectedMaker != null) 
        ? currentModel.makerDetailsMap[_selectedMaker!.name] 
        : null;

    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : const Color(0xFF14161E).withOpacity(0.75),
                border: Border(right: BorderSide(color: dataProvider.borderColor)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, color: isWhite ? const Color(0xFF008855) : const Color(0xFF00CCFF)),
                        const SizedBox(width: 10),
                        Text("機種・メーカー選択", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dataProvider.mainTextColor)),
                      ],
                    ),
                  ),
                  Divider(color: dataProvider.borderColor, height: 1),
                  
                  _buildFilterUI(context, dataProvider, isWhite),
                  
                  Divider(color: dataProvider.borderColor, height: 1),
                  
                  Expanded(
                    child: ListView(
                      children: (() {
                        final sortedList = _modelDataMap.values.toList()
                          ..sort((a, b) {
                            int cmp = a.sortId.compareTo(b.sortId);
                            if (cmp != 0) return cmp;
                            return a.name.compareTo(b.name);
                          });
                          
                        return sortedList.map((summary) {
                          bool isModelSelected = currentModel?.name == summary.name;

                          bool overallHasWarning = 
                              (summary.air > 0 && summary.airSpeed < (summary.stdAir * 0.7)) ||
                              (summary.clean > 0 && summary.cleanSpeed < (summary.stdClean * 0.7)) ||
                              (summary.swap > 0 && summary.swapSpeed < (summary.stdSwap * 0.7));

                          Color baseColor = summary.totalFinished > 0 ? (isWhite ? Colors.green.shade100 : Colors.green.shade900) : (isWhite ? Colors.grey.shade200 : Colors.blueGrey.shade900);
                          
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
                              color: overallHasWarning ? (isWhite ? Colors.orange.shade200 : Colors.orange) : (isWhite ? Colors.grey.shade100 : Colors.white10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              overallHasWarning ? Icons.priority_high_rounded : Icons.check_rounded,
                              color: overallHasWarning ? (isWhite ? Colors.deepOrange : Colors.black) : (isWhite ? const Color(0xFF008855) : Colors.greenAccent),
                              size: 20,
                            ),
                          );

                          Widget titleText = Text(
                            summary.name, 
                            style: TextStyle(
                              color: dataProvider.mainTextColor, 
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
                                  baseColor.withOpacity(isWhite ? 0.9 : 0.5),
                                  isModelSelected ? (isWhite ? const Color(0xFF007799).withOpacity(0.2) : Colors.blue.withOpacity(0.4)) : (isWhite ? Colors.white : Colors.black26),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: overallHasWarning ? Colors.orange.shade700 : (isModelSelected ? (isWhite ? const Color(0xFF007799) : Colors.blue) : dataProvider.borderColor),
                                width: overallHasWarning || isModelSelected ? 2 : 1,
                              ),
                              boxShadow: overallHasWarning ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.15),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                            child: needsExpansion 
                              ? Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    initiallyExpanded: isModelSelected,
                                    collapsedIconColor: dataProvider.subTextColor, 
                                    iconColor: dataProvider.mainTextColor,
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    leading: leadingIcon,
                                    title: titleText,
                                    children: (() {
                                      var makers = summary.makerDetailsMap.values.toList();
                                      makers.sort((a, b) {
                                        int getMakerOrder(String model, String maker) {
                                          if (model.contains('PR-600')) {
                                            if (maker == 'M/M') return 1;
                                            if (maker == 'H/O') return 2;
                                            if (maker == 'M/O') return 3;
                                          }

                                          if (maker == 'M') return 1;
                                          if (maker == 'FA') return 2;
                                          if (maker == 'O') return 3;

                                          if (maker == 'M/M') return 4;
                                          if (maker == 'M/O') return 5;
                                          if (maker == 'F/M') return 6;
                                          if (maker == 'F/O') return 7;
                                          if (maker == 'H/M') return 8;
                                          if (maker == 'H/O') return 9;
                                          
                                          return 99;
                                        }

                                        String abbrA = a.abbr.isNotEmpty ? a.abbr : a.name;
                                        String abbrB = b.abbr.isNotEmpty ? b.abbr : b.name;

                                        int orderA = getMakerOrder(summary.name, abbrA);
                                        int orderB = getMakerOrder(summary.name, abbrB);
                                        
                                        int cmp = orderA.compareTo(orderB);
                                        if (cmp != 0) return cmp;
                                        return abbrA.compareTo(abbrB);
                                      });
                                      return makers.map((md) {
                                        bool isMakerSelected = isModelSelected && currentMaker?.name == md.name;
                                        
                                        String abbr = md.abbr; 
                                        String displayName = abbr.isNotEmpty ? abbr : md.name;
                                        if (displayName.isEmpty) displayName = "不明";

                                      double makerAirSpeed = md.airWorkMinutes > 0 ? (md.air / (md.airWorkMinutes / 60)) : 0;
                                      double makerCleanSpeed = md.cleanWorkMinutes > 0 ? (md.clean / (md.cleanWorkMinutes / 60)) : 0;
                                      double makerSwapSpeed = md.swapWorkMinutes > 0 ? (md.swap / (md.swapWorkMinutes / 60)) : 0;

                                      bool makerHasWarning = 
                                          (md.air > 0 && makerAirSpeed < (summary.stdAir * 0.7)) ||
                                          (md.clean > 0 && makerCleanSpeed < (summary.stdClean * 0.7)) ||
                                          (md.swap > 0 && makerSwapSpeed < (summary.stdSwap * 0.7));

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
                                                ? (isWhite ? const Color(0xFF007799).withOpacity(0.15) : Colors.blue.withOpacity(0.3)) 
                                                : (makerHasWarning ? (isWhite ? Colors.orange.withOpacity(0.1) : Colors.orange.withOpacity(0.15)) : Colors.transparent),
                                            border: Border(
                                              left: BorderSide(
                                                color: isMakerSelected 
                                                    ? (isWhite ? const Color(0xFF007799) : Colors.blueAccent) 
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
                                                      ? (isWhite ? const Color(0xFF007799) : Colors.blueAccent) 
                                                      : (makerHasWarning ? Colors.orange.shade700 : (isWhite ? Colors.grey.shade400 : Colors.white24)),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "メーカー",
                                                  style: TextStyle(color: isWhite && !isMakerSelected && !makerHasWarning ? Colors.black87 : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        displayName,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: makerHasWarning && !isMakerSelected ? (isWhite ? Colors.orange.shade800 : Colors.orange.shade300) : dataProvider.mainTextColor,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 1.0,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (makerHasWarning && !isMakerSelected) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(Icons.warning_amber_rounded, color: isWhite ? Colors.orange.shade800 : Colors.orangeAccent, size: 16),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  })(),
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
          
          Expanded(
            flex: 7,
            child: (currentModel == null || currentMaker == null)
                ? Center(child: Text("左のリストから機種を選択してください", style: TextStyle(color: dataProvider.subTextColor, fontSize: 18, fontWeight: FontWeight.bold))) 
                : _buildDetailView(currentModel, currentMaker, dataProvider, isWhite),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterUI(BuildContext context, DataProvider provider, bool isWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: provider.currentCardColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _customToggleButton(
                  title: "全期間 (累計)", 
                  isSelected: provider.isSummaryCumulative, 
                  onTap: () => provider.setSummaryMode(true),
                  provider: provider,
                  isWhite: isWhite,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _customToggleButton(
                  title: "期間指定", 
                  isSelected: !provider.isSummaryCumulative, 
                  onTap: () {
                    provider.setSummaryMode(false);
                  },
                  provider: provider,
                  isWhite: isWhite,
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
                  color: isWhite ? Colors.grey.shade100 : Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: provider.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.date_range, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "${DateFormat('yyyy/MM/dd').format(provider.summaryStartDate)} 〜 ${DateFormat('yyyy/MM/dd').format(provider.summaryEndDate)}",
                          style: TextStyle(color: provider.mainTextColor, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.edit, color: provider.subTextColor, size: 16), 
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _customToggleButton({required String title, required bool isSelected, required VoidCallback onTap, required DataProvider provider, required bool isWhite}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? (isWhite ? const Color(0xFF007799).withOpacity(0.15) : const Color(0xFF00CCFF).withOpacity(0.2)) : (isWhite ? Colors.grey.shade200 : Colors.black12),
          border: Border.all(color: isSelected ? (isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)) : provider.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? (isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF)) : provider.subTextColor, 
              fontWeight: FontWeight.bold, 
              fontSize: 14
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(ModelSummary m, MakerDetails md, DataProvider provider, bool isWhite) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasAbbr ? "機種名 / メーカー" : "機種名", style: TextStyle(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), fontWeight: FontWeight.bold)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(m.name, style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: provider.mainTextColor)),
                          ),
                        ),
                        if (hasAbbr) ...[
                          const SizedBox(width: 15),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isWhite ? Colors.grey.shade200 : Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: provider.borderColor)
                              ),
                              child: Text(abbr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: provider.mainTextColor)), 
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
                  Text("筐体完了合計", style: TextStyle(color: isWhite ? Colors.amber.shade800 : const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(NumberFormat('#,##0').format(md.totalFinished), style: TextStyle(fontSize: 65, fontWeight: FontWeight.w900, color: isWhite ? Colors.amber.shade800 : const Color(0xFFFFD700))),
                      Text("台", style: TextStyle(fontSize: 24, color: isWhite ? Colors.amber.shade800 : const Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Divider(color: provider.borderColor, height: 20),

          Row(
            children: [
              Icon(Icons.speed_rounded, color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), size: 28),
              const SizedBox(width: 10),
              Text("作業効率", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: provider.mainTextColor)), 
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _speedCard("エアー清掃", airSpeed, m.stdAir, isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), Icons.air_rounded, isWhite, provider),
              const SizedBox(width: 15),
              _speedCard("通常清掃", cleanSpeed, m.stdClean, isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), Icons.cleaning_services_rounded, isWhite, provider),
              const SizedBox(width: 15),
              _speedCard("筐体交換", swapSpeed, m.stdSwap, isWhite ? Colors.amber.shade800 : Colors.amber, Icons.settings_outlined, isWhite, provider),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), size: 28),
              const SizedBox(width: 10),
              Text("実績フロー ＆ 品質", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: provider.mainTextColor)), 
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
                      color: isWhite ? Colors.white : const Color(0xFF111319),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: provider.borderColor),
                      boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFlowItem("エアー清掃", md.air, Icons.air_rounded, isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), false, provider, isWhite),
                        _buildFlowItem("清掃行き", md.toClean, Icons.forward_rounded, Colors.blueGrey, true, provider, isWhite),
                        _buildFlowItem("通常清掃", md.clean, Icons.cleaning_services_rounded, isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC), true, provider, isWhite),
                        _buildFlowItem("交換行き", md.toSwap, Icons.report_problem_outlined, Colors.orange.shade700, true, provider, isWhite),
                        _buildFlowItem("交換完了", md.swap, Icons.settings_outlined, isWhite ? Colors.amber.shade800 : Colors.amber, true, provider, isWhite),
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
                      color: provider.currentCardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: provider.borderColor),
                      boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.query_stats_rounded, size: 16, color: provider.subTextColor), 
                            const SizedBox(width: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text("発生率概要", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: provider.subTextColor))
                            ), 
                          ],
                        ),
                        Divider(color: provider.borderColor, height: 12),
                        _rateGauge("エアー清掃率", md.airRate, isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), provider, isWhite),
                        const SizedBox(height: 8),
                        _rateGauge("筐体交換発生率", md.swapRate, isWhite ? Colors.red.shade700 : Colors.redAccent, provider, isWhite),
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

  Widget _buildFlowItem(String label, int count, IconData icon, Color color, bool showArrow, DataProvider provider, bool isWhite) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showArrow) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.chevron_right_rounded, color: provider.borderColor, size: 16),
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
                    NumberFormat('#,##0').format(count), 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: provider.mainTextColor), 
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label, 
                    style: TextStyle(fontSize: 12, color: provider.subTextColor, fontWeight: FontWeight.bold), 
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

  Widget _speedCard(String label, double actual, double std, Color color, IconData icon, bool isWhite, DataProvider provider) {
    final bool isZero = actual <= 0.0;
    final bool isEfficient = actual >= std;
    final bool isAcceptable = !isZero && !isEfficient && actual >= (std * 0.7);

    Color statusColor;
    Color borderColor;
    List<Color> gradientColors;
    
    if (isZero) {
      statusColor = provider.subTextColor;
      borderColor = provider.borderColor;
      gradientColors = isWhite ? [Colors.grey.shade100, Colors.grey.shade50] : [const Color(0xFF1A1A1A), const Color(0xFF111111)];
    } else if (isEfficient) {
      statusColor = isWhite ? const Color(0xFF007A3D) : const Color(0xFF00E676);
      borderColor = statusColor.withOpacity(isWhite ? 0.6 : 0.4);
      gradientColors = isWhite ? [const Color(0xFFE8F5E9), Colors.white] : [const Color(0xFF0D3211), const Color(0xFF051506)];
    } else if (isAcceptable) {
      statusColor = isWhite ? Colors.orange.shade700 : Colors.orangeAccent;
      borderColor = statusColor.withOpacity(isWhite ? 0.6 : 0.4);
      gradientColors = isWhite ? [const Color(0xFFFFF3E0), Colors.white] : [const Color(0xFF332000), const Color(0xFF1A1000)];
    } else {
      statusColor = isWhite ? const Color(0xFFD32F2F) : const Color(0xFFFF5252);
      borderColor = statusColor.withOpacity(isWhite ? 0.6 : 0.4);
      gradientColors = isWhite ? [const Color(0xFFFFEBEE), Colors.white] : [const Color(0xFF3E1414), const Color(0xFF1B0A0A)];
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
            color: borderColor,
            width: isZero ? 1.5 : 2.0,
          ),
          boxShadow: !isZero ? [
            BoxShadow(
              color: statusColor.withOpacity(isWhite ? 0.12 : 0.18),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isZero ? provider.subTextColor : color, size: 32), 
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label, 
                style: TextStyle(
                  fontSize: 18, 
                  color: isZero ? provider.subTextColor : provider.mainTextColor, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2
                )
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!isZero) ...[
                    Icon(
                      isEfficient ? Icons.arrow_upward_rounded : (isAcceptable ? Icons.trending_flat_rounded : Icons.arrow_downward_rounded),
                      color: statusColor,
                      size: 36,
                    ),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    actual.toStringAsFixed(1), 
                    style: TextStyle(
                      fontSize: 46, 
                      fontWeight: FontWeight.w900, 
                      color: statusColor, 
                      fontFamily: 'monospace',
                      letterSpacing: -0.5,
                    )
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "台",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: provider.subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isZero 
                    ? (isWhite ? Colors.grey.shade200 : Colors.black26)
                    : statusColor.withOpacity(isWhite ? 0.1 : 0.2),
                borderRadius: BorderRadius.circular(6),
                border: !isZero ? Border.all(color: statusColor.withOpacity(0.5), width: 1) : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "目標: ${std.toStringAsFixed(1)}台/1H", 
                      style: TextStyle(
                        color: provider.mainTextColor, 
                        fontSize: 14,
                        fontWeight: FontWeight.bold 
                      )
                    ),
                    if (!isZero) ...[
                      const SizedBox(width: 8),
                      Text(
                        "${isEfficient ? '▲ +' : (isAcceptable ? '▶ ' : '▼ ')}${(actual - std).toStringAsFixed(1)}",
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateGauge(String label, double value, Color color, DataProvider provider, bool isWhite) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: provider.mainTextColor, fontSize: 13))
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
            backgroundColor: isWhite ? Colors.grey.shade200 : Colors.white10, 
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}