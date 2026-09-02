import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/data_provider.dart';
import 'short_term_schedule_tab.dart';

class ScheduleProgressTab extends StatefulWidget {
  const ScheduleProgressTab({Key? key}) : super(key: key);

  @override
  _ScheduleProgressTabState createState() => _ScheduleProgressTabState();
}

class _ScheduleProgressTabState extends State<ScheduleProgressTab> {
  final _scrollGroup = _LinkedScrollControllerGroup();
  late ScrollController _headerScrollController;
  late ScrollController _bodyScrollController;
  late ScrollController _verticalScrollController;
  bool _isBuilding = true;
  bool _isRestoringScroll = false;
  bool _hasInitialScrolled = false; // 新規追加：初回ジャンプ判定フラグ
  late DataProvider _dpProvider;

  List<Widget> _leftColumnWidgets = [];
  
  // 新規追加：遅延描画用のデータ構造
  List<DateTime> _sortedDates = [];
  List<String> _dates = [];
  List<String> _modelKeys = [];
  Map<String, Map<String, List<int>>> _scheduleData = {};
  Map<String, String> _makerMap = {};
  Map<String, String> _modelNameMap = {};
  
  double _totalDateWidth = 0;

  Set<String> _hiddenModels = {};

  @override
  void initState() {
    super.initState();
    _headerScrollController = _scrollGroup.addAndGet();
    _bodyScrollController = _scrollGroup.addAndGet();
    _verticalScrollController = ScrollController();

    _dpProvider = Provider.of<DataProvider>(context, listen: false);
    _dpProvider.addListener(_onDataUpdated);

    _loadPreferences();
  }

  void _onDataUpdated() {
    if (mounted && !_isBuilding) {
      _buildTableWidgets();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenList = prefs.getStringList('hidden_schedule_models');
    if (hiddenList != null) {
      setState(() {
        _hiddenModels = hiddenList.toSet();
      });
    }

    // データロード後に表を構築
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _buildTableWidgets();
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_schedule_models', _hiddenModels.toList());
  }

  Future<void> _buildTableWidgets() async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final isDark = dp.displayMode == DisplayMode.pureDark;
    final textColor = dp.mainTextColor;
    final cellBorderColor = isDark
        ? const Color(0xFF33363F)
        : Colors.grey[300]!;
    final headerColor = isDark ? const Color(0xFF1A1C23) : Colors.grey[200]!;

    final schedules = dp.scheduleList;
    Set<DateTime> rawDateSet = {};
    Set<String> modelKeySet = {};
    Map<String, Map<String, List<int>>> scheduleData = {};
    Map<String, String> makerMap = {};
    Map<String, String> modelNameMap = {};
    Map<String, int> sortIdMap = {};
    const weekDays = ['月', '火', '水', '木', '金', '土', '日'];

    for (var s in schedules) {
      rawDateSet.add(s.targetDate);
      String uniqueKey = '${s.makerName}_${s.modelName}';
      modelKeySet.add(uniqueKey);
      makerMap[uniqueKey] = s.makerName;
      modelNameMap[uniqueKey] = s.modelName;
      sortIdMap[uniqueKey] = s.sortId;

      if (scheduleData[uniqueKey] == null) {
        scheduleData[uniqueKey] = {};
      }
      String dayStr =
          '${s.targetDate.month}/${s.targetDate.day}(${weekDays[s.targetDate.weekday - 1]})';
      scheduleData[uniqueKey]![dayStr] = [s.actualCount, s.planCount];
    }

    // マスターの全機種も追加（スケジュール未登録用）および並び順の上書き
    for (var m in dp.masterModelsList) {
      String maker = m['maker_name'] ?? '';
      String model = m['model_name'] ?? '';
      String uniqueKey = '${maker}_${model}';

      int sortId = int.tryParse(m['csv_id']?.toString() ?? '999999') ?? 999999;

      if (!modelKeySet.contains(uniqueKey)) {
        // スケジュールに実績がなく、エクセル(aシート)にも存在しない未分類機種は一覧に出さない
        if (sortId < 9999) {
          modelKeySet.add(uniqueKey);
          makerMap[uniqueKey] = maker;
          modelNameMap[uniqueKey] = model;
        }
      }

      // 他の画面と同じ順序（m_models.sort_order順）にするため、スケジュール側のソートIDをマスターのもので上書き
      sortIdMap[uniqueKey] = sortId;
    }

    List<DateTime> extractedDates = rawDateSet.toList();
    _sortedDates = [];
    _dates = [];
    if (extractedDates.isNotEmpty) {
      extractedDates.sort((a, b) => a.compareTo(b));
      DateTime minDate = extractedDates.first;
      DateTime maxDate = extractedDates.last;

      // ユーザーの要望により、今年いっぱい（12月31日）までは日付を必ず表示する（ListView.builder導入により重くならないため復元）
      DateTime endOfYear = DateTime(DateTime.now().year, 12, 31);
      if (maxDate.isBefore(endOfYear)) {
        maxDate = endOfYear;
      }

      DateTime curr = minDate;
      while (!curr.isAfter(maxDate)) {
        _sortedDates.add(curr);
        _dates.add('${curr.month}/${curr.day}(${weekDays[curr.weekday - 1]})');
        curr = curr.add(const Duration(days: 1));
      }
    }

    _modelKeys = modelKeySet.toList();
    _modelKeys.sort((a, b) {
      int sortA = sortIdMap[a] ?? 999999;
      int sortB = sortIdMap[b] ?? 999999;
      int cmp = sortA.compareTo(sortB);
      if (cmp != 0) return cmp;

      // sort_idが同じ場合は機種名でソート
      String modelA = modelNameMap[a] ?? '';
      String modelB = modelNameMap[b] ?? '';
      cmp = modelA.compareTo(modelB);
      if (cmp != 0) return cmp;

      // 機種名も同じ場合はメーカー名でカスタムソート (M -> FA -> O)
      String makerA = makerMap[a] ?? '';
      String makerB = makerMap[b] ?? '';

      int getMakerOrder(String model, String maker) {
        // PR-600 特有のメーカーソート順 (M/M -> H/O -> M/O)
        if (model.contains('PR-600')) {
          if (maker == 'M/M') return 1;
          if (maker == 'H/O') return 2;
          if (maker == 'M/O') return 3;
        }

        // デフォルトのメーカーソート順
        if (maker == 'M') return 1;
        if (maker == 'FA') return 2;
        if (maker == 'O') return 3;

        if (maker == 'M/M') return 4;
        if (maker == 'M/O') return 5;
        if (maker == 'F/M') return 6;
        if (maker == 'F/O') return 7;
        if (maker == 'H/M') return 8;
        if (maker == 'H/O') return 9;
        if (maker == 'O/O') return 10;

        return 99; // その他のメーカー
      }

      int makerOrderA = getMakerOrder(modelA, makerA);
      int makerOrderB = getMakerOrder(modelB, makerB);
      cmp = makerOrderA.compareTo(makerOrderB);
      if (cmp != 0) return cmp;

      return makerA.compareTo(makerB);
    });

    const double dateColWidth = 120.0;
    const double rowHeight = 80.0;
    const double modelColWidth = 150.0;

    List<Widget> tempLeft = [];
    bool isFirstBuild = !_hasInitialScrolled; // 初回だけtrue

    // 現在のスクロール位置を保存
    double savedY = 0.0;
    double savedX = 0.0;
    double savedVertical = 0.0;
    if (_bodyScrollController.hasClients) {
      savedY = _bodyScrollController.offset;
    }
    if (_headerScrollController.hasClients) {
      savedX = _headerScrollController.offset;
    }
    if (_verticalScrollController.hasClients) {
      savedVertical = _verticalScrollController.offset;
    }

    _scheduleData = scheduleData;
    _makerMap = makerMap;
    _modelNameMap = modelNameMap;

    for (int i = 0; i < _modelKeys.length; i++) {
      String key = _modelKeys[i];
      if (_hiddenModels.contains(key)) continue;

      final modelName = _modelNameMap[key] ?? '';
      final makerName = _makerMap[key] ?? '';
      final prog = dp.scheduleProgressMap[key];
      final airCount = prog?.airCount ?? 0;
      final cleanCount = prog?.cleanCount ?? 0;
      final swapCount = prog?.swapCount ?? 0;
      final totalCount = prog?.totalCount ?? 0;

      // 左列セル
      tempLeft.add(
        Row(
          children: [
            Container(
              width: modelColWidth,
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: dp.currentBgColor,
                border: Border(
                  bottom: BorderSide(color: cellBorderColor),
                  right: BorderSide(color: cellBorderColor, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      makerName.isNotEmpty
                          ? '$modelName ($makerName)'
                          : modelName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatsCell(
              airCount,
              isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
              cellBorderColor,
              textColor,
              onTap: () => _showModelProgressEditDialog(
                modelName,
                makerName,
                airCount,
                cleanCount,
                swapCount,
                totalCount,
                dp,
              ),
            ),
            _buildStatsCell(
              cleanCount,
              isDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50,
              cellBorderColor,
              textColor,
              onTap: () => _showModelProgressEditDialog(
                modelName,
                makerName,
                airCount,
                cleanCount,
                swapCount,
                totalCount,
                dp,
              ),
            ),
            _buildStatsCell(
              swapCount,
              isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
              cellBorderColor,
              textColor,
              onTap: () => _showModelProgressEditDialog(
                modelName,
                makerName,
                airCount,
                cleanCount,
                swapCount,
                totalCount,
                dp,
              ),
            ),
            _buildStatsCell(
              totalCount,
              isDark ? Colors.purple.withOpacity(0.1) : Colors.purple.shade50,
              cellBorderColor,
              textColor,
              isBold: true,
            ),
          ],
        ),
      );

      // ※横スクロールの高速化のため、右側のセル生成ループは削除し、
      // 描画時に ListView.builder で遅延構築するように変更しました。
      
      // UIを途中でクリアせず、待機だけ入れてフリーズを防ぐ
      if (i % 50 == 0 && i > 0) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    if (mounted) {
      setState(() {
        _leftColumnWidgets = tempLeft;
        _isBuilding = false;
        // 初回でも2回目以降でも、スクロールが完了するまで透明にしておく
        _isRestoringScroll = true;
      });

      // 描画後にスクロール位置を調整 (初回のみ)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isFirstBuild) {
          _hasInitialScrolled = true; // 初回ジャンプ完了を記録
          // 初回描画時：今日の日付までジャンプ
          Future.delayed(const Duration(milliseconds: 50), () {
            if (!mounted) return;
            DateTime now = DateTime.now();
            int todayIndex = _sortedDates.indexWhere(
              (d) =>
                  d.year == now.year && d.month == now.month && d.day == now.day,
            );
            if (todayIndex >= 0) {
              double targetOffset = todayIndex * 120.0; // dateColWidth = 120.0
              if (_headerScrollController.hasClients) {
                double maxScroll = _headerScrollController.position.maxScrollExtent;
                targetOffset = targetOffset > maxScroll ? maxScroll : targetOffset;
                _headerScrollController.jumpTo(targetOffset);
              }
            }
            // スクロール完了後に画面を表示
            if (mounted) {
              setState(() {
                _isRestoringScroll = false;
              });
            }
          });
        } else {
          // 2回目以降（自動更新）：保存したスクロール位置を復元
          // ユーザーの要望により、50msの遅延を入れて確実にスクロールを復元するバージョンに戻す
          // その50msの間は画面を透明にしてチラつきを隠す
          Future.delayed(const Duration(milliseconds: 50), () {
            if (!mounted) return;
            if (_bodyScrollController.hasClients) {
              _bodyScrollController.jumpTo(
                savedY.clamp(0.0, _bodyScrollController.position.maxScrollExtent),
              );
            }
            if (_headerScrollController.hasClients) {
              _headerScrollController.jumpTo(
                savedX.clamp(0.0, _headerScrollController.position.maxScrollExtent),
              );
            }
            if (_verticalScrollController.hasClients) {
              _verticalScrollController.jumpTo(
                savedVertical.clamp(0.0, _verticalScrollController.position.maxScrollExtent),
              );
            }
            // スクロール復元が終わったら画面を表示
            if (mounted) {
              setState(() {
                _isRestoringScroll = false;
              });
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _dpProvider.removeListener(_onDataUpdated);
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final isDark = dp.displayMode == DisplayMode.pureDark;
    final headerColor = isDark ? const Color(0xFF1A1C23) : Colors.grey[200]!;
    final cellBorderColor = isDark
        ? const Color(0xFF33363F)
        : Colors.grey[300]!;
    final textColor = dp.mainTextColor;

    // テーブルのセル幅・高さの定義
    const double modelColWidth = 150.0;
    const double headerHeight = 50.0;

    return Scaffold(
      backgroundColor: dp.currentBgColor,
      appBar: AppBar(
        backgroundColor: dp.currentCardColor,
        elevation: isDark ? 0 : 2,
        iconTheme: IconThemeData(color: dp.mainTextColor),
        title: Text(
          "スケジュール進捗状況",
          style: TextStyle(
            color: dp.mainTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 28, color: dp.mainTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.flash_on, color: dp.mainTextColor),
            label: Text("直近スケジュール", style: TextStyle(color: dp.mainTextColor)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShortTermScheduleTab()),
              );
            },
          ),
          if (_isBuilding)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orangeAccent,
                ),
              ),
            ),
          const SizedBox(width: 15),
          const Center(child: _ConnectionStatusIndicator()),
          const SizedBox(width: 20),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分（凡例など）
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: isDark ? Colors.purpleAccent : Colors.purple,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Text(
                  "日程別 達成状況",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cellBorderColor),
                  ),
                  child: Row(
                    children: [
                      _buildLegendItem(
                        Colors.greenAccent.withOpacity(0.2),
                        Colors.green,
                        "達成",
                        textColor,
                      ),
                      const SizedBox(width: 15),
                      _buildLegendItem(
                        Colors.redAccent.withOpacity(0.2),
                        Colors.red,
                        "未達",
                        textColor,
                      ),
                      const SizedBox(width: 15),
                      _buildLegendItem(
                        isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        Colors.grey,
                        "未着手",
                        textColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 💡 外部パッケージ不要のカスタム2Dテーブル
            Expanded(
              child: Stack(
                children: [
                  Opacity(
                    opacity: (_isBuilding || _isRestoringScroll) ? 0.0 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: cellBorderColor, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Column(
                    children: [
                      // --- 💡 上ブロック（ヘッダー行：高さ固定） ---
                      SizedBox(
                        height: headerHeight,
                        child: Row(
                          children: [
                            // 1. 左上の角（完全固定：機種名ラベルと合計列）
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: cellBorderColor,
                                    width: 2,
                                  ),
                                  bottom: BorderSide(color: cellBorderColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: modelColWidth,
                                    height: headerHeight,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: headerColor,
                                      border: Border(
                                        right: BorderSide(
                                          color: cellBorderColor,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "機種名",
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            Icons.filter_list,
                                            size: 20,
                                            color: textColor,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _showFilterDialog(dp),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatsHeader(
                                    "エアー",
                                    isDark
                                        ? Colors.blue.withOpacity(0.2)
                                        : Colors.blue.shade50,
                                    cellBorderColor,
                                    textColor,
                                  ),
                                  _buildStatsHeader(
                                    "清掃",
                                    isDark
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.green.shade50,
                                    cellBorderColor,
                                    textColor,
                                  ),
                                  _buildStatsHeader(
                                    "筐体交換",
                                    isDark
                                        ? Colors.orange.withOpacity(0.2)
                                        : Colors.orange.shade50,
                                    cellBorderColor,
                                    textColor,
                                  ),
                                  _buildStatsHeader(
                                    "合計",
                                    isDark
                                        ? Colors.purple.withOpacity(0.2)
                                        : Colors.purple.shade50,
                                    cellBorderColor,
                                    textColor,
                                  ),
                                ],
                              ),
                            ),

                            // 2. 右上の日付リスト（横スクロール・遅延描画）
                            Expanded(
                              child: ListView.builder(
                                controller: _headerScrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: _dates.length,
                                itemBuilder: (context, index) {
                                  String date = _dates[index];
                                  Color dayColor = textColor;
                                  if (date.contains('土')) {
                                    dayColor = isDark ? Colors.lightBlueAccent : Colors.blue;
                                  } else if (date.contains('日')) {
                                    dayColor = isDark ? Colors.redAccent : Colors.red;
                                  }
                                  return Container(
                                    width: 120.0, // dateColWidth
                                    height: 50.0, // headerHeight
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: headerColor,
                                      border: Border(bottom: BorderSide(color: cellBorderColor)),
                                    ),
                                    child: Text(
                                      date,
                                      style: TextStyle(
                                        color: dayColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- 💡 下ブロック（データ行：残り全部の高さ） ---
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          // 縦スクロール
                          scrollDirection: Axis.vertical,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 3. 左下の機種リストと合計（横にはスクロールしない）
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: cellBorderColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Column(children: _leftColumnWidgets),
                              ),

                              // 4. 右下のデータリスト（横スクロール・遅延描画）
                              Expanded(
                                child: SizedBox(
                                  height: _leftColumnWidgets.length * 80.0, // <-- 高さを明示的に指定
                                  child: ListView.builder(
                                    controller: _bodyScrollController,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _dates.length,
                                    itemBuilder: (context, index) {
                                      return _buildColumnForDate(
                                        index,
                                        dp,
                                        isDark,
                                        textColor,
                                        cellBorderColor,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ), // Row
                        ), // SingleChildScrollView
                      ), // Expanded
                      ],
                    ), // Column
                  ), // ClipRRect
                ), // Container
              ), // Opacity
              if (_isBuilding || _isRestoringScroll)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orangeAccent),
                      SizedBox(height: 16),
                      Text("スケジュール表を構築中です...", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ), // Stack
        ), // Expanded
          ],
        ), // Column
      ), // Container
    ); // Scaffold
  }

  Widget _buildLegendItem(
    Color bgColor,
    Color borderColor,
    String label,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // 1日分（縦1列）のセルを生成して返すメソッド（遅延描画用）
  Widget _buildColumnForDate(
    int dateIndex,
    DataProvider dp,
    bool isDark,
    Color textColor,
    Color cellBorderColor,
  ) {
    const double dateColWidth = 120.0;
    const double rowHeight = 80.0;

    DateTime d = _sortedDates[dateIndex];
    String dateStr = _dates[dateIndex];

    List<Widget> cells = [];
    for (int i = 0; i < _modelKeys.length; i++) {
      String key = _modelKeys[i];
      if (_hiddenModels.contains(key)) continue;

      final modelName = _modelNameMap[key] ?? '';
      final makerName = _makerMap[key] ?? '';
      final data = _scheduleData[key]?[dateStr] ?? [0, 0];
      final int actual = data[0];
      final int plan = data[1];

      Color cellBgColor = Colors.transparent;
      Color cellBorderColorInside = Colors.transparent;

      if (plan > 0) {
        if (actual >= plan) {
          cellBgColor = Colors.greenAccent.withOpacity(isDark ? 0.2 : 0.3);
          cellBorderColorInside = Colors.green;
        } else if (actual > 0) {
          cellBgColor = Colors.redAccent.withOpacity(isDark ? 0.2 : 0.3);
          cellBorderColorInside = Colors.redAccent;
        } else {
          cellBgColor = isDark
              ? Colors.grey.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1);
          cellBorderColorInside = Colors.grey;
        }
      }

      cells.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              _showEditDialog(modelName, makerName, d, dateStr, actual, plan),
          child: Container(
            width: dateColWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              color: cellBgColor,
              border: Border(
                bottom: BorderSide(color: cellBorderColor),
                right: BorderSide(color: cellBorderColor, width: 1),
              ),
            ),
            child: (plan > 0 || actual > 0)
                ? Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cellBorderColorInside != Colors.transparent
                            ? cellBorderColorInside
                            : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$actual / $plan",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (plan > 0)
                          Text(
                            actual >= plan
                                ? "完了"
                                : "${((actual / plan) * 100).toStringAsFixed(1)}%",
                            style: TextStyle(
                              color: actual >= plan
                                  ? Colors.green
                                  : (isDark ? Colors.redAccent : Colors.red),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          const Text(
                            "予定外",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      );
    }
    return Column(children: cells);
  }

  void _showFilterDialog(DataProvider dp) {
    final isDark = dp.displayMode == DisplayMode.pureDark;

    // 現在のスケジュールデータから機種リストを抽出
    Set<String> modelKeySet = {};
    Map<String, String> modelNameMap = {};
    Map<String, String> makerMap = {};
    Map<String, int> sortIdMap = {};

    for (var s in dp.scheduleList) {
      String uniqueKey = '${s.makerName}_${s.modelName}';
      modelKeySet.add(uniqueKey);
      modelNameMap[uniqueKey] = s.modelName;
      makerMap[uniqueKey] = s.makerName;
      sortIdMap[uniqueKey] = s.sortId;
    }

    // マスターの全機種も追加および並び順の上書き
    for (var m in dp.masterModelsList) {
      String maker = m['maker_name'] ?? '';
      String model = m['model_name'] ?? '';
      String uniqueKey = '${maker}_${model}';

      int sortId = int.tryParse(m['csv_id']?.toString() ?? '999999') ?? 999999;

      if (!modelKeySet.contains(uniqueKey)) {
        if (sortId < 9999) {
          modelKeySet.add(uniqueKey);
          modelNameMap[uniqueKey] = model;
          makerMap[uniqueKey] = maker;
        }
      }
      sortIdMap[uniqueKey] = sortId;
    }

    List<String> modelKeys = modelKeySet.toList();
    // sortId順に並び替え
    modelKeys.sort((a, b) {
      int sortA = sortIdMap[a] ?? 999999;
      int sortB = sortIdMap[b] ?? 999999;
      int cmp = sortA.compareTo(sortB);
      if (cmp != 0) return cmp;

      String modelA = modelNameMap[a] ?? '';
      String modelB = modelNameMap[b] ?? '';
      cmp = modelA.compareTo(modelB);
      if (cmp != 0) return cmp;

      String makerA = makerMap[a] ?? '';
      String makerB = makerMap[b] ?? '';

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
        if (maker == 'O/O') return 10;

        return 99;
      }

      int makerOrderA = getMakerOrder(modelA, makerA);
      int makerOrderB = getMakerOrder(modelB, makerB);
      cmp = makerOrderA.compareTo(makerOrderB);
      if (cmp != 0) return cmp;

      return makerA.compareTo(makerB);
    });

    // ダイアログ内のローカル状態
    Set<String> localHidden = Set.from(_hiddenModels);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dp.currentCardColor,
              title: Text(
                '表示する機種の選択',
                style: TextStyle(
                  color: dp.mainTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 400,
                height: 500,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              localHidden.clear();
                            });
                          },
                          child: const Text('すべて表示'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              localHidden.addAll(modelKeys);
                            });
                          },
                          child: const Text('すべて非表示'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: modelKeys.length,
                        itemBuilder: (context, index) {
                          String key = modelKeys[index];
                          String name = modelNameMap[key] ?? '';
                          String maker = makerMap[key] ?? '';
                          bool isVisible = !localHidden.contains(key);
                          return CheckboxListTile(
                            title: Text(
                              maker.isNotEmpty ? '$name ($maker)' : name,
                              style: TextStyle(
                                color: dp.mainTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: isVisible,
                            activeColor: isDark
                                ? Colors.blueAccent
                                : Colors.blue,
                            checkColor: Colors.white,
                            onChanged: (bool? val) {
                              setDialogState(() {
                                if (val == true) {
                                  localHidden.remove(key);
                                } else {
                                  localHidden.add(key);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent : Colors.blue,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _hiddenModels = localHidden;
                    });
                    _savePreferences();
                    _buildTableWidgets();
                  },
                  child: const Text(
                    '適用',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatsHeader(
    String label,
    Color bgColor,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      width: 70.0,
      height: 50.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatsCell(
    int count,
    Color bgColor,
    Color borderColor,
    Color textColor, {
    bool isBold = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70.0,
        height: 80.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: Text(
          count.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 16,
          ),
        ),
      ),
    );
  }

  void _showModelProgressEditDialog(
    String model,
    String maker,
    int curAir,
    int curClean,
    int curSwap,
    int curTotal,
    DataProvider dp,
  ) {
    // 現在数を保持するコントローラー（直接編集可能）
    final currentAirCtrl = TextEditingController(text: curAir.toString());
    final currentCleanCtrl = TextEditingController(text: curClean.toString());
    final currentSwapCtrl = TextEditingController(text: curSwap.toString());

    // 増減数を入力するコントローラー
    final addAirCtrl = TextEditingController();
    final addCleanCtrl = TextEditingController();
    final addSwapCtrl = TextEditingController();

    final bool isWhite = dp.displayMode == DisplayMode.pureWhite;
    final Color dialogBgColor = isWhite
        ? Colors.white
        : const Color(0xFF252832);
    final Color textColor = isWhite ? Colors.black87 : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget _buildAddRow(
              String label,
              TextEditingController currentCtrl,
              TextEditingController addCtrl,
            ) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isWhite ? Colors.black54 : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // 現在数（直接編集可能）
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: currentCtrl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: "現在数",
                              labelStyle: TextStyle(
                                color: isWhite
                                    ? Colors.black38
                                    : Colors.white30,
                                fontSize: 12,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: isWhite
                                      ? Colors.black26
                                      : Colors.white30,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 増減数
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: addCtrl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: "増減数",
                              labelStyle: TextStyle(
                                color: isWhite
                                    ? Colors.black38
                                    : Colors.white30,
                                fontSize: 12,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: isWhite
                                      ? Colors.black26
                                      : Colors.white30,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ＋ボタン
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              int cur = int.tryParse(currentCtrl.text) ?? 0;
                              int add = int.tryParse(addCtrl.text) ?? 0;
                              if (add != 0) {
                                currentCtrl.text = (cur + add).toString();
                                addCtrl.clear();
                              }
                            },
                            child: const Text(
                              "＋",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // ーボタン
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              int cur = int.tryParse(currentCtrl.text) ?? 0;
                              int add = int.tryParse(addCtrl.text) ?? 0;
                              if (add != 0) {
                                currentCtrl.text = (cur - add).toString();
                                addCtrl.clear();
                              }
                            },
                            child: const Text(
                              "ー",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                '$model($maker)',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380, // ボタンが増えた分、幅を少し確保
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAddRow("エアー清掃", currentAirCtrl, addAirCtrl),
                      const Divider(height: 16),
                      _buildAddRow("通常清掃", currentCleanCtrl, addCleanCtrl),
                      const Divider(height: 16),
                      _buildAddRow("筐体交換", currentSwapCtrl, addSwapCtrl),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("キャンセル"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 保存時は、現在数のフィールドの値を正として採用
                    // (増減枠に入力中のまま保存を押した場合は、意図が読めないため現在枠を優先する)
                    // しかし、親切設計として増減枠に数字があれば自動で＋として計算しておく
                    int curAir = int.tryParse(currentAirCtrl.text) ?? 0;
                    int addAir = int.tryParse(addAirCtrl.text) ?? 0;
                    int finalAir = curAir + addAir;

                    int curClean = int.tryParse(currentCleanCtrl.text) ?? 0;
                    int addClean = int.tryParse(addCleanCtrl.text) ?? 0;
                    int finalClean = curClean + addClean;

                    int curSwap = int.tryParse(currentSwapCtrl.text) ?? 0;
                    int addSwap = int.tryParse(addSwapCtrl.text) ?? 0;
                    int finalSwap = curSwap + addSwap;

                    int total = finalAir + finalClean + finalSwap;

                    await dp.updateModelScheduleProgress(
                      model,
                      maker,
                      finalAir,
                      finalClean,
                      finalSwap,
                      total,
                    );
                    if (mounted) {
                      setState(() {
                        _isBuilding = true;
                      });
                      _buildTableWidgets();
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("保存"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(
    String model,
    String maker,
    DateTime targetDate,
    String dateStr,
    int currentActual,
    int currentPlan,
  ) {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final bool isWhite = dp.displayMode == DisplayMode.pureWhite;
    final Color dialogBgColor = isWhite
        ? Colors.white
        : const Color(0xFF252832);
    final Color textColor = isWhite ? Colors.black87 : Colors.white;

    final TextEditingController actualController = TextEditingController(
      text: currentActual.toString(),
    );
    final TextEditingController planController = TextEditingController(
      text: currentPlan.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          title: Text(
            "$model\n$dateStr の予定・実績編集",
            style: TextStyle(color: textColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "予定と実績の台数を入力して保存してください",
                style: TextStyle(
                  color: isWhite ? Colors.black54 : Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: planController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "予定台数",
                  labelStyle: TextStyle(
                    color: isWhite ? Colors.black54 : Colors.grey,
                  ),
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
                  labelStyle: TextStyle(
                    color: isWhite ? Colors.black54 : Colors.grey,
                  ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: isWhite ? Colors.green.shade600 : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                int? newPlan = int.tryParse(planController.text);
                if (newPlan != null) {
                  final dp = Provider.of<DataProvider>(context, listen: false);
                  await dp.updateSchedule(
                    model,
                    maker,
                    targetDate,
                    newPlan,
                    newPlan,
                  );
                  if (mounted) {
                    setState(() {
                      _isBuilding = true;
                    });
                    _buildTableWidgets();
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("完了"),
            ),
            ElevatedButton(
              onPressed: () async {
                int? newPlan = int.tryParse(planController.text);
                int? newActual = int.tryParse(actualController.text);
                if (newPlan != null && newActual != null) {
                  final dp = Provider.of<DataProvider>(context, listen: false);
                  await dp.updateSchedule(
                    model,
                    maker,
                    targetDate,
                    newPlan,
                    newActual,
                  );
                  if (mounted) {
                    setState(() {
                      _isBuilding = true;
                    });
                    _buildTableWidgets();
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("データベースに保存"),
            ),
          ],
        );
      },
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

// ----------------------------------------------------------------------
// 💡 カスタムのスクロール同期グループ（ラグなしで同期するための仕組み）
// ----------------------------------------------------------------------
class _LinkedScrollControllerGroup {
  final List<ScrollController> _controllers = [];
  double _offset = 0.0;

  ScrollController addAndGet() {
    final controller = ScrollController(initialScrollOffset: _offset);
    _controllers.add(controller);
    controller.addListener(() {
      if (controller.offset != _offset) {
        _offset = controller.offset;
        for (var c in _controllers) {
          if (c != controller && c.hasClients && c.offset != _offset) {
            c.jumpTo(_offset);
          }
        }
      }
    });
    return controller;
  }
}
