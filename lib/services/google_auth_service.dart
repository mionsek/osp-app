import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Service handling Google Sign-In and providing authenticated HTTP client
/// for Google Drive API access.
class GoogleAuthService {
  static const _scopes = [drive.DriveApi.driveFileScope];

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  Map<String, String>? _authHeaders;

  GoogleSignIn get _signIn {
    _googleSignIn ??= GoogleSignIn(scopes: _scopes);
    return _googleSignIn!;
  }

  /// Current signed-in user, or null.
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Whether the user is currently signed in.
  bool get isSignedIn => _currentUser != null;

  /// Try to silently sign in (restore previous session).
  Future<bool> trySilentSignIn() async {
    try {
      _currentUser = await _signIn.signInSilently();
      if (_currentUser != null) {
        _authHeaders = await _currentUser!.authHeaders;
      }
      return isSignedIn;
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
      return false;
    }
  }

  /// Interactive sign in.
  Future<bool> signIn() async {
    try {
      _currentUser = await _signIn.signIn();
      if (_currentUser != null) {
        _authHeaders = await _currentUser!.authHeaders;
      }
      return isSignedIn;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      return false;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _signIn.signOut();
    _currentUser = null;
    _authHeaders = null;
  }

  /// Returns an authenticated HTTP client for googleapis calls.
  /// Throws if not signed in.
  http.Client getAuthenticatedClient() {
    if (_authHeaders == null) {
      throw StateError('Not signed in. Call signIn() first.');
    }
    return _AuthenticatedClient(_authHeaders!);
  }

  /// Get user email.
  String? get userEmail => _currentUser?.email;
}

/// Simple HTTP client that injects auth headers into every request.
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
