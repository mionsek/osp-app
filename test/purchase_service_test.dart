import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/purchase_service.dart';

// ---------------------------------------------------------------------------
// Minimal mock for Box<dynamic> — only `get` and `put` are needed.
// ---------------------------------------------------------------------------
class MockBox extends Mock implements Box<dynamic> {}

class MockDatabaseService extends Mock implements DatabaseService {
  final MockBox _box = MockBox();

  @override
  Box<dynamic> get settingsBox => _box;
}

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('PurchaseService.isPremium', () {
    test('returns false when configBox has no isPremium entry', () {
      when(() => mockDb.settingsBox.get('isPremium')).thenReturn(null);
      final service = PurchaseService(mockDb);
      expect(service.isPremium, isFalse);
    });

    test('returns false when configBox has isPremium = false', () {
      when(() => mockDb.settingsBox.get('isPremium')).thenReturn(false);
      final service = PurchaseService(mockDb);
      expect(service.isPremium, isFalse);
    });

    test('returns true when configBox has isPremium = true', () {
      when(() => mockDb.settingsBox.get('isPremium')).thenReturn(true);
      final service = PurchaseService(mockDb);
      expect(service.isPremium, isTrue);
    });
  });

  group('PurchaseService product ID', () {
    test('kRemoveAdsProductId has expected value', () {
      expect(kRemoveAdsProductId, 'remove_ads');
    });
  });
}
