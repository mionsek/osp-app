import '../models/models.dart';

/// Praca sprzętu z wpisów przejazdu — co z niej trafia na kartę drogową wozu.
///
/// Karta drogowa liczy w kolumnie 10 („Minuty pracy urządzeń
/// specjalistycznych") i pozycji 5 rozliczenia tylko sprzęt zasilany
/// z wozu, normą autopompy z nagłówka. Sprzęt z własnym silnikiem (agregat,
/// pilarka) ma w gminie osobną kartę pracy — wcześniej jego minuty liczyły
/// się normą autopompy wozu i zawyżały paliwo z baku.
class EquipmentUsage {
  EquipmentUsage._();

  /// Urządzenie z listy sprzętu dla wpisu: po identyfikatorze, a we wpisach
  /// bez niego — po nazwie, najpierw wśród sprzętu wozu [vehicleId].
  static Equipment? resolve(
    TripEquipmentUse use,
    List<Equipment> equipment, {
    String? vehicleId,
  }) {
    final id = use.equipmentId;
    if (id != null) {
      for (final e in equipment) {
        if (e.id == id) return e;
      }
    }
    final name = use.name.trim().toLowerCase();
    if (name.isEmpty) return null;
    Equipment? elsewhere;
    for (final e in equipment) {
      if (e.name.trim().toLowerCase() != name) continue;
      if (e.vehicleId == vehicleId) return e;
      elsewhere ??= e;
    }
    return elsewhere;
  }

  /// Nazwy ze stałej listy sprzed listy sprzętu, które oznaczały sprzęt
  /// z własnym silnikiem. Autopompa i wyciągarka pracują z silnika wozu.
  static const _ownEngineLegacyNames = {
    SpecialEquipment.generator,
    SpecialEquipment.saw,
    SpecialEquipment.fan,
  };

  /// Czy wpis liczy się na karcie drogowej wozu.
  ///
  /// Wpis bez urządzenia z listy (sprzed niej albo nazwa wpisana ręcznie)
  /// liczy się jak dawniej — chyba że to agregat, piła albo wentylator ze
  /// starej stałej listy.
  static bool countsOnVehicleCard(
    TripEquipmentUse use,
    List<Equipment> equipment, {
    String? vehicleId,
  }) {
    final device = resolve(use, equipment, vehicleId: vehicleId);
    if (device != null) return device.poweredByVehicle;
    return !_ownEngineLegacyNames.contains(use.name);
  }

  /// Minuty pracy sprzętu do kolumny 10 karty drogowej wozu.
  ///
  /// Przejazd sprzed rozbicia na urządzenia ma tylko jedną liczbę
  /// ([VehicleTrip.specialEquipmentMinutes]) — liczy się w całości, jak
  /// dotąd.
  static int vehicleCardMinutes(VehicleTrip trip, List<Equipment> equipment) {
    if (trip.equipmentUse.isEmpty) return trip.specialEquipmentMinutes ?? 0;
    return trip.equipmentUse
        .where((u) =>
            countsOnVehicleCard(u, equipment, vehicleId: trip.vehicleId))
        .fold(0, (sum, u) => sum + u.minutes);
  }
}
