import 'dart:io';

import 'package:hive/hive.dart';
import 'package:osp_app/services/database_service.dart';

/// Baza „telefonu" w testach kilku telefonów na jednym Dysku: każdy ma
/// własny katalog [name] pod [root]. Poprzednia baza jest zamykana — Hive
/// ma naraz otwartą jedną, więc testy przełączają telefony po kolei.
///
/// Adaptery rejestruje `DatabaseService.registerAdapters` w `setUpAll`.
Future<void> openPhoneDb(Directory root, String name) async {
  await Hive.close();
  final dir = Directory('${root.path}/$name')..createSync(recursive: true);
  Hive.init(dir.path);
  await DatabaseService.openBoxes();
}
