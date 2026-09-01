import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// --- データ構造の定義 ---

// 💡 機種ごとの作業内訳を記録するクラス
class WorkerModelCount {
  final String modelName;
  int air = 0;
  int clean = 0;
  int swap = 0;
  WorkerModelCount(this.modelName);
  int get total => air + clean + swap;
}

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
  String aiReport = "";
  String aiTone = "標準";
  Map<String, WorkerModelCount> modelCounts = {};

  WorkerStats(this.id, this.name);

  int get totalFinished => air + clean + swap;
  int get uniqueModels => modelsHandled.length;

  double get speedScore {
    if (workMinutes <= 0) return 0.0;
    double ratio = stdWorkMinutes / workMinutes;
    return (ratio / 1.2).clamp(0.0, 1.0); // 1.2倍でA(100%)
  }

  double get qualityScore {
    int hAir = air + toClean;
    int hClean = clean + toSwap;
    // 💡 筐体交換（swap）は不良率の概念がないため品質スコアの評価から除外する
    int totalHandled = hAir + hClean;

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

    double finalScore = ((airScore * hAir) + (cleanScore * hClean)) / totalHandled;
    // 💡 全体的にワンランクアップするように1.25倍（0.8で満点）してクランプ
    return (finalScore * 1.25).clamp(0.0, 1.0);
  }

  // 💡 ベーススコアは Aランクの基準（1.0）でクランプする（レーダーの図形が枠を突き破らないように）
  double get techScore => (uniqueModels / 25.0).clamp(0.0, 1.0); // A=25機種 (C=15機種)
  double get staminaScore => (workMinutes / (60 * 2000.0)).clamp(0.0, 1.0); // A=2000時間
  double get contributionScore => (earnedPoints / 200000.0).clamp(0.0, 1.0); // A=20万pt

  // 💡 レベルアップに必要なポイントを2000ptに緩和（サクサク上がりやすくする）
  int get level => (earnedPoints / 2000).floor() + 1;
  int get currentExp => (earnedPoints % 2000).toInt();
  int get nextExp => 2000 - currentExp;
  double get expProgress => currentExp / 2000.0;

  String get title {
    // 1. 最上位の伝説・神クラス
    if (level >= 150 || earnedPoints >= 500000) return "和気センターの伝説";
    if (speedScore >= 1.5 && qualityScore >= 0.99) return "神速の仕事人";
    if (qualityScore >= 0.99 && earnedPoints >= 200000) return "絶対無ミスの精密機械";

    // 2. スペシャリスト
    if (level >= 100) return "4Fの守護神";
    if (speedScore >= 1.2 && qualityScore >= 0.9) return "熟練のスピードスター";
    if (techScore >= 25.0 / 30.0) return "百戦錬磨の匠";
    if (contributionScore >= 1.0) return "センターの柱"; 
    
    // 3. 成長度合い
    if (level >= 50) return "フロアマスター";
    if (earnedPoints >= 100000) return "ベテラン作業員";
    if (earnedPoints >= 30000) return "一人前の仕事人";
    if (earnedPoints >= 10000) return "期待のホープ";
    
    // 4. 初期
    return "新人作業員";
  }

  // ---------------------------------------------
  // 💡 レーダーチャート用の SS～F ランク算出処理
  // ---------------------------------------------
  String _calcRank(double ratio, {double? sRatio, double? ssRatio}) {
    if (ssRatio != null && ratio >= ssRatio) return "SS";
    if (sRatio != null && ratio >= sRatio) return "S";
    if (ratio >= 1.0) return "A";
    if (ratio >= 0.8) return "B";
    if (ratio >= 0.6) return "C";
    if (ratio >= 0.4) return "D";
    if (ratio >= 0.2) return "E";
    return "F";
  }

  String get speedRank {
    if (workMinutes <= 0) return "F";
    double ratio = stdWorkMinutes / workMinutes;
    // 基準1.2倍でA(1.0)、1.5倍でS、2.0倍でSS
    return _calcRank(ratio / 1.2, sRatio: 1.5 / 1.2, ssRatio: 2.0 / 1.2);
  }

  String get qualityRank {
    // 累積作業台数が加味される (ワンランクアップのため、ベーススコアは甘くなっている)
    if (qualityScore >= 0.99 && totalFinished >= 50000) return "SS"; // 50,000台 (約3年規模)
    if (qualityScore >= 0.99 && totalFinished >= 20000) return "S";  // 20,000台 (約1年規模)
    return _calcRank(qualityScore);
  }

  String get techRank {
    // 機種マスター (A=25機種, C=15機種, S=28機種, SS=30機種)
    return _calcRank(uniqueModels / 25.0, sRatio: 28.0 / 25.0, ssRatio: 30.0 / 25.0);
  }

  String get staminaRank {
    // 継続力 (A=2000時間, S=4000時間, SS=6000時間)
    return _calcRank((workMinutes / 60) / 2000.0, sRatio: 4000.0 / 2000.0, ssRatio: 6000.0 / 2000.0);
  }

  String get contributionRank {
    // 総合実績 (A=20万pt, S=40万pt, SS=60万pt)
    return _calcRank(earnedPoints / 200000.0, sRatio: 400000.0 / 200000.0, ssRatio: 600000.0 / 200000.0);
  }

  // indexに応じたランクを取得 (0: Speed, 1: Quality, 2: Tech, 3: Stamina, 4: Contribution)
  String getRankByIndex(int index) {
    switch (index) {
      case 0: return speedRank;
      case 1: return qualityRank;
      case 2: return techRank;
      case 3: return staminaRank;
      case 4: return contributionRank;
      default: return "F";
    }
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



class ScheduleItem {
  final DateTime targetDate;
  final String modelName;
  final String makerName;
  final int planCount;
  final int actualCount;
  final int sortId;

  ScheduleItem({
    required this.targetDate,
    required this.modelName,
    required this.makerName,
    required this.planCount,
    required this.actualCount,
    required this.sortId,
  });
}

class ModelScheduleProgress {
  final String modelName;
  final String makerName;
  int airCount;
  int cleanCount;
  int swapCount;
  int totalCount;

  ModelScheduleProgress({
    required this.modelName,
    required this.makerName,
    this.airCount = 0,
    this.cleanCount = 0,
    this.swapCount = 0,
    this.totalCount = 0,
  });
}

class WorkerRank {
  final String id;
  String name = "";
  double points = 0;
  bool isLucky = false;
  WorkerRank(this.id);
}

class ActiveWorker {
  final String workerId;
  final String workerName;
  final DateTime startTime;
  final bool isPaused;
  final DateTime? pausedAt;
  final String inferredTask;

  ActiveWorker({
    required this.workerId,
    required this.workerName,
    required this.startTime,
    required this.isPaused,
    this.pausedAt,
    this.inferredTask = "清掃",
  });
}

// ⭐ 画面の視認性と光反射を完全コントロールする表示トーン定義
enum DisplayMode {
  pureWhite,  // 🤍 極限反射防止：クリア・ライトパーリーホワイト（蛍光灯の映り込みを完全消滅！）
  middleGray, // ☀ 反射低減：マットミドルグレー
  pureDark,   // 🌙 従来のオリジナルダーク（純黒）
}

// ⭐ 背景に白を選んでも見えにくくならない文字色の最適・強制調整定義
enum TextTone {
  auto,       // 🤖 自動調整（背景白→ディープブラック文字 / 背景ダーク→純白文字）
  deepBlack,  // ⚫ 漆黒ジェットブラック（白背景で最高のくっきり感！）
  navySlate,  // 🔵 シックなダークオックスフォードネイビー
  crispWhite, // ⚪ 従来のピュアブライトホワイト
}

class DataProvider extends ChangeNotifier {
  Map<String, ModelSummary> _modelDataMap = {};
  List<WorkerRank> _workerRanks = [];
  List<WorkerRank> _airWorkerRanks = [];
  List<WorkerRank> _swapWorkerRanks = [];
  List<ModelSummary> _todayModels = [];
  List<ScheduleItem> _scheduleList = [];
  Map<String, ModelScheduleProgress> _scheduleProgressMap = {};
  List<ActiveWorker> _activeWorkers = [];

  Map<String, WorkerStats> _workerStatsMap = {};
  
  // マスター上の全機種リスト (表示用)
  List<Map<String, String>> _masterModelsList = [];
  List<Map<String, String>> get masterModelsList => _masterModelsList;

  bool _isLoading = false;
  bool _isCheckingUpdates = false;
  String? _lastTimestamp;
  Timer? _refreshTimer;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 💡 【修正】アプリ起動時は「Offline（通信前）」状態からスタートさせる
  bool isOnline = false;

  // ⭐ タブレットのライト・蛍光灯の猛烈な反射（映り込み）を根絶する至高の白背景＆カラー可変・手動切替設計！
  DisplayMode displayMode = DisplayMode.pureWhite; // 今ご実感いただけるよう、即座に「完全反射消しホワイトモード」を標準起動設定！
  TextTone customTextTone = TextTone.auto;

  void setDisplayMode(DisplayMode mode) {
    displayMode = mode;
    notifyListeners();
  }

  void setTextTone(TextTone tone) {
    customTextTone = tone;
    notifyListeners();
  }

  bool get isAntiGlareMode => displayMode != DisplayMode.pureDark;

  void toggleAntiGlareMode() {
    if (displayMode == DisplayMode.pureWhite) {
      displayMode = DisplayMode.pureDark;
    } else {
      displayMode = DisplayMode.pureWhite;
    }
    notifyListeners();
  }

  Color get currentBgColor {
    switch (displayMode) {
      case DisplayMode.pureWhite:
        return const Color(0xFFEFF2F7); // 液晶ガラスの反射干渉をゼロに退行させ、屋外や強ライト下で無敵を誇るソフトクリアホワイト！
      case DisplayMode.middleGray:
      case DisplayMode.pureDark:
        return const Color(0xFF0F1115);
    }
  }

  Color get currentCardColor {
    switch (displayMode) {
      case DisplayMode.pureWhite:
        return Colors.white; // 光が跳ね返らない紙の上質さとクリーン感のカードパネル！
      case DisplayMode.middleGray:
      case DisplayMode.pureDark:
        return const Color(0xFF1A1C23);
    }
  }

  // ⭐ 背景（白モード/黒モード）に応じて、迷うことなく最高峰にくっきり読みやすい文字カラーへ自動統一！
  Color get mainTextColor {
    return displayMode == DisplayMode.pureWhite 
        ? const Color(0xFF0F172A) // 白モード：圧倒的に読みやすくコントラストが高いジェットブラック！
        : Colors.white;           // 黒モード：くっきり光るピュアホワイト！
  }

  Color get subTextColor {
    return displayMode == DisplayMode.pureWhite 
        ? const Color(0xFF334155) // 白モード：蛍光灯下でもしっかり読める濃いめのディープスレート！
        : Colors.white70;         // 黒モード：上品で目立ちすぎないブライトグレー！
  }

  Color get borderColor {
    return displayMode == DisplayMode.pureWhite 
        ? const Color(0xFF94A3B8) // 白モード：境界をしっかり切り分けるミディアムスチール！
        : Colors.white24;
  }

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
  List<ScheduleItem> get scheduleList => _scheduleList;
  Map<String, ModelScheduleProgress> get scheduleProgressMap => _scheduleProgressMap;
  List<ActiveWorker> get activeWorkers => _activeWorkers;
  Map<String, WorkerStats> get workerStatsMap => _workerStatsMap;
  bool get isLoading => _isLoading;

  void setRankingPeriod(DateTime start, DateTime end) {
    _rankStartDate = start;
    _rankEndDate = end;
    fetchAndAnalyze(silent: false);
  }
  int _lastCheckedDay = DateTime.now().day; // 日付またぎリセット用

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      int currentDay = DateTime.now().day;
      if (_lastCheckedDay != currentDay) {
        _lastCheckedDay = currentDay;
        // 日付が変わった瞬間（深夜0時0分0秒〜5秒以内）にリフレッシュを強制実行
        fetchAndAnalyze(silent: true);
      }
      
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

  Future<bool> deleteLogData(int logId) async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );

      await conn.connect();
      
      String sql = "DELETE FROM unit_cleaning_logs WHERE id = :id";
      await conn.execute(sql, {"id": logId});
      
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
      print("データ削除エラー: $e");
      if (isOnline) {
        isOnline = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> checkForUpdates() async {
    if (_isCheckingUpdates) return;
    _isCheckingUpdates = true;

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
    } finally {
      _isCheckingUpdates = false;
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
              MIN(sort_order) as sort_id 
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

          double stdAir = double.tryParse(data['std_air']?.toString() ?? '10.0') ?? 10.0;
          double stdClean = double.tryParse(data['std_clean']?.toString() ?? '10.0') ?? 10.0;
          double stdSwap = double.tryParse(data['std_swap']?.toString() ?? '10.0') ?? 10.0;

          if (stdAir <= 0 || stdAir.isNaN || stdAir.isInfinite) stdAir = 10.0;
          if (stdClean <= 0 || stdClean.isNaN || stdClean.isInfinite) stdClean = 10.0;
          if (stdSwap <= 0 || stdSwap.isNaN || stdSwap.isInfinite) stdSwap = 10.0;

          String luckyFlag = data['lucky_flag']?.toString() ?? "";
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
          if (model.isNotEmpty) {
            ws.modelsHandled.add(model);
            
            var mc = ws.modelCounts.putIfAbsent(model, () => WorkerModelCount(model));
            mc.air += a;
            mc.clean += c;
            mc.swap += s;
          }
        }
        _workerStatsMap = tempWsMap;
      } catch (e) {
        print("🚨 RPGステータス計算エラー: $e");
      }

      // --- 🤖 AIレポートの取得 ---
      try {
        var aiResults = await conn.execute('''
          SELECT r.worker_id, r.report_content, m.ai_tone
          FROM t_ai_reports r
          LEFT JOIN m_members m ON r.worker_id = m.worker_id
        ''');
        for (var row in aiResults.rows) {
          var data = row.assoc();
          String wId = data['worker_id'] ?? "";
          String report = data['report_content'] ?? "";
          String aiTone = data['ai_tone'] ?? "標準";
          if (wId.isNotEmpty && _workerStatsMap.containsKey(wId)) {
            _workerStatsMap[wId]!.aiReport = report;
            _workerStatsMap[wId]!.aiTone = aiTone;
          }
        }
      } catch (e) {
        print("🚨 AIレポート取得エラー: $e");
      }
      
      // --- 🎮 5. スケジュールデータ集計 ---
      try {
        var schedResults = await conn.execute('''
          SELECT s.target_date, s.model_name, s.maker_name, s.plan_count, s.actual_count, IFNULL(m.sort_order, 9999) as sort_id
          FROM t_schedules s
          LEFT JOIN (
            SELECT model_name COLLATE utf8mb4_unicode_ci as model_name,
                   maker_abbr COLLATE utf8mb4_unicode_ci as maker_name,
                   MIN(sort_order) as sort_order
            FROM m_models
            GROUP BY model_name, maker_abbr
          ) m ON s.model_name = m.model_name 
            AND (s.maker_name = m.maker_name OR (s.maker_name = '' AND (m.maker_name IS NULL OR m.maker_name = '')))
          ORDER BY sort_id ASC, s.target_date ASC
        ''');

        List<ScheduleItem> tempSchedules = [];
        for (var row in schedResults.rows) {
          var data = row.assoc();
          DateTime? tDate = DateTime.tryParse(data['target_date'] ?? '');
          if (tDate != null) {
            tempSchedules.add(ScheduleItem(
              targetDate: tDate,
              modelName: data['model_name'] ?? '不明',
              makerName: data['maker_name'] ?? '不明',
              planCount: int.tryParse(data['plan_count'] ?? '0') ?? 0,
              actualCount: int.tryParse(data['actual_count'] ?? '0') ?? 0,
              sortId: int.tryParse(data['sort_id'] ?? '999999') ?? 999999,
            ));
          }
        }
        _scheduleList = tempSchedules;
      } catch (e) {
        print("🚨 スケジュールデータ取得エラー: $e");
      }

      // --- 📊 6. スケジュール進捗データ（手動編集用）集計 ---
      try {
        var progResults = await conn.execute('''
          SELECT model_name, maker_name, air_count, clean_count, swap_count, total_count
          FROM t_model_schedules
        ''');

        Map<String, ModelScheduleProgress> tempProgressMap = {};
        for (var row in progResults.rows) {
          var data = row.assoc();
          String modelName = data['model_name'] ?? '不明';
          String makerName = data['maker_name'] ?? '不明';
          String key = "${makerName}_${modelName}";
          
          tempProgressMap[key] = ModelScheduleProgress(
            modelName: modelName,
            makerName: makerName,
            airCount: int.tryParse(data['air_count'] ?? '0') ?? 0,
            cleanCount: int.tryParse(data['clean_count'] ?? '0') ?? 0,
            swapCount: int.tryParse(data['swap_count'] ?? '0') ?? 0,
            totalCount: int.tryParse(data['total_count'] ?? '0') ?? 0,
          );
        }
        _scheduleProgressMap = tempProgressMap;
      } catch (e) {
        print("🚨 スケジュール進捗データ取得エラー: $e");
      }

      // --- 📝 7. マスターの全機種リストを取得（スケジュール未登録機種表示用） ---
      try {
        var masterResults = await conn.execute('''
          SELECT 
            model_name, 
            IFNULL(maker_abbr, '') AS maker_name, 
            MIN(sort_order) AS sort_id,
            MAX(category) AS category
          FROM m_models
          GROUP BY model_name, maker_name
          ORDER BY sort_id ASC
        ''');

        List<Map<String, String>> tempMasterModels = [];
        for (var row in masterResults.rows) {
          var data = row.assoc();
          tempMasterModels.add({
            'model_name': data['model_name']?.toString() ?? '',
            'maker_name': data['maker_name']?.toString() ?? '',
            'csv_id': data['sort_id']?.toString() ?? '9999',
            'category': data['category']?.toString() ?? '',
          });
        }
        _masterModelsList = tempMasterModels;
      } catch (e) {
        print("🚨 マスター全機種取得エラー: $e");
      }

      // --- 🪑 8. 稼働状況（Active Workers）の取得 ---
      try {
        var activeResults = await conn.execute('''
          SELECT a.worker_id, m.worker_name, a.start_time, a.is_paused, a.paused_at
          FROM t_active_workers a
          LEFT JOIN m_members m ON a.worker_id = m.worker_id
        ''');

        // 直近1週間のうち、各作業者の「一番最後（最新）の作業ログ」を取得して推測する
        var taskCountResults = await conn.execute('''
          SELECT worker_id, 
                 IFNULL(air_clean_qty, 0) as air_sum,
                 IFNULL(clean_qty, 0) as clean_sum,
                 IFNULL(swap_qty, 0) as swap_sum
          FROM unit_cleaning_logs
          WHERE id IN (
            SELECT MAX(id)
            FROM unit_cleaning_logs
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            GROUP BY worker_id
          )
        ''');

        Map<String, String> workerInferredTask = {};
        for (var row in taskCountResults.rows) {
          var tData = row.assoc();
          String wId = tData['worker_id'] ?? '';
          double air = double.tryParse(tData['air_sum'] ?? '0') ?? 0;
          double clean = double.tryParse(tData['clean_sum'] ?? '0') ?? 0;
          double swap = double.tryParse(tData['swap_sum'] ?? '0') ?? 0;

          String bestTask = "清掃";
          if (air > clean && air >= swap) {
            bestTask = "エアー";
          } else if (swap > clean && swap > air) {
            bestTask = "筐体交換";
          }
          workerInferredTask[wId] = bestTask;
        }

        List<ActiveWorker> tempActiveWorkers = [];
        for (var row in activeResults.rows) {
          var data = row.assoc();
          String wId = data['worker_id'] ?? '';
          double startTs = double.tryParse(data['start_time'] ?? '0') ?? 0;
          DateTime startTime = DateTime.fromMillisecondsSinceEpoch((startTs * 1000).toInt());
          bool isPaused = (data['is_paused'] ?? '0') == '1';
          
          DateTime? pausedAt;
          if (isPaused) {
            double pausedTs = double.tryParse(data['paused_at'] ?? '0') ?? 0;
            if (pausedTs > 0) {
              pausedAt = DateTime.fromMillisecondsSinceEpoch((pausedTs * 1000).toInt());
            }
          }

          tempActiveWorkers.add(ActiveWorker(
            workerId: wId,
            workerName: data['worker_name'] ?? (wId.isNotEmpty ? wId : '不明'),
            startTime: startTime,
            isPaused: isPaused,
            pausedAt: pausedAt,
            inferredTask: workerInferredTask[wId] ?? "清掃",
          ));
        }

        // 開始時刻が新しい順に並べる
        tempActiveWorkers.sort((a, b) => b.startTime.compareTo(a.startTime));
        _activeWorkers = tempActiveWorkers;
      } catch (e) {
        print("🚨 稼働状況データ取得エラー: $e");
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


  // --- 📝 スケジュールの更新（手動編集用） ---
  Future<void> updateSchedule(String modelName, String makerName, DateTime targetDate, int planCount, int actualCount) async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );
      await conn.connect();

      String dateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      
      // UNIQUE KEY (target_date, model_name, maker_name) を利用してUPSERT
      await conn.execute(
        '''
        INSERT INTO t_schedules (target_date, model_name, maker_name, plan_count, actual_count)
        VALUES (:date, :model, :maker, :plan, :actual)
        ON DUPLICATE KEY UPDATE 
        plan_count = VALUES(plan_count),
        actual_count = VALUES(actual_count)
        ''',
        {
          "date": dateStr,
          "model": modelName,
          "maker": makerName,
          "plan": planCount,
          "actual": actualCount
        }
      );
      await conn.close();

      // ローカル状態の更新
      int idx = _scheduleList.indexWhere((s) => s.modelName == modelName && s.makerName == makerName && 
          s.targetDate.year == targetDate.year && s.targetDate.month == targetDate.month && s.targetDate.day == targetDate.day);
      
      if (idx >= 0) {
        var old = _scheduleList[idx];
        _scheduleList[idx] = ScheduleItem(
          targetDate: old.targetDate,
          modelName: old.modelName,
          makerName: old.makerName,
          planCount: planCount,
          actualCount: actualCount,
          sortId: old.sortId,
        );
      } else {
        // 同じ機種の既存データから sortId を探す（並び順を維持するため）
        int inheritedSortId = 999999;
        try {
          var existingItems = _scheduleList.where((s) => s.modelName == modelName && s.makerName == makerName);
          if (existingItems.isNotEmpty) {
            inheritedSortId = existingItems.map((s) => s.sortId).reduce((a, b) => a < b ? a : b);
          }
        } catch (e) {
          print("sortId継承エラー: $e");
        }

        _scheduleList.add(ScheduleItem(
          targetDate: targetDate,
          modelName: modelName,
          makerName: makerName,
          planCount: planCount,
          actualCount: actualCount,
          sortId: inheritedSortId, // 既存の並び順を引き継ぐ
        ));
      }
      notifyListeners();
    } catch (e) {
      print("🚨 スケジュール更新エラー: $e");
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

      // ⭐ プラットフォーム別の最適保存フォルダー自動選択！
      // (タブレット(Android)なら本体の「ダウンロード」フォルダ、Windowsなら「デスクトップ」等に確実に自動保存)
      String dirPath = '';
      if (Platform.isAndroid) {
        dirPath = '/storage/emulated/0/Download';
      } else if (Platform.isWindows) {
        String userProfile = Platform.environment['USERPROFILE'] ?? 'C:/Users/yamada';
        dirPath = '$userProfile/Desktop';
      } else {
        dirPath = 'C:/Users/yamada/Desktop';
      }

      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String fileName = 'work_logs_$timestamp.csv';
      String outPath = '$dirPath/$fileName';

      // ⭐ メンバー情報の辞書を回収 ( worker_id ➔ worker_name への神変換用！ )
      Map<String, String> memberMap = {};
      try {
        var memRes = await conn.execute('SELECT worker_id, worker_name FROM m_members');
        for (var row in memRes.rows) {
          var assoc = row.assoc();
          String wid = assoc['worker_id'] ?? '';
          String wname = assoc['worker_name'] ?? '';
          if (wid.isNotEmpty && wname.isNotEmpty) {
            memberMap[wid] = wname;
          }
        }
      } catch (e) {
        print("m_members 取り出し警告 (無視): $e");
      }

      // データベースからすべての実績を回収
      var res = await conn.execute('SELECT * FROM unit_cleaning_logs ORDER BY id ASC');
      await conn.close();

      if (res.rows.isEmpty) {
        return null;
      }

      // 確実なCSVセルエスケープ
      String escapeCsv(String? val) {
        if (val == null) return '';
        String str = val.replaceAll('"', '""');
        return '"$str"';
      }

      List<String> columns = res.rows.first.assoc().keys.toList();
      StringBuffer csvBuffer = StringBuffer();
      
      // 1. カラム名(ヘッダー)を印字 (💡 'worker_id' を自動で 'worker_name' に書き換え！)
      csvBuffer.writeln(columns.map((c) => escapeCsv(c == 'worker_id' ? 'worker_name' : c)).join(','));

      // 2. 実績データをきれいなCSVフォーマットへ変換
      for (var row in res.rows) {
        var assoc = row.assoc();
        String line = columns.map((col) {
          String val = assoc[col]?.toString() ?? '';
          // 💡 worker_id の列なら、名簿と付け合わせて「実際のお名前(worker_name)」へチェンジ！
          if (col == 'worker_id' && memberMap.containsKey(val)) {
            val = memberMap[val]!;
          }
          return escapeCsv(val);
        }).join(',');
        csvBuffer.writeln(line);
      }

      // ⭐ どのExcel/ソフトで開いても絶対に文字化けさせない秘技: 【 BOM (0xEF, 0xBB, 0xBF) 】付き UTF-8 形式！
      List<int> bom = [0xEF, 0xBB, 0xBF];
      List<int> utf8Bytes = utf8.encode(csvBuffer.toString());

      File file = File(outPath);
      if (!(await file.parent.exists())) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes([...bom, ...utf8Bytes], flush: true);

      print("✅ タブレット/PCローカル保存完遂(お名前変換済み): $outPath");
      return outPath;
    } catch (e) {
      print("🚨 CSV出力エラー詳細: $e");
      return null;
    }
  }

  // --- 📝 機種別スケジュール進捗の更新（手動編集用） ---
  Future<bool> updateModelScheduleProgress(String modelName, String makerName, int air, int clean, int swap, int total) async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );

      await conn.connect();
      
      String sql = '''
        INSERT INTO t_model_schedules (model_name, maker_name, air_count, clean_count, swap_count, total_count)
        VALUES (:model, :maker, :air, :clean, :swap, :total)
        ON DUPLICATE KEY UPDATE
        air_count = :air,
        clean_count = :clean,
        swap_count = :swap,
        total_count = :total
      ''';
      
      await conn.execute(sql, {
        "model": modelName,
        "maker": makerName,
        "air": air,
        "clean": clean,
        "swap": swap,
        "total": total,
      });
      
      await conn.close();

      String key = "${makerName}_${modelName}";
      _scheduleProgressMap[key] = ModelScheduleProgress(
        modelName: modelName,
        makerName: makerName,
        airCount: air,
        cleanCount: clean,
        swapCount: swap,
        totalCount: total,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      print("機種別スケジュール進捗更新エラー: $e");
      return false;
    }
  }

  // --- 🤖 AI口調設定の更新 ---
  Future<void> updateAiTone(String workerId, String tone) async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );
      await conn.connect();
      
      await conn.execute(
        'UPDATE m_members SET ai_tone = :tone WHERE worker_id = :id',
        {'tone': tone, 'id': workerId},
      );

      String tempMsg = "スタイルを変更しました！明日のレポートをお待ちください。";
      if (tone == "関西弁") {
        tempMsg = "おおきに！スタイル変更完了や！明日の作業分析レポートからワイが関西弁でビシバシ言うたるさかい、楽しみにな！";
      } else if (tone == "熱血コーチ") {
        tempMsg = "スタイル変更完了だ！お前の熱い想い、しかと受け取った！明日のレポートから俺がビシバシしごいてやるから覚悟しておけよ！";
      } else if (tone == "執事") {
        tempMsg = "かしこまりました。私、執事がスタイル変更を承りました。明日のレポートより、誠心誠意ご報告させていただきます。";
      }

      await conn.execute(
        '''
        UPDATE t_ai_reports 
        SET report_content = :msg 
        WHERE worker_id = :id 
        ORDER BY target_date DESC 
        LIMIT 1
        ''',
        {'msg': tempMsg, 'id': workerId},
      );

      await conn.close();
      
      if (_workerStatsMap.containsKey(workerId)) {
        _workerStatsMap[workerId]!.aiTone = tone;
        _workerStatsMap[workerId]!.aiReport = tempMsg;
        notifyListeners();
      }
    } catch (e) {
      print("🚨 AI口調設定更新エラー: $e");
    }
  }

}
