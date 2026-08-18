import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class MemberAddScannerPage extends StatefulWidget {
  const MemberAddScannerPage({super.key});

  @override
  State<MemberAddScannerPage> createState() => _MemberAddScannerPageState();
}

class _MemberAddScannerPageState extends State<MemberAddScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final TextEditingController _workerIdCtrl = TextEditingController();
  final TextEditingController _workerNameCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isScanning = true; // カメラがスキャン中かどうかのフラグ
  int _quarterTurns = 3; // カメラ映像の回転用変数 (デフォルトを270度に設定)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialGuidance();
    });
  }

  void _showInitialGuidance() {
    showDialog(
      context: context,
      barrierDismissible: false, // 画面外タップで閉じないようにする
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
          "QRコードをスキャンする前に、以下の準備をお願いします。\n\n"
          "1. PCで「nfc_to_qr.exe」を起動する\n"
          "2. ツール上で「タブレット用 (QR出力)」を選択する\n"
          "3. 登録したい社員証をPCのPaSoRiにかざす\n"
          "4. PC画面にQRコードが表示されたら準備完了！",
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
              onPressed: () => Navigator.pop(context),
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
    _scannerController.dispose();
    _workerIdCtrl.dispose();
    _workerNameCtrl.dispose();
    super.dispose();
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
        // SnackBarの代わりに画面全体(中央)に大きく成功メッセージを表示
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
          "メンバー追加 (QRスキャン)",
          style: TextStyle(
            color: dp.mainTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: dp.mainTextColor),
      ),
      body: Column(
        children: [
          // カメラプレビュー領域
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black, // カメラ停止時の背景色
              child: _isScanning
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              if (!_isScanning) return; // スキャン停止中は無視
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty &&
                                  barcodes.first.rawValue != null) {
                                final code = barcodes.first.rawValue!;
                                // まだ入力されていなければセット
                                if (_workerIdCtrl.text.isEmpty ||
                                    _workerIdCtrl.text != code) {
                                  setState(() {
                                    _workerIdCtrl.text = code;
                                    _isScanning = false; // 読み取り成功でカメラ停止
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("QRコードを読み取りました！"),
                                      backgroundColor: Colors.blueAccent,
                                      duration: Duration(milliseconds: 1500),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        // スキャン枠 UI
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.purpleAccent.withOpacity(0.5),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          width: 250,
                          height: 250,
                        ),
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "PC上のQRコードを枠内に映してください",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        // 映像回転ボタン
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.rotate_90_degrees_ccw,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: "映像を90度回転",
                              onPressed: () {
                                setState(() {
                                  _quarterTurns = (_quarterTurns + 1) % 4;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
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
                            "QRコードを読み取りました",
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
                                _isScanning = true;
                              });
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
            ),
          ),
          // フォーム領域
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
                      style: TextStyle(
                        color: dp.mainTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: "社員ID (QRスキャン)",
                        labelStyle: TextStyle(color: dp.subTextColor),
                        prefixIcon: Icon(
                          Icons.qr_code,
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
