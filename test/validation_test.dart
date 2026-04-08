import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';

void main() {
  group('CrewAssignment - allAssignedIds security', () {
    test('filters out empty string IDs', () {
      final ca = CrewAssignment(
        vehicleId: 'v1',
        vehicleName: 'Test',
        driverId: 'f1',
        commanderId: '',
        crewMemberIds: ['f2', '', 'f3', ''],
      );
      expect(ca.allAssignedIds, ['f1', 'f2', 'f3']);
    });

    test('handles all nulls and empties', () {
      final ca = CrewAssignment(
        vehicleId: 'v1',
        vehicleName: 'Test',
        driverId: null,
        commanderId: null,
        crewMemberIds: ['', ''],
      );
      expect(ca.allAssignedIds, isEmpty);
    });
  });

  group('Report - totalFirefighters with empty IDs', () {
    test('does not count empty string IDs', () {
      final report = Report(
        id: 'r1',
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 4, 7),
        departureTime: DateTime(2026, 4, 7, 14, 30),
        addressLocality: 'Kielno',
        threatCategory: 'Pożar',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        crewAssignments: [
          CrewAssignment(
            vehicleId: 'v1',
            vehicleName: 'Mercedes',
            driverId: 'f1',
            commanderId: '',
            crewMemberIds: ['f2', '', ''],
          ),
        ],
      );
      expect(report.totalFirefighters, 2); // only f1 and f2
    });
  });

  group('Vehicle - input constraints', () {
    test('copyWith preserves data', () {
      final v = Vehicle(id: '1', name: 'Test', seats: 3);
      final v2 = v.copyWith(name: 'Updated');
      expect(v2.name, 'Updated');
      expect(v2.seats, 3);
      expect(v2.id, '1');
    });
  });

  group('Firefighter - input constraints', () {
    test('copyWith preserves data', () {
      final f = Firefighter(
        id: '1',
        firstName: 'Jan',
        lastName: 'Kowalski',
        rank: 'Strażak',
      );
      final f2 = f.copyWith(rank: 'Aspirant');
      expect(f2.firstName, 'Jan');
      expect(f2.lastName, 'Kowalski');
      expect(f2.rank, 'Aspirant');
    });
  });

  group('UnitConfig - defaults', () {
    test('has safe default values', () {
      final config = UnitConfig();
      expect(config.namePrefix, 'Ochotnicza Straż Pożarna');
      expect(config.locality, '');
      expect(config.onboardingCompleted, false);
      expect(config.isAdmin, true);
    });
  });

  group('Report - duplicate firefighter detection', () {
    test('same ID in two vehicles is detectable', () {
      final report = Report(
        id: 'r1',
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 4, 7),
        departureTime: DateTime(2026, 4, 7, 14, 30),
        addressLocality: 'Test',
        threatCategory: 'Pożar',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        crewAssignments: [
          CrewAssignment(
            vehicleId: 'v1',
            vehicleName: 'Car1',
            driverId: 'f1',
          ),
          CrewAssignment(
            vehicleId: 'v2',
            vehicleName: 'Car2',
            driverId: 'f1', // duplicate!
          ),
        ],
      );

      // Collect all IDs and check for duplicates
      final allIds = <String>[];
      for (final crew in report.crewAssignments) {
        allIds.addAll(crew.allAssignedIds);
      }
      final hasDuplicates = allIds.toSet().length != allIds.length;
      expect(hasDuplicates, true);
    });

    test('unique IDs across vehicles passes check', () {
      final report = Report(
        id: 'r1',
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 4, 7),
        departureTime: DateTime(2026, 4, 7, 14, 30),
        addressLocality: 'Test',
        threatCategory: 'Pożar',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        crewAssignments: [
          CrewAssignment(
            vehicleId: 'v1',
            vehicleName: 'Car1',
            driverId: 'f1',
            commanderId: 'f2',
          ),
          CrewAssignment(
            vehicleId: 'v2',
            vehicleName: 'Car2',
            driverId: 'f3',
            commanderId: 'f4',
          ),
        ],
      );

      final allIds = <String>[];
      for (final crew in report.crewAssignments) {
        allIds.addAll(crew.allAssignedIds);
      }
      final hasDuplicates = allIds.toSet().length != allIds.length;
      expect(hasDuplicates, false);
    });
  });
}
