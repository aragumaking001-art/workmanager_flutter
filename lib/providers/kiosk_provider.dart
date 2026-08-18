import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class KioskProvider extends ChangeNotifier {
  Timer? _pollingTimer;
  String? _lastCardId;
  double _lastTimestamp = 0;
  
  // 💡 アプリ起動時刻を記録し、これより前の「残骸データ」は無視する
  final double _startupTimestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;

  // 現在表示中の作業者ID（nullなら待機中）
  String? currentWorkerId;

  KioskProvider() {
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkNfcStatus();
    });
  }

  Future<void> _checkNfcStatus() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 1); // タイムアウトを短く設定
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:8080/api/nfc/status'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody);
        
        final String? cardId = data['card_id'];
        final num? ts = data['timestamp'];
        final double timestamp = ts != null ? ts.toDouble() : 0.0;
        
        if (cardId != null && cardId.isNotEmpty) {
          // 💡 起動時刻より新しいデータ、かつ（カードIDが変わった or タイムスタンプが更新された）場合のみ反応
          if (timestamp > _startupTimestamp) {
            if (cardId != _lastCardId || timestamp > _lastTimestamp) {
              _lastCardId = cardId;
              _lastTimestamp = timestamp;
              
              // 新しいカードが読まれた
              _onCardScanned(cardId);
            }
          }
        }
      }
      client.close();
    } catch (e) {
      // サーバーが立っていない、通信エラーなどは無視
    }
  }

  void _onCardScanned(String cardId) {
    // 取得したカードIDをそのままワーカーIDとする
    currentWorkerId = cardId;
    notifyListeners();
  }

  void resetToStandby() {
    currentWorkerId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
