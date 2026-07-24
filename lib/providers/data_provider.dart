import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// --- データ構造の定義 ---

// 💡 個人の能力値を計算するクラス
class WorkerStats {
  final String id;
  String name = "";
  int air = 0;
  int clean = 0;
  int swap = 0;
  int toClean = 0;
  int toSwap = 0;
  double workMinutes = 0;
  double stdWorkMinutes = 0;
  double earnedPoints = 0;
  Set<String> modelsHandled = {};

  WorkerStats(this.id, this.name);

  int get totalFinished => air + clean + swap;
  int get uniqueModels => modelsHandled.length;

  double get speedScore {
    if (workMinutes <= 0) return 0.0;
    double ratio = stdWorkMinutes / workMinutes;
    return (ratio / 1.5).clamp(0.0, 1.0);
  }

  double get qualityScore {
    int hAir = air + toClean;
    int hClean = clean + toSwap;
    int hSwap = swap;
    int totalHandled = hAir + hClean + hSwap;

    if (totalHandled == 0) return 0.0;

    double airScore = 0.0;
    if (hAir > 0) {
      double rate = air / hAir;
      if (rate >= 0.40) {
        airScore = 1.0;
      } else if (rate >= 0.30) {
        airScore = 0.75 + ((rate - 0.30) / 0.10) * 0.25;
      } else {
        airScore = (rate / 0.30) * 0.75;
      }
    }

    double cleanScore = 0.0;
    if (hClean > 0) {
      double rate = clean / hClean;
      if (rate >= 1.0) {
        cleanScore = 1.0;
      } else if (rate >= 0.95) {
        cleanScore = 0.75 + ((rate - 0.95) / 0.05) * 0.25;
      } else {
        cleanScore = (rate / 0.95) * 0.75;
      }
    }

    double swapScore = hSwap > 0 ? 1.0 : 0.0;

    double finalScore =
        ((airScore * hAir) + (cleanScore * hClean) + (swapScore * hSwap)) /
        totalHandled;
    return finalScore.clamp(0.0, 1.0);
  }

  double get techScore => (uniqueModels / 50.0).clamp(0.0, 1.0);
  double get staminaScore => (workMinutes / (60 * 100)).clamp(0.0, 1.0);
  double get contributionScore => (earnedPoints / 10000.0).clamp(0.0, 1.0);

  int get level => (earnedPoints / 100).floor() + 1;
  int get currentExp => (earnedPoints % 100).toInt();
  int get nextExp => 100 - currentExp;
  double get expProgress => currentExp / 100.0;

  String get title {
    if (totalFinished < 1000) return "新人作業員";
    if (speedScore >= 0.8 && qualityScore >= 0.8) return "神速の仕事人";
    if (speedScore >= 0.8) return "音速の清掃者";
    if (qualityScore >= 0.9) return "精密機械";
    if (techScore >= 0.8) return "百戦錬磨の匠";
    if (contributionScore >= 0.8) return "センターの柱";
    if (level > 50) return "4Fの守護神";
    return "ベテラン作業員";
  }
}

class MakerDetails {
  final String name;
  String abbr = "";
  int air = 0;
  int clean = 0;
  int swap = 0;
  int toClean = 0;
  int toSwap = 0;
  double workMinutes = 0;

  double airWorkMinutes = 0;
  double cleanWorkMinutes = 0;
  double swapWorkMinutes = 0;

  MakerDetails(this.name);

  int get totalFinished => air + clean + swap;
  double get airRate => (air + toClean) > 0 ? (air / (air + toClean) * 100) : 0;
  double get swapRate => (air + clean) > 0 ? (toSwap / (air + clean) * 100) : 0;
}

class ModelSummary {
  final String name;
  String maker = "";
  int sortId = 0;
  int air = 0;
  int clean = 0;
  int swap = 0;
  int toClean = 0;
  int toSwap = 0;
  double workMinutes = 0;
  double stdAir = 0.0;
  double stdClean = 0.0;
  double stdSwap = 0.0;

  double airWorkMinutes = 0;
  double cleanWorkMinutes = 0;
  double swapWorkMinutes = 0;

  Map<String, MakerDetails> makerDetailsMap = {};

  ModelSummary(this.name);

  int get totalFinished => air + clean + swap;

  double get airSpeed => airWorkMinutes > 0 ? (air / (airWorkMinutes / 60)) : 0;
  double get cleanSpeed =>
      cleanWorkMinutes > 0 ? (clean / (cleanWorkMinutes / 60)) : 0;
  double get swapSpeed =>
      swapWorkMinutes > 0 ? (swap / (swapWorkMinutes / 60)) : 0;

  double get airRate => (air + toClean) > 0 ? (air / (air + toClean) * 100) : 0;
  double get swapRate => (air + clean) > 0 ? (toSwap / (air + clean) * 100) : 0;
}

class WorkerRank {
  final String id;
  String name = "";
  double points = 0;
  bool isLucky = false;
  WorkerRank(this.id);
}

class DataProvider extends ChangeNotifier {
  Map<String, ModelSummary> _modelDataMap = {};
  List<WorkerRank> _workerRanks = [];
  List<WorkerRank> _airWorkerRanks = [];
  List<WorkerRank> _swapWorkerRanks = [];
  List<ModelSummary> _todayModels = [];

  Map<String, WorkerStats> _workerStatsMap = {};

  bool _isLoading = false;
  String? _lastTimestamp;
  Timer? _refreshTimer;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 💡 【修正】アプリ起動時は「Offline（通信前）」状態からスタートさせる
  bool isOnline = false;

  DateTime? _rankStartDate = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - 1),
  );
  DateTime? _rankEndDate = DateTime.now()
      .subtract(Duration(days: DateTime.now().weekday - 1))
      .add(const Duration(days: 5));

  bool isSummaryCumulative = true;
  DateTime summaryStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime summaryEndDate = DateTime.now();

  void setSummaryMode(bool isCumul, {DateTime? start, DateTime? end}) {
    isSummaryCumulative = isCumul;
    if (start != null) summaryStartDate = start;
    if (end != null) summaryEndDate = end;
    fetchAndAnalyze(silent: false);
  }

  Map<String, ModelSummary> get modelDataMap => _modelDataMap;
  List<WorkerRank> get workerRanks => _workerRanks;
  List<WorkerRank> get airWorkerRanks => _airWorkerRanks;
  List<WorkerRank> get swapWorkerRanks => _swapWorkerRanks;
  List<ModelSummary> get todayModels => _todayModels;
  Map<String, WorkerStats> get workerStatsMap => _workerStatsMap;
  bool get isLoading => _isLoading;

  void setRankingPeriod(DateTime start, DateTime end) {
    _rankStartDate = start;
    _rankEndDate = end;
    fetchAndAnalyze(silent: false);
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkForUpdates();
    });
  }

  int airTarget = 600;
  int cleanTarget = 1200;
  int swapTarget = 50;

  Future<void> updateDailyTarget(String type, int newValue) async {
    try {
      // 💡 【重要】通信準備も try の内側に入れる
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );

      await conn.connect();
      String column = "";
      if (type == "エアー")
        column = "air_target";
      else if (type == "清掃")
        column = "clean_target";
      else if (type == "交換" || type == "筐体交換")
        column = "swap_target";

      if (column.isNotEmpty) {
        await conn.execute(
          'UPDATE daily_targets SET $column = :val WHERE id = 1',
          {"val": newValue},
        );
        await conn.execute(
          'UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1',
        );

        if (type == "エアー")
          airTarget = newValue;
        else if (type == "清掃")
          cleanTarget = newValue;
        else if (type == "交換" || type == "筐体交換")
          swapTarget = newValue;

        notifyListeners();
      }
      await conn.close();

      // 成功したらオンライン判定
      if (!isOnline) {
        isOnline = true;
        notifyListeners();
      }
    } catch (e) {
      print("目標値更新エラー: $e");
      // エラー時は確実にオフライン判定
      if (isOnline) {
        isOnline = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateFullLogData(
    int logId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // 💡 【重要】通信準備も try の内側に入れる
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );

      await conn.connect();
      List<String> setClauses = [];
      Map<String, dynamic> params = {"id": logId};
      updates.forEach((key, value) {
        setClauses.add("$key = :$key");
        params[key] = value;
      });

      String sql =
          "UPDATE unit_cleaning_logs SET ${setClauses.join(', ')}, edit_count = edit_count + 1 WHERE id = :id";
      await conn.execute(sql, params);
      await conn.execute(
        'UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1',
      );
      await conn.close();

      if (!isOnline) {
        isOnline = true;
        notifyListeners();
      }

      fetchAndAnalyze(silent: true);
      return true;
    } catch (e) {
      print("データ一括修正エラー: $e");
      if (isOnline) {
        isOnline = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> checkForUpdates() async {
    try {
      // 💡 【重要】通信準備も try の内側に入れる
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );

      await conn.connect();
      var result = await conn.execute(
        'SELECT last_updated FROM data_update_tracker WHERE id = 1',
      );
      await conn.close();

      if (result.rows.isNotEmpty) {
        String newTimestamp = result.rows.first.assoc()['last_updated'] ?? "";
        if (_lastTimestamp != newTimestamp) {
          _lastTimestamp = newTimestamp;
          fetchAndAnalyze(silent: true);
        }
      }

      _errorMessage = null;

      if (!isOnline) {
        isOnline = true;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = "自動更新チェック失敗: $e";
      if (isOnline) {
        isOnline = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchAndAnalyze({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // 💡 【重要】一番最初に走るメインのデータ取得。ここも try の中に入れる！
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );

      await conn.connect();
      await conn.execute("SET time_zone = '+09:00'");

      // --- 🎯 目標値の取得 ---
      try {
        var targetRes = await conn.execute(
          'SELECT air_target, clean_target, swap_target FROM daily_targets WHERE id = 1',
        );
        if (targetRes.rows.isNotEmpty) {
          var data = targetRes.rows.first.assoc();
          airTarget = int.tryParse(data['air_target'] ?? '600') ?? 600;
          cleanTarget = int.tryParse(data['clean_target'] ?? '1200') ?? 1200;
          swapTarget = int.tryParse(data['swap_target'] ?? '50') ?? 50;
        }
      } catch (e) {}

      // --- 📊 1. 全体集計 ---
      try {
        String summaryDateFilter = "";
        if (!isSummaryCumulative) {
          String sHyphen = DateFormat('yyyy-MM-dd').format(summaryStartDate);
          String eHyphen = DateFormat(
            'yyyy-MM-dd 23:59:59',
          ).format(summaryEndDate);
          String sSlash = DateFormat('yyyy/MM/dd').format(summaryStartDate);
          String eSlash = DateFormat(
            'yyyy/MM/dd 23:59:59',
          ).format(summaryEndDate);

          summaryDateFilter =
              '''
            WHERE (l.work_date >= '$sHyphen' AND l.work_date <= '$eHyphen')
               OR (l.work_date >= '$sSlash' AND l.work_date <= '$eSlash')
          ''';
        }

        var summaryResults = await conn.execute('''
          SELECT 
            DATE_FORMAT(l.work_date, '%Y/%m/%d') AS w_date, 
            l.model_name, l.air_clean_qty, l.clean_qty, l.swap_qty, l.maker, l.maker_abbr, 
            l.to_clean_qty, l.to_swap_qty, l.work_minutes,
            m.std_air, m.std_clean, m.std_swap, m.sort_id 
          FROM unit_cleaning_logs l
          LEFT JOIN (
            SELECT model_name,
              MAX(CASE WHEN work_type = 'エアー清掃' THEN std_qty END) as std_air,
              MAX(CASE WHEN work_type = '清掃' THEN std_qty END) as std_clean,
              MAX(CASE WHEN work_type = '筐体交換' THEN std_qty END) as std_swap,
              MIN(CASE WHEN csv_id = '' OR csv_id = '0' THEN 9999 ELSE CAST(csv_id AS UNSIGNED) END) as sort_id 
            FROM m_models 
            GROUP BY model_name
          ) m ON l.model_name = m.model_name
          $summaryDateFilter
        ''');

        Map<String, ModelSummary> tempModelMap = {};
        for (var row in summaryResults.rows) {
          var data = row.assoc();

          String rawName = data['model_name'] ?? "不明";
          String cleanName = rawName.contains(':')
              ? rawName.split(':').last.replaceAll('}', '').trim()
              : rawName;
          var summary = tempModelMap.putIfAbsent(
            cleanName,
            () => ModelSummary(cleanName),
          );

          String rawMaker = data['maker'] ?? "不明";
          summary.maker = rawMaker;
          var mDetails = summary.makerDetailsMap.putIfAbsent(
            rawMaker,
            () => MakerDetails(rawMaker),
          );
          mDetails.abbr = data['maker_abbr'] ?? "";

          int a = double.tryParse(data['air_clean_qty'] ?? '0')?.toInt() ?? 0;
          int c = double.tryParse(data['clean_qty'] ?? '0')?.toInt() ?? 0;
          int s = double.tryParse(data['swap_qty'] ?? '0')?.toInt() ?? 0;
          int tc = double.tryParse(data['to_clean_qty'] ?? '0')?.toInt() ?? 0;
          int ts = double.tryParse(data['to_swap_qty'] ?? '0')?.toInt() ?? 0;
          double wm = double.tryParse(data['work_minutes'] ?? '0') ?? 0;

          summary.air += a;
          summary.clean += c;
          summary.swap += s;
          summary.toClean += tc;
          summary.toSwap += ts;
          summary.workMinutes += wm;
          mDetails.air += a;
          mDetails.clean += c;
          mDetails.swap += s;
          mDetails.toClean += tc;
          mDetails.toSwap += ts;
          mDetails.workMinutes += wm;

          if (a > 0) {
            summary.airWorkMinutes += wm;
            mDetails.airWorkMinutes += wm;
          }
          if (c > 0) {
            summary.cleanWorkMinutes += wm;
            mDetails.cleanWorkMinutes += wm;
          }
          if (s > 0) {
            summary.swapWorkMinutes += wm;
            mDetails.swapWorkMinutes += wm;
          }

          summary.stdAir = double.tryParse(data['std_air'] ?? '10.0') ?? 10.0;
          summary.stdClean =
              double.tryParse(data['std_clean'] ?? '10.0') ?? 10.0;
          summary.stdSwap = double.tryParse(data['std_swap'] ?? '10.0') ?? 10.0;
          summary.sortId = int.tryParse(data['sort_id'] ?? '9999') ?? 9999;
        }
        _modelDataMap = tempModelMap;
      } catch (e) {}

      // --- 🏆 2. ランキング集計 ---
      try {
        String dateFilter = "";
        if (_rankStartDate != null && _rankEndDate != null) {
          String sHyphen = DateFormat('yyyy-MM-dd').format(_rankStartDate!);
          String eHyphen = DateFormat(
            'yyyy-MM-dd 23:59:59',
          ).format(_rankEndDate!);
          String sSlash = DateFormat('yyyy/MM/dd').format(_rankStartDate!);
          String eSlash = DateFormat(
            'yyyy/MM/dd 23:59:59',
          ).format(_rankEndDate!);

          dateFilter =
              '''
            WHERE (l.work_date >= '$sHyphen' AND l.work_date <= '$eHyphen')
               OR (l.work_date >= '$sSlash' AND l.work_date <= '$eSlash')
          ''';
        }

        var rankResults = await conn.execute('''
          SELECT l.clean_qty, l.air_clean_qty, l.swap_qty, m.std_clean, m.std_air, m.std_swap, l.worker_id, l.lucky_flag, mem.worker_name 
          FROM unit_cleaning_logs l
          LEFT JOIN (
            SELECT model_name, MAX(CASE WHEN work_type = '清掃' THEN std_qty END) as std_clean, MAX(CASE WHEN work_type = 'エアー清掃' THEN std_qty END) as std_air, MAX(CASE WHEN work_type = '筐体交換' THEN std_qty END) as std_swap FROM m_models GROUP BY model_name
          ) m ON l.model_name = m.model_name
          LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
          $dateFilter
        ''');

        Map<String, WorkerRank> tempCleanMap = {};
        Map<String, WorkerRank> tempAirMap = {};
        Map<String, WorkerRank> tempSwapMap = {};

        for (var row in rankResults.rows) {
          var data = row.assoc();
          String workerId = data['worker_id'] ?? "unknown";
          if (workerId == "unknown" || workerId.isEmpty) continue;

          String wName = data['worker_name'] ?? "";
          String luckyFlag = data['lucky_flag'] ?? "";
          double bonus = luckyFlag.contains("Lucky") ? 1.2 : 1.0;

          int cQty = double.tryParse(data['clean_qty'] ?? '0')?.toInt() ?? 0;
          if (cQty > 0) {
            var r = tempCleanMap.putIfAbsent(
              workerId,
              () => WorkerRank(workerId)..name = wName,
            );
            double std = double.tryParse(data['std_clean'] ?? '10.0') ?? 10.0;
            r.points += (cQty * (60.0 / std) * bonus);
            if (bonus > 1.0) r.isLucky = true;
          }

          int aQty =
              double.tryParse(data['air_clean_qty'] ?? '0')?.toInt() ?? 0;
          if (aQty > 0) {
            var r = tempAirMap.putIfAbsent(
              workerId,
              () => WorkerRank(workerId)..name = wName,
            );
            double std = double.tryParse(data['std_air'] ?? '10.0') ?? 10.0;
            r.points += (aQty * (60.0 / std) * bonus);
            if (bonus > 1.0) r.isLucky = true;
          }

          int sQty = double.tryParse(data['swap_qty'] ?? '0')?.toInt() ?? 0;
          if (sQty > 0) {
            var r = tempSwapMap.putIfAbsent(
              workerId,
              () => WorkerRank(workerId)..name = wName,
            );
            double std = double.tryParse(data['std_swap'] ?? '10.0') ?? 10.0;
            r.points += (sQty * (60.0 / std) * bonus);
            if (bonus > 1.0) r.isLucky = true;
          }
        }

        _workerRanks = tempCleanMap.values.toList()
          ..sort((a, b) => b.points.compareTo(a.points));
        _airWorkerRanks = tempAirMap.values.toList()
          ..sort((a, b) => b.points.compareTo(a.points));
        _swapWorkerRanks = tempSwapMap.values.toList()
          ..sort((a, b) => b.points.compareTo(a.points));
      } catch (e) {}

      // --- 📅 3. 本日実績集計 ---
      try {
        DateTime now = DateTime.now();
        String todayHyphen = DateFormat('yyyy-MM-dd').format(now);
        String todaySlash = DateFormat('yyyy/MM/dd').format(now);

        var todayResults = await conn.execute('''
          SELECT l.model_name, CAST(SUM(l.clean_qty) AS SIGNED) AS total_clean, MAX(IFNULL(l.maker_abbr, '')) AS maker_abbr, CAST(SUM(l.air_clean_qty) AS SIGNED) AS total_air, CAST(SUM(l.swap_qty) AS SIGNED) AS total_swap, MIN(l.id) AS first_id
          FROM unit_cleaning_logs l
          WHERE (l.work_date LIKE '$todayHyphen%' OR l.work_date LIKE '$todaySlash%')
          GROUP BY l.model_name, l.maker_abbr
        ''');

        List<ModelSummary> tempToday = [];
        for (var row in todayResults.rows) {
          var data = row.assoc();
          String rawName = data['model_name'] ?? "不明";
          String cleanName = rawName.contains(':')
              ? rawName.split(':').last.replaceAll('}', '').trim()
              : rawName;
          var m = ModelSummary(cleanName);

          m.clean = double.tryParse(data['total_clean'] ?? '0')?.toInt() ?? 0;
          m.maker = data['maker_abbr'] ?? "";
          m.air = double.tryParse(data['total_air'] ?? '0')?.toInt() ?? 0;
          m.swap = double.tryParse(data['total_swap'] ?? '0')?.toInt() ?? 0;
          m.sortId =
              int.tryParse(data['first_id'] ?? '9999999') ??
              9999999; // 💡 登録順(最小ID)を保持

          if (m.clean > 0 || m.air > 0 || m.swap > 0) tempToday.add(m);
        }

        // 💡 最初に見つかったログID（登録順）で昇順ソートする
        tempToday.sort((a, b) => a.sortId.compareTo(b.sortId));

        _todayModels = tempToday;
      } catch (e) {}

      // --- 🎮 4. 個人別RPGステータス集計 ---
      try {
        var wsResults = await conn.execute('''
          SELECT 
            l.worker_id, mem.worker_name, l.model_name, 
            l.air_clean_qty, l.clean_qty, l.swap_qty, 
            l.to_clean_qty, l.to_swap_qty, 
            l.work_minutes, l.lucky_flag,
            m.std_air, m.std_clean, m.std_swap
          FROM unit_cleaning_logs l
          LEFT JOIN m_members mem ON l.worker_id = mem.worker_id
          LEFT JOIN (
            SELECT model_name, 
              MAX(CASE WHEN work_type = 'エアー清掃' THEN std_qty END) as std_air,
              MAX(CASE WHEN work_type = '清掃' THEN std_qty END) as std_clean,
              MAX(CASE WHEN work_type = '筐体交換' THEN std_qty END) as std_swap 
            FROM m_models GROUP BY model_name
          ) m ON l.model_name = m.model_name
          WHERE l.worker_id IS NOT NULL AND l.worker_id != ''
        ''');

        Map<String, WorkerStats> tempWsMap = {};
        for (var row in wsResults.rows) {
          var data = row.assoc();
          String wId = data['worker_id']!;
          String wName = data['worker_name'] ?? wId;
          var ws = tempWsMap.putIfAbsent(wId, () => WorkerStats(wId, wName));

          int a = double.tryParse(data['air_clean_qty'] ?? '0')?.toInt() ?? 0;
          int c = double.tryParse(data['clean_qty'] ?? '0')?.toInt() ?? 0;
          int s = double.tryParse(data['swap_qty'] ?? '0')?.toInt() ?? 0;
          int ta = double.tryParse(data['to_clean_qty'] ?? '0')?.toInt() ?? 0;
          int ts = double.tryParse(data['to_swap_qty'] ?? '0')?.toInt() ?? 0;
          double wm = double.tryParse(data['work_minutes'] ?? '0') ?? 0;

          double stdAir = double.tryParse(data['std_air'] ?? '10.0') ?? 10.0;
          double stdClean =
              double.tryParse(data['std_clean'] ?? '10.0') ?? 10.0;
          double stdSwap = double.tryParse(data['std_swap'] ?? '10.0') ?? 10.0;

          String luckyFlag = data['lucky_flag'] ?? "";
          double bonus = luckyFlag.contains("Lucky") ? 1.2 : 1.0;

          ws.air += a;
          ws.clean += c;
          ws.swap += s;
          ws.toClean += ta;
          ws.toSwap += ts;
          ws.workMinutes += wm;

          if (a > 0) ws.stdWorkMinutes += a * (60.0 / stdAir);
          if (c > 0) ws.stdWorkMinutes += c * (60.0 / stdClean);
          if (s > 0) ws.stdWorkMinutes += s * (60.0 / stdSwap);

          if (a > 0) ws.earnedPoints += (a * (60.0 / stdAir) * bonus);
          if (c > 0) ws.earnedPoints += (c * (60.0 / stdClean) * bonus);
          if (s > 0) ws.earnedPoints += (s * (60.0 / stdSwap) * bonus);

          String model = data['model_name'] ?? "";
          if (model.isNotEmpty) ws.modelsHandled.add(model);
        }
        _workerStatsMap = tempWsMap;
      } catch (e) {
        print("🚨 RPGステータス計算エラー: $e");
      }

      _isLoading = false;
      _errorMessage = null;

      // 💡 通信が最後まで完了したのでオンライン判定
      isOnline = true;

      notifyListeners();
      await conn.close();
    } catch (e) {
      _isLoading = false;

      // 💡 DB接続失敗時は確実にオフライン判定にし、エラーメッセージをセット
      if (isOnline) {
        isOnline = false;
      }
      _errorMessage = "【DB接続エラー】\n$e";

      notifyListeners();
      print("🚨 致命的エラー詳細: $e");
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<String?> exportCsvToDatabasePC() async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );
      await conn.connect();

      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String fileName = 'work_logs_$timestamp.csv';
      String outPath = 'C:/Users/yamada/Desktop/$fileName';

      // カラム名を動的に取得してヘッダー行を作成
      var res = await conn.execute('SELECT * FROM unit_cleaning_logs LIMIT 1');
      String headerRow = "*";
      String dataRow = "*";
      if (res.rows.isNotEmpty) {
        List<String> columns = res.rows.first.assoc().keys.toList();
        headerRow = columns.map((c) => "'$c'").join(", ");
        dataRow = columns.map((c) => "IFNULL($c, '')").join(", ");
      } else {
        // データがない場合
        return null;
      }

      String sql =
          '''
        SELECT $headerRow
        UNION ALL
        SELECT $dataRow
        INTO OUTFILE '$outPath'
        CHARACTER SET cp932
        FIELDS TERMINATED BY ',' 
        ENCLOSED BY '"'
        LINES TERMINATED BY '\\n'
        FROM unit_cleaning_logs
      ''';

      await conn.execute(sql);
      await conn.close();
      return outPath;
    } catch (e) {
      print("CSV出力エラー: $e");
      return null;
    }
  }
}
