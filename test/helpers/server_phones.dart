import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/services/auth_service.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'phone_db.dart';

/// Konto na serwerze w testach — bez Firebase i bez okna wyboru konta.
class FakeServerAuth implements AuthService {
  @override
  String? userEmail;

  @override
  String? uid;

  /// Imię i nazwisko z konta Google.
  @override
  String? displayName;

  /// Konto, które „wybierze” użytkownik przy logowaniu i zmianie konta;
  /// `null` — zamknięte okno wyboru.
  ({String uid, String email})? nextAccount;

  /// Błąd przy odświeżaniu tokenu — jak zerwane połączenie z serwerem.
  Object? failRefresh;

  FakeServerAuth(this.uid, this.userEmail, [this.displayName]);

  @override
  bool get isSignedIn => uid != null;

  @override
  Future<bool> trySilentSignIn() async => isSignedIn;

  @override
  Future<bool> signIn() async {
    uid = nextAccount?.uid;
    userEmail = nextAccount?.email;
    return isSignedIn;
  }

  @override
  Future<void> signOut() async {
    uid = null;
    userEmail = null;
  }

  @override
  Future<bool> switchAccount() => signIn();

  @override
  Future<void> refreshAuth({bool force = false}) async {
    if (failRefresh case final e?) throw e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Kilka „telefonów” i jeden serwer w pamięci (`fake_cloud_firestore`).
///
/// Każdy telefon ma własną bazę Hive pod [root]; przełączenie zamyka bazę
/// jednego i otwiera bazę drugiego — tak, jakby kolega uruchomił aplikację
/// u siebie. Zasad bezpieczeństwa serwera atrapa nie zna — sprawdzają je
/// testy na emulatorze (`firebase/test`).
class ServerPhones {
  ServerPhones(this.root);

  final Directory root;
  final fs = FakeFirebaseFirestore();
  final db = DatabaseService();

  /// Ostatnio przełączony telefon — jego konto.
  late FakeServerAuth auth;

  /// Telefon [name] zalogowany kontem `<name>@gmail.com` (albo [account]).
  Future<SyncService> phone(
    String name, {
    String? account,
    String? uid,
    String? displayName,
    Duration localChangeDelay = const Duration(seconds: 2),
  }) async {
    await openPhoneDb(root, name);
    final email = account ?? '$name@gmail.com';
    auth = FakeServerAuth(uid ?? email.split('@').first, email, displayName);
    final sync = SyncService(db, auth,
        firestore: fs, localChangeDelay: localChangeDelay);
    await sync.restoreState();
    return sync;
  }

  /// Jak ekran wprowadzenia i Ustawienia: nazwa trafia najpierw do
  /// ustawień telefonu, potem zakłada się jednostkę.
  Future<String> create(SyncService sync, [String unitName = 'OSP Test']) async {
    await db.saveConfig(db.getConfig().copyWith(unitFullName: unitName));
    return sync.createUnit(unitName);
  }

  /// [founder] zakłada jednostkę, zaprasza [member], a ten dołącza — na
  /// koniec otwarty jest telefon [member]. Zwraca kod zaproszenia.
  Future<String> unitWith(String founder, String member,
      {String unitName = 'OSP Test'}) async {
    final a = await phone(founder);
    final code = await create(a, unitName);
    await a.inviteMember('$member@gmail.com');
    final b = await phone(member);
    expect(await b.joinUnit(code), isTrue);
    return code;
  }

  Future<Map<String, dynamic>?> doc(String path) async =>
      (await fs.doc(path).get()).data();

  Future<String> unitIdOf(String code) async =>
      (await doc('inviteCodes/$code'))!['unitId'] as String;

  /// Dokumenty kolekcji jednostki (np. `reports`) — identyfikator → treść.
  Future<Map<String, Map<String, dynamic>>> docs(
      String code, String collection) async {
    final snap = await fs
        .collection('units/${await unitIdOf(code)}/$collection')
        .get();
    return {for (final d in snap.docs) d.id: d.data()};
  }

  /// Treść wpisów kolekcji (`data`), bez znaczników usunięcia.
  Future<List<Map<String, dynamic>>> live(String code, String collection) async =>
      [
        for (final d in (await docs(code, collection)).values)
          if (d['deleted'] != true) Map<String, dynamic>.from(d['data'] as Map),
      ];

  /// Czy tekst występuje gdziekolwiek na serwerze.
  bool mentions(String text) => fs.dump().contains(text);
}
