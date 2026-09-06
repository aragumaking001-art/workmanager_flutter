import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../widgets/app_background_wrapper.dart';

class SeatingChartTab extends StatefulWidget {
  const SeatingChartTab({super.key});

  @override
  State<SeatingChartTab> createState() => _SeatingChartTabState();
}

class _SeatingChartTabState extends State<SeatingChartTab> {
  Timer? _timer;
  Timer? _pollTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 💡 画面表示直後にも最新の稼働データを取得
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });

    // 💡 作業経過時間の毎秒カウントアップ
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    // 💡 30秒ごとに稼働状況データを定期ポーリング
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await Provider.of<DataProvider>(context, listen: false).fetchActiveWorkersOnly();
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isWhite = data.displayMode == DisplayMode.pureWhite;
    final workers = data.activeWorkers;

    final airWorkers = workers.where((w) => w.inferredTask == "エアー").toList();
    final cleanWorkers = workers.where((w) => w.inferredTask == "清掃").toList();
    final swapWorkers = workers.where((w) => w.inferredTask == "筐体交換").toList();

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: data.mainTextColor, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.people_alt,
                    size: 32,
                    color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "現在の稼働状況 (${workers.length}名)",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: data.mainTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (workers.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "現在稼働中の作業者はいません",
                    style: TextStyle(
                      fontSize: 20,
                      color: data.subTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildColumn(
                              "エアー",
                              airWorkers,
                              isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF),
                              Icons.air,
                              data,
                              isWhite,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildColumn(
                              "筐体交換",
                              swapWorkers,
                              isWhite ? Colors.amber.shade800 : Colors.amber,
                              Icons.swap_horiz,
                              data,
                              isWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildColumn(
                        "通常清掃",
                        cleanWorkers,
                        isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC),
                        Icons.cleaning_services,
                        data,
                        isWhite,
                        isGrid: true,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _buildColumn(String title, List<ActiveWorker> colWorkers, Color headerColor, IconData headerIcon, DataProvider data, bool isWhite, {bool isGrid = false}) {
    return Container(
      decoration: BoxDecoration(
        color: data.currentCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isWhite
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: headerColor.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  "$title (${colWorkers.length}名)",
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: colWorkers.isEmpty
                ? Center(
                    child: Text(
                      "稼働なし",
                      style: TextStyle(
                        color: data.subTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : (isGrid
                    ? GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 74,
                        ),
                        itemCount: colWorkers.length,
                        itemBuilder: (context, index) {
                          return _buildWorkerCard(colWorkers[index], data, isWhite);
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: colWorkers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildWorkerCard(colWorkers[index], data, isWhite);
                        },
                      )),
          ),
        ],
      ),
    );
  }

  Duration _calculateEffectiveWorkTime(DateTime start, DateTime end) {
    Duration totalElapsed = end.difference(start);
    Duration breakDurationToSubtract = Duration.zero;

    // 休憩時間帯の定義 (開始時, 開始分, 終了時, 終了分)
    final breakTimes = [
      (startHour: 11, startMinute: 55, endHour: 12, endMinute: 45), // お昼休憩
      (startHour: 15, startMinute: 0, endHour: 15, endMinute: 10),  // 午後の休憩
      (startHour: 18, startMinute: 30, endHour: 18, endMinute: 40), // 夕方の休憩
    ];

    // 日付またぎも考慮し、startの日からendの日までループ
    DateTime startDay = DateTime(start.year, start.month, start.day);
    DateTime endDay = DateTime(end.year, end.month, end.day);
    
    for (DateTime day = startDay; !day.isAfter(endDay); day = day.add(const Duration(days: 1))) {
      for (var b in breakTimes) {
        DateTime breakStart = DateTime(day.year, day.month, day.day, b.startHour, b.startMinute);
        DateTime breakEnd = DateTime(day.year, day.month, day.day, b.endHour, b.endMinute);

        DateTime overlapStart = start.isAfter(breakStart) ? start : breakStart;
        DateTime overlapEnd = end.isBefore(breakEnd) ? end : breakEnd;

        // 稼働時間と休憩時間が重なっている場合は差し引く
        if (overlapStart.isBefore(overlapEnd)) {
          breakDurationToSubtract += overlapEnd.difference(overlapStart);
        }
      }
    }

    return totalElapsed - breakDurationToSubtract;
  }

  Widget _buildWorkerCard(ActiveWorker worker, DataProvider data, bool isWhite) {
    Duration elapsed;
    if (worker.isPaused && worker.pausedAt != null) {
      elapsed = _calculateEffectiveWorkTime(worker.startTime, worker.pausedAt!);
    } else {
      final now = DateTime.now();
      elapsed = _calculateEffectiveWorkTime(worker.startTime, now);
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (worker.isPaused) {
      statusColor = isWhite ? Colors.orange.shade700 : Colors.orangeAccent;
      statusText = "休憩中";
      statusIcon = Icons.coffee;
    } else {
      statusText = "${worker.inferredTask}中";
      if (worker.inferredTask == "エアー") {
        statusColor = isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF);
        statusIcon = Icons.air;
      } else if (worker.inferredTask == "筐体交換") {
        statusColor = isWhite ? Colors.amber.shade800 : Colors.amber;
        statusIcon = Icons.swap_horiz;
      } else {
        statusColor = isWhite ? const Color(0xFF008855) : const Color(0xFF00FFCC);
        statusIcon = Icons.cleaning_services;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: data.currentBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    worker.workerName,
                    style: TextStyle(
                      color: data.mainTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: data.subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "経過: ${_formatDuration(elapsed)}",
                        style: TextStyle(
                          color: worker.isPaused ? data.subTextColor : statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
    );
  }
}
