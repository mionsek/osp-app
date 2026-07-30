import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/services/location_service.dart';

String street({
  String? thoroughfare,
  String? subThoroughfare,
  String? streetLine,
  String locality = 'Kielno',
}) =>
    LocationService.buildStreet(
      thoroughfare: thoroughfare,
      subThoroughfare: subThoroughfare,
      streetLine: streetLine,
      locality: locality,
    );

void main() {
  group('LocationService.buildStreet', () {
    test('nie dubluje numeru domu', () {
      // Przypadek ze zgloszenia: pole `street` zawiera juz numer,
      // wiec doklejanie `subThoroughfare` dawalo "... 12 12".
      final result = street(
        thoroughfare: 'Józefa Sikorskiego',
        subThoroughfare: '12',
        streetLine: 'Józefa Sikorskiego 12',
      );
      expect(result, 'Józefa Sikorskiego 12');
    });

    test('sklada nazwe ulicy z numerem, gdy linia adresu jest pusta', () {
      expect(
        street(thoroughfare: 'Leśna', subThoroughfare: '5', streetLine: null),
        'Leśna 5',
      );
    });

    test('sama nazwa ulicy, gdy brak numeru', () {
      expect(street(thoroughfare: 'Leśna', subThoroughfare: null), 'Leśna');
    });

    test('adres wiejski: nie powtarza miejscowosci w polu ulicy', () {
      // "Kielno 85" — geokoder podaje miejscowosc jako ulice. Adres ma
      // brzmiec "Kielno, 85", a nie "Kielno, Kielno 85".
      final result = street(
        thoroughfare: 'Kielno',
        subThoroughfare: '85',
        streetLine: 'Kielno 85',
      );
      expect(result, '85');
    });

    test('bez nazwy ulicy korzysta z gotowej linii adresu', () {
      expect(
        street(thoroughfare: null, subThoroughfare: '85', streetLine: '85'),
        '85',
      );
    });

    test('dokleja numer do linii adresu tylko gdy go w niej brakuje', () {
      expect(
        street(thoroughfare: null, subThoroughfare: '5', streetLine: 'Leśna'),
        'Leśna 5',
      );
    });

    test('numer 12 nie jest uznany za obecny w numerze 112', () {
      expect(
        street(thoroughfare: null, subThoroughfare: '12', streetLine: 'Leśna 112'),
        'Leśna 112 12',
      );
    });

    test('brak jakichkolwiek danych daje pusty wynik', () {
      expect(street(), '');
    });
  });
}
