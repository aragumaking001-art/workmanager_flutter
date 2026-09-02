# Workmanager
このリポジトリには、Flutterアプリ（フロントエンド）およびPythonアプリ（バックグラウンド処理、ダッシュボード等）が含まれています。

## 新しいPCでの環境構築手順

### 1. Flutterアプリのビルド（exe化）
新しいPCにFlutter SDKをインストールし、環境変数にパスを通した上で、以下のコマンドを実行してください。

```bash
# 依存パッケージのインストール
flutter pub get

# Windows用実行ファイルのビルド
flutter build windows
```
ビルド完了後、`build\windows\x64\runner\Release\` フォルダ内に `workmanager_flutter.exe` が生成されます。

### 2. Pythonアプリのビルド（exe化）
新しいPCにPython（3.x系）をインストールし、以下の手順でビルドしてください。

```bash
# 依存パッケージのインストール
pip install -r requirements.txt
pip install pyinstaller

# exeのビルドスクリプトを実行
build_python.bat
```
ビルド完了後、`dist\` フォルダ内に `dashboard_workplace.exe` および `work_app.exe` が生成されます。

---

**※注意事項**
- データベースの接続情報（IPアドレス、ポートなど）が新しいPCの環境と異なる場合は、必要に応じて `data_provider.dart` や各Pythonスクリプト内のIPアドレスを変更して再ビルドしてください。
- 実行時に必要なアセットフォルダ等（例: `assets/` フォルダの音声ファイルなど）は、別途アプリケーションの実行パスに合わせて配置してください。
