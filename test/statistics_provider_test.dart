import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/providers/statistics_provider.dart';

// ---------------------------------------------------------------------------
// Pomocnicze fabryki
// ---------------------------------------------------------------------------

Firefighter _ff(String id, String firstName, String lastName) => Firefighter(
      id: id,
      firstName: firstName,
      lastName: lastName,
      rank: 'strażak',
    );

CrewAssignment _crew({
  String vehicleId = 'v1',
  String vehicleName = 'GBA 1',
  String? driverId,
  String? commanderId,
  List<String> crewMemberIds = const [],
}) =>
    CrewAssignment(
      vehicleId: vehicleId,
      vehicleName: vehicleName,
      driverId: driverId,
      commanderId: commanderId,
      crewMemberIds: crewMemberIds,
    );

Report _report({
  required String id,
  required String reportNumber,
  required int year,
  required String threatCategory,
  List<CrewAssignment> crewAssignments = const [],
  DateTime? departureTime,
  DateTime? returnTime,
}) {
  final dep = departureTime ?? DateTime(year, 6, 1, 8, 0);
  return Report(
    id: id,
    reportNumber: reportNumber,
    year: year,
    date: dep,
    departureTime: dep,
    returnTime: returnTime,
    addressLocality: 'Testowo',
    threatCategory: threatCategory,
    crewAssignments: crewAssignments,
    createdAt: dep,
    updatedAt: dep,
  );
}

// ---------------------------------------------------------------------------
// Testy
// ---------------------------------------------------------------------------

void main() {
  group('computeYearStats', () {
    test('brak raportów — puste statystyki', () {
      final stats = computeYearStats([], [], 2025);

      expect(stats.totalTrips, 0);
      expect(stats.firefighterStats, isEmpty);
      expect(stats.threatCategoryCounts, isEmpty);
      expect(stats.totalDuration, Duration.zero);
      expect(stats.incompleteReports, isEmpty);
    });

    test('filtr roku — ignoruje raporty z innych lat', () {
      final reports = [
        _report(
            id: 'r1',
            reportNumber: '0001/2024',
            year: 2024,
            threatCategory: 'Pożar'),
        _report(
            id: 'r2',
            reportNumber: '0001/2025',
            year: 2025,
            threatCategory: 'Pożar'),
      ];

      final stats = computeYearStats(reports, [], 2025);

      expect(stats.totalTrips, 1);
    });

    test('zliczanie kategorii zagrożeń', () {
      final reports = [
        _report(
            id: 'r1',
            reportNumber: '001/2025',
            year: 2025,
            threatCategory: 'Pożar'),
        _report(
            id: 'r2',
            reportNumber: '002/2025',
            year: 2025,
            threatCategory: 'Pożar'),
        _report(
            id: 'r3',
            reportNumber: '003/2025',
            year: 2025,
            threatCategory: 'Miejscowe zagrożenie'),
        _report(
            id: 'r4',
            reportNumber: '004/2025',
            year: 2025,
            threatCategory: 'Fałszywy alarm'),
      ];

      final stats = computeYearStats(reports, [], 2025);

      expect(stats.threatCategoryCounts['Pożar'], 2);
      expect(stats.threatCategoryCounts['Miejscowe zagrożenie'], 1);
      expect(stats.threatCategoryCounts['Fałszywy alarm'], 1);
      expect(stats.totalTrips, 4);
    });

    test('strażak w dwóch pojazdach jednego raportu = 1 wyjazd', () {
      final ff1 = _ff('ff1', 'Jan', 'Kowalski');
      final report = _report(
        id: 'r1',
        reportNumber: '001/2025',
        year: 2025,
        threatCategory: 'Pożar',
        crewAssignments: [
          _crew(vehicleId: 'v1', driverId: 'ff1'),
          _crew(vehicleId: 'v2', commanderId: 'ff1'),
        ],
      );

      final stats = computeYearStats([report], [ff1], 2025);

      expect(stats.firefighterStats.length, 1);
      expect(stats.firefighterStats.first.tripCount, 1);
    });

    test('strażacy posortowani malejąco wg liczby wyjazdów', () {
      final ff1 = _ff('ff1', 'Jan', 'Kowalski');
      final ff2 = _ff('ff2', 'Anna', 'Nowak');
      final ff3 = _ff('ff3', 'Piotr', 'Wiśniewski');

      final reports = [
        _report(
            id: 'r1',
            reportNumber: '001/2025',
            year: 2025,
            threatCategory: 'Pożar',
            crewAssignments: [
              _crew(driverId: 'ff1', commanderId: 'ff2',
                  crewMemberIds: ['ff3'])
            ]),
        _report(
            id: 'r2',
            reportNumber: '002/2025',
            year: 2025,
            threatCategory: 'Pożar',
            crewAssignments: [_crew(driverId: 'ff1', commanderId: 'ff2')]),
        _report(
            id: 'r3',
            reportNumber: '003/2025',
            year: 2025,
            threatCategory: 'Pożar',
            crewAssignments: [_crew(driverId: 'ff1')]),
      ];

      final stats = computeYearStats(reports, [ff1, ff2, ff3], 2025);

      expect(stats.firefighterStats[0].firefighter.id, 'ff1'); // 3 wyjazdy
      expect(stats.firefighterStats[0].tripCount, 3);
      expect(stats.firefighterStats[1].firefighter.id, 'ff2'); // 2 wyjazdy
      expect(stats.firefighterStats[1].tripCount, 2);
      expect(stats.firefighterStats[2].firefighter.id, 'ff3'); // 1 wyjazd
      expect(stats.firefighterStats[2].tripCount, 1);
    });

    test('strażacy z 0 wyjazdami są ukryci', () {
      final ff1 = _ff('ff1', 'Jan', 'Kowalski');
      final ff2 = _ff('ff2', 'Anna', 'Nowak'); // nie bierze udziału

      final report = _report(
        id: 'r1',
        reportNumber: '001/2025',
        year: 2025,
        threatCategory: 'Pożar',
        crewAssignments: [_crew(driverId: 'ff1')],
      );

      final stats = computeYearStats([report], [ff1, ff2], 2025);

      expect(stats.firefighterStats.length, 1);
      expect(stats.firefighterStats.first.firefighter.id, 'ff1');
    });

    test('łączny czas akcji — suma czasów', () {
      final reports = [
        _report(
          id: 'r1',
          reportNumber: '001/2025',
          year: 2025,
          threatCategory: 'Pożar',
          departureTime: DateTime(2025, 6, 1, 8, 0),
          returnTime: DateTime(2025, 6, 1, 10, 30), // 2h 30min
        ),
        _report(
          id: 'r2',
          reportNumber: '002/2025',
          year: 2025,
          threatCategory: 'Pożar',
          departureTime: DateTime(2025, 6, 2, 14, 0),
          returnTime: DateTime(2025, 6, 2, 15, 0), // 1h
        ),
      ];

      final stats = computeYearStats(reports, [], 2025);

      expect(stats.totalDuration, const Duration(hours: 3, minutes: 30));
      expect(stats.incompleteReports, isEmpty);
    });

    test('raport bez returnTime — czas 0 i pojawia się w incompleteReports', () {
      final report = _report(
        id: 'r1',
        reportNumber: '001/2025',
        year: 2025,
        threatCategory: 'Pożar',
        returnTime: null,
      );

      final stats = computeYearStats([report], [], 2025);

      expect(stats.totalDuration, Duration.zero);
      expect(stats.incompleteReports, contains('001/2025'));
    });

    test('raport z ujemnym czasem — traktowany jak niekompletny', () {
      final report = _report(
        id: 'r1',
        reportNumber: '001/2025',
        year: 2025,
        threatCategory: 'Pożar',
        departureTime: DateTime(2025, 6, 1, 10, 0),
        returnTime: DateTime(2025, 6, 1, 8, 0), // returnTime przed departureTime
      );

      final stats = computeYearStats([report], [], 2025);

      expect(stats.totalDuration, Duration.zero);
      expect(stats.incompleteReports, contains('001/2025'));
    });
  });
}
