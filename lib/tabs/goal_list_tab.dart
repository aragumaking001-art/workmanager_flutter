import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../widgets/app_background_wrapper.dart';

class GoalListTab extends StatefulWidget {
  const GoalListTab({super.key});

  @override
  State<GoalListTab> createState() => _GoalListTabState();
}

class _GoalListTabState extends State<GoalListTab> {
  List<Map<String, dynamic>> _standards = [];
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchStandards();
  }

  Future<void> _fetchStandards() async {
    setState(() => _isFetching = true);

    final conn = await MySQLConnection.createConnection(
      host: '192.168.10.101',
      port: 3306,
      userName: 'work_user',
      password: 'work1234',
      databaseName: 'work_manager_db',
    );

    try {
      await conn.connect();
      var result = await conn.execute('''
        SELECT 
          model_name, 
          MAX(CASE WHEN work_type = 'エアー清掃' THEN std_qty END) as std_air,
          MAX(CASE WHEN work_type = '清掃' THEN std_qty END) as std_clean,
          MAX(CASE WHEN work_type = '筐体交換' THEN std_qty END) as std_swap,
          MIN(sort_order) as sort_id
        FROM m_models 
        GROUP BY model_name
        ORDER BY sort_id ASC
      ''');

      List<Map<String, dynamic>> temp = [];
      for (var row in result.rows) {
        temp.add(row.assoc());
      }
      setState(() {
        _standards = temp;
      });
    } catch (e) {
      print("マスターデータ取得エラー: $e");
    } finally {
      await conn.close();
      setState(() => _isFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: dp.currentCardColor.withValues(alpha: isWhite ? 0.85 : 0.65),
        elevation: isWhite ? 2 : 0,
        iconTheme: IconThemeData(color: dp.mainTextColor),
        title: Text("作業標準台数", style: TextStyle(fontWeight: FontWeight.bold, color: dp.mainTextColor)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dp.mainTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isWhite ? const Color(0xFF006688) : Colors.cyanAccent),
            tooltip: "更新",
            onPressed: _fetchStandards,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00CCFF)))
          : _standards.isEmpty
              ? Center(
                  child: Text(
                    "マスターデータがありません",
                    style: TextStyle(color: dp.subTextColor, fontSize: 18),
                  ),
                )
              : Column(
                  children: [
                    // --- ヘッダー行 ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: dp.currentCardColor.withValues(alpha: isWhite ? 0.88 : 0.75),
                        border: Border(bottom: BorderSide(color: isWhite ? const Color(0xFF007799) : const Color(0xFF00CCFF), width: 2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text("機種名", style: TextStyle(color: isWhite ? const Color(0xFF007799) : Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Text("エアー清掃", style: TextStyle(color: isWhite ? const Color(0xFF007799) : Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Text("清掃", style: TextStyle(color: isWhite ? const Color(0xFF007799) : Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Text("筐体交換", style: TextStyle(color: isWhite ? const Color(0xFF007799) : Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                        ],
                      ),
                    ),
                    // --- データ行 ---
                    Expanded(
                      child: ListView.builder(
                        itemCount: _standards.length,
                        itemBuilder: (context, index) {
                          var row = _standards[index];
                          bool isEven = index % 2 == 0;
                          
                          // 機種名
                          String rawModelName = row['model_name']?.toString() ?? "不明";
                          String cleanModelName = rawModelName.contains(':') 
                              ? rawModelName.split(':').last.replaceAll('}', '').trim() 
                              : rawModelName;

                          // 各作業区分の目標台数 (nullなら - )
                          String stdAir = row['std_air'] != null ? "${row['std_air']} 台/h" : "-";
                          String stdClean = row['std_clean'] != null ? "${row['std_clean']} 台/h" : "-";
                          String stdSwap = row['std_swap'] != null ? "${row['std_swap']} 台/h" : "-";

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            color: isWhite 
                                ? (isEven ? Colors.white.withValues(alpha: 0.85) : Colors.grey.shade100.withValues(alpha: 0.75))
                                : (isEven ? const Color(0xFF16181D).withValues(alpha: 0.75) : const Color(0xFF0F1115).withValues(alpha: 0.65)),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3, 
                                  child: Text(
                                    cleanModelName, 
                                    style: TextStyle(color: dp.mainTextColor, fontSize: 20, fontWeight: FontWeight.bold)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Align(
                                    alignment: Alignment.center, 
                                    child: _GoalChip(text: stdAir, color: isWhite ? Colors.blue.shade700 : Colors.blueAccent, isWhite: isWhite)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Align(
                                    alignment: Alignment.center, 
                                    child: _GoalChip(text: stdClean, color: isWhite ? const Color(0xFF008040) : Colors.greenAccent, isWhite: isWhite)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Align(
                                    alignment: Alignment.center, 
                                    child: _GoalChip(text: stdSwap, color: isWhite ? Colors.orange.shade800 : Colors.orangeAccent, isWhite: isWhite)
                                  )
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

// 💡 視認性を上げるための共通チップコンポーネント
class _GoalChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool isWhite;

  const _GoalChip({required this.text, required this.color, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    if (text == "-") {
      return Text("-", style: TextStyle(color: isWhite ? Colors.black26 : Colors.white38, fontSize: 16));
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isWhite ? 0.1 : 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(isWhite ? 0.4 : 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
