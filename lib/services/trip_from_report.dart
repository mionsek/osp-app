import '../models/models.dart';

/// Tworzenie wpisów ewidencji przejazdów z zapisanego wyjazdu alarmowego.
///
/// Ustalenie z rozmowy: karta drogowa obejmuje **wszystkie** wyjazdy, także
/// alarmowe, i „im więcej wypełni się samo, tym lepiej". Z raportu da się
/// odtworzyć 7 z 11 kolumn druku — zostaje licznik, dysponent i minuty pracy
/// urządzeń specjalnych.
///
/// Jeden raport może obejmować kilka pojazdów, a każdy pojazd ma własną kartę,
/// więc powstaje tyle przejazdów, ile zastępów wyjechało.
class TripFromReport {
  const TripFromReport._();

  /// Buduje przejazdy dla wszystkich zastępów z [report].
  ///
  /// [existingTripReportIds] chroni przed dopisaniem tego samego wyjazdu drugi
  /// raz przy edycji raportu — bez tego każde otwarcie i zapisanie raportu
  /// mnożyłoby wiersze w karcie.
  static List<VehicleTrip> build({
    required Report report,
    required String unitLocality,
    required String Function(String firefighterId)? resolveDriverName,
    required Set<String> existingVehicleIdsForReport,
    String createdBy = '',
  }) {
    final trips = <VehicleTrip>[];
    final now = DateTime.now();

    for (final crew in report.crewAssignments) {
      if (crew.vehicleId.isEmpty) continue;
      if (existingVehicleIdsForReport.contains(crew.vehicleId)) continue;

      final driverId = crew.driverId;
      final driverName = (driverId != null && resolveDriverName != null)
          ? resolveDriverName(driverId)
          : '';

      trips.add(VehicleTrip(
        // Identyfikator wyprowadzony z raportu i pojazdu, żeby ponowny zapis
        // tego samego raportu trafiał w ten sam wpis, a nie tworzył kolejny.
        id: 'trip_${report.id}_${crew.vehicleId}',
        vehicleId: crew.vehicleId,
        date: report.date,
        routeFrom: unitLocality,
        routeTo: _destination(report),
        purpose: TripPurposes.alarm,
        driverName: driverName,
        driverId: driverId,
        departureTime: report.departureTime,
        returnTime: report.returnTime,
        reportId: report.id,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
      ));
    }

    return trips;
  }

  /// Cel wyjazdu w formacie kolumny „dokąd": ulica z numerem, a gdy jej brak —
  /// sama miejscowość. Opis miejsca pomijamy, bo w kratce karty i tak się nie
  /// mieści.
  static String _destination(Report report) {
    final locality = report.addressLocality.trim();
    final street = report.addressStreet.trim();
    if (street.isEmpty) return locality;
    if (locality.isEmpty) return street;
    return '$locality, $street';
  }
}
