import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'dart:math' as math;
import 'dart:async';
import '../providers/data_provider.dart';

class PersonalStatsTab extends StatefulWidget {
  final String? initialWorkerId;
  final bool isKioskMode;

  const PersonalStatsTab({
    super.key,
    this.initialWorkerId,
    this.isKioskMode = false,
  });

  @override
  State<PersonalStatsTab> createState() => _PersonalStatsTabState();
}

class _PersonalStatsTabState extends State<PersonalStatsTab>
    with SingleTickerProviderStateMixin {
  String? _selectedWorker;
  String _selectedFloor = "4F";

  late AnimationController _animController;
  late Animation<double> _animValue;

  @override
  void initState() {
    super.initState();
    _selectedWorker = widget.initialWorkerId;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animValue = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    if (widget.isKioskMode && _selectedWorker != null) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final isWhite = dataProvider.displayMode == DisplayMode.pureWhite;
    final workers = dataProvider.workerStatsMap.values.toList();
    workers.sort((a, b) => b.level.compareTo(a.level));

    return Scaffold(
      backgroundColor: dataProvider.currentBgColor,
      appBar: widget.isKioskMode
          ? null
          : AppBar(
              backgroundColor: dataProvider.currentCardColor,
              elevation: isWhite ? 2 : 0,
              iconTheme: IconThemeData(color: dataProvider.mainTextColor),
              title: Text(
                "個人別実績ステータス",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: dataProvider.mainTextColor,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: dataProvider.mainTextColor),
                onPressed: () => Navigator.pop(context),
              ),
              actions: const [
                Center(child: _ConnectionStatusIndicator()),
                SizedBox(width: 20),
              ],
            ),
      body: Row(
        children: [
          if (!widget.isKioskMode)
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: dataProvider.currentCardColor,
                  border: Border(
                    right: BorderSide(color: dataProvider.borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            color: isWhite
                                ? const Color(0xFF007799)
                                : const Color(0xFF00CCFF),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "作業者を選択",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: dataProvider.mainTextColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: dataProvider.borderColor, height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          var worker = workers[index];
                          bool isSelected = _selectedWorker == worker.id;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedWorker = worker.id;
                                _selectedFloor = "4F";
                              });
                              _animController.forward(from: 0.0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isWhite
                                          ? const Color(
                                              0xFF007799,
                                            ).withOpacity(0.12)
                                          : const Color(
                                              0xFF00CCFF,
                                            ).withOpacity(0.15))
                                    : (isWhite
                                          ? Colors.grey.shade100
                                          : Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? (isWhite
                                            ? const Color(0xFF007799)
                                            : const Color(0xFF00CCFF))
                                      : dataProvider.borderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSelected
                                        ? (isWhite
                                              ? const Color(0xFF007799)
                                              : const Color(0xFF00CCFF))
                                        : (isWhite
                                              ? Colors.grey.shade300
                                              : Colors.white24),
                                    child: Text(
                                      worker.name.isNotEmpty
                                          ? worker.name.substring(0, 1)
                                          : "?",
                                      style: TextStyle(
                                        color: isSelected && isWhite
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          worker.name,
                                          style: TextStyle(
                                            color: dataProvider.mainTextColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "Lv.${worker.level} - ${worker.title}",
                                          style: TextStyle(
                                            color: dataProvider.subTextColor,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
            ),

          Expanded(
            flex: widget.isKioskMode ? 10 : 7,
            child: Container(
              color: dataProvider.currentBgColor,
              child: _selectedWorker == null
                  ? Center(
                      child: Text(
                        "左のリストから作業者を選択してください",
                        style: TextStyle(
                          color: dataProvider.subTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildMainContent(dataProvider, isWhite),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(DataProvider provider, bool isWhite) {
    var worker = provider.workerStatsMap[_selectedWorker];
    if (worker == null) {
      return Center(
        child: Text(
          "該当する作業者のデータがありません",
          style: TextStyle(
            color: provider.mainTextColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      children: [
        if (!widget.isKioskMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: provider.currentCardColor,
              border: Border(bottom: BorderSide(color: provider.borderColor)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers,
                  color: isWhite
                      ? const Color(0xFF007799)
                      : const Color(0xFF00CCFF),
                  size: 28,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _floorTabButton(
                    "1F",
                    "入荷",
                    Icons.warehouse,
                    isWhite ? Colors.blueGrey.shade700 : Colors.blueGrey,
                    provider,
                    isWhite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _floorTabButton(
                    "2F",
                    "梱包",
                    Icons.inventory_2,
                    isWhite ? Colors.blueGrey.shade700 : Colors.blueGrey,
                    provider,
                    isWhite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _floorTabButton(
                    "3F",
                    "検品",
                    Icons.fact_check,
                    isWhite ? Colors.blueGrey.shade700 : Colors.blueGrey,
                    provider,
                    isWhite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _floorTabButton(
                    "4F",
                    "清掃",
                    Icons.cleaning_services,
                    isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC),
                    provider,
                    isWhite,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _selectedFloor == "4F"
              ? _build4FStatsView(worker, provider, isWhite)
              : _buildComingSoonView(provider),
        ),
      ],
    );
  }

  Widget _floorTabButton(
    String floor,
    String label,
    IconData icon,
    Color activeColor,
    DataProvider provider,
    bool isWhite,
  ) {
    bool isSelected = _selectedFloor == floor;

    return InkWell(
      onTap: () {
        setState(() => _selectedFloor = floor);
        if (floor == "4F") {
          _animController.forward(from: 0.0);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : provider.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected && !isWhite
              ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 10)]
              : [],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : provider.subTextColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "$floor $label",
                style: TextStyle(
                  color: isSelected
                      ? provider.mainTextColor
                      : provider.subTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonView(DataProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, color: provider.subTextColor, size: 80),
          const SizedBox(height: 20),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$_selectedFloor の実績データは現在システム構築中です",
                style: TextStyle(
                  color: provider.mainTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build4FStatsView(
    WorkerStats worker,
    DataProvider provider,
    bool isWhite,
  ) {
    int safePoints =
        (worker.earnedPoints.isNaN || worker.earnedPoints.isInfinite)
        ? 0
        : worker.earnedPoints.toInt();
    double safeQuality =
        (worker.qualityScore.isNaN || worker.qualityScore.isInfinite)
        ? 0.0
        : worker.qualityScore;
    int safeFinished =
        (worker.totalFinished.isNaN || worker.totalFinished.isInfinite)
        ? 0
        : worker.totalFinished;

    List<double> stats = [
      worker.speedScore.isNaN || worker.speedScore.isInfinite
          ? 0.0
          : worker.speedScore,
      safeQuality,
      worker.techScore.isNaN || worker.techScore.isInfinite
          ? 0.0
          : worker.techScore,
      worker.staminaScore.isNaN || worker.staminaScore.isInfinite
          ? 0.0
          : worker.staminaScore,
      worker.contributionScore.isNaN || worker.contributionScore.isInfinite
          ? 0.0
          : worker.contributionScore,
    ];

    // 💡 レーダーチャートのラベル名称を変更
    List<String> labels = ["作業スピード", "作業品質", "機種マスター", "継続力", "総合実績"];

    // 💡 各項目のランク文字列を取得
    List<String> ranks = List.generate(5, (i) => worker.getRankByIndex(i));

    bool isGold = [
      "和気センターの伝説",
      "神速の仕事人",
      "絶対無ミスの精密機械",
      "4Fの守護神",
    ].contains(worker.title);
    bool isSilver = [
      "熟練のスピードスター",
      "百戦錬磨の匠",
      "センターの柱",
      "フロアマスター",
      "ベテラン作業員",
    ].contains(worker.title);
    bool isBronze = ["一人前の仕事人"].contains(worker.title);
    bool isIron = ["期待のホープ"].contains(worker.title);

    Color rankColor = isGold
        ? Colors.amber
        : isSilver
        ? Colors.grey.shade300
        : isBronze
        ? Colors.orange.shade700
        : isIron
        ? Colors.blueGrey.shade300
        : const Color(0xFF00CCFF);

    Color rankGlow = isGold
        ? Colors.amberAccent
        : isSilver
        ? Colors.white
        : isBronze
        ? Colors.deepOrangeAccent
        : isIron
        ? Colors.blueGrey
        : const Color(0xFF00CCFF);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: provider.currentCardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: rankColor.withOpacity(isWhite ? 0.8 : 0.5),
                width: isWhite ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isWhite
                      ? rankColor.withOpacity(0.2)
                      : rankGlow.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isWhite ? Colors.white : Colors.black45,
                        ),
                        child: Center(
                          child: Text(
                            "Lv.${worker.level}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: provider.mainTextColor,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Image.asset(
                          isGold
                              ? 'assets/frame_gold.png'
                              : isSilver
                              ? 'assets/frame_silver.png'
                              : isBronze
                              ? 'assets/frame_bronze.png'
                              : isIron
                              ? 'assets/frame_iron.png'
                              : 'assets/frame_wood.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          worker.title,
                          style: TextStyle(
                            color: isWhite ? rankColor : rankGlow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          worker.name,
                          style: TextStyle(
                            color: provider.mainTextColor,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            "EXP",
                            style: TextStyle(
                              color: provider.subTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value:
                                    worker.expProgress.isNaN ||
                                        worker.expProgress.isInfinite
                                    ? 0.0
                                    : worker.expProgress,
                                backgroundColor: isWhite
                                    ? Colors.grey.shade200
                                    : Colors.white10,
                                color: isWhite ? rankColor : rankGlow,
                                minHeight: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "NEXT: ${worker.nextExp} pt",
                                style: TextStyle(
                                  color: provider.subTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 💡 新レイアウト：システム分析カードを一番上に横幅いっぱいで表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isWhite ? Colors.grey.shade100 : Colors.black26,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: provider.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: widget.isKioskMode
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "💡 システム分析 (和気センターAI)",
                          style: TextStyle(
                            color: provider.subTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.pinkAccent,
                              width: 1.5,
                            ),
                          ),
                          child: const Text(
                            "キャラクター名募集中！",
                            style: TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isKioskMode) const SizedBox(width: 30),
                    Row(
                      children: [
                        Text(
                          "スタイル設定: ",
                          style: TextStyle(
                            color: provider.subTextColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ), // パディングを少し戻す
                          decoration: BoxDecoration(
                            color: isWhite ? Colors.white : Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: provider.borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 5,
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: provider.subTextColor,
                              ), // アイコンを明示的に指定
                              value: worker.aiTone,
                              dropdownColor: isWhite
                                  ? Colors.white
                                  : const Color(0xFF2C2C2E),
                              style: TextStyle(
                                color: provider.mainTextColor,
                                fontSize: 14,
                              ),
                              items: ["標準", "関西弁", "熱血コーチ", "執事"].map((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  provider.updateAiTone(worker.id, newValue);
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) {
                                      Future.delayed(
                                        const Duration(seconds: 2),
                                        () {
                                          if (Navigator.of(context).canPop()) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      );
                                      return AlertDialog(
                                        backgroundColor: isWhite
                                            ? Colors.white
                                            : const Color(0xFF2C2C2E),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: isWhite
                                                  ? const Color(0xFF008855)
                                                  : Colors.greenAccent,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              "変更完了",
                                              style: TextStyle(
                                                color: provider.mainTextColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          "AIの口調を「$newValue」に変更しました！\n\n明日のレポートをお楽しみに待ってね！",
                                          style: TextStyle(
                                            color: provider.mainTextColor,
                                            fontSize: 16,
                                            height: 1.5,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/mascot.png',
                        width: 180, // 120 -> 180
                        height: 180, // 120 -> 180
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isWhite ? Colors.white : Colors.black45,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(15),
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          border: Border.all(
                            color: isWhite
                                ? Colors.grey.shade300
                                : Colors.grey.shade800,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getSystemComment(worker),
                              style: TextStyle(
                                color: provider.mainTextColor,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: provider.subTextColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "※ このレポートはAIによって自動生成されているため、間違っている可能性があることにご注意ください。",
                                    style: TextStyle(
                                      color: provider.subTextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 下段：左にレーダーチャート、右に4つの枠
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: provider.currentCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: provider.borderColor),
                    boxShadow: isWhite
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedBuilder(
                    animation: _animValue,
                    builder: (context, child) {
                      List<double> animStats = stats
                          .map((e) => e * _animValue.value)
                          .toList();
                      return CustomPaint(
                        painter: RadarChartPainter(
                          animStats,
                          ranks,
                          labels,
                          isWhite
                              ? const Color(0xFF008855)
                              : const Color(0xFF00FFCC),
                          provider.mainTextColor,
                          isWhite,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 30),

              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statRow(
                      "累計完了台数",
                      NumberFormat('#,##0').format(safeFinished),
                      "台",
                      isWhite ? const Color(0xFF008855) : Colors.greenAccent,
                      provider,
                      isWhite,
                    ),
                    _statRow(
                      "獲得pt (総合実績)",
                      NumberFormat('#,##0').format(safePoints),
                      "pt",
                      isWhite ? Colors.amber.shade800 : Colors.amberAccent,
                      provider,
                      isWhite,
                    ),
                    _statRow(
                      "対応機種 (機種マスター)",
                      NumberFormat('#,##0').format(worker.uniqueModels),
                      "機種",
                      isWhite ? const Color(0xFFD45500) : Colors.orangeAccent,
                      provider,
                      isWhite,
                    ),
                    _statRow(
                      "作業品質スコア",
                      (safeQuality * 100).toStringAsFixed(0),
                      "pt",
                      isWhite ? Colors.purple.shade700 : Colors.purpleAccent,
                      provider,
                      isWhite,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildModelBreakdown(worker, provider, isWhite),
        ],
      ),
    );
  }

  Widget _buildModelBreakdown(
    WorkerStats worker,
    DataProvider provider,
    bool isWhite,
  ) {
    if (worker.modelCounts.isEmpty) return const SizedBox.shrink();

    // 台数が多い順にソート
    var sortedModels = worker.modelCounts.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    int totalAir = worker.air;
    int totalClean = worker.clean;
    int totalSwap = worker.swap;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: provider.currentCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: provider.borderColor),
        boxShadow: isWhite
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "作業機種・実績ブレイクダウン",
            style: TextStyle(
              color: provider.mainTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1, // キオスク時もグラフとリストを1:1〜1:2でバランスを取る
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: widget.isKioskMode
                          ? 320
                          : 260, // 高さを少し確保してグラフを大きくする
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(
                              widget.isKioskMode ? 280 : 220,
                              widget.isKioskMode ? 280 : 220,
                            ), // グラフ本体のサイズを大きく
                            painter: DonutChartPainter(
                              totalAir,
                              totalClean,
                              totalSwap,
                              isWhite
                                  ? Colors.blue.shade600
                                  : Colors.lightBlueAccent,
                              isWhite
                                  ? const Color(0xFF008855)
                                  : Colors.greenAccent,
                              isWhite
                                  ? Colors.amber.shade700
                                  : Colors.amberAccent,
                              isWhite ? Colors.grey.shade200 : Colors.white10,
                              provider.mainTextColor,
                              isWhite,
                              strokeWidth: widget.isKioskMode
                                  ? 60
                                  : 48, // グラフを太くして文字の余白をさらに確保
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "総作業",
                                style: TextStyle(
                                  color: provider.subTextColor,
                                  fontSize: widget.isKioskMode ? 18 : 16,
                                ),
                              ),
                              Text(
                                NumberFormat(
                                  '#,##0',
                                ).format(worker.totalFinished),
                                style: TextStyle(
                                  color: provider.mainTextColor,
                                  fontSize: widget.isKioskMode ? 36 : 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                "台",
                                style: TextStyle(
                                  color: provider.subTextColor,
                                  fontSize: widget.isKioskMode ? 16 : 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendItem(
                          "エアー",
                          isWhite
                              ? Colors.blue.shade600
                              : Colors.lightBlueAccent,
                          provider,
                        ),
                        const SizedBox(width: 15),
                        _legendItem(
                          "清掃",
                          isWhite
                              ? const Color(0xFF008855)
                              : Colors.greenAccent,
                          provider,
                        ),
                        const SizedBox(width: 15),
                        _legendItem(
                          "交換",
                          isWhite ? Colors.amber.shade700 : Colors.amberAccent,
                          provider,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                flex: widget.isKioskMode
                    ? 1
                    : 2, // キオスクモード時のグラフとリストの割合を 1:1 に戻す
                child: Container(
                  height: widget.isKioskMode ? 350 : 250, // 高さも調整
                  decoration: BoxDecoration(
                    color: isWhite ? Colors.grey.shade50 : Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: provider.borderColor, width: 0.5),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    itemCount: sortedModels.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: provider.borderColor, height: 1),
                    itemBuilder: (context, index) {
                      var mc = sortedModels[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: widget.isKioskMode
                                  ? 4
                                  : 3, // 機種名に少し多めの割合を割り当て
                              child: Text(
                                mc.modelName,
                                style: TextStyle(
                                  color: provider.mainTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: widget.isKioskMode ? 22 : 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.isKioskMode) ...[
                              // タグを「左詰め」で並べつつ、2個目・3個目の縦列が揃うようにする
                              Expanded(
                                flex: 6, // タグ領域全体の割合
                                child: Builder(
                                  builder: (context) {
                                    // 表示すべきタグをリストにまとめる
                                    List<Widget> activeTags = [];
                                    if (mc.air > 0) {
                                      activeTags.add(
                                        _miniTag(
                                          "エアー ${NumberFormat('#,##0').format(mc.air)}",
                                          isWhite
                                              ? Colors.blue.shade600
                                              : Colors.lightBlueAccent,
                                          isWhite,
                                          true,
                                        ),
                                      );
                                    }
                                    if (mc.clean > 0) {
                                      activeTags.add(
                                        _miniTag(
                                          "清掃 ${NumberFormat('#,##0').format(mc.clean)}",
                                          isWhite
                                              ? const Color(0xFF008855)
                                              : Colors.greenAccent,
                                          isWhite,
                                          true,
                                        ),
                                      );
                                    }
                                    if (mc.swap > 0) {
                                      activeTags.add(
                                        _miniTag(
                                          "交換 ${NumberFormat('#,##0').format(mc.swap)}",
                                          isWhite
                                              ? Colors.amber.shade700
                                              : Colors.amberAccent,
                                          isWhite,
                                          true,
                                        ),
                                      );
                                    }

                                    // 足りない分は空の枠で埋める（常に3枠ある状態にする）
                                    while (activeTags.length < 3) {
                                      activeTags.add(const SizedBox.shrink());
                                    }

                                    // 3つの枠を均等に分割して並べる
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            child: activeTags[0],
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            child: activeTags[1],
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            child: activeTags[2],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "${NumberFormat('#,##0').format(mc.total)}台",
                                      style: TextStyle(
                                        color: provider.mainTextColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    if (mc.air > 0)
                                      _miniTag(
                                        "エアー ${NumberFormat('#,##0').format(mc.air)}",
                                        isWhite
                                            ? Colors.blue.shade600
                                            : Colors.lightBlueAccent,
                                        isWhite,
                                      ),
                                    if (mc.clean > 0)
                                      _miniTag(
                                        "清掃 ${NumberFormat('#,##0').format(mc.clean)}",
                                        isWhite
                                            ? const Color(0xFF008855)
                                            : Colors.greenAccent,
                                        isWhite,
                                      ),
                                    if (mc.swap > 0)
                                      _miniTag(
                                        "交換 ${NumberFormat('#,##0').format(mc.swap)}",
                                        isWhite
                                            ? Colors.amber.shade700
                                            : Colors.amberAccent,
                                        isWhite,
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                "${NumberFormat('#,##0').format(mc.total)}台",
                                style: TextStyle(
                                  color: provider.mainTextColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, DataProvider provider) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: provider.mainTextColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _miniTag(
    String text,
    Color color,
    bool isWhite, [
    bool isKiosk = false,
  ]) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: EdgeInsets.symmetric(
        horizontal: isKiosk ? 8 : 8, // 余白を減らして文字スペースを確保
        vertical: isKiosk ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(isWhite ? 0.1 : 0.15),
        borderRadius: BorderRadius.circular(isKiosk ? 10 : 6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown, // 横幅が足りない場合は自動で1行のまま文字を縮小
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: isKiosk ? 16 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getSystemComment(WorkerStats w) {
    if (w.aiReport.isNotEmpty) {
      return w.aiReport;
    }
    if (w.level > 50)
      return "熟練の技術により、すべての指標でトップクラスの成績を叩き出しています。引き続きフロアの牽引をお願いします！";
    if (w.speedScore > 0.8 && w.qualityScore > 0.8)
      return "圧倒的な作業スピードと高い完結力を両立しています。素晴らしいパフォーマンスです。";
    if (w.speedScore > 0.8)
      return "非常に速いペースで作業を行っています。このスピードを維持しつつ、さらに様々な機種を触ることで総合力がアップします。";
    if (w.qualityScore > 0.9)
      return "丁寧な作業で、自分の工程でしっかり完結させる割合が非常に高いです。品質の高さはピカイチです。";
    if (w.techScore > 0.5)
      return "幅広い機種に対応できる柔軟性があります。特定の機種に偏らないバランスの良いスキルセットを持っています。";
    if (w.contributionScore > 0.7)
      return "難易度の高い作業を積極的にこなし、フロアのポイント稼ぎ頭として大きく貢献しています！";
    return "着実に経験を積んでいます。まずは作業台数をこなし、レベルアップを目指しましょう！";
  }

  Widget _statRow(
    String label,
    String value,
    String unit,
    Color color,
    DataProvider provider,
    bool isWhite,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 85),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : provider.currentCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWhite ? Colors.grey.shade300 : provider.borderColor,
          width: 1.5,
        ),
        boxShadow: isWhite
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: provider.mainTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "$value $unit",
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> ranks; // targetValues(double) から ranks(String) に変更
  final List<String> labels;
  final Color color;
  final Color textColor;
  final bool isWhite;

  RadarChartPainter(
    this.values,
    this.ranks,
    this.labels,
    this.color,
    this.textColor,
    this.isWhite,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 40;
    final int sides = values.length;
    final angle = (2 * math.pi) / sides;

    final paintBg = Paint()
      ..color = isWhite
          ? Colors.grey.withOpacity(0.35)
          : Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintValueFill = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final paintValueStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (int i = 1; i <= 5; i++) {
      final r = radius * (i / 5);
      final path = Path();
      for (int j = 0; j < sides; j++) {
        final x = center.dx + r * math.cos(angle * j - math.pi / 2);
        final y = center.dy + r * math.sin(angle * j - math.pi / 2);
        if (j == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paintBg);
    }

    for (int j = 0; j < sides; j++) {
      final x = center.dx + radius * math.cos(angle * j - math.pi / 2);
      final y = center.dy + radius * math.sin(angle * j - math.pi / 2);
      canvas.drawLine(center, Offset(x, y), paintBg);
    }

    final valuePath = Path();
    for (int j = 0; j < sides; j++) {
      final r = radius * values[j];
      final x = center.dx + r * math.cos(angle * j - math.pi / 2);
      final y = center.dy + r * math.sin(angle * j - math.pi / 2);
      if (j == 0)
        valuePath.moveTo(x, y);
      else
        valuePath.lineTo(x, y);

      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = isWhite ? textColor : Colors.white,
      );
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()..color = color.withOpacity(0.5),
      );
    }
    valuePath.close();
    canvas.drawPath(valuePath, paintValueFill);
    canvas.drawPath(valuePath, paintValueStroke);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    for (int j = 0; j < sides; j++) {
      final r = radius + 35;
      final x = center.dx + r * math.cos(angle * j - math.pi / 2);
      final y = center.dy + r * math.sin(angle * j - math.pi / 2);

      String rankStr = ranks[j];
      Color rankColor;
      // 💡 パワプロ風のランクカラー設定
      switch (rankStr) {
        case "SS":
        case "S":
          rankColor = Colors.amberAccent; // ゴールド/虹
          break;
        case "A":
          rankColor = Colors.pinkAccent; // ピンク
          break;
        case "B":
          rankColor = Colors.redAccent; // 赤
          break;
        case "C":
          rankColor = Colors.orangeAccent; // オレンジ
          break;
        case "D":
          rankColor = Colors.yellowAccent; // 黄色
          break;
        case "E":
          rankColor = Colors.greenAccent; // 緑
          break;
        case "F":
          rankColor = Colors.lightBlueAccent; // 青/水色
          break;
        default:
          rankColor = Colors.grey;
      }

      // ライトモード（白背景）の場合は色が薄すぎて見えないため少し濃くする
      if (isWhite) {
        if (rankStr == "SS" || rankStr == "S")
          rankColor = Colors.amber.shade700;
        else if (rankStr == "A")
          rankColor = Colors.pink.shade600;
        else if (rankStr == "B")
          rankColor = Colors.red.shade600;
        else if (rankStr == "C")
          rankColor = Colors.orange.shade700;
        else if (rankStr == "D")
          rankColor = Colors.yellow.shade800;
        else if (rankStr == "E")
          rankColor = Colors.green.shade600;
        else if (rankStr == "F")
          rankColor = Colors.lightBlue.shade600;
      }

      textPainter.text = TextSpan(
        children: [
          TextSpan(
            text: "${labels[j]}\n",
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: rankStr,
            style: TextStyle(
              color: rankColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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

// 💡 ドーナツチャート描画クラス (円弧の中にテキストを入れるスタイル)
class DonutChartPainter extends CustomPainter {
  final int air;
  final int clean;
  final int swap;
  final Color airColor;
  final Color cleanColor;
  final Color swapColor;
  final Color bgColor;
  final Color textColor;
  final bool isWhite;
  final double strokeWidth;

  DonutChartPainter(
    this.air,
    this.clean,
    this.swap,
    this.airColor,
    this.cleanColor,
    this.swapColor,
    this.bgColor,
    this.textColor,
    this.isWhite, {
    this.strokeWidth = 45,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 背景のトラック
    final paintBg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paintBg);

    int total = air + clean + swap;
    if (total == 0) return;

    double startAngle = -math.pi / 2;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawSegment(int value, Color color, String label) {
      if (value <= 0) return;
      double sweepAngle = (value / total) * 2 * math.pi;

      final Rect rect = Rect.fromCircle(center: center, radius: radius);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = strokeWidth;

      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = strokeWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(rect, startAngle, sweepAngle, false, shadowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      // 💡 円弧の「中心(線上)」にパーセンテージを描画
      // 割合が小さすぎる(例: 5%以下)場合は、文字がはみ出すので描画しない
      int percent = ((value / total) * 100).round();
      if (percent > 5) {
        double midAngle = startAngle + sweepAngle / 2;
        // 文字を書くための座標（円の線上）
        double tx = center.dx + radius * math.cos(midAngle);
        double ty = center.dy + radius * math.sin(midAngle);

        textPainter.text = TextSpan(
          text: "$percent%",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
            ],
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(tx - textPainter.width / 2, ty - textPainter.height / 2),
        );
      }

      startAngle += sweepAngle;
    }

    drawSegment(air, airColor, "エアー");
    drawSegment(clean, cleanColor, "清掃");
    drawSegment(swap, swapColor, "交換");
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
