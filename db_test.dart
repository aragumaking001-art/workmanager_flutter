import 'package:mysql_client/mysql_client.dart';
import 'dart:io';

Future<void> main() async {
  final conn = await MySQLConnection.createConnection(
    host: '192.168.10.101',
    port: 3306,
    userName: 'work_user',
    password: 'work1234',
    databaseName: 'work_manager_db',
  );

  await conn.connect();
  print("Connected");

  var results = await conn.execute("SELECT model_name, maker_abbr, sort_order FROM m_models ORDER BY sort_order ASC LIMIT 20;");
  
  for (var row in results.rows) {
    print(row.assoc());
  }

  await conn.close();
}
