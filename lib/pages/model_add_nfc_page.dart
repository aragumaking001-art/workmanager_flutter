import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class ModelAddNfcPage extends StatefulWidget {
  const ModelAddNfcPage({super.key});

  @override
  State<ModelAddNfcPage> createState() => _ModelAddNfcPageState();
}

class _ModelAddNfcPageState extends State<ModelAddNfcPage> {
  final TextEditingController _modelIdCtrl = TextEditingController();
  final TextEditingController _modelNameCtrl = TextEditingController();
  final TextEditingController _makerCtrl = TextEditingController();
  final TextEditingController _makerAbbrCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();
  final TextEditingController _workTypeCtrl = TextEditingController(text: "エアー清掃");
  final TextEditingController _stdQtyCtrl = TextEditingController(text: "10");
  
  final FocusNode _idFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();

  bool _isSaving = false;
  bool _isScanning = true; // NFC待ち状態

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
                backgroundColor: Colors.orangeAccent,
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
    _modelIdCtrl.dispose();
    _modelNameCtrl.dispose();
    _makerCtrl.dispose();
    _makerAbbrCtrl.dispose();
    _categoryCtrl.dispose();
    _workTypeCtrl.dispose();
    _stdQtyCtrl.dispose();
    _idFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onNfcScanned(String code) {
    if (code.isEmpty) return;

    setState(() {
      _modelIdCtrl.text = code.toUpperCase();
      _isScanning = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("カードを読み取りました！機種情報を入力してください。"),
        backgroundColor: Colors.orangeAccent,
        duration: Duration(milliseconds: 1500),
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _nameFocusNode.requestFocus();
    });
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
          "機種マスター追加 (NFCリーダー)",
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
                        const Icon(Icons.nfc, size: 100, color: Colors.orangeAccent),
                        const SizedBox(height: 20),
                        const Text(
                          "NFCリーダーにカードをかざしてください",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                        )
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
                                _modelIdCtrl.clear();
                                _isScanning = true;
                              });
                              Future.delayed(const Duration(milliseconds: 100), () => _idFocusNode.requestFocus());
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
                      focusNode: _idFocusNode,
                      onSubmitted: (val) {
                        _onNfcScanned(val);
                      },
                      style: TextStyle(
                        color: dp.mainTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: "機種ID (NFCスキャンまたは手入力)",
                        labelStyle: TextStyle(color: dp.subTextColor),
                        prefixIcon: Icon(
                          Icons.nfc,
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
                            focusNode: _nameFocusNode,
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
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
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
