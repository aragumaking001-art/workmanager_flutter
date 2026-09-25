import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'video_splash_screen.dart';
import 'providers/data_provider.dart';
import 'pages/personal_productivity_page.dart';
import 'tabs/database_settings_tab.dart';
import 'widgets/digital_signage_screen.dart';

import 'tabs/summary_tab.dart';
import 'tabs/today_summary_tab.dart';
import 'tabs/seating_chart_tab.dart';
import 'tabs/total_ranking_tab.dart';
import 'tabs/data_edit_tab.dart';
import 'tabs/data_view_tab.dart';
import 'tabs/personal_stats_tab.dart';
import 'tabs/goal_list_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/schedule_progress_tab.dart';
import 'providers/kiosk_provider.dart';
import 'widgets/app_background_wrapper.dart';
import 'widgets/anomaly_status_indicator.dart';
export 'widgets/anomaly_status_indicator.dart';

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

      // 💡 IPアドレスによるモード判定ロジック（※UI編集中・デバッグ時は管理者モードを優先）
      if (kDebugMode) {
        currentMode = AppMode.administrator;
      } else if (myIp == "192.168.10.102") {
        currentMode = AppMode.kiosk;
      } else {
        if (myIp == "192.168.10.103") {
          currentMode = AppMode.administrator;
        } else if (myIp == "192.168.10.150" || myIp == "192.168.10.151" || myIp == "192.168.10.152") {
          currentMode = AppMode.administrator; // 150, 151, 152は管理者モード
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
      bool isDevPC = kDebugMode || (myIp == "192.168.10.150") || (myIp == "192.168.10.151") || (myIp == "192.168.10.152");

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
        ChangeNotifierProvider(
          create: (_) => KioskProvider(isEnabled: currentMode == AppMode.kiosk),
        ),
      ],
      // 💡 判定されたモードとIPをアプリ全体に渡す
      child: MyApp(appMode: currentMode, ipAddress: myIp),
    ),
  );
}

// 💡 画面遷移を監視して、メインメニュー復帰時にサイネージタイマーを確実にリセットするためのオブザーバー
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class MyApp extends StatelessWidget {
  final AppMode appMode;
  final String ipAddress;

  const MyApp({super.key, required this.appMode, required this.ipAddress});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '和気センター WorkManager Pro',
      navigatorObservers: [routeObserver],
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


// --- 🏠 メインメニュー画面（管理者・マネージャ共用） ---
class MainLayout extends StatefulWidget {
  final AppMode appMode;
  const MainLayout({super.key, required this.appMode});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with RouteAware, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 💡 放置時間設定（デバッグ用30秒。運用時は2分等に変更可能）
  static const Duration _inactivityTimeout = Duration(seconds: 30);
  Timer? _inactivityTimer;
  bool _isSignageActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _inactivityTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // 他の画面やダイアログからメインメニューへ戻った際に、即座に放置タイマーを開始・リセット
    _isSignageActive = false;
    _resetInactivityTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        _isSignageActive = false;
        _resetInactivityTimer();
      }
    }
  }

  /// ユーザー操作時にタイマーを再スタート
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!mounted || _isSignageActive) return;
    _inactivityTimer = Timer(_inactivityTimeout, _openSignage);
  }

  /// スクリーンセーバー／サイネージ画面を開く
  void _openSignage() {
    // メインメニューが最前面にない（他のタブを開いている）場合は開かないが、
    // タイマーを消滅させずに再スケジュールして待機状態を維持する
    if (!mounted || _isSignageActive) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _resetInactivityTimer();
      return;
    }

    setState(() => _isSignageActive = true);
    _inactivityTimer?.cancel();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DigitalSignageScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isSignageActive = false);
        _resetInactivityTimer();
      }
    });
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
          imagePath: 'assets/menu_personal_stats.jpg',
          entranceIndex: 4,
        ),
      );
      page1BottomCards.add(
        _menuCard(
          context,
          "生産性",
          Icons.emoji_events_rounded,
          Colors.amber,
          const PersonalProductivityPage(),
          imagePath: 'assets/menu_productivity.jpg',
          entranceIndex: 5,
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
        imagePath: 'assets/menu_data_edit.jpg',
        entranceIndex: 6,
      ),
    );
    page1BottomCards.add(
      _menuCard(
        context,
        "データ確認",
        Icons.find_in_page_rounded,
        Colors.indigoAccent,
        const DataViewTab(),
        imagePath: 'assets/menu_data_view.jpg',
        entranceIndex: 7,
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
        Colors.amber,
        const GoalListTab(),
        imagePath: 'assets/menu_goal_list.jpg',
        entranceIndex: 0,
      ),
      _menuCard(
        context,
        "清掃スケジュール",
        Icons.calendar_month,
        const Color(0xFF00CCFF),
        const ScheduleProgressTab(),
        imagePath: 'assets/menu_schedule.jpg',
        entranceIndex: 1,
      ),
      _menuCard(
        context,
        "稼働状況",
        Icons.people_alt_rounded,
        Colors.greenAccent,
        const SeatingChartTab(),
        imagePath: 'assets/menu_seating_chart.jpg',
        entranceIndex: 2,
      ),
    ];
    List<Widget> page2BottomCards = [];
    int bottomEntranceIndex = 3;
    if (widget.appMode == AppMode.administrator) {
      page2BottomCards.add(
        _menuCard(
          context,
          "データベース運用設定",
          Icons.storage_rounded,
          Colors.purpleAccent,
          const DatabaseSettingsTab(),
          imagePath: 'assets/menu_database_settings.jpg',
          entranceIndex: bottomEntranceIndex++,
        ),
      );
    }
    // 💡 画面・表示設定（データベース運用設定の右に配置）
    page2BottomCards.add(
      _menuCard(
        context,
        "画面・表示設定",
        Icons.settings_display_rounded,
        const Color(0xFF00CCFF),
        const SettingsTab(),
        imagePath: 'assets/menu_display_settings.jpg',
        entranceIndex: bottomEntranceIndex++,
      ), // ⭐ 反射低減と純黒トーンを心ゆくまで自由に選択できる専用設定カード！
    );

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
    final isWhiteMode = dp.displayMode == DisplayMode.pureWhite;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(),
      onPointerHover: (_) => _resetInactivityTimer(),
      onPointerSignal: (_) => _resetInactivityTimer(),
      child: AppBackgroundWrapper(
        blurSigma: 8.0,
        whiteAlpha: 0.70,
        darkAlpha: 0.60,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: dp.currentCardColor.withValues(alpha: 0.5),
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
              const SizedBox(width: 10),
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
                    _buildSectionHeader(
                      "作業実績・データ管理",
                      const Color(0xFF00E5FF),
                      Icons.data_usage_rounded,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _menuCard(
                          context,
                          "4F 筐体清掃",
                          Icons.cleaning_services_rounded,
                          const Color(0xFF00E5FF),
                          const TabPageLayout(),
                          imagePath: 'assets/menu_unit_cleaning.jpg',
                          entranceIndex: 0,
                        ),
                        const SizedBox(width: 20),
                        _menuCard(
                          context,
                          "データ修正",
                          Icons.edit_note_rounded,
                          const Color(0xFF00E676),
                          DataEditTab(isAdmin: false),
                          imagePath: 'assets/menu_data_edit.jpg',
                          entranceIndex: 1,
                        ),
                        const SizedBox(width: 20),
                        _menuCard(
                          context,
                          "データ確認",
                          Icons.find_in_page_rounded,
                          const Color(0xFF2979FF),
                          const DataViewTab(),
                          imagePath: 'assets/menu_data_view.jpg',
                          entranceIndex: 2,
                        ),
                        const SizedBox(width: 20),
                        _menuCard(
                          context,
                          "作業標準台数",
                          Icons.flag_circle,
                          const Color(0xFFFFB300),
                          const GoalListTab(),
                          imagePath: 'assets/menu_goal_list.jpg',
                          entranceIndex: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildSectionHeader(
                      "スケジュール管理",
                      const Color(0xFFFF9100),
                      Icons.edit_calendar_rounded,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _menuCard(
                          context,
                          "清掃スケジュール",
                          Icons.calendar_month,
                          const Color(0xFFFF9100),
                          const ScheduleProgressTab(),
                          imagePath: 'assets/menu_schedule.jpg',
                          entranceIndex: 4,
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
          : Stack(
              children: [
                Column(
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
                                vertical: 24.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    "フロア実績 (1F - 4F)",
                                    const Color(0xFF00CCFF),
                                    Icons.business_rounded,
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
                                        entranceIndex: 0,
                                      ),
                                      const SizedBox(width: 20),
                                      _menuCard(
                                        context,
                                        "2F 梱包・アダプタ",
                                        Icons.inventory_2_rounded,
                                        Colors.blueGrey,
                                        null,
                                        entranceIndex: 1,
                                      ),
                                      const SizedBox(width: 20),
                                      _menuCard(
                                        context,
                                        "3F 試験・検品",
                                        Icons.fact_check_rounded,
                                        Colors.blueGrey,
                                        null,
                                        entranceIndex: 2,
                                      ),
                                      const SizedBox(width: 20),
                                      _menuCard(
                                        context,
                                        "4F 筐体清掃",
                                        Icons.cleaning_services_rounded,
                                        const Color(0xFF00CCFF),
                                        const TabPageLayout(),
                                        imagePath: 'assets/menu_unit_cleaning.jpg',
                                        entranceIndex: 3,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 36),
                                  _buildSectionHeader(
                                    "分析・管理メニュー",
                                    Colors.orangeAccent,
                                    Icons.analytics_rounded,
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
                                vertical: 24.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    "目標・拡張機能",
                                    Colors.pinkAccent,
                                    Icons.extension_rounded,
                                  ),
                                  const SizedBox(height: 20),
                                  Row(children: page2TopRowChildren),
                                  const SizedBox(height: 36),
                                  _buildSectionHeader(
                                    "追加機能枠",
                                    Colors.grey,
                                    Icons.add_circle_outline_rounded,
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
                    // 💡 ページ表示バッジ（現在ページのテキスト ＋ インジケーター）
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWhiteMode
                              ? Colors.white.withValues(alpha: 0.85)
                              : const Color(0xFF0F172A).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isWhiteMode
                                ? Colors.black.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isWhiteMode ? 0.05 : 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(2, (index) {
                                bool isActive = _currentPage == index;
                                final dotColor = isActive
                                    ? (index == 0
                                        ? (isWhiteMode ? const Color(0xFF006688) : const Color(0xFF00CCFF))
                                        : (isWhiteMode ? const Color(0xFFC2185B) : Colors.pinkAccent))
                                    : (isWhiteMode ? Colors.black26 : Colors.white24);
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                                  height: 7.0,
                                  width: isActive ? 18.0 : 7.0,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    borderRadius: BorderRadius.circular(3.5),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _currentPage == 0
                                  ? "1 / 2　フロア実績・分析"
                                  : "2 / 2　目標・拡張機能",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _currentPage == 0
                                    ? (isWhiteMode ? const Color(0xFF006688) : const Color(0xFF00CCFF))
                                    : (isWhiteMode ? const Color(0xFFC2185B) : Colors.pinkAccent),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // 💡 画面端のタッチナビゲーションボタン（1ページ目：右端「次へ」 / 2ページ目：左端「戻る」）
                _buildFloatingSideNav(isWhiteMode: isWhiteMode),
              ],
            ),
          ),
        ),
      );
  }

  // 💡 画面端のフローティングナビゲーションボタン（1ページ目は右端に「次へ」、2ページ目は左端に「戻る」）
  Widget _buildFloatingSideNav({required bool isWhiteMode}) {
    final isPage0 = _currentPage == 0;
    final accentColor = isPage0
        ? (isWhiteMode ? const Color(0xFFC2185B) : Colors.pinkAccent)
        : (isWhiteMode ? const Color(0xFF006688) : const Color(0xFF00CCFF));

    return Positioned(
      right: isPage0 ? 12 : null,
      left: isPage0 ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              final target = isPage0 ? 1 : 0;
              _pageController.animateToPage(
                target,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 16),
              decoration: BoxDecoration(
                color: isWhiteMode
                    ? Colors.white.withValues(alpha: 0.94)
                    : const Color(0xFF1E293B).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.75),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPage0 ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPage0 ? "次\nへ" : "戻\nる",
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    final dp = context.watch<DataProvider>();
    final isWhiteMode = dp.displayMode == DisplayMode.pureWhite;
    final textColor = isWhiteMode ? const Color(0xFF0F172A) : Colors.white;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 💡 左側の呼吸するように発光するカラーアクセントピラー（セクションの目印）
          PulsingAccentPillar(
            color: color,
            isWhiteMode: isWhiteMode,
          ),
          const SizedBox(width: 12),
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.2,
              shadows: isWhiteMode
                  ? null
                  : const [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 12.0,
                        offset: Offset(0, 2),
                      ),
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4.0,
                        offset: Offset(0, 1),
                      ),
                    ],
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
    Widget? targetPage, {
    String? imagePath,
    int entranceIndex = 0,
  }) {
    return Expanded(
      child: InteractiveMenuCard(
        title: title,
        icon: icon,
        color: color,
        targetPage: targetPage,
        imagePath: imagePath,
        entranceIndex: entranceIndex,
        onReturn: _resetInactivityTimer,
      ),
    );
  }
}

// --- 🌟 インタラクティブ・メニューカード（ドミノ登場・ホバー浮遊・ネオングロー拡散・シマー光彩） ---
class InteractiveMenuCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? targetPage;
  final String? imagePath;
  final int entranceIndex;
  final VoidCallback? onReturn;

  const InteractiveMenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.targetPage,
    this.imagePath,
    this.entranceIndex = 0,
    this.onReturn,
  });

  @override
  State<InteractiveMenuCard> createState() => _InteractiveMenuCardState();
}

class _InteractiveMenuCardState extends State<InteractiveMenuCard>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  late final AnimationController _entranceController;
  late final AnimationController _shimmerController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    // 🎬 画面遷移時のドミノ倒し風カード登場アニメーション
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.93,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    ));

    // entranceIndex に応じて順番に発火
    final delayMs = widget.entranceIndex * 60;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _entranceController.forward();
      }
    });

    // ✨ シマー光彩アニメーション（ホバー・タップ・登場時のみ発火させて放置時のCPU負荷をゼロにする）
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 画面登場時に一度だけ優雅にシマーを一閃させる
    if (widget.targetPage != null) {
      Future.delayed(Duration(milliseconds: delayMs + 350), () {
        if (mounted) {
          _shimmerController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(InteractiveMenuCard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.targetPage != null;
    final dp = Provider.of<DataProvider>(context);
    final isWhiteMode = dp.displayMode == DisplayMode.pureWhite;
    final isHighlighted = isAvailable && (_isHovered || _isPressed);

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: MouseRegion(
              onEnter: isAvailable
                  ? (_) {
                      setState(() => _isHovered = true);
                      _shimmerController.forward(from: 0.0);
                    }
                  : null,
              onExit: isAvailable ? (_) => setState(() => _isHovered = false) : null,
              cursor: isAvailable ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: AnimatedScale(
                scale: isHighlighted ? 1.035 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isAvailable
                      ? () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  widget.targetPage!,
                              transitionDuration: const Duration(milliseconds: 280),
                              reverseTransitionDuration:
                                  const Duration(milliseconds: 240),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                final curve = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                  reverseCurve: Curves.easeInCubic,
                                );
                                return FadeTransition(
                                  opacity: Tween<double>(begin: 0.0, end: 1.0)
                                      .animate(curve),
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.92, end: 1.0)
                                        .animate(curve),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                          ).then((_) {
                            widget.onReturn?.call();
                          });
                        }
                      : null,
                  onHighlightChanged: isAvailable
                      ? (val) {
                          setState(() => _isPressed = val);
                          if (val) _shimmerController.forward(from: 0.0);
                        }
                      : null,
                  child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 200,
            padding: EdgeInsets.all(widget.imagePath != null ? 0 : 10),
            decoration: BoxDecoration(
              color: widget.imagePath != null
                  ? null
                  : dp.currentCardColor.withValues(alpha: 0.4),
              image: widget.imagePath != null
                  ? DecorationImage(
                      image: AssetImage(widget.imagePath!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: (isWhiteMode || widget.imagePath != null)
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withValues(
                          alpha: isAvailable ? (isHighlighted ? 0.8 : 0.6) : 0.1,
                        ),
                        widget.color.withValues(
                          alpha: isAvailable ? (isHighlighted ? 0.2 : 0.1) : 0.05,
                        ),
                      ],
                    ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWhiteMode
                    ? (isAvailable ? widget.color : Colors.grey.shade300)
                    : (isAvailable
                        ? (isHighlighted
                            ? widget.color
                            : widget.color.withValues(alpha: 0.95))
                        : widget.color.withValues(alpha: 0.15)),
                width: isWhiteMode
                    ? (isHighlighted ? 3.0 : 2.5)
                    : (isHighlighted ? 2.5 : 2.0),
              ),
              boxShadow: isAvailable
                  ? (isHighlighted
                      ? [
                          BoxShadow(
                            color: isWhiteMode
                                ? widget.color.withValues(alpha: 0.35)
                                : widget.color.withValues(alpha: 0.70),
                            blurRadius: isWhiteMode ? 16 : 24,
                            spreadRadius: isWhiteMode ? 1 : 2,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: isWhiteMode
                                ? Colors.black.withValues(alpha: 0.12)
                                : widget.color.withValues(alpha: 0.35),
                            blurRadius: 36,
                            spreadRadius: 6,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: isWhiteMode
                                ? Colors.black.withValues(alpha: 0.08)
                                : widget.color.withValues(alpha: 0.35),
                            blurRadius: isWhiteMode ? 8 : 12,
                            spreadRadius: isWhiteMode ? 0 : 1,
                            offset: const Offset(0, 4),
                          ),
                        ])
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  if (widget.imagePath != null)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55],
                          ),
                        ),
                      ),
                    ),
                  // ✨ 光の筋が走るシマーエフェクト (Shimmer Light Sweep)
                  if (isAvailable)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            final progress = _shimmerAnimation.value;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-2.5 + progress * 3.5, -1.0),
                                  end: Alignment(-1.5 + progress * 3.5, 1.0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(
                                      alpha: isWhiteMode ? 0.28 : 0.18,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(widget.imagePath != null ? 16.0 : 0.0),
                      child: Column(
                        mainAxisAlignment: widget.imagePath != null
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.center,
                        crossAxisAlignment: widget.imagePath != null
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          if (widget.imagePath == null)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Icon(
                                  widget.icon,
                                  size: 60,
                                  color: isAvailable
                                      ? widget.color
                                      : (isWhiteMode
                                          ? Colors.grey.shade400
                                          : Colors.white24),
                                ),
                              ),
                            ),
                          if (widget.imagePath == null) const SizedBox(height: 15),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.title,
                                textAlign: widget.imagePath != null
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: TextStyle(
                                  fontSize: widget.imagePath != null ? 30 : 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: widget.imagePath != null ? 1.5 : 1.0,
                                  color: isAvailable
                                      ? (widget.imagePath != null
                                          ? Colors.white
                                          : (isWhiteMode ? Colors.black87 : Colors.white))
                                      : (isWhiteMode ? Colors.grey.shade500 : Colors.white24),
                                  shadows: isAvailable
                                      ? const [
                                          Shadow(
                                            offset: Offset(0, 2),
                                            blurRadius: 8.0,
                                            color: Colors.black,
                                          ),
                                          Shadow(
                                            offset: Offset(0, 0),
                                            blurRadius: 14.0,
                                            color: Colors.black,
                                          ),
                                        ]
                                      : null,
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
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
),
),
);
  }
}

// ============================================================================
// 💡 セクションヘッダー用: 発光アクセントピラー (PulsingAccentPillar - 静的グロー化で省電力)
// ============================================================================
class PulsingAccentPillar extends StatelessWidget {
  final Color color;
  final bool isWhiteMode;

  const PulsingAccentPillar({
    super.key,
    required this.color,
    required this.isWhiteMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: isWhiteMode
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6.0,
                  spreadRadius: 0.5,
                ),
              ]
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.65),
                  blurRadius: 10.0,
                  spreadRadius: 1.5,
                ),
              ],
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

    return AppBackgroundWrapper(
      blurSigma: 10.0,
      whiteAlpha: 0.78,
      darkAlpha: 0.72,
      child: Scaffold(
        backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: dp.currentCardColor.withOpacity(0.55),
            elevation: isWhite ? 2 : 0,
            iconTheme: IconThemeData(color: dp.mainTextColor),
            title: Text(
              "4F 作業実績詳細",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: dp.mainTextColor,
              ),
            ),
            actions: const [
              Center(child: ConnectionStatusIndicator()),
              SizedBox(width: 20),
            ],
          ),
          body: _tabs[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: dp.currentCardColor.withOpacity(0.85),
            elevation: 0,
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
        ),
      );
  }
}
