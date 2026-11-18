import '../models/models.dart';

/// Trasa i cel przejazdu tak, jak wpisuje się je długopisem na kartach
/// w Kielnie: „OSP – Kielno", „Powrót" (wypełniona karta drogowa, zdjęcie
/// z 7.08.2026).
///
/// W aplikacji trasa trzyma pełne adresy (podpowiedź „Skąd" to adres remizy,
/// „Dokąd" z raportu to miejscowość i ulica). Na wąskich rubrykach karty to
/// się nie mieściło i nie wyglądało jak karta, którą gmina zna.
///
/// Cel jazdy — pełną nazwą, bez skrótów „MZ", „P", „Ć" (Dawid, 18.11.2026);
/// za długi napis zmniejsza się w rubryce.
class TripLabels {
  TripLabels._();

  static const String station = 'OSP';

  /// Cel drugiego wiersza wyjazdu na karcie drogowej.
  static const String returnLeg = 'Powrót';

  /// „OSP" dla remizy, inaczej sama miejscowość — część adresu przed
  /// pierwszym przecinkiem („Kielno, Szkolna 5" → „Kielno").
  static String place(String address, {required String stationAddress}) {
    final a = address.trim();
    if (a.isEmpty) return '';
    if (_normalize(a) == _normalize(station) ||
        (stationAddress.trim().isNotEmpty &&
            _normalize(a) == _normalize(stationAddress))) {
      return station;
    }
    return a.split(',').first.trim();
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s,.]+'), '');

  /// Cel jazdy na ekranie i na karcie: przy przejeździe z raportu rodzaj
  /// zdarzenia („Pożar", „Miejscowe Zagrożenie", „Fałszywy Alarm"), inaczej
  /// cel przejazdu („Ćwiczenia", „Tankowanie"); drugi wiersz wyjazdu na
  /// karcie to [returnLeg].
  static String purpose(VehicleTrip t, Report? report) {
    final category = report?.threatCategory.trim() ?? '';
    return category.isNotEmpty ? category : t.purpose;
  }

  /// Cel jazdy w rubryce karty drogowej: „Miejscowe Zagrożenie" w dwóch
  /// liniach (Dawid, 18.11.2026) — w jednej zmniejszało się do ok. 6,5 pt.
  /// Krótsze nazwy mieszczą się w jednej linii, więc zostają bez zmian.
  static String cardPurpose(VehicleTrip t, Report? report) {
    final p = purpose(t, report);
    return p.toLowerCase() == TripPurposes.localThreat.toLowerCase()
        ? p.replaceFirst(' ', '\n')
        : p;
  }

  /// „OSP – Kielno" — puste strony trasy pominięte.
  static String route(String from, String to) =>
      [from, to].where((s) => s.isNotEmpty).join(' – ');
}
