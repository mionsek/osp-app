import '../models/models.dart';
import 'equipment_usage.dart';

/// Wiersz miesięcznej karty pracy sprzętu silnikowego: Data, Nazwisko i imię
/// obsługującego, Minut pracy, Cel użycia.
class EquipmentCardRow {
  final DateTime date;
  final String operatorName;
  final int minutes;
  final String purpose;

  /// Rozruch kontrolny — pozycja 6 rozliczenia zamiast 4–5.
  final bool isStartup;

  /// Skąd wiersz pochodzi — do otwarcia wpisu z listy na ekranie karty.
  final String? tripId;
  final String? workId;

  const EquipmentCardRow({
    required this.date,
    required this.operatorName,
    required this.minutes,
    required this.purpose,
    this.isStartup = false,
    this.tripId,
    this.workId,
  });
}

/// Sumy do rozliczenia materiałów pędnych karty pracy.
///
/// Paliwo `null`, gdy sprzęt nie ma wpisanej normy — rozliczenie zostaje
/// wtedy puste do wypełnienia długopisem, jak na karcie drogowej.
class EquipmentCardTotals {
  /// Pozycja 4: „Przepracowano godz. i min." — bez rozruchów.
  final int workMinutes;
  final int startupMinutes;

  /// Pozycja 5: „zużyto".
  final double? workFuel;

  /// Pozycja 6: „zużyto na rozruchy i kontrole".
  final double? startupFuel;

  const EquipmentCardTotals({
    required this.workMinutes,
    required this.startupMinutes,
    required this.workFuel,
    required this.startupFuel,
  });

  /// Pozycja 7: „zużyto w ciągu mies. razem".
  double? get totalFuel => workFuel == null || startupFuel == null
      ? null
      : workFuel! + startupFuel!;
}

/// Miesięczna karta pracy sprzętu silnikowego — jak karta drogowa, nie
/// osobny byt, tylko widok: urządzenie + miesiąc nad wpisami.
///
/// Wiersze biorą się z dwóch miejsc: z przejazdów (praca przy akcji, na
/// ćwiczeniach) i z wpisów pracy poza przejazdem ([EquipmentWork] —
/// rozruchy kontrolne w remizie).
class EquipmentCard {
  EquipmentCard._();

  /// Wiersze karty [device] za miesiąc, od najwcześniejszego.
  ///
  /// [equipment] to cała lista sprzętu — wpisy przejazdów sprzed listy mają
  /// samą nazwę i dopasowują się po niej ([EquipmentUsage.resolve]).
  /// [reportOf] daje wyjazd alarmowy przejazdu, z którego bierze się „Cel
  /// użycia" (rodzaj zdarzenia i miejscowość).
  static List<EquipmentCardRow> rows({
    required Equipment device,
    required int year,
    required int month,
    required Iterable<VehicleTrip> trips,
    required Iterable<EquipmentWork> work,
    required List<Equipment> equipment,
    Report? Function(String reportId)? reportOf,
  }) {
    bool inMonth(DateTime d) => d.year == year && d.month == month;

    final rows = <EquipmentCardRow>[
      for (final t in trips)
        if (inMonth(t.date))
          for (final use in t.equipmentUse)
            if (use.minutes > 0 &&
                EquipmentUsage.resolve(use, equipment, vehicleId: t.vehicleId)
                        ?.id ==
                    device.id)
              EquipmentCardRow(
                date: t.departureTime,
                operatorName: use.operatorName,
                minutes: use.minutes,
                purpose: _tripPurpose(t, reportOf),
                tripId: t.id,
              ),
      for (final w in work)
        if (w.equipmentId == device.id && inMonth(w.date) && w.minutes > 0)
          EquipmentCardRow(
            date: w.date,
            operatorName: w.operatorName,
            minutes: w.minutes,
            purpose: w.isStartup && w.purpose.trim().isEmpty
                ? EquipmentWork.startupPurpose
                : w.purpose,
            isStartup: w.isStartup,
            workId: w.id,
          ),
    ];
    rows.sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  /// „Pożar, Kielno" przy wyjeździe alarmowym, inaczej cel przejazdu
  /// i miejsce („Ćwiczenia, Szemud").
  static String _tripPurpose(
    VehicleTrip t,
    Report? Function(String reportId)? reportOf,
  ) {
    final report = t.reportId == null ? null : reportOf?.call(t.reportId!);
    final parts = report != null
        ? [report.threatCategory, report.addressLocality]
        : [t.purpose, t.routeTo];
    return parts.map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
  }

  static EquipmentCardTotals totals(
    Equipment device,
    List<EquipmentCardRow> rows,
  ) {
    var work = 0;
    var startup = 0;
    for (final r in rows) {
      if (r.isStartup) {
        startup += r.minutes;
      } else {
        work += r.minutes;
      }
    }
    final norm = device.fuelPerHour;
    return EquipmentCardTotals(
      workMinutes: work,
      startupMinutes: startup,
      workFuel: norm == null ? null : work / 60 * norm,
      startupFuel: norm == null ? null : startup / 60 * norm,
    );
  }

  /// Miesiące, w których urządzenie pracowało — od najnowszego.
  static List<({int year, int month})> months({
    required Equipment device,
    required Iterable<VehicleTrip> trips,
    required Iterable<EquipmentWork> work,
    required List<Equipment> equipment,
  }) {
    final keys = <int>{
      for (final t in trips)
        for (final use in t.equipmentUse)
          if (EquipmentUsage.resolve(use, equipment, vehicleId: t.vehicleId)
                  ?.id ==
              device.id)
            t.date.year * 12 + t.date.month - 1,
      for (final w in work)
        if (w.equipmentId == device.id) w.date.year * 12 + w.date.month - 1,
    };
    return [
      for (final k in keys.toList()..sort((a, b) => b.compareTo(a)))
        (year: k ~/ 12, month: k % 12 + 1),
    ];
  }

  /// „1 godz. 35 min", „45 min", „2 godz." — rubryka „Przepracowano godz.
  /// i min.".
  static String hoursAndMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h godz.';
    return '$h godz. $m min';
  }
}
