import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mysql_client/mysql_client.dart';
import '../providers/data_provider.dart';
import 'member_add_scanner_page.dart';
import 'model_add_scanner_page.dart';
import '../pages/member_add_nfc_page.dart';
import '../pages/model_add_nfc_page.dart';

class DatabaseSettingsTab extends StatefulWidget {
  const DatabaseSettingsTab({super.key});

  @override
  State<DatabaseSettingsTab> createState() => _DatabaseSettingsTabState();
}

class _DatabaseSettingsTabState extends State<DatabaseSettingsTab> {
  bool _isLoading = true;
  String _errorMsg = "";
  List<Map<String, String>> _members = [];
  List<Map<String, String>> _models = [];

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final conn = await MySQLConnection.createConnection(
        host: '192.168.10.101',
        port: 3306,
        userName: 'work_user',
        password: 'work1234',
        databaseName: 'work_manager_db',
      );
      await conn.connect();

      // Fetch Members
      var memRes = await conn.execute('SELECT worker_id, worker_name FROM m_members ORDER BY worker_id ASC');
      _members = memRes.rows.map((r) => {
        'worker_id': r.assoc()['worker_id'] ?? '',
        'worker_name': r.assoc()['worker_name'] ?? '',
      }).toList();

      // Fetch Models
      var modRes = await conn.execute(
        "SELECT csv_id, model_id, model_name, maker, maker_abbr, category, work_type, std_qty "
        "FROM m_models "
        "ORDER BY CASE work_type "
        "WHEN 'エアー清掃' THEN 1 "
        "WHEN '清掃' THEN 2 "
        "WHEN '通常清掃' THEN 2 "
        "WHEN '筐体交換' THEN 3 "
        "ELSE 4 END ASC, "
        "CAST(csv_id AS UNSIGNED) ASC"
      );
      _models = modRes.rows.map((r) => {
        'csv_id': r.assoc()['csv_id'] ?? '',
        'model_id': r.assoc()['model_id'] ?? '',
        'model_name': r.assoc()['model_name'] ?? '',
        'maker': r.assoc()['maker'] ?? '',
        'maker_abbr': r.assoc()['maker_abbr'] ?? '',
        'category': r.assoc()['category'] ?? '',
        'work_type': r.assoc()['work_type'] ?? '',
        'std_qty': r.assoc()['std_qty'] ?? '',
      }).toList();

      await conn.close();
    } catch (e) {
      _errorMsg = "データベース接続エラー: $e";
      print(_errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editMember(Map<String, String> member) async {
    final TextEditingController nameCtrl = TextEditingController(text: member['worker_name']);
    final dp = Provider.of<DataProvider>(context, listen: false);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dp.currentCardColor,
          title: Text("メンバー情報の編集", style: TextStyle(color: dp.mainTextColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: member['worker_id']),
                enabled: false,
                style: TextStyle(color: dp.subTextColor),
                decoration: InputDecoration(labelText: "社員ID (変更不可)", labelStyle: TextStyle(color: dp.subTextColor)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: dp.mainTextColor),
                decoration: InputDecoration(
                  labelText: "氏名", 
                  labelStyle: TextStyle(color: dp.mainTextColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dp.borderColor)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isWhite ? Colors.blue : Colors.blueAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("キャンセル", style: TextStyle(color: dp.subTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isWhite ? Colors.blue.shade700 : Colors.blueAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("保存", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );

    if (result == true && nameCtrl.text.isNotEmpty) {
      try {
        final conn = await MySQLConnection.createConnection(
          host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db',
        );
        await conn.connect();
        await conn.execute('UPDATE m_members SET worker_name = :name WHERE worker_id = :id', {
          'name': nameCtrl.text,
          'id': member['worker_id'],
        });
        await conn.close();
        if (mounted) {
          Navigator.pop(context);
          _fetchMasterData();
          _showSuccessDialog("更新完了！", "メンバー情報を更新しました。");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("エラー: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _deleteMember(Map<String, String> member) async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dp.currentCardColor,
          title: Text("メンバーの削除", style: TextStyle(color: Colors.redAccent)),
          content: Text("${member['worker_name']} さん (ID: ${member['worker_id']}) を削除しますか？\n※関連する過去の実績表示に影響が出る可能性があります。", style: TextStyle(color: dp.mainTextColor)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("キャンセル", style: TextStyle(color: dp.subTextColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("削除する", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );

    if (result == true) {
      try {
        final conn = await MySQLConnection.createConnection(host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db');
        await conn.connect();
        await conn.execute('DELETE FROM m_members WHERE worker_id = :id', {'id': member['worker_id']});
        await conn.close();
        if (mounted) {
          Navigator.pop(context);
          _fetchMasterData();
          _showSuccessDialog("削除完了", "メンバーをマスターから削除しました。");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("エラー: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _editModel(Map<String, String> model) async {
    final TextEditingController idCtrl = TextEditingController(text: model['model_id']);
    final TextEditingController nameCtrl = TextEditingController(text: model['model_name']);
    final TextEditingController makerCtrl = TextEditingController(text: model['maker']);
    final TextEditingController abbrCtrl = TextEditingController(text: model['maker_abbr']);
    final TextEditingController catCtrl = TextEditingController(text: model['category']);
    final TextEditingController workTypeCtrl = TextEditingController(text: model['work_type']);
    final TextEditingController stdCtrl = TextEditingController(text: model['std_qty']);
    
    final dp = Provider.of<DataProvider>(context, listen: false);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dp.currentCardColor,
          title: Text("機種マスターの編集", style: TextStyle(color: dp.mainTextColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(idCtrl, "機種ID", Icons.qr_code, dp, isWhite),
                _buildField(nameCtrl, "機種名", Icons.text_fields, dp, isWhite),
                _buildFieldWithDropdown(makerCtrl, "メーカー", Icons.business, ["三菱", "富士通", "沖", "NEC", "住友", "日立", "PMC", "サクサ", "ナカヨ", "シスコ", "トレンドマイクロ", "三菱/三菱", "富士通/三菱", "富士通/沖", "沖/沖", "三菱/沖", "日立/三菱", "日立/沖", "沖/三菱"], dp, isWhite),
                _buildFieldWithDropdown(abbrCtrl, "メーカー略称", Icons.short_text, ["M", "FA", "O", "N", "S", "H", "D", "E", "M/M", "F/M", "F/O", "O/O", "M/O", "H/M", "H/O", "O/M"], dp, isWhite),
                _buildFieldWithDropdown(catCtrl, "分類", Icons.category, ["単体型", "一体型", "情報機器", "カード", "SFP"], dp, isWhite),
                _buildFieldWithDropdown(workTypeCtrl, "作業内容", Icons.build, ["エアー清掃", "清掃", "筐体交換"], dp, isWhite),
                _buildField(stdCtrl, "1時間標準作業台数", Icons.timer, dp, isWhite, isNumber: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("キャンセル", style: TextStyle(color: dp.subTextColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isWhite ? Colors.orange.shade700 : Colors.orangeAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("保存", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );

    if (result == true) {
      try {
        final conn = await MySQLConnection.createConnection(host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db');
        await conn.connect();
        await conn.execute(
          'UPDATE m_models SET model_id = :modelId, model_name = :name, maker = :maker, maker_abbr = :abbr, category = :cat, work_type = :workType, std_qty = :std WHERE model_id = :oldModelId', 
          {
            'modelId': idCtrl.text,
            'name': nameCtrl.text,
            'maker': makerCtrl.text,
            'abbr': abbrCtrl.text,
            'cat': catCtrl.text,
            'workType': workTypeCtrl.text,
            'std': stdCtrl.text,
            'oldModelId': model['model_id'],
          }
        );
        await conn.close();
        if (mounted) {
          Navigator.pop(context);
          _fetchMasterData();
          _showSuccessDialog("更新完了！", "機種情報を更新しました。");
        }
      } catch (e) {
        if (mounted) {
          String errMsg = e.toString();
          if (errMsg.contains('1062')) {
            errMsg = "この機種IDはすでに別の機種で登録されています（重複不可）。";
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("エラー: $errMsg"), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  Future<void> _deleteModel(Map<String, String> model) async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dp.currentCardColor,
          title: Text("機種の削除", style: TextStyle(color: Colors.redAccent)),
          content: Text("${model['model_name']} を削除しますか？\n※関連する過去の実績表示に影響が出る可能性があります。", style: TextStyle(color: dp.mainTextColor)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("キャンセル", style: TextStyle(color: dp.subTextColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("削除する", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );

    if (result == true) {
      try {
        final conn = await MySQLConnection.createConnection(host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db');
        await conn.connect();
        await conn.execute('DELETE FROM m_models WHERE csv_id = :id', {'id': model['csv_id']});
        await conn.close();
        if (mounted) {
          Navigator.pop(context);
          _fetchMasterData();
          _showSuccessDialog("削除完了", "機種をマスターから削除しました。");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("エラー: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _addModel() async {
    final TextEditingController idCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController makerCtrl = TextEditingController();
    final TextEditingController abbrCtrl = TextEditingController();
    final TextEditingController catCtrl = TextEditingController();
    final TextEditingController workTypeCtrl = TextEditingController(text: "エアー清掃");
    final TextEditingController stdCtrl = TextEditingController(text: "10");

    final dp = Provider.of<DataProvider>(context, listen: false);
    final isWhite = dp.displayMode == DisplayMode.pureWhite;

    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dp.currentCardColor,
          title: Text("機種マスターの新規追加", style: TextStyle(color: dp.mainTextColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: idCtrl, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "機種ID (例: KB1234)", labelStyle: TextStyle(color: dp.mainTextColor))),
                TextField(controller: nameCtrl, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "機種名 (例: K-32)", labelStyle: TextStyle(color: dp.mainTextColor))),
                TextField(controller: makerCtrl, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "メーカー (例: SANKYO)", labelStyle: TextStyle(color: dp.mainTextColor))),
                TextField(controller: abbrCtrl, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "メーカー略称 (例: S)", labelStyle: TextStyle(color: dp.mainTextColor))),
                TextField(controller: catCtrl, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "分類 (例: P)", labelStyle: TextStyle(color: dp.mainTextColor))),
                TextField(controller: workTypeCtrl, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "作業内容 (エアー清掃/清掃/筐体交換)", labelStyle: TextStyle(color: dp.mainTextColor))),
                TextField(controller: stdCtrl, keyboardType: TextInputType.number, style: TextStyle(color: dp.mainTextColor), decoration: InputDecoration(labelText: "1時間標準作業台数 (例: 10)", labelStyle: TextStyle(color: dp.mainTextColor))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("キャンセル", style: TextStyle(color: dp.subTextColor))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isWhite ? Colors.orange.shade700 : Colors.orangeAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("追加する", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );

    if (result == true && idCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
      try {
        final conn = await MySQLConnection.createConnection(host: '192.168.10.101', port: 3306, userName: 'work_user', password: 'work1234', databaseName: 'work_manager_db');
        await conn.connect();
        
        // 現在の最大の csv_id を取得して +1 する
        final maxRes = await conn.execute('SELECT MAX(CAST(csv_id AS UNSIGNED)) AS max_id FROM m_models');
        int nextCsvId = 1;
        if (maxRes.rows.isNotEmpty && maxRes.rows.first.assoc()['max_id'] != null) {
          nextCsvId = int.parse(maxRes.rows.first.assoc()['max_id']!) + 1;
        }

        await conn.execute(
          'INSERT INTO m_models (csv_id, model_id, model_name, maker, maker_abbr, category, work_type, std_qty) '
          'VALUES (:csvId, :modelId, :name, :maker, :abbr, :cat, :workType, :std)', 
          {
            'csvId': nextCsvId.toString(),
            'modelId': idCtrl.text,
            'name': nameCtrl.text,
            'maker': makerCtrl.text,
            'abbr': abbrCtrl.text,
            'cat': catCtrl.text,
            'workType': workTypeCtrl.text,
            'std': stdCtrl.text,
          }
        );
        await conn.close();
        if (mounted) {
          _fetchMasterData();
          _showSuccessDialog("追加完了！", "「${nameCtrl.text}」をマスターに追加しました。");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("追加エラー: $e"), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, DataProvider dp, bool isWhite, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: dp.mainTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dp.subTextColor, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: isWhite ? Colors.grey.shade600 : Colors.grey.shade400),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dp.borderColor)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent)),
      ),
    );
  }

  Widget _buildFieldWithDropdown(TextEditingController ctrl, String label, IconData icon, List<String> options, DataProvider dp, bool isWhite) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: dp.mainTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dp.subTextColor, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: isWhite ? Colors.grey.shade600 : Colors.grey.shade400),
        suffixIcon: PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isWhite ? Colors.blue.shade50 : Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isWhite ? Colors.blue.shade300 : Colors.blueAccent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("選択", style: TextStyle(color: isWhite ? Colors.blue.shade700 : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                Icon(Icons.arrow_drop_down, color: isWhite ? Colors.blue.shade700 : Colors.blueAccent, size: 16),
              ],
            ),
          ),
          tooltip: "リストから選択",
          onSelected: (String value) {
            ctrl.text = value; // 選択されたらテキストフィールドを上書き
          },
          itemBuilder: (BuildContext context) {
            return options.map((String choice) {
              return PopupMenuItem<String>(
                value: choice,
                child: Text(choice),
              );
            }).toList();
          },
        ),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dp.borderColor)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent)),
      ),
    );
  }

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
          "データベース運用設定",
          style: TextStyle(fontWeight: FontWeight.bold, color: dp.mainTextColor),
        ),
        iconTheme: IconThemeData(color: dp.mainTextColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: isWhite ? Colors.purple.shade700 : Colors.purpleAccent))
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMsg,
                    style: TextStyle(color: Colors.redAccent, fontSize: 18),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      // 左側: メンバーリスト
                      Expanded(
                        flex: 4,
                        child: _buildListCard(
                          title: "作業員マスター (${_members.length}件)",
                          icon: Icons.people_alt_rounded,
                          color: isWhite ? Colors.blue.shade700 : Colors.blueAccent,
                          dp: dp,
                          isWhite: isWhite,
                          child: ListView.separated(
                            itemCount: _members.length,
                            separatorBuilder: (context, index) => Divider(color: isWhite ? Colors.grey.shade300 : Colors.white24, height: 1),
                            itemBuilder: (context, index) {
                              final mem = _members[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (isWhite ? Colors.blue.shade100 : Colors.blue.withOpacity(0.2)),
                                  child: Icon(Icons.person, color: isWhite ? Colors.blue.shade700 : Colors.blueAccent),
                                ),
                                title: Text(mem['worker_name']!, style: TextStyle(color: dp.mainTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
                                subtitle: Text("ID: ${mem['worker_id']}", style: TextStyle(color: dp.subTextColor, fontSize: 14)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, color: isWhite ? Colors.blue.shade600 : Colors.blueAccent),
                                      onPressed: () => _editMember(mem),
                                      tooltip: "編集",
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _deleteMember(mem),
                                      tooltip: "削除",
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 右側: 機種リスト
                      Expanded(
                        flex: 6,
                        child: _buildListCard(
                          title: "機種マスター (${_models.length}件)",
                          icon: Icons.devices_rounded,
                          color: isWhite ? Colors.orange.shade700 : Colors.orangeAccent,
                          dp: dp,
                          isWhite: isWhite,
                          child: ListView.separated(
                            itemCount: _models.length,
                            separatorBuilder: (context, index) => Divider(color: isWhite ? Colors.grey.shade300 : Colors.white24, height: 1),
                            itemBuilder: (context, index) {
                              final mod = _models[index];
                              
                              Color tileBgColor;
                              Color avatarBgColor;
                              Color avatarIconColor;

                              if (mod['work_type'] == "エアー清掃") {
                                tileBgColor = isWhite ? const Color(0xFFD4EFFF) : const Color(0xFF007799).withOpacity(0.25);
                                avatarBgColor = isWhite ? const Color(0xFFB3E0FF) : const Color(0xFF007799).withOpacity(0.5);
                                avatarIconColor = isWhite ? const Color(0xFF005580) : const Color(0xFF00E5FF);
                              } else if (mod['work_type'] == "清掃" || mod['work_type'] == "通常清掃") {
                                tileBgColor = isWhite ? const Color(0xFFD4F7E6) : const Color(0xFF008855).withOpacity(0.25);
                                avatarBgColor = isWhite ? const Color(0xFFB3F0D1) : const Color(0xFF008855).withOpacity(0.5);
                                avatarIconColor = isWhite ? const Color(0xFF006633) : const Color(0xFF00FFCC);
                              } else if (mod['work_type'] == "筐体交換") {
                                tileBgColor = isWhite ? const Color(0xFFFFEBD6) : Colors.amber.shade900.withOpacity(0.3);
                                avatarBgColor = isWhite ? const Color(0xFFFFD6AD) : Colors.amber.shade900.withOpacity(0.6);
                                avatarIconColor = isWhite ? Colors.deepOrange.shade800 : Colors.amberAccent;
                              } else {
                                tileBgColor = Colors.transparent;
                                avatarBgColor = isWhite ? Colors.grey.shade300 : Colors.white12;
                                avatarIconColor = isWhite ? Colors.grey.shade800 : Colors.grey;
                              }

                              return Container(
                                color: tileBgColor,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: avatarBgColor,
                                    child: Icon(Icons.router_rounded, color: avatarIconColor),
                                  ),
                                  title: Text(mod['model_name']!, style: TextStyle(color: dp.mainTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
                                  subtitle: Text(
                                    "メーカー: ${mod['maker']} (${mod['maker_abbr']})   |   作業: ${mod['work_type']}   |   標準台数: ${mod['std_qty']}台/h",
                                    style: TextStyle(color: dp.subTextColor, fontSize: 14),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: isWhite ? Colors.orange.shade700 : Colors.orangeAccent),
                                        onPressed: () => _editModel(mod),
                                        tooltip: "編集",
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteModel(mod),
                                        tooltip: "削除",
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // BottomSheetを出してどちらを追加するか選ばせる
          showModalBottomSheet(
            context: context,
            backgroundColor: dp.currentCardColor,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (BuildContext context) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("データ追加メニュー", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dp.mainTextColor)),
                      const SizedBox(height: 20),
                      // 💡 プラットフォームに応じて表示を切り替え
                      if (!Platform.isWindows)
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.2), child: const Icon(Icons.qr_code_scanner, color: Colors.purpleAccent)),
                          title: Text("メンバーの新規追加", style: TextStyle(color: dp.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          subtitle: Text("カメラでQRをスキャンして追加します", style: TextStyle(color: dp.subTextColor, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(context);
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MemberAddScannerPage()),
                            );
                            if (result == true) _fetchMasterData();
                          },
                        ),
                      if (Platform.isWindows || Platform.isMacOS)
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.2), child: const Icon(Icons.nfc, color: Colors.purpleAccent)),
                          title: Text("メンバーの新規追加", style: TextStyle(color: dp.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          subtitle: Text("NFCリーダー（PaSoRi）でかざして追加します", style: TextStyle(color: dp.subTextColor, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(context);
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MemberAddNfcPage()),
                            );
                            if (result == true) _fetchMasterData();
                          },
                        ),
                      
                      Divider(color: dp.borderColor),
                      
                      if (!Platform.isWindows)
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.2), child: const Icon(Icons.qr_code_scanner, color: Colors.orangeAccent)),
                          title: Text("機種マスターの新規追加", style: TextStyle(color: dp.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          subtitle: Text("カメラでQRをスキャンして追加します", style: TextStyle(color: dp.subTextColor, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(context);
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ModelAddScannerPage()),
                            );
                            if (result == true) _fetchMasterData();
                          },
                        ),
                      if (Platform.isWindows || Platform.isMacOS)
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.2), child: const Icon(Icons.nfc, color: Colors.orangeAccent)),
                          title: Text("機種マスターの新規追加", style: TextStyle(color: dp.mainTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          subtitle: Text("NFCリーダー（PaSoRi）でかざして追加します", style: TextStyle(color: dp.subTextColor, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(context);
                            bool? result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ModelAddNfcPage()),
                            );
                            if (result == true) _fetchMasterData();
                          },
                        ),
                    ],
                  ),
                ),
              );
            }
          );
        },
        backgroundColor: isWhite ? Colors.blue.shade700 : Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("データを追加", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 画面全体(中央)に大きく成功メッセージを表示する共通メソッド
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 18, color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard({
    required String title,
    required IconData icon,
    required Color color,
    required DataProvider dp,
    required bool isWhite,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: dp.currentCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dp.borderColor),
        boxShadow: isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))] : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: isWhite ? color.withOpacity(0.1) : color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: isWhite ? color.withOpacity(0.3) : color.withOpacity(0.5), width: 2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isWhite ? color : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
