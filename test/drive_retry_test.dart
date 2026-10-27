import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:osp_app/services/drive_retry.dart';
import 'package:osp_app/services/sync_service.dart';

/// Ponawianie zapytań do Dysku przy błędach, które mijają same.
///
/// Zgłoszenie z testów 1.7.3: „ClientException: Software caused connection
/// abort" przy wysyłce raportu. Ręczne „Synchronizuj teraz" od razu
/// przechodziło — telefon powinien spróbować sam, zanim pokaże błąd.
void main() {
  final abort = http.ClientException(
    'Software caused connection abort',
    Uri.parse('https://www.googleapis.com/upload/drive/v3/files'),
  );
  const noDelay = [Duration.zero, Duration.zero];

  group('isTransientDriveError', () {
    test('zerwane połączenie i przekroczony czas mijają same', () {
      expect(isTransientDriveError(abort), isTrue);
      expect(
          isTransientDriveError(
              const SocketException('Connection reset by peer')),
          isTrue);
      expect(isTransientDriveError(TimeoutException('za długo')), isTrue);
    });

    test('chwilowe przeciążenie Google mija samo', () {
      expect(
          isTransientDriveError(
              drive.DetailedApiRequestError(503, 'Backend Error')),
          isTrue);
      expect(
          isTransientDriveError(
              drive.DetailedApiRequestError(429, 'Too Many Requests')),
          isTrue);
    });

    test('odmowa dostępu, brak pliku i zły token nie miną od ponowienia', () {
      expect(
          isTransientDriveError(drive.DetailedApiRequestError(403, 'Forbidden')),
          isFalse);
      expect(
          isTransientDriveError(drive.DetailedApiRequestError(404, 'Not Found')),
          isFalse);
      expect(
          isTransientDriveError(
              drive.DetailedApiRequestError(401, 'Unauthorized')),
          isFalse);
      expect(isTransientDriveError(StateError('Not signed in')), isFalse);
      expect(isTransientDriveError(const FormatException('zły JSON')), isFalse);
    });
  });

  group('retryTransient', () {
    test('trzecia próba się udaje i błąd nie wychodzi wyżej', () async {
      var attempts = 0;
      final result = await retryTransient(() async {
        if (++attempts < 3) throw abort;
        return 'ok';
      }, delays: noDelay);

      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('po trzech nieudanych próbach przekazuje ten sam błąd', () async {
      var attempts = 0;
      await expectLater(
        retryTransient<void>(() async {
          attempts++;
          throw abort;
        }, delays: noDelay),
        throwsA(same(abort)),
      );
      expect(attempts, 3, reason: 'łącznie trzy próby, nie więcej');
    });

    test('odmowy dostępu nie ponawia', () async {
      var attempts = 0;
      await expectLater(
        retryTransient<void>(() async {
          attempts++;
          throw drive.DetailedApiRequestError(404, 'Not Found');
        }, delays: noDelay),
        throwsA(isA<drive.DetailedApiRequestError>()),
      );
      expect(attempts, 1);
    });
  });

  group('describeSyncError', () {
    test('zerwane połączenie: po polsku, bez adresu i nazwy wyjątku', () {
      final text = describeSyncError(abort);
      expect(text, contains('Połączenie z internetem zostało przerwane'));
      expect(text, contains('Dane są zapisane na telefonie'));
      expect(text, isNot(contains('ClientException')));
      expect(text, isNot(contains('googleapis')));
    });

    test('przeciążenie Google ma własny komunikat', () {
      expect(describeSyncError(drive.DetailedApiRequestError(503, 'x')),
          contains('Dysk Google chwilowo nie odpowiada'));
    });
  });
}
