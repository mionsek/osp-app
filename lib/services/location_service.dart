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
      final street = buildStreet(
        thoroughfare: p.thoroughfare,
        subThoroughfare: p.subThoroughfare,
        streetLine: p.street,
        locality: locality,
      );
      return ResolvedAddress(locality: locality, street: street);
    } on LocationFailure {
      rethrow;
    } catch (e) {
      throw const LocationFailure(
        'Nie udało się zamienić pozycji na adres — zwykle brakuje wtedy '
        'internetu. Wpisz adres ręcznie.',
      );
    }
  }

  /// Składa pole „ulica i nr domu" z danych geokodera.
  ///
  /// Uwaga na znaczenie pól — pomyłka tutaj powodowała podwojony numer
  /// domu („Józefa Sikorskiego 12 12"):
  /// * [thoroughfare] — sama nazwa ulicy („Józefa Sikorskiego"),
  /// * [subThoroughfare] — numer domu („12"),
  /// * [streetLine] — **gotowa linia adresu, już z numerem** (na Androidzie
  ///   to fragment sformatowanego adresu do pierwszego przecinka).
  ///
  /// Dlatego numer dokładamy tylko do nazwy ulicy, a nigdy do gotowej
  /// linii, która już go zawiera.
  static String buildStreet({
    required String? thoroughfare,
    required String? subThoroughfare,
    required String? streetLine,
    required String locality,
  }) {
    final name = (thoroughfare ?? '').trim();
    final number = (subThoroughfare ?? '').trim();
    final line = (streetLine ?? '').trim();

    if (name.isNotEmpty) {
      // Na wsi geokoder podaje jako „ulicę" nazwę miejscowości
      // („Kielno 85") — wtedy w polu ulicy zostaje sam numer, żeby adres
      // nie brzmiał „Kielno, Kielno 85".
      if (name.toLowerCase() == locality.toLowerCase()) return number;
      if (number.isEmpty) return name;
      return '$name $number';
    }

    if (line.isEmpty) return number;
    if (line.toLowerCase() == locality.toLowerCase()) return number;
    // Gotowa linia zwykle zawiera już numer — dokładamy go tylko wtedy,
    // gdy faktycznie go w niej brakuje.
    if (number.isEmpty || _endsWithNumber(line, number)) return line;
    return '$line $number';
  }

  /// Czy [line] kończy się osobnym wyrazem [number] (żeby „12" nie
  /// „domknęło" numeru 112).
  static bool _endsWithNumber(String line, String number) {
    final parts = line.split(RegExp(r'\s+'));
    return parts.isNotEmpty && parts.last.toLowerCase() == number.toLowerCase();
  }

  static bool _notEmpty(String? s) => s != null && s.trim().isNotEmpty;

  static String _firstNonEmpty(List<String?> candidates) {
    for (final c in candidates) {
      if (_notEmpty(c)) return c!.trim();
    }
    return '';
  }
}
