import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/trip_card.dart';
import 'package:osp_app/services/trip_labels.dart';

/// Karta drogowa tak, jak wypełnia się ją w Kielnie (zdjęcie z 7.08.2026,
/// wyjaśnienia Dawida z 5.11.2026): dwa wiersze na wyjazd — „OSP – Kielno ·
/// MZ" i „Kielno – OSP · Powrót" — skróty zdarzeń i „OSP" zamiast adresu.
void main() {
  const station = 'Kielno, Oliwska 12';

  final report = Report(
    id: 'r1',
    reportNumber: '0007/2026',
    year: 2026,
    date: DateTime(2026, 4, 3),
    departureTime: DateTime(2026, 4, 3, 19, 40),
    addressLocality: 'Kielno',
    addressStreet: 'Szkolna 5',
    threatCategory: 'Miejscowe Zagrożenie',
    createdAt: DateTime(2026, 4, 3),
    updatedAt: DateTime(2026, 4, 3),
  );

  VehicleTrip trip({
    String purpose = TripPurposes.alarm,
    String routeTo = 'Kielno, Szkolna 5',
    String? reportId = 'r1',
    DateTime? sceneArrival,
    int? sceneOdometer,
    DateTime? sceneDeparture,
    DateTime? returnTime,
    int? odometerEnd,
  }) =>
      VehicleTrip(
        id: 't1',
        vehicleId: 'v1',
        date: DateTime(2026, 4, 3),
        dispatcherName: 'Kwapisz O.',
        routeFrom: station,
        routeTo: routeTo,
        purpose: purpose,
        driverName: 'Mielewczyk M.',
        departureTime: DateTime(2026, 4, 3, 19, 40),
        odometerStart: 3523,
        sceneArrivalTime: sceneArrival,
        sceneOdometer: sceneOdometer,
        sceneDepartureTime: sceneDeparture,
        returnTime: returnTime,
        odometerEnd: odometerEnd,
        idleMinutes: 25,
        reportId: reportId,
        createdAt: DateTime(2026, 4, 3),
        updatedAt: DateTime(2026, 4, 3),
      );

  group('skróty na karcie', () {
    test('zdarzenia: MZ, P, AF — wielkość liter bez znaczenia', () {
      expect(TripLabels.threatShort('Miejscowe Zagrożenie'), 'MZ');
      expect(TripLabels.threatShort('miejscowe zagrożenie'), 'MZ');
      expect(TripLabels.threatShort('Pożar'), 'P');
      expect(TripLabels.threatShort('Fałszywy Alarm'), 'AF');
      expect(TripLabels.threatShort('Ratownictwo wodne'), 'Ratownictwo wodne');
    });

    test('miejsce: remiza to „OSP", reszta — sama miejscowość', () {
      String place(String a) => TripLabels.place(a, stationAddress: station);
      expect(place(station), 'OSP');
      expect(place('kielno,  oliwska 12'), 'OSP');
      expect(place('OSP'), 'OSP');
      expect(place('Kielno, Szkolna 5'), 'Kielno');
      expect(place('Szemud'), 'Szemud');
      expect(place('  '), '');
      expect(TripLabels.place('Kielno, Oliwska 12', stationAddress: ''),
          'Kielno', reason: 'bez adresu remizy nie zgadujemy');
    });
  });

  test('cel jazdy: P, MZ, Ć, Tankowanie, Powrót (Dawid, 9.11.2026)', () {
    final fire = Report(
      id: 'r2',
      reportNumber: '0008/2026',
      year: 2026,
      date: DateTime(2026, 4, 3),
      departureTime: DateTime(2026, 4, 3, 19, 40),
      addressLocality: 'Kielno',
      addressStreet: '',
      threatCategory: 'Pożar',
      createdAt: DateTime(2026, 4, 3),
      updatedAt: DateTime(2026, 4, 3),
    );
    expect(TripLabels.purpose(trip(), fire), 'P');
    expect(TripLabels.purpose(trip(), report), 'MZ');
    expect(
        TripLabels.purpose(
            trip(purpose: TripPurposes.training, reportId: null), null),
        'Ć');
    expect(
        TripLabels.purpose(
            trip(purpose: TripPurposes.refuelling, reportId: null), null),
        'Tankowanie');
    expect(TripLabels.returnLeg, 'Powrót');
  });

  group('dwa wiersze na wyjazd', () {
    test('wyjazd alarmowy z pobytem na miejscu — jak na papierze', () {
      final rows = TripCard.tripRowTexts(
        trip(
          sceneArrival: DateTime(2026, 4, 3, 19, 43),
          sceneOdometer: 3525,
          sceneDeparture: DateTime(2026, 4, 3, 20, 55),
          returnTime: DateTime(2026, 4, 3, 21, 0),
          odometerEnd: 3529,
        ),
        equipmentMinutes: 61,
        stationAddress: station,
        report: report,
      );

      expect(rows, hasLength(2));
      expect(rows[0], [
        '03.04', 'Kwapisz O.', 'OSP – Kielno', 'MZ', 'Mielewczyk M.',
        '19:40', '3523', '19:43', '3525', '61', '', '25', '',
      ]);
      expect(rows[1], [
        '03.04', 'Kwapisz O.', 'Kielno – OSP', 'Powrót', 'Mielewczyk M.',
        '20:55', '3525', '21:00', '3529', '', '', '', '',
      ]);
    });

    test('bez pobytu na miejscu — puste rubryki zamiast zgadywania', () {
      final rows = TripCard.tripRowTexts(
        trip(returnTime: DateTime(2026, 4, 3, 21, 0), odometerEnd: 3529),
        equipmentMinutes: 0,
        stationAddress: station,
        report: report,
      );
      expect(rows[0].sublist(5, 9), ['19:40', '3523', '', '']);
      expect(rows[1].sublist(5, 9), ['', '', '21:00', '3529']);
    });

    test('ćwiczenia w remizie: „OSP – OSP · Ć" i powrót (Dawid, 9.11.2026)', () {
      final rows = TripCard.tripRowTexts(
        trip(purpose: TripPurposes.training, routeTo: station, reportId: null),
        equipmentMinutes: 0,
        stationAddress: station,
      );
      expect(rows[0].sublist(2, 4), ['OSP – OSP', 'Ć']);
      expect(rows[1].sublist(2, 4), ['OSP – OSP', 'Powrót']);
    });

    test('akcja po północy — wiersz powrotu z datą powrotu', () {
      final rows = TripCard.tripRowTexts(
        trip(
          sceneDeparture: DateTime(2026, 4, 3, 23, 58),
          returnTime: DateTime(2026, 4, 4, 0, 2),
        ),
        equipmentMinutes: 0,
        stationAddress: station,
        report: report,
      );
      expect(rows[1][0], '03.04', reason: 'wyjazd z miejsca przed północą');

      final later = TripCard.tripRowTexts(
        trip(returnTime: DateTime(2026, 4, 4, 0, 2)),
        equipmentMinutes: 0,
        stationAddress: station,
        report: report,
      );
      expect(later[1][0], '04.04');
    });
  });

  group('pobyt na miejscu', () {
    test('licznik na miejscu poza zakresem przejazdu — ostrzeżenie', () {
      expect(trip(sceneOdometer: 3525, odometerEnd: 3529)
          .hasSceneOdometerConflict, isFalse);
      expect(trip(sceneOdometer: 3520).hasSceneOdometerConflict, isTrue);
      expect(trip(sceneOdometer: 3540, odometerEnd: 3529)
          .hasSceneOdometerConflict, isTrue);
      expect(trip().hasSceneOdometerConflict, isFalse);
    });

    test('przeżywa zapis na Dysk; przejazd bez niego ma tę samą treść co '
        'dawniej', () {
      final full = trip(
        sceneArrival: DateTime(2026, 4, 3, 19, 43),
        sceneOdometer: 3525,
        sceneDeparture: DateTime(2026, 4, 3, 20, 55),
      );
      final back = SyncJson.tripFromJson(SyncJson.tripToJson(full));
      expect(back.sceneArrivalTime, DateTime(2026, 4, 3, 19, 43));
      expect(back.sceneOdometer, 3525);
      expect(back.sceneDepartureTime, DateTime(2026, 4, 3, 20, 55));

      final legacy = SyncJson.tripToJson(trip());
      expect(legacy.keys.where((k) => k.startsWith('scene')), isEmpty);
    });
  });
}
