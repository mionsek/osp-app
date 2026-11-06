import '../models/models.dart';

/// Trasa i cel przejazdu tak, jak wpisuje się je długopisem na kartach
/// w Kielnie: „OSP – Kielno", „MZ", „Powrót" (wypełniona karta drogowa,
/// zdjęcie z 7.08.2026).
///
/// W aplikacji trasa trzyma pełne adresy (podpowiedź „Skąd" to adres remizy,
/// „Dokąd" z raportu to miejscowość i ulica), a cel wyjazdu alarmowego to
/// „Wyjazd alarmowy". Na wąskich rubrykach karty to się nie mieściło i nie
/// wyglądało jak karta, którą gmina zna.
class TripLabels {
  TripLabels._();

  static const String station = 'OSP';

  /// Cel drugiego wiersza wyjazdu na karcie drogowej.
  static const String returnLeg = 'Powrót';

  /// Skrót rodzaju zdarzenia: MZ, P, AF.
  static String threatShort(String category) =>
      switch (category.trim().toLowerCase()) {
        'miejscowe zagrożenie' => 'MZ',
        'pożar' => 'P',
        'fałszywy alarm' || 'alarm fałszywy' => 'AF',
        _ => category.trim(),
      };

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

  /// Cel jazdy: skrót zdarzenia przy wyjeździe alarmowym, inaczej cel
  /// przejazdu („Ćwiczenia", „Tankowanie").
  static String purpose(VehicleTrip t, Report? report) =>
      report != null ? threatShort(report.threatCategory) : t.purpose;

  /// „OSP – Kielno" — puste strony trasy pominięte.
  static String route(String from, String to) =>
      [from, to].where((s) => s.isNotEmpty).join(' – ');
}
