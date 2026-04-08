import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';

void main() {
  group('Vehicle', () {
    test('toString shows name and seats', () {
      final v = Vehicle(id: '1', name: 'Mercedes Axor', seats: 6);
      expect(v.toString(), 'Mercedes Axor (6 miejsc)');
    });
  });

  group('Firefighter', () {
    test('fullName returns first + last', () {
      final f = Firefighter(
        id: '1',
        firstName: 'Dawid',
        lastName: 'Kowalski',
        rank: 'Strażak',
      );
      expect(f.fullName, 'Dawid Kowalski');
      expect(f.fullNameWithRank, 'Dawid Kowalski, Strażak');
    });
  });

  group('CrewAssignment', () {
    test('allAssignedIds returns all non-null IDs', () {
      final ca = CrewAssignment(
        vehicleId: 'v1',
        vehicleName: 'MAN',
        driverId: 'f1',
        commanderId: 'f2',
        crewMemberIds: ['f3', 'f4'],
      );
      expect(ca.allAssignedIds, ['f1', 'f2', 'f3', 'f4']);
    });

    test('allAssignedIds excludes nulls', () {
      final ca = CrewAssignment(
        vehicleId: 'v1',
        vehicleName: 'MAN',
        crewMemberIds: ['f3'],
      );
      expect(ca.allAssignedIds, ['f3']);
    });
  });

  group('UnitConfig', () {
    test('fullName computed correctly', () {
      final config = UnitConfig(
        namePrefix: 'Ochotnicza Straż Pożarna',
        locality: 'Kielno',
      );
      expect(config.fullName, 'Ochotnicza Straż Pożarna Kielno');
    });

    test('fullName without locality', () {
      final config = UnitConfig(
        namePrefix: 'Ochotnicza Straż Pożarna',
        locality: '',
      );
      expect(config.fullName, 'Ochotnicza Straż Pożarna');
    });
  });

  group('Report', () {
    test('totalFirefighters counts unique IDs', () {
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
            commanderId: 'f2',
            crewMemberIds: ['f3'],
          ),
          CrewAssignment(
            vehicleId: 'v2',
            vehicleName: 'MAN',
            driverId: 'f4',
            commanderId: 'f5',
            crewMemberIds: [],
          ),
        ],
      );
      expect(report.vehicleCount, 2);
      expect(report.totalFirefighters, 5);
    });

    test('totalFirefighters deduplicates across vehicles', () {
      final report = Report(
        id: 'r1',
        reportNumber: '0002/2026',
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
            commanderId: 'f2',
          ),
        ],
      );
      // f1 + f2 = 2 unique firefighters
      expect(report.totalFirefighters, 2);
    });
  });
}
