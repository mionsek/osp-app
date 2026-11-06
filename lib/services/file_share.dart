import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Wysyłka pliku innego niż PDF — systemowe okno „Udostępnij" (poczta,
/// Dysk, komunikatory).
///
/// PDF-y idą przez `Printing.sharePdf`, ale ono oznacza każdy plik jako PDF,
/// więc arkusz Excela poczta podpisałaby złym typem.
class FileShare {
  FileShare._();

  static Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
    ));
  }
}
