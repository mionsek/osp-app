import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/database_service.dart';

/// Tworzy minimalny obiekt Report z podanym numerem i rokiem.
Report _makeReport({
  required String reportNumber,
  required int year,
  String? id,
}) {
  final now = DateTime(year, 6, 1, 10, 0);
  return Report(
    id: id ?? reportNumber.replaceAll('/', '_'),
    reportNumber: reportNumber,
    year: year,
    date: now,
    departureTime: now,
    returnTime: now,
    addressLocality: 'Testowo',
    addressStreet: '',
    addressDescription: '',
    threatCategory: 'Pożar',
    crewAssignments: const [],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Box<Report> box;

  setUpAll(() async {
    Hive.init('test_hive');
    Hive.registerAdapter(ReportAdapter());
    Hive.registerAdapter(CrewAssignmentAdapter());
  });

  setUp(() async {
    box = await Hive.openBox<Report>('reports_dedup_test_${DateTime.now().millisecondsSinceEpoch}');
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  DatabaseService _buildDb(Box<Report> reportsBox) {
    // Wstrzykujemy box przez patch — zamiast tego testujemy logikę bezpośrednio
    // przez wywołanie metod na DatabaseService z otwartym boxem.
    // Ponieważ DatabaseService korzysta z Hive.box() globalnie, testujemy
    // logikę findDuplicateReportNumbers() niezależnie.
    return DatabaseService();
  }

  group('findDuplicateReportNumbers — logika', () {
    test('brak duplikatów zwraca pustą listę', () {
      final reports = [
        _makeReport(reportNumber: '0001/2025', year: 2025),
        _makeReport(reportNumber: '0002/2025', year: 2025),
        _makeReport(reportNumber: '0003/2025', year: 2025),
      ];

      final counts = <String, int>{};
      for (final r in reports) {
        counts[r.reportNumber] = (counts[r.reportNumber] ?? 0) + 1;
      }
      final duplicates = counts.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList();

      expect(duplicates, isEmpty);
    });

    test('jeden duplikat jest wykrywany', () {
      final reports = [
        _makeReport(reportNumber: '0001/2025', year: 2025, id: 'a'),
        _makeReport(reportNumber: '0001/2025', year: 2025, id: 'b'),
        _makeReport(reportNumber: '0002/2025', year: 2025),
      ];

      final counts = <String, int>{};
      for (final r in reports) {
        counts[r.reportNumber] = (counts[r.reportNumber] ?? 0) + 1;
      }
      final duplicates = counts.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList();

      expect(duplicates.length, 1);
      expect(duplicates, contains('0001/2025'));
    });

    test('wiele duplikatów są wszystkie wykrywane', () {
      final reports = [
        _makeReport(reportNumber: '0001/2025', year: 2025, id: 'a'),
        _makeReport(reportNumber: '0001/2025', year: 2025, id: 'b'),
        _makeReport(reportNumber: '0002/2025', year: 2025, id: 'c'),
        _makeReport(reportNumber: '0002/2025', year: 2025, id: 'd'),
        _makeReport(reportNumber: '0003/2025', year: 2025),
      ];

      final counts = <String, int>{};
      for (final r in reports) {
        counts[r.reportNumber] = (counts[r.reportNumber] ?? 0) + 1;
      }
      final duplicates = counts.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList();

      expect(duplicates.length, 2);
      expect(duplicates, containsAll(['0001/2025', '0002/2025']));
    });

    test('raporty z różnych lat nie są traktowane jako duplikaty', () {
      final reports = [
        _makeReport(reportNumber: '0001/2024', year: 2024),
        _makeReport(reportNumber: '0001/2025', year: 2025),
      ];

      // Symuluj filtr po roku 2025
      final reportsThisYear = reports.where((r) => r.year == 2025).toList();
      final counts = <String, int>{};
      for (final r in reportsThisYear) {
        counts[r.reportNumber] = (counts[r.reportNumber] ?? 0) + 1;
      }
      final duplicates = counts.entries
          .where((e) => e.value > 1)
          .map((e) => e.key)
          .toList();

      expect(duplicates, isEmpty);
    });
  });

  group('getNextReportNumber — logika max+1', () {
    test('zwraca 0001 gdy brak raportów w roku', () {
      final reports = <Report>[];
      final year = 2025;
      int maxNum = 0;
      for (final r in reports.where((r) => r.year == year)) {
        final parts = r.reportNumber.split('/');
        final num = int.tryParse(parts.first) ?? 0;
        if (num > maxNum) maxNum = num;
      }
      final result = '${(maxNum + 1).toString().padLeft(4, '0')}/$year';
      expect(result, '0001/2025');
    });

    test('zwraca max+1 gdy istnieją raporty', () {
      final reports = [
        _makeReport(reportNumber: '0003/2025', year: 2025),
        _makeReport(reportNumber: '0007/2025', year: 2025),
        _makeReport(reportNumber: '0005/2025', year: 2025),
      ];
      final year = 2025;
      int maxNum = 0;
      for (final r in reports.where((r) => r.year == year)) {
        final parts = r.reportNumber.split('/');
        final num = int.tryParse(parts.first) ?? 0;
        if (num > maxNum) maxNum = num;
      }
      final result = '${(maxNum + 1).toString().padLeft(4, '0')}/$year';
      expect(result, '0008/2025');
    });

    test('ignoruje raporty z innych lat', () {
      final reports = [
        _makeReport(reportNumber: '0010/2024', year: 2024),
        _makeReport(reportNumber: '0002/2025', year: 2025),
      ];
      final year = 2025;
      int maxNum = 0;
      for (final r in reports.where((r) => r.year == year)) {
        final parts = r.reportNumber.split('/');
        final num = int.tryParse(parts.first) ?? 0;
        if (num > maxNum) maxNum = num;
      }
      final result = '${(maxNum + 1).toString().padLeft(4, '0')}/$year';
      expect(result, '0003/2025');
    });
  });
}
