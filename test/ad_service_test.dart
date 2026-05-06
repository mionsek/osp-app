import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/services/ad_service.dart';

void main() {
  group('shouldShowAds', () {
    test('returns false for the ospkielno email', () {
      expect(shouldShowAds('ospkielno@gmail.com'), isFalse);
    });

    test('returns true for any other email', () {
      expect(shouldShowAds('jan.kowalski@gmail.com'), isTrue);
      expect(shouldShowAds('user@osp.pl'), isTrue);
      expect(shouldShowAds('admin@example.com'), isTrue);
    });

    test('returns true when email is null (not signed in)', () {
      expect(shouldShowAds(null), isTrue);
    });

    test('returns true when email is empty string', () {
      expect(shouldShowAds(''), isTrue);
    });

    test('is case-sensitive — different case means ads shown', () {
      // Email check is intentionally exact — prevents trivial bypass
      expect(shouldShowAds('OSPKIELNO@GMAIL.COM'), isTrue);
      expect(shouldShowAds('Ospkielno@gmail.com'), isTrue);
    });
  });

  group('bannerAdUnitId', () {
    test('test ad unit ID has expected Google test format', () {
      expect(bannerAdUnitId, startsWith('ca-app-pub-'));
      // Google's official test publisher ID
      expect(bannerAdUnitId, contains('3940256099942544'));
    });
  });
}
