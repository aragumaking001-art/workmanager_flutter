import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class MemberAddNfcPage extends StatefulWidget {
  const MemberAddNfcPage({super.key});

  @override
  State<MemberAddNfcPage> createState() => _MemberAddNfcPageState();
}

class _MemberAddNfcPageState extends State<MemberAddNfcPage> {
  final TextEditingController _workerIdCtrl = TextEditingController();
  final TextEditingController _workerNameCtrl = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();

  bool _isSaving = false;
  bool _isScanning = true; // NFC待ち状態

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialGuidance();
      // ダイアログが出ている間はフォーカスできないので、ダイアログを閉じた後にフォーカスする
    });
  }

  void _showInitialGuidance() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blueAccent, size: 28),
            SizedBox(width: 10),
            Text(
              "事前準備のお願い",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "カードをスキャンする前に、以下の準備をお願いします。\n\n"
          "1. PCで「nfc_to_qr.exe」を起動する\n"
          "2. ツール上で「PC用 (キーボード自動入力)」を選択する\n"
          "3. 準備完了ボタンを押し、PCのPaSoRiにカードをかざす",
          style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _idFocusNode.requestFocus();
              },
              child: const Text(
                "準備完了 (スキャン開始)",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _workerIdCtrl.dispose();
    _workerNameCtrl.dispose();
    _idFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onNfcScanned(String code) {
    if (code.isEmpty) return;

    setState(() {
      _workerIdCtrl.text = code.toUpperCase();
      _isScanning = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("カードを読み取りました！氏名を入力してください。"),
        backgroundColor: Colors.blueAccent,
        duration: Duration(milliseconds: 1500),
      ),
    );

    // 氏名欄にフォーカスを移動
    Future.delayed(const Duration(milliseconds: 100), () {
      _nameFocusNode.requestFocus();
    });
  }

  Future<void> _saveMember() async {
    final wid = _workerIdCtrl.text.trim();
    final wname = _workerNameCtrl.text.trim();

    if (wid.isEmpty || wname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("社員IDと氏名の両方を入力してください"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
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

      // 重複チェック
      final checkRes = await conn.execute(
        'SELECT worker_name FROM m_members WHERE worker_id = :id',
        {'id': wid},
      );

      if (checkRes.rows.isNotEmpty) {
        final existingName = checkRes.rows.first.assoc()['worker_name'] ?? '不明';
        await conn.close();
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                  SizedBox(width: 8),
                  Text(
                    "登録済みエラー",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                "この社員IDは既に\n「$existingName」さん\nとして登録されています。\n\n別のカードを使用するか、一覧から編集してください。",
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK", style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 重複がなければINSERT
      await conn.execute(
        'INSERT INTO m_members (worker_id, worker_name, ai_tone) VALUES (:id, :name, :tone)',
        {'id': wid, 'name': wname, 'tone': '標準'},
      );

      // AIレポートの初期データも作成
      await conn.execute(
        'INSERT INTO t_ai_reports (target_date, worker_id, worker_name, report_content) VALUES (CURRENT_DATE(), :id, :name, :report)',
        {
          'id': wid,
          'name': wname,
          'report':
              '【AI分析レポート】\n$wname さん、新規登録ありがとうございます！\nこれから一緒に頑張りましょう。システムが日々の作業を分析し、こちらにアドバイスを表示します。',
        },
      );

      // データ更新トラッカーを更新してUIを自動リロードさせる
      await conn.execute(
        'UPDATE data_update_tracker SET last_updated = NOW() WHERE id = 1',
      );

      await conn.close();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 20),
                const Text(
                  "登録完了！",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "新規メンバーをマスターに登録しました。",
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (mounted) Navigator.pop(context, true); // スキャナー画面を閉じてリスト更新
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("登録エラー: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
          "メンバー追加 (NFCリーダー)",
          style: TextStyle(
            color: dp.mainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: dp.mainTextColor),
      ),
      body: Column(
        children: [
          // 上部：NFC待機領域
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF0F1115),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isScanning)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.nfc,
                          size: 100,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "NFCリーダーにカードをかざしてください",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "※nfc_to_qrツールを「PC用」モードで起動してください",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        // 非表示の入力フォームは削除しました
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {
                            _idFocusNode.requestFocus();
                          },
                          icon: const Icon(Icons.keyboard),
                          label: const Text("入力欄を選択する"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.greenAccent,
                            size: 80,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "カードを読み取りました",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _workerIdCtrl.clear();
                                _workerNameCtrl.clear();
                                _isScanning = true;
                              });
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () => _idFocusNode.requestFocus(),
                              );
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              "もう一度スキャンする",
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 下部：フォーム領域
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: dp.currentCardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: isWhite
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ]
                    : null,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _workerIdCtrl,
                      focusNode: _idFocusNode,
                      onSubmitted: (val) {
                        _onNfcScanned(val);
                      },
                      style: TextStyle(
                        color: dp.mainTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: "社員ID (NFCスキャンまたは手入力)",
                        labelStyle: TextStyle(color: dp.subTextColor),
                        prefixIcon: Icon(
                          Icons.nfc,
                          color: isWhite
                              ? Colors.purple.shade700
                              : Colors.purpleAccent,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: dp.borderColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isWhite
                                ? Colors.purple.shade700
                                : Colors.purpleAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _workerNameCtrl,
                      focusNode: _nameFocusNode,
                      style: TextStyle(color: dp.mainTextColor, fontSize: 20),
                      decoration: InputDecoration(
                        labelText: "氏名",
                        labelStyle: TextStyle(color: dp.subTextColor),
                        prefixIcon: Icon(
                          Icons.person,
                          color: isWhite
                              ? Colors.blue.shade700
                              : Colors.blueAccent,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: dp.borderColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isWhite
                                ? Colors.blue.shade700
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite
                              ? Colors.purple.shade700
                              : Colors.purpleAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveMember,
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "マスターに登録する",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
