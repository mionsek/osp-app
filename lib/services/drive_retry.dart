import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Przerwy między próbami — łącznie trzy próby, zanim pokażemy błąd.
///
/// Zgłoszenie z testów 1.7.3: „Software caused connection abort" przy
/// wysyłce raportu, przy dobrym zasięgu. Ponowienie ręczne od razu
/// przechodziło — telefon powinien zrobić to sam.
const defaultDriveRetryDelays = [Duration(seconds: 2), Duration(seconds: 5)];

/// Czy błąd Dysku może minąć sam: zerwane połączenie, przekroczony czas,
/// chwilowe przeciążenie Google.
///
/// Odmowa dostępu, brak pliku albo odrzucony token od ponowienia nie miną,
/// więc na nie nie czekamy.
bool isTransientDriveError(Object e) {
  if (e is http.ClientException ||
      e is SocketException ||
      e is HttpException ||
      e is HandshakeException ||
      e is TimeoutException) {
    return true;
  }
  if (e is drive.DetailedApiRequestError) {
    final status = e.status ?? 0;
    if (status == 408 || status == 429 || status >= 500) return true;
    // Limit zapytań Dysk zgłasza jako 403 — od zwykłej odmowy dostępu
    // odróżnia go dopiero powód.
    if (status == 403) {
      return e.errors.any((d) =>
          d.reason == 'rateLimitExceeded' ||
          d.reason == 'userRateLimitExceeded');
    }
  }
  return false;
}

/// Wywołuje [call], a przy błędzie, który może minąć sam, ponawia je po
/// kolejnych przerwach z [delays]. Inne błędy i ostatnią porażkę przekazuje
/// dalej bez zmian.
///
/// [call] musi za każdym razem budować zapytanie od nowa — treść wysyłanego
/// pliku to strumień, który da się odczytać tylko raz.
Future<T> retryTransient<T>(
  Future<T> Function() call, {
  List<Duration> delays = defaultDriveRetryDelays,
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await call();
    } catch (e) {
      if (attempt >= delays.length || !isTransientDriveError(e)) rethrow;
      debugPrint('Dysk: próba ${attempt + 1} nieudana ($e), ponawiam');
      await Future<void>.delayed(delays[attempt]);
    }
  }
}
