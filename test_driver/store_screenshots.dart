import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Sterownik do `integration_test/store_screenshots_test.dart` — zapisuje
/// zrzuty ekranu do sklepu Play w `build/store_screenshots/`.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('build/store_screenshots/$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
    );
