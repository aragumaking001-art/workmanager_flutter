import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'video_splash_screen.dart';
import 'providers/data_provider.dart';
import 'pages/personal_productivity_page.dart';
import 'tabs/database_settings_tab.dart';

import 'tabs/summary_tab.dart';
import 'tabs/today_summary_tab.dart';
import 'tabs/total_ranking_tab.dart';
import 'tabs/data_edit_tab.dart';
import 'tabs/data_view_tab.dart';
import 'tabs/personal_stats_tab.dart';
import 'tabs/goal_list_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/schedule_progress_tab.dart';
import 'tabs/kiosk_screen.dart';
import 'providers/kiosk_provider.dart';

// 💡 動作モードの定義
enum AppMode { administrator, kiosk, manager }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppMode currentMode = AppMode.manager; // デフォルトはマネージャ用
  String myIp = "Unknown";

  if (!kIsWeb) {
    try {
      // 💡 ローカルIPアドレスを取得
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // "192.168.10."から始まるIPを最優先で取得する
            if (addr.address.startsWith("192.168.10.")) {
              myIp = addr.address;
            } else if (myIp == "Unknown") {
              // 192.168.10.x が見つからない場合のフォールバック
              myIp = addr.address;
            }
          }
        }
      }

      // 💡 IPアドレスによるモード判定ロジック
      if (myIp == "192.168.10.102") {
        currentMode = AppMode.kiosk;
      } else {
        if (myIp == "192.168.10.103") {
          currentMode = AppMode.administrator;
        } else if (myIp == "192.168.10.150" || myIp == "192.168.10.151") {
          currentMode = AppMode.administrator; // 150と151は管理者モード
        } else {
          currentMode = AppMode.manager;
        }
      }
    } catch (e) {
      print("IP取得失敗: $e");
    }

    // 全画面設定
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.ensureInitialized();

      // 💡 開発用PC(デバッグモード)ならウィンドウモードにする
      bool isDevPC = kDebugMode || (myIp == "192.168.10.150") || (myIp == "192.168.10.151");

      windowManager.waitUntilReadyToShow(
        WindowOptions(
          size: isDevPC ? const Size(1280, 800) : null,
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: isDevPC ? TitleBarStyle.normal : TitleBarStyle.hidden,
        ),
        () async {
          await windowManager.show();
          await windowManager.focus();
          if (!isDevPC) {
            await windowManager.setFullScreen(true);
          }
        },
      );
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DataProvider()
            ..fetchAndAnalyze()
            ..startAutoRefresh(),
        ),
        ChangeNotifierProvider(create: (_) => KioskProvider()),
      ],
      // 💡 判定されたモードとIPをアプリ全体に渡す
      child: MyApp(appMode: currentMode, ipAddress: myIp),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppMode appMode;
  final String ipAddress;

  const MyApp({super.key, required this.appMode, required this.ipAddress});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '和気センター WorkManager Pro',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      locale: const Locale('ja', 'JP'),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00CCFF),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      // 💡 PC環境（マウス）でもドラッグ操作でスクロールできるように設定
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      // 💡 スプラッシュ画面にモード情報を渡す
      home: VideoSplashScreen(appMode: appMode, ipAddress: ipAddress),
    );
  }
}

// ----------------------------------------------------------------------
// 💡 共通で使えるオンライン・オフラインのインジケーターUI
// ----------------------------------------------------------------------
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final bool isOnline = data.isOnline;
    final bool isWhite = data.displayMode == DisplayMode.pureWhite;

    // 💡 白モードではディープで美しい視認性を発揮するグリーン/レッドを使用！
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

// --- 🏠 メインメニュー画面（管理者・マネージャ共用） ---
class MainLayout extends StatefulWidget {
  final AppMode appMode;
  const MainLayout({super.key, required this.appMode});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> page1BottomCards = [];

    if (widget.appMode == AppMode.administrator) {
      page1BottomCards.add(
        _menuCard(
          context,
          "個人別ステータス",
          Icons.person_search_rounded,
          Colors.orangeAccent,
          const PersonalStatsTab(isKioskMode: false),
        ),
      );
      page1BottomCards.add(
        _menuCard(
          context,
          "生産性",
          Icons.emoji_events_rounded,
          Colors.amber,
          const PersonalProductivityPage(),
        ),
      );
    }
    page1BottomCards.add(
      _menuCard(
        context,
        "データ修正",
        Icons.edit_note_rounded,
        Colors.teal,
        DataEditTab(isAdmin: widget.appMode == AppMode.administrator),
      ),
    );
    page1BottomCards.add(
      _menuCard(
        context,
        "データ確認",
        Icons.find_in_page_rounded,
        Colors.indigoAccent,
        const DataViewTab(),
      ),
    );

    List<Widget> page1BottomRowChildren = [];
    for (int i = 0; i < 4; i++) {
      if (i < page1BottomCards.length) {
        page1BottomRowChildren.add(page1BottomCards[i]);
      } else {
        page1BottomRowChildren.add(const Expanded(child: SizedBox.shrink()));
      }

      if (i < 3) {
        page1BottomRowChildren.add(const SizedBox(width: 20));
      }
    }

    // 2ページ目の構成
    List<Widget> page2TopCards = [
      _menuCard(
        context,
        "作業標準台数",
        Icons.flag_circle,
        Colors.pinkAccent,
        const GoalListTab(),
      ),
      _menuCard(
        context,
        "画面・表示設定",
        Icons.settings_display_rounded,
        const Color(0xFF00CCFF),
        const SettingsTab(),
      ), // ⭐ 反射低減と純黒トーンを心ゆくまで自由に選択できる専用設定カード！
      _menuCard(
        context,
        "清掃スケジュール",
        Icons.calendar_month,
        Colors.deepOrange,
        const ScheduleProgressTab(),
      ),
    ];
    List<Widget> page2BottomCards = [];
    if (widget.appMode == AppMode.administrator) {
      page2BottomCards.add(
        _menuCard(
          context,
          "データベース\n運用設定",
          Icons.storage_rounded,
          Colors.purpleAccent,
          const DatabaseSettingsTab(),
        ),
      );
    }

    List<Widget> page2TopRowChildren = [];
    List<Widget> page2BottomRowChildren = [];
    for (int i = 0; i < 4; i++) {
      if (i < page2TopCards.length) {
        page2TopRowChildren.add(page2TopCards[i]);
      } else {
        page2TopRowChildren.add(const Expanded(child: SizedBox.shrink()));
      }

      if (i < page2BottomCards.length) {
        page2BottomRowChildren.add(page2BottomCards[i]);
      } else {
        page2BottomRowChildren.add(const Expanded(child: SizedBox.shrink()));
      }

      if (i < 3) {
        page2TopRowChildren.add(const SizedBox(width: 20));
        page2BottomRowChildren.add(const SizedBox(width: 20));
      }
    }

    final dp = context.watch<DataProvider>();

    return Scaffold(
      backgroundColor: dp.currentBgColor,
      appBar: AppBar(
        backgroundColor: dp.currentCardColor,
        elevation: dp.displayMode == DisplayMode.pureWhite ? 2 : 0,
        title: Text(
          widget.appMode == AppMode.administrator
              ? "和気センター 統合ダッシュボード [管理者]"
              : "和気センター 統合ダッシュボード [4Fスーパーバイザー]",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dp.mainTextColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.appMode == AppMode.administrator)
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  Icons.download,
                  color: dp.displayMode == DisplayMode.pureWhite
                      ? const Color(0xFF006688)
                      : const Color(0xFF00CCFF),
                  size: 30,
                ),
                tooltip: "CSVを出力 (PC:デスクトップ / タブ:ダウンロード)",
                onPressed: () async {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("CSVファイルを作成しています...")),
                  );
                  String? path = await Provider.of<DataProvider>(
                    ctx,
                    listen: false,
                  ).exportCsvToDatabasePC();
                  if (path != null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text("✅ CSV出力完了\nPCのデスクトップ ($path) に保存しました！"),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "❌ CSV出力失敗 (データベース側の設定で保存先が制限されている可能性があります)",
                        ),
                        backgroundColor: Colors.redAccent,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                },
              ),
            ),
          const SizedBox(width: 15),
          const Center(child: ConnectionStatusIndicator()), // 💡 メイン画面の右上
          const SizedBox(width: 20),
        ],
      ),
      body: widget.appMode == AppMode.manager
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 30.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "作業実績・データ管理",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00CCFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _menuCard(
                          context,
                          "4F 筐体清掃",
                          Icons.cleaning_services_rounded,
                          const Color(0xFF00CCFF),
                          const TabPageLayout(),
                        ),
                        const SizedBox(width: 20),
                        _menuCard(
                          context,
                          "データ修正",
                          Icons.edit_note_rounded,
                          Colors.teal,
                          DataEditTab(isAdmin: false),
                        ),
                        const SizedBox(width: 20),
                        _menuCard(
                          context,
                          "データ確認",
                          Icons.find_in_page_rounded,
                          Colors.indigoAccent,
                          const DataViewTab(),
                        ),
                        const SizedBox(width: 20),
                        _menuCard(
                          context,
                          "作業標準台数",
                          Icons.flag_circle,
                          Colors.pinkAccent,
                          const GoalListTab(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "スケジュール管理",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _menuCard(
                          context,
                          "清掃スケジュール",
                          Icons.calendar_month,
                          Colors.deepOrange,
                          const ScheduleProgressTab(),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(child: SizedBox.shrink()),
                        const SizedBox(width: 20),
                        const Expanded(child: SizedBox.shrink()),
                        const SizedBox(width: 20),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      // ページ1
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40.0,
                            vertical: 30.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "フロア実績 (1F - 4F)",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00CCFF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _menuCard(
                                    context,
                                    "1F 開梱・登録",
                                    Icons.unarchive_rounded,
                                    Colors.blueGrey,
                                    null,
                                  ),
                                  const SizedBox(width: 20),
                                  _menuCard(
                                    context,
                                    "2F 梱包・アダプタ",
                                    Icons.inventory_2_rounded,
                                    Colors.blueGrey,
                                    null,
                                  ),
                                  const SizedBox(width: 20),
                                  _menuCard(
                                    context,
                                    "3F 試験・検品",
                                    Icons.fact_check_rounded,
                                    Colors.blueGrey,
                                    null,
                                  ),
                                  const SizedBox(width: 20),
                                  _menuCard(
                                    context,
                                    "4F 筐体清掃",
                                    Icons.cleaning_services_rounded,
                                    const Color(0xFF00CCFF),
                                    const TabPageLayout(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "分析・管理メニュー",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(children: page1BottomRowChildren),
                            ],
                          ),
                        ),
                      ),
                      // ページ2
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40.0,
                            vertical: 30.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "目標・拡張機能",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pinkAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(children: page2TopRowChildren),
                              const SizedBox(height: 40),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "追加機能枠",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(children: page2BottomRowChildren),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) {
                      bool isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        height: 12.0,
                        width: isActive ? 30.0 : 12.0,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF00CCFF)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget? targetPage,
  ) {
    bool isAvailable = targetPage != null;
    final dp = Provider.of<DataProvider>(context);
    final isWhiteMode = dp.displayMode == DisplayMode.pureWhite;

    return Expanded(
      child: InkWell(
        onTap: isAvailable
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => targetPage),
                );
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isWhiteMode
                ? (isAvailable ? Colors.white : Colors.grey.shade200)
                : null,
            gradient: isWhiteMode
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(isAvailable ? 0.6 : 0.1),
                      color.withOpacity(isAvailable ? 0.1 : 0.05),
                    ],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isWhiteMode
                  ? (isAvailable ? color : Colors.grey.shade300)
                  : color.withOpacity(isAvailable ? 0.8 : 0.1),
              width: isWhiteMode ? 2.5 : 2,
            ),
            boxShadow: isWhiteMode && isAvailable
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Icon(
                    icon,
                    size: 60,
                    color: isAvailable
                        ? color
                        : (isWhiteMode ? Colors.grey.shade400 : Colors.white10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isAvailable
                          ? dp.mainTextColor
                          : (isWhiteMode
                                ? Colors.grey.shade500
                                : Colors.white10),
                    ),
                  ),
                ),
              ),
              if (!isAvailable)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "(準備中)",
                      style: TextStyle(
                        color: isWhiteMode
                            ? Colors.grey.shade400
                            : Colors.white10,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 📊 2. 4F実績詳細画面 ---
class TabPageLayout extends StatefulWidget {
  const TabPageLayout({super.key});

  @override
  State<TabPageLayout> createState() => _TabPageLayoutState();
}

class _TabPageLayoutState extends State<TabPageLayout> {
  int _selectedIndex = 1;

  final List<Widget> _tabs = [
    const TotalRankingTab(), // 0: ランキング
    const TodaySummaryTab(), // 1: 本日出来高
    const ModelAnalysisPage(), // 2: 機種別集計
  ];

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return Scaffold(
      backgroundColor: dp.currentBgColor,
      appBar: AppBar(
        backgroundColor: dp.currentCardColor,
        elevation: isWhite ? 2 : 0,
        title: Text(
          "4F 作業実績詳細",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dp.mainTextColor,
          ),
        ),
        actions: const [
          // 💡 更新・閉じるボタンを削除し、インジケーターだけを配置
          Center(child: ConnectionStatusIndicator()),
          SizedBox(width: 20),
        ],
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: dp.currentCardColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: isWhite
            ? const Color(0xFF006688)
            : const Color(0xFF00CCFF),
        unselectedItemColor: isWhite ? Colors.black38 : Colors.white30,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_rounded),
            label: 'ランキング',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_rounded),
            label: '本日出来高',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.summarize), label: '機種別集計'),
        ],
      ),
    );
  }
}
