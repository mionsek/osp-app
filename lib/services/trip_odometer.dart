import '../models/vehicle_trip.dart';

/// Łańcuch stanów licznika w ewidencji przejazdów.
///
/// Założenie z rozmowy z użytkownikiem: stan licznika *przed* wyjazdem
/// teoretycznie już znamy, bo jest to stan *po* poprzednim przejeździe tego
/// samego pojazdu. Kartę drogową oddaje się często w środku akcji, więc
/// kierowca notuje licznik dopiero po powrocie do jednostki. Aplikacja pyta
/// go zatem o **jedną liczbę na przejazd**, a stan początkowy podstawia sama.
///
/// Funkcje są czyste (bez Hive i bez UI), żeby dało się je przetestować
/// jednostkowo — łańcuch łatwo zepsuć wpisem wstawionym wstecz.
class TripOdometer {
  const TripOdometer._();

  /// Porządkuje przejazdy tak, jak biegnie licznik: po godzinie odjazdu.
  ///
  /// Świadomie **nie** po kolejności dodawania — ktoś uzupełniający zaległości
  /// wpisze wczorajszy przejazd po dzisiejszym, a licznik i tak rósł
  /// chronologicznie. Przy identycznym czasie odjazdu rozstrzyga [VehicleTrip.id],
  /// żeby kolejność była stabilna między uruchomieniami.
  static List<VehicleTrip> inChainOrder(Iterable<VehicleTrip> trips) {
    final sorted = trips.toList()
      ..sort((a, b) {
        final byTime = a.departureTime.compareTo(b.departureTime);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  /// Stan licznika po ostatnim przejeździe [vehicleId] przed [before].
  ///
  /// Zwraca `null`, gdy nie ma z czego wziąć — czyli przy pierwszym przejeździe
  /// pojazdu w aplikacji. Tylko wtedy formularz pyta o obie liczby.
  ///
  /// [excludeTripId] pozwala pominąć edytowany właśnie przejazd, żeby nie
  /// wyznaczał sam sobie stanu początkowego.
  static int? previousReading(
    Iterable<VehicleTrip> allTrips, {
    required String vehicleId,
    required DateTime before,
    String? excludeTripId,
  }) {
    final earlier = allTrips.where(
      (t) =>
          t.vehicleId == vehicleId &&
          t.id != excludeTripId &&
          t.odometerEnd != null &&
          t.departureTime.isBefore(before),
    );
    if (earlier.isEmpty) return null;
    return inChainOrder(earlier).last.odometerEnd;
  }

  /// Stan licznika, który należy pokazać jako „przed wyjazdem".
  ///
  /// Wpis oznaczony [VehicleTrip.odometerStartManual] wygrywa z łańcuchem —
  /// bez tego jeden pominięty przejazd rozjeżdżałby wszystkie następne i nie
  /// dałoby się tego odkręcić.
  static int? resolveStart(
    VehicleTrip trip,
    Iterable<VehicleTrip> allTrips,
  ) {
    if (trip.odometerStartManual) return trip.odometerStart;
    return previousReading(
      allTrips,
      vehicleId: trip.vehicleId,
      before: trip.departureTime,
      excludeTripId: trip.id,
    );
  }

  /// Przelicza łańcuch dla jednego pojazdu i zwraca przejazdy, które zmieniły
  /// stan początkowy — do zapisania.
  ///
  /// Wywoływane po każdej zmianie, bo dodanie przejazdu wstecz przesuwa stany
  /// początkowe wszystkich późniejszych.
  static List<VehicleTrip> rechain(
    Iterable<VehicleTrip> allTrips, {
    required String vehicleId,
  }) {
    final ofVehicle = inChainOrder(
      allTrips.where((t) => t.vehicleId == vehicleId),
    );

    final changed = <VehicleTrip>[];
    int? running;

    for (final trip in ofVehicle) {
      if (trip.odometerStartManual) {
        // Ręczna korekta jest punktem odniesienia dla dalszej części łańcucha.
        running = trip.odometerEnd ?? trip.odometerStart ?? running;
        continue;
      }

      // Gdy nie ma z czego wyliczyć stanu początkowego (pierwszy przejazd
      // pojazdu), zostawiamy to, co wpisał człowiek. Nadpisanie tego na `null`
      // kasowałoby jedyną liczbę, od której cały łańcuch się zaczyna.
      if (running != null && trip.odometerStart != running) {
        trip.odometerStart = running;
        changed.add(trip);
      }

      running = trip.odometerEnd ?? trip.odometerStart ?? running;
    }

    return changed;
  }

  /// Suma kilometrów przejechanych przez pojazd w danym miesiącu.
  ///
  /// Liczona z domkniętych przejazdów — otwarte (bez licznika po powrocie)
  /// nie mają jeszcze czego wnieść.
  static int distanceInMonth(
    Iterable<VehicleTrip> allTrips, {
    required String vehicleId,
    required int year,
    required int month,
  }) {
    var sum = 0;
    for (final trip in allTrips) {
      if (trip.vehicleId != vehicleId) continue;
      if (trip.year != year || trip.month != month) continue;
      final d = trip.distance;
      if (d != null && d > 0) sum += d;
    }
    return sum;
  }
}
