import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';

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
          MIN(CAST(NULLIF(csv_id, '') AS UNSIGNED)) as sort_id
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1C23),
        title: const Text("作業標準台数", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            tooltip: "更新",
            onPressed: _fetchStandards,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00CCFF)))
          : _standards.isEmpty
              ? const Center(
                  child: Text(
                    "マスターデータがありません",
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                )
              : Column(
                  children: [
                    // --- ヘッダー行 ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1C23),
                        border: Border(bottom: BorderSide(color: Color(0xFF00CCFF), width: 2)),
                      ),
                      child: Row(
                        children: const [
                          Expanded(flex: 3, child: Text("機種名", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Text("エアー清掃", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Text("清掃", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
                          Expanded(flex: 2, child: Align(alignment: Alignment.center, child: Text("筐体交換", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)))),
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
                            color: isEven ? const Color(0xFF16181D) : const Color(0xFF0F1115),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3, 
                                  child: Text(
                                    cleanModelName, 
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Align(
                                    alignment: Alignment.center, 
                                    child: _GoalChip(text: stdAir, color: Colors.blueAccent)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Align(
                                    alignment: Alignment.center, 
                                    child: _GoalChip(text: stdClean, color: Colors.green)
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Align(
                                    alignment: Alignment.center, 
                                    child: _GoalChip(text: stdSwap, color: Colors.orangeAccent)
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
    );
  }
}

// 💡 視認性を上げるための共通チップコンポーネント
class _GoalChip extends StatelessWidget {
  final String text;
  final Color color;

  const _GoalChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    if (text == "-") {
      return const Text("-", style: TextStyle(color: Colors.white38, fontSize: 16));
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
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
