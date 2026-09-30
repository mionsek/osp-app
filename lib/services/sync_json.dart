import 'dart:convert';

import '../models/models.dart';

/// Rodzaje rekordów synchronizowanych z Dyskiem — klucze znaczników
/// usunięcia i pamięci plików.
class SyncKind {
  SyncKind._();

  static const String report = 'report';
  static const String handover = 'handover';
  static const String trip = 'trip';
  static const String firefighter = 'firefighter';
  static const String vehicle = 'vehicle';
}

/// Zapis rekordów na Dysk i odczyt z powrotem.
///
/// Osobno od `SyncService`, bo korzysta z tego także baza przy usuwaniu:
/// znacznik usunięcia to ostatnia treść rekordu z dopiskiem `deleted`.
///
/// To najbardziej krucha część synchronizacji: przy każdym dodaniu pola do
/// modelu trzeba dopisać je tutaj **i** w mapowaniu odwrotnym, a nic tego nie
/// wymusza poza testami z listą kluczy.
class SyncJson {
  SyncJson._();

  // ── Znaczniki usunięcia ─────────────────────────────────────────────

  /// Znacznik usunięcia: pełna ostatnia treść rekordu plus `deleted`.
  ///
  /// Pełna, a nie samo `id`: starsza wersja aplikacji czyta taki plik jak
  /// zwykły rekord i nie wywraca się na brakujących polach. `updatedAt`
  /// równy chwili usunięcia, żeby usunięcie wygrywało ze starszymi kopiami
  /// według tej samej reguły „nowszy wygrywa", co zwykła edycja.
  static Map<String, dynamic> tombstone(
    Map<String, dynamic> lastJson,
    DateTime deletedAt,
  ) =>
      {
        ...lastJson,
        'updatedAt': deletedAt.toIso8601String(),
        'deleted': true,
        'deletedAt': deletedAt.toIso8601String(),
      };

  static bool isTombstone(Map<String, dynamic> json) => json['deleted'] == true;

  static DateTime? stampOf(Map<String, dynamic> json) {
    final raw = json['updatedAt'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  /// Skrót treści (FNV-1a, 64 bity) — do sprawdzenia, czy plik na Dysku
  /// różni się od wersji w telefonie. Wystarczy wykryć zmianę, nie chroni
  /// przed celowym podrabianiem.
  static String contentHash(Object json) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(jsonEncode(json))) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  // ── Ratownik ────────────────────────────────────────────────────────

  static Map<String, dynamic> firefighterToJson(Firefighter ff) => {
        'id': ff.id,
        'firstName': ff.firstName,
        'lastName': ff.lastName,
        'rank': ff.rank,
        'isDriver': ff.isDriver,
        'isCommander': ff.isCommander,
        'isKPP': ff.isKPP,
        'medicalExamExpiry': ff.medicalExamExpiry?.toIso8601String(),
        'updatedAt': ff.updatedAt?.toIso8601String(),
      };

  /// [local] to ten sam ratownik z telefonu. Plik zapisany przez starszą
  /// wersję aplikacji nie ma klucza z datą badań — wtedy zostawiamy datę
  /// lokalną, zamiast ją kasować. Klucz z wartością pustą to co innego:
  /// ktoś świadomie wyczyścił datę.
  static Firefighter firefighterFromJson(
    Map<String, dynamic> j, {
    Firefighter? local,
  }) {
    final expiry = j.containsKey('medicalExamExpiry')
        ? (j['medicalExamExpiry'] == null
            ? null
            : DateTime.parse(j['medicalExamExpiry'] as String))
        : local?.medicalExamExpiry;
    return Firefighter(
      id: j['id'] as String,
      firstName: j['firstName'] as String,
      lastName: j['lastName'] as String,
      rank: j['rank'] as String? ?? '',
      isDriver: j['isDriver'] as bool? ?? false,
      isCommander: j['isCommander'] as bool? ?? false,
      isKPP: j['isKPP'] as bool? ?? false,
      medicalExamExpiry: expiry,
      updatedAt: stampOf(j),
    );
  }

  // ── Pojazd ──────────────────────────────────────────────────────────

  static Map<String, dynamic> vehicleToJson(Vehicle v) => {
        'id': v.id,
        'name': v.name,
        'seats': v.seats,
        // Dane z nagłówka karty drogowej — wspólne dla całej jednostki,
        // więc kolega, który dołączy kodem, dostaje je bez przepisywania.
        'make': v.make,
        'model': v.model,
        'kind': v.kind,
        'plate': v.plate,
        'operationalNumber': v.operationalNumber,
        'fuelType': v.fuelType,
        'fuelPer100Km': v.fuelPer100Km,
        'pumpFuelPerHour': v.pumpFuelPerHour,
        'idleFuelPerMinute': v.idleFuelPerMinute,
        'startupFuelPerMonth': v.startupFuelPerMonth,
        'updatedAt': v.updatedAt?.toIso8601String(),
      };

  static Vehicle vehicleFromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        name: j['name'] as String,
        seats: (j['seats'] as num).toInt(),
        make: j['make'] as String? ?? '',
        model: j['model'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        plate: j['plate'] as String? ?? '',
        operationalNumber: j['operationalNumber'] as String? ?? '',
        fuelType: j['fuelType'] as String? ?? '',
        fuelPer100Km: (j['fuelPer100Km'] as num?)?.toDouble(),
        pumpFuelPerHour: (j['pumpFuelPerHour'] as num?)?.toDouble(),
        idleFuelPerMinute: (j['idleFuelPerMinute'] as num?)?.toDouble(),
        startupFuelPerMonth: (j['startupFuelPerMonth'] as num?)?.toDouble(),
        updatedAt: stampOf(j),
      );

  // ── Słownik zagrożeń ────────────────────────────────────────────────

  static Map<String, dynamic> threatToJson(ThreatEntry t) => {
        'category': t.category,
        'subtypes': t.subtypes,
        'isCustom': t.isCustom,
      };

  static ThreatEntry threatFromJson(Map<String, dynamic> j) => ThreatEntry(
        category: j['category'] as String,
        subtypes: (j['subtypes'] as List?)?.cast<String>() ?? [],
        isCustom: j['isCustom'] as bool? ?? false,
      );

  // ── Raport ──────────────────────────────────────────────────────────

  static Map<String, dynamic> reportToJson(Report r) => {
        'id': r.id,
        'reportNumber': r.reportNumber,
        'year': r.year,
        'date': r.date.toIso8601String(),
        'departureTime': r.departureTime.toIso8601String(),
        'returnTime': r.returnTime?.toIso8601String(),
        'addressLocality': r.addressLocality,
        'addressStreet': r.addressStreet,
        'addressDescription': r.addressDescription,
        'threatCategory': r.threatCategory,
        'threatSubtype': r.threatSubtype,
        'crewAssignments': r.crewAssignments.map(crewToJson).toList(),
        'operationCommanderId': r.operationCommanderId,
        'notes': r.notes,
        'createdAt': r.createdAt.toIso8601String(),
        'updatedAt': r.updatedAt.toIso8601String(),
        'createdBy': r.createdBy,
        'syncStatus': 'synced',
      };

  static Report reportFromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        reportNumber: j['reportNumber'] as String,
        year: (j['year'] as num).toInt(),
        date: DateTime.parse(j['date'] as String),
        departureTime: DateTime.parse(j['departureTime'] as String),
        returnTime: j['returnTime'] != null
            ? DateTime.parse(j['returnTime'] as String)
            : null,
        addressLocality: j['addressLocality'] as String,
        addressStreet: j['addressStreet'] as String? ?? '',
        addressDescription: j['addressDescription'] as String? ?? '',
        threatCategory: j['threatCategory'] as String,
        threatSubtype: j['threatSubtype'] as String?,
        crewAssignments: (j['crewAssignments'] as List?)
                ?.map((c) => crewFromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        operationCommanderId: j['operationCommanderId'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        createdBy: j['createdBy'] as String? ?? '',
        syncStatus: 'synced',
      );

  /// Skład zastępu — część raportu.
  static Map<String, dynamic> crewToJson(CrewAssignment c) => {
        'vehicleId': c.vehicleId,
        'vehicleName': c.vehicleName,
        'driverId': c.driverId,
        'commanderId': c.commanderId,
        'crewMemberIds': c.crewMemberIds,
      };

  static CrewAssignment crewFromJson(Map<String, dynamic> j) => CrewAssignment(
        vehicleId: j['vehicleId'] as String,
        vehicleName: j['vehicleName'] as String,
        driverId: j['driverId'] as String?,
        commanderId: j['commanderId'] as String?,
        crewMemberIds: (j['crewMemberIds'] as List?)?.cast<String>() ?? [],
      );

  // ── Przejazd ────────────────────────────────────────────────────────

  static Map<String, dynamic> tripToJson(VehicleTrip t) => {
        'id': t.id,
        'vehicleId': t.vehicleId,
        'date': t.date.toIso8601String(),
        'dispatcherName': t.dispatcherName,
        'routeFrom': t.routeFrom,
        'routeTo': t.routeTo,
        'purpose': t.purpose,
        'driverName': t.driverName,
        'driverId': t.driverId,
        'departureTime': t.departureTime.toIso8601String(),
        'returnTime': t.returnTime?.toIso8601String(),
        'odometerStart': t.odometerStart,
        'odometerEnd': t.odometerEnd,
        'odometerStartManual': t.odometerStartManual,
        'specialEquipmentMinutes': t.specialEquipmentMinutes,
        'equipmentUse': [
          for (final e in t.equipmentUse) {'name': e.name, 'minutes': e.minutes},
        ],
        'idleMinutes': t.idleMinutes,
        'overriddenFields': t.overriddenFields,
        'extras': t.extras,
        'notes': t.notes,
        'reportId': t.reportId,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
        'createdBy': t.createdBy,
        'syncStatus': 'synced',
      };

  static VehicleTrip tripFromJson(Map<String, dynamic> j) => VehicleTrip(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        dispatcherName: j['dispatcherName'] as String? ?? '',
        routeFrom: j['routeFrom'] as String? ?? '',
        routeTo: j['routeTo'] as String? ?? '',
        purpose: j['purpose'] as String? ?? TripPurposes.economic,
        driverName: j['driverName'] as String? ?? '',
        driverId: j['driverId'] as String?,
        departureTime: DateTime.parse(j['departureTime'] as String),
        returnTime: j['returnTime'] == null
            ? null
            : DateTime.parse(j['returnTime'] as String),
        odometerStart: (j['odometerStart'] as num?)?.toInt(),
        odometerEnd: (j['odometerEnd'] as num?)?.toInt(),
        odometerStartManual: j['odometerStartManual'] as bool? ?? false,
        specialEquipmentMinutes:
            (j['specialEquipmentMinutes'] as num?)?.toInt(),
        idleMinutes: (j['idleMinutes'] as num?)?.toInt(),
        equipmentUse: [
          for (final e in (j['equipmentUse'] as List? ?? const []))
            TripEquipmentUse(
              name: (e as Map)['name'] as String? ?? '',
              minutes: (e['minutes'] as num?)?.toInt() ?? 0,
            ),
        ],
        overriddenFields: [
          for (final f in (j['overriddenFields'] as List? ?? const []))
            f.toString(),
        ],
        extras: j['extras'] as String? ?? '',
        notes: j['notes'] as String?,
        reportId: j['reportId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        createdBy: j['createdBy'] as String? ?? '',
        syncStatus: 'synced',
      );

  // ── Przekazanie mienia ──────────────────────────────────────────────

  static Map<String, dynamic> handoverToJson(PropertyHandover h) => {
        'id': h.id,
        'reportId': h.reportId,
        'eventLocation': h.eventLocation,
        'eventDate': h.eventDate.toIso8601String(),
        'eventTime': h.eventTime.toIso8601String(),
        'recipientType': h.recipientType,
        'recipientTypeOther': h.recipientTypeOther,
        'recipientName': h.recipientName,
        'recipientAddress': h.recipientAddress,
        'recipientPhone': h.recipientPhone,
        'propertyDescription': h.propertyDescription,
        'propertyKind': h.propertyKind,
        'notes': h.notes,
        'handoverFirefighterId': h.handoverFirefighterId,
        'signLocality': h.signLocality,
        'signDate': h.signDate.toIso8601String(),
        'createdAt': h.createdAt.toIso8601String(),
        'updatedAt': h.updatedAt.toIso8601String(),
        'createdBy': h.createdBy,
        'syncStatus': 'synced',
      };

  static PropertyHandover handoverFromJson(Map<String, dynamic> j) =>
      PropertyHandover(
        id: j['id'] as String,
        reportId: j['reportId'] as String?,
        eventLocation: j['eventLocation'] as String? ?? '',
        eventDate: DateTime.parse(j['eventDate'] as String),
        eventTime: DateTime.parse(j['eventTime'] as String),
        recipientType: j['recipientType'] as String?,
        recipientTypeOther: j['recipientTypeOther'] as String?,
        recipientName: j['recipientName'] as String? ?? '',
        recipientAddress: j['recipientAddress'] as String? ?? '',
        recipientPhone: j['recipientPhone'] as String? ?? '',
        propertyDescription: j['propertyDescription'] as String? ?? '',
        propertyKind: j['propertyKind'] as String?,
        notes: j['notes'] as String?,
        handoverFirefighterId: j['handoverFirefighterId'] as String?,
        signLocality: j['signLocality'] as String? ?? '',
        signDate: DateTime.parse(j['signDate'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        createdBy: j['createdBy'] as String? ?? '',
        syncStatus: 'synced',
      );
}
