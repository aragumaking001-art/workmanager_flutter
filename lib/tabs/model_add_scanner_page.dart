import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class ModelAddScannerPage extends StatefulWidget {
  const ModelAddScannerPage({super.key});

  @override
  State<ModelAddScannerPage> createState() => _ModelAddScannerPageState();
}

class _ModelAddScannerPageState extends State<ModelAddScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  final TextEditingController _modelIdCtrl = TextEditingController();
  final TextEditingController _modelNameCtrl = TextEditingController();
  final TextEditingController _makerCtrl = TextEditingController();
  final TextEditingController _makerAbbrCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _workTypeCtrl = TextEditingController(
    text: "エアー清掃",
  );
  final TextEditingController _stdQtyCtrl = TextEditingController(text: "10");

  bool _isSaving = false;
  bool _isScanning = true;
  int _quarterTurns = 3;

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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orangeAccent, size: 28),
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
          "3. 登録したい機種カードをPCのPaSoRiにかざす\n"
          "4. PC画面にQRコードが表示されたら準備完了！",
          style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
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
    _modelIdCtrl.dispose();
    _modelNameCtrl.dispose();
    _makerCtrl.dispose();
    _makerAbbrCtrl.dispose();
    _categoryCtrl.dispose();
    _workTypeCtrl.dispose();
    _stdQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveModel() async {
    final mid = _modelIdCtrl.text.trim();
    final mname = _modelNameCtrl.text.trim();
    final maker = _makerCtrl.text.trim();
    final abbr = _makerAbbrCtrl.text.trim();
    final cat = _categoryCtrl.text.trim();
    final work = _workTypeCtrl.text.trim();
    final std = _stdQtyCtrl.text.trim();

    if (mid.isEmpty || mname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("機種IDと機種名は必須入力です"),
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
        'SELECT model_name FROM m_models WHERE model_id = :id',
        {'id': mid},
      );

      if (checkRes.rows.isNotEmpty) {
        final existingName = checkRes.rows.first.assoc()['model_name'] ?? '不明';
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
                "この機種IDは既に\n「$existingName」\nとして登録されています。\n\n一覧から編集してください。",
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

      // 最大csv_idを取得
      final maxRes = await conn.execute(
        'SELECT MAX(CAST(csv_id AS UNSIGNED)) AS max_id FROM m_models',
      );
      int nextCsvId = 1;
      if (maxRes.rows.isNotEmpty &&
          maxRes.rows.first.assoc()['max_id'] != null) {
        nextCsvId = int.parse(maxRes.rows.first.assoc()['max_id']!) + 1;
      }

      await conn.execute(
        'INSERT INTO m_models (csv_id, model_id, model_name, maker, maker_abbr, category, work_type, std_qty) '
        'VALUES (:csvId, :modelId, :name, :maker, :abbr, :cat, :workType, :std)',
        {
          'csvId': nextCsvId.toString(),
          'modelId': mid,
          'name': mname,
          'maker': maker,
          'abbr': abbr,
          'cat': cat,
          'workType': work,
          'std': std,
        },
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
                const Icon(
                  Icons.check_circle,
                  color: Colors.orangeAccent,
                  size: 80,
                ),
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
                  "新しい機種をマスターに登録しました。",
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
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
        if (mounted) Navigator.pop(context, true);
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
          "機種追加 (QRスキャン)",
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
            flex: 2,
            child: Container(
              color: Colors.black,
              child: _isScanning
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              if (!_isScanning) return;
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty &&
                                  barcodes.first.rawValue != null) {
                                final code = barcodes.first.rawValue!;
                                if (_modelIdCtrl.text.isEmpty ||
                                    _modelIdCtrl.text != code) {
                                  setState(() {
                                    _modelIdCtrl.text = code;
                                    _isScanning = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("QRコードを読み取りました！"),
                                      backgroundColor: Colors.orangeAccent,
                                      duration: Duration(milliseconds: 1500),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.orangeAccent.withOpacity(0.5),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          width: 250,
                          height: 250,
                        ),
                        Positioned(
                          bottom: 10,
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
                              "PC上のQRコードを映してください",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
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
                              onPressed: () => setState(
                                () => _quarterTurns = (_quarterTurns + 1) % 4,
                              ),
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
                            color: Colors.orangeAccent,
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
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _modelIdCtrl.clear();
                              _isScanning = true;
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              "もう一度スキャンする",
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          // フォーム領域
          Expanded(
            flex: 3,
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
                      controller: _modelIdCtrl,
                      style: TextStyle(
                        color: dp.mainTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: "機種ID (QRスキャン)",
                        labelStyle: TextStyle(color: dp.subTextColor),
                        prefixIcon: Icon(
                          Icons.qr_code,
                          color: isWhite
                              ? Colors.orange.shade700
                              : Colors.orangeAccent,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: dp.borderColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isWhite
                                ? Colors.orange.shade700
                                : Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            _modelNameCtrl,
                            "機種名",
                            Icons.router,
                            dp,
                            isWhite,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildFieldWithDropdown(
                            _makerCtrl,
                            "メーカー",
                            Icons.business,
                            [
                              "三菱",
                              "富士通",
                              "沖",
                              "NEC",
                              "住友",
                              "日立",
                              "PMC",
                              "サクサ",
                              "ナカヨ",
                              "シスコ",
                              "トレンドマイクロ",
                              "三菱/三菱",
                              "富士通/三菱",
                              "富士通/沖",
                              "沖/沖",
                              "三菱/沖",
                              "日立/三菱",
                              "日立/沖",
                              "沖/三菱",
                            ],
                            dp,
                            isWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFieldWithDropdown(
                            _makerAbbrCtrl,
                            "メーカー略称",
                            Icons.short_text,
                            [
                              "M",
                              "FA",
                              "O",
                              "N",
                              "S",
                              "H",
                              "D",
                              "E",
                              "M/M",
                              "F/M",
                              "F/O",
                              "O/O",
                              "M/O",
                              "H/M",
                              "H/O",
                              "O/M",
                            ],
                            dp,
                            isWhite,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildFieldWithDropdown(
                            _categoryCtrl,
                            "分類",
                            Icons.category,
                            ["単体型", "一体型", "情報機器", "カード", "SFP"],
                            dp,
                            isWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFieldWithDropdown(
                            _workTypeCtrl,
                            "作業内容",
                            Icons.build,
                            ["エアー清掃", "清掃", "筐体交換"],
                            dp,
                            isWhite,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildField(
                            _stdQtyCtrl,
                            "1時間標準台数",
                            Icons.timer,
                            dp,
                            isWhite,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWhite
                              ? Colors.orange.shade700
                              : Colors.orangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveModel,
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

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    DataProvider dp,
    bool isWhite, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: dp.mainTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dp.subTextColor, fontSize: 14),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: isWhite ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: dp.borderColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: isWhite ? Colors.orange.shade700 : Colors.orangeAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldWithDropdown(
    TextEditingController ctrl,
    String label,
    IconData icon,
    List<String> options,
    DataProvider dp,
    bool isWhite,
  ) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: dp.mainTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dp.subTextColor, fontSize: 14),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: isWhite ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
        suffixIcon: PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isWhite ? Colors.blue.shade50 : Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isWhite ? Colors.blue.shade300 : Colors.blueAccent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "選択",
                  style: TextStyle(
                    color: isWhite ? Colors.blue.shade700 : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: isWhite ? Colors.blue.shade700 : Colors.blueAccent,
                  size: 16,
                ),
              ],
            ),
          ),
          tooltip: "リストから選択",
          onSelected: (String value) {
            ctrl.text = value; // 選択されたらテキストフィールドを上書き
          },
          itemBuilder: (BuildContext context) {
            return options.map((String choice) {
              return PopupMenuItem<String>(value: choice, child: Text(choice));
            }).toList();
          },
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: dp.borderColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: isWhite ? Colors.orange.shade700 : Colors.orangeAccent,
          ),
        ),
      ),
    );
  }
}
