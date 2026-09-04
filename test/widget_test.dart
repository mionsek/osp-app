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
      expect(f.fullNameWithRank, 'Kowalski Dawid, Strażak',
          reason: 'na drukach obowiązuje kolejność Nazwisko Imię');
    });

    test('lastNameFirst puts the surname first for phone reporting', () {
      final f = Firefighter(
        id: '1',
        firstName: 'Wiktoria',
        lastName: 'Nowak',
        rank: '',
      );
      expect(f.lastNameFirst, 'Nowak Wiktoria');
    });

    test('functionLabels falls back to "Ratownik" when no role is set', () {
      final f = Firefighter(
          id: '1', firstName: 'Anna', lastName: 'Kowalska', rank: '');
      expect(f.functionLabels, ['Ratownik']);
      expect(f.functionsLabel, 'Ratownik');
    });

    test('functionLabels lists only the roles actually granted', () {
      final f = Firefighter(
        id: '1',
        firstName: 'Jan',
        lastName: 'Kowalski',
        rank: '',
        isDriver: true,
        isKPP: true,
      );
      expect(f.functionLabels, ['Kierowca', 'KPP']);
      expect(f.functionsLabel, 'Kierowca, KPP');
    });

    test('fullNameWithRank omits the comma when rank is empty', () {
      final f = Firefighter(
        id: '1',
        firstName: 'Jan',
        lastName: 'Kowalski',
        rank: '',
      );
      expect(f.fullNameWithRank, 'Kowalski Jan');
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

    test('fullName is empty-safe when nothing was ever configured', () {
      final c = UnitConfig(namePrefix: '', locality: '');
      expect(c.fullName, '');
    });

    test('fullName uses the manually entered unit name when set', () {
      final c = UnitConfig(
        namePrefix: 'Ochotnicza Straż Pożarna',
        locality: 'Kielno',
        unitFullName: 'Ochotnicza Straż Pożarna w Kielnie',
      );
      expect(c.fullName, 'Ochotnicza Straż Pożarna w Kielnie');
    });

    test('fullName falls back to prefix + locality for old configs', () {
      final c = UnitConfig(
        namePrefix: 'Ochotnicza Straż Pożarna',
        locality: 'Kielno',
        unitFullName: '   ',
      );
      expect(c.fullName, 'Ochotnicza Straż Pożarna Kielno');
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

  group('Firefighter — badania lekarskie', () {
    Firefighter withExpiry(DateTime? d) => Firefighter(
          id: 'f1',
          firstName: 'Jan',
          lastName: 'Kowalski',
          rank: '',
          medicalExamExpiry: d,
        );

    test('brak daty to stan nieznany, nie brak waznosci', () {
      // Ratownik bez wpisanej daty nie jest tym samym, co ratownik po
      // terminie — pierwszemu brakuje danych, drugi nie może jechać.
      final ff = withExpiry(null);
      expect(ff.medicalExamStatus, MedicalExamStatus.unknown);
      expect(ff.hasMedicalExam, isFalse);
      expect(ff.isMedicalExamExpired, isFalse);
      expect(ff.isMedicalExamExpiringSoon, isFalse);
    });

    test('data z przeszlosci to brak waznosci', () {
      final ff = withExpiry(DateTime.now().subtract(const Duration(days: 1)));
      expect(ff.medicalExamStatus, MedicalExamStatus.expired);
      expect(ff.isMedicalExamExpired, isTrue);
      // Po terminie nie jest jednocześnie „wygasające" — inaczej lista
      // pokazywałaby dwa ostrzeżenia naraz.
      expect(ff.isMedicalExamExpiringSoon, isFalse);
    });

    test('data w oknie ostrzegawczym to stan wygasajacy', () {
      final ff = withExpiry(
        DateTime.now().add(Firefighter.medicalExamWarningWindow ~/ 2),
      );
      expect(ff.medicalExamStatus, MedicalExamStatus.expiringSoon);
      expect(ff.isMedicalExamExpiringSoon, isTrue);
    });

    test('data poza oknem to badania wazne', () {
      final ff = withExpiry(
        DateTime.now().add(Firefighter.medicalExamWarningWindow * 2),
      );
      expect(ff.medicalExamStatus, MedicalExamStatus.valid);
      expect(ff.isMedicalExamExpiringSoon, isFalse);
      expect(ff.isMedicalExamExpired, isFalse);
    });

    test('formularz liczy stan z samej daty tak samo jak model', () {
      // Formularz ratownika trzyma wpisywaną datę, zanim powstanie z niej
      // `Firefighter`. Wcześniej miał **własną** kopię reguły z własnym progiem
      // 30 dni — po zmianie progu w modelu lista ostrzegałaby, a formularz nie.
      for (final d in <DateTime?>[
        null,
        DateTime.now().subtract(const Duration(days: 5)),
        DateTime.now().add(Firefighter.medicalExamWarningWindow ~/ 2),
        DateTime.now().add(Firefighter.medicalExamWarningWindow * 3),
      ]) {
        expect(MedicalExamStatusX.of(d), withExpiry(d).medicalExamStatus);
      }
    });
  });
}
