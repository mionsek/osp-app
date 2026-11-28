import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Logowanie do serwera jednostek — Firebase Auth kontem Google
/// (feature/081).
///
/// Konto Google prosi **tylko o adres e-mail i imię** — bez dostępu do Dysku,
/// więc bez ekranu „aplikacja chce wyświetlać, edytować, tworzyć i usuwać
/// wszystkie pliki na Dysku” i bez limitu 100 kont dla niezweryfikowanej
/// aplikacji (PLAN_BAZA_DANYCH.md).
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? google,
  })  : _authOverride = auth,
        _googleOverride = google;

  final FirebaseAuth? _authOverride;
  GoogleSignIn? _googleOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Same podstawowe dane konta (e-mail, imię) — `GoogleSignIn()` bez
  /// dodatkowych zakresów.
  GoogleSignIn get _google => _googleOverride ??= GoogleSignIn();

  /// Bez uruchomionego Firebase (brak konfiguracji, testy) — niezalogowany.
  User? get _user {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Identyfikator konta na serwerze — klucz rekordu członka jednostki.
  String? get uid => _user?.uid;

  bool get isSignedIn => _user != null;

  String? get userEmail => _user?.email;

  /// Imię i nazwisko z konta Google — do pokazania obok adresu.
  String? get displayName => _user?.displayName;

  /// Firebase pamięta zalogowanie sam — bez okna wyboru konta.
  Future<bool> trySilentSignIn() async => isSignedIn;

  /// Logowanie kontem Google: tylko e-mail i imię.
  Future<bool> signIn() async {
    try {
      final account = await _google.signIn();
      if (account == null) return false;
      final tokens = await account.authentication;
      await _auth.signInWithCredential(GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ));
      return isSignedIn;
    } catch (e) {
      debugPrint('Logowanie na serwer nieudane: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _google.signOut();
    } catch (_) {}
  }

  /// Pokazuje wybór konta Google od nowa.
  ///
  /// [signIn] przy zalogowanym koncie oddaje to samo konto bez pytania, więc
  /// żeby wybrać inne, trzeba się najpierw wylogować. Anulowanie wyboru
  /// zostawia aplikację wylogowaną.
  Future<bool> switchAccount() async {
    await signOut();
    return signIn();
  }

  /// Świeży token serwera (żyje godzinę; SDK odświeża go samo, [force]
  /// wymusza nowy po odmowie).
  Future<void> refreshAuth({bool force = false}) async {
    await _user?.getIdToken(force);
  }

  /// Usuwa konto z serwera. Firebase może zażądać świeżego logowania —
  /// wtedy jeszcze raz pytamy o konto Google i ponawiamy.
  Future<void> deleteAccount() async {
    final user = _user;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      final account = await _google.signIn();
      if (account == null) rethrow;
      final tokens = await account.authentication;
      await user.reauthenticateWithCredential(GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      ));
      await user.delete();
    }
    await signOut();
  }
}
