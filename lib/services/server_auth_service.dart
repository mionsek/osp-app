import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'google_auth_service.dart';

/// Logowanie do serwera jednostek — Firebase Auth (feature/081).
///
/// W odróżnieniu od [GoogleAuthService] konto Google prosi **tylko o adres
/// e-mail i imię** — bez dostępu do Dysku, więc bez ekranu „aplikacja chce
/// wyświetlać, edytować, tworzyć i usuwać wszystkie pliki na Dysku” i bez
/// limitu 100 kont dla niezweryfikowanej aplikacji (PLAN_BAZA_DANYCH.md).
///
/// Dostęp do Dysku jest potrzebny już tylko przy przeniesieniu jednostki
/// z Dysku na serwer — prosi o niego [requestDriveAccess], dopiero wtedy.
class ServerAuthService extends GoogleAuthService {
  ServerAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? google,
    GoogleAuthService? driveAuth,
  })  : _authOverride = auth,
        _googleOverride = google,
        _driveAuth = driveAuth;

  final FirebaseAuth? _authOverride;
  GoogleSignIn? _googleOverride;
  GoogleAuthService? _driveAuth;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// Same podstawowe dane konta (e-mail, imię) — `GoogleSignIn()` bez
  /// dodatkowych zakresów.
  GoogleSignIn get _google => _googleOverride ??= GoogleSignIn();

  /// Konto Google z dostępem do Dysku — tylko na czas przeniesienia
  /// jednostki ([requestDriveAccess]).
  GoogleAuthService get _drive => _driveAuth ??= GoogleAuthService();

  User? get _user => _auth.currentUser;

  /// Identyfikator konta na serwerze — klucz rekordu członka jednostki.
  String? get uid => _user?.uid;

  @override
  bool get isSignedIn => _user != null;

  @override
  String? get userEmail => _user?.email;

  @override
  String? get displayName => _user?.displayName;

  /// Firebase pamięta zalogowanie sam — bez okna wyboru konta.
  @override
  Future<bool> trySilentSignIn() async => isSignedIn;

  /// Logowanie kontem Google: tylko e-mail i imię.
  @override
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

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _google.signOut();
    } catch (_) {}
    if (_driveAuth != null) await _drive.signOut();
  }

  @override
  Future<bool> switchAccount() async {
    await signOut();
    return signIn();
  }

  /// Świeży token serwera (żyje godzinę; SDK odświeża go samo, [force]
  /// wymusza nowy po odmowie).
  @override
  Future<void> refreshAuth({bool force = false}) async {
    await _user?.getIdToken(force);
    if (_driveAuth != null && _drive.isSignedIn) {
      await _drive.refreshAuth(force: force);
    }
  }

  /// Klient Dysku — działa dopiero po [requestDriveAccess].
  @override
  http.Client getAuthenticatedClient() => _drive.getAuthenticatedClient();

  /// Pyta o dostęp do Dysku — tylko przy przeniesieniu jednostki z Dysku.
  /// Konto musi być tym samym, którym zalogowano się na serwer.
  Future<bool> requestDriveAccess() async {
    final ok = _drive.isSignedIn || await _drive.trySilentSignIn() ||
        await _drive.signIn();
    if (!ok) return false;
    final same = (_drive.userEmail ?? '').trim().toLowerCase() ==
        (userEmail ?? '').trim().toLowerCase();
    if (!same) await _drive.signOut();
    return same;
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
