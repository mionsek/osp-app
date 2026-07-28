import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Wynik ustalania adresu z GPS. Zawsze traktujemy go jako podpowiedź —
/// GPS bywa niedokładny, a w terenie może nie być zasięgu, więc pola
/// formularza pozostają w pełni edytowalne.
class ResolvedAddress {
  /// Miejscowość, np. „Kielno".
  final String locality;

  /// Ulica z numerem, np. „Leśna 5". Pusta, gdy nie udało się ustalić.
  final String street;

  const ResolvedAddress({required this.locality, required this.street});

  /// Zapis w jednej linii — „Kielno, Leśna 5".
  String get oneLine =>
      [locality, street].where((s) => s.isNotEmpty).join(', ');

  bool get isEmpty => locality.isEmpty && street.isEmpty;
}

/// Błąd z komunikatem gotowym do pokazania użytkownikowi.
class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);

  @override
  String toString() => message;
}

/// Ustalanie bieżącej lokalizacji i zamiana jej na adres.
class LocationService {
  LocationService._();

  /// Pobiera bieżącą pozycję i zamienia ją na adres.
  ///
  /// Rzuca [LocationFailure] z czytelnym komunikatem, gdy nie da się tego
  /// zrobić (wyłączony GPS, brak zgody, brak sieci do geokodowania).
  static Future<ResolvedAddress> currentAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'Lokalizacja jest wyłączona w telefonie — włącz ją i spróbuj ponownie.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Brak zgody na dostęp do lokalizacji.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Dostęp do lokalizacji jest trwale zablokowany — zmień to '
        'w ustawieniach telefonu.',
      );
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      throw const LocationFailure(
        'Nie udało się ustalić pozycji GPS. Sprawdź, czy masz widok na '
        'niebo, albo wpisz adres ręcznie.',
      );
    }

    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isEmpty) {
        throw const LocationFailure('Nie znaleziono adresu dla tej pozycji.');
      }
      final p = places.first;
      // `locality` bywa puste na terenach wiejskich — wtedy sięgamy po
      // kolejne poziomy administracyjne.
      final locality = _firstNonEmpty([
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
      ]);
      final street = _firstNonEmpty([
        [p.street, p.subThoroughfare].where(_notEmpty).join(' ').trim(),
        p.thoroughfare,
      ]);
      // Geokoder czasem wstawia nazwę miejscowości również jako ulicę —
      // nie powtarzamy jej wtedy dwa razy.
      return ResolvedAddress(
        locality: locality,
        street: street == locality ? '' : street,
      );
    } on LocationFailure {
      rethrow;
    } catch (e) {
      throw const LocationFailure(
        'Nie udało się zamienić pozycji na adres — zwykle brakuje wtedy '
        'internetu. Wpisz adres ręcznie.',
      );
    }
  }

  static bool _notEmpty(String? s) => s != null && s.trim().isNotEmpty;

  static String _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (_notEmpty(c)) return c!.trim();
    }
    return '';
  }
}
