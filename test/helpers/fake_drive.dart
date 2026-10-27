import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:osp_app/services/google_auth_service.dart';
import 'package:osp_app/services/google_drive_service.dart';

/// Dysk Google w pamięci — wspólny dla kilku „telefonów" w jednym teście.
///
/// Odwzorowuje tylko to, czego używa synchronizacja: foldery, pliki JSON,
/// chwilę modyfikacji. Liczy zapisy, żeby dało się sprawdzić, że
/// synchronizacja bez zmian niczego nie wysyła.
class FakeDrive implements GoogleDriveService {
  final Map<String, FakeFile> files = {};
  var _nextId = 0;
  var _clock = DateTime.utc(2026, 1, 1);

  /// Zapisy i utworzenia plików od ostatniego [resetCounters].
  int writes = 0;

  /// Odczyty treści plików od ostatniego [resetCounters].
  int reads = 0;

  /// Konto, na którym „pracuje" telefon — właściciel zakładanych jednostek.
  /// Atrapa nie zna kont, więc test ustawia je wprost.
  String? account;

  /// Błąd, którym kończy się każdy zapis — np. zerwane połączenie.
  Object? failWrites;

  void _maybeFail() {
    final error = failWrites;
    if (error != null) throw error;
  }

  void resetCounters() {
    writes = 0;
    reads = 0;
  }

  String _newId(String prefix) => '$prefix${_nextId++}';

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  String _folder(String name, String? parent) {
    final id = _newId('folder');
    files[id] = FakeFile(id, name, parent, isFolder: true);
    return id;
  }

  Iterable<FakeFile> _children(String parentId) =>
      files.values.where((f) => f.parent == parentId);

  String? _childFolder(String parentId, String name) => _children(parentId)
      .where((f) => f.isFolder && f.name == name)
      .firstOrNull
      ?.id;

  /// Plik o dowolnej treści — np. uszkodzony JSON.
  String putRaw(String folderId, String name, String content) {
    final id = _newId('file');
    files[id] = FakeFile(id, name, folderId)
      ..content = content
      ..modified = _tick();
    return id;
  }

  /// Treść wszystkich plików JSON w folderze o podanej nazwie.
  List<Map<String, dynamic>> jsonIn(String folderName) => [
        for (final f in files.values)
          if (!f.isFolder &&
              files[f.parent]?.name == folderName &&
              f.content != null)
            jsonDecode(f.content!) as Map<String, dynamic>,
      ];

  String? folderIdByName(String name) =>
      files.values.where((f) => f.isFolder && f.name == name).firstOrNull?.id;

  @override
  Future<String> createUnitFolder(String unitName) async {
    final id = _folder('OSP_App_$unitName', null);
    files[id]!.owner = account;
    _folder('config', id);
    _folder('reports', id);
    _folder('handovers', id);
    return id;
  }

  @override
  Future<String> createSubfolder(String parentId, String name) async =>
      _folder(name, parentId);

  @override
  Future<List<drive.File>> listSubfolders(String parentId) async => [
        for (final f in _children(parentId))
          if (f.isFolder)
            drive.File()
              ..id = f.id
              ..name = f.name,
      ];

  @override
  Future<String?> findReportsFolder(String unitFolderId) async =>
      _childFolder(unitFolderId, 'reports');

  @override
  Future<String?> findHandoversFolder(String unitFolderId) async =>
      _childFolder(unitFolderId, 'handovers');

  @override
  Future<String?> findConfigFolder(String unitFolderId) async =>
      _childFolder(unitFolderId, 'config');

  @override
  Future<String> findOrCreateYearFolder(String reportsFolderId, int year) async =>
      _childFolder(reportsFolderId, '$year') ??
      _folder('$year', reportsFolderId);

  @override
  Future<List<UnitCandidate>> findUnitsByInviteCode(String code) async => [
        for (final u in _units())
          if (u.inviteCode == code) u,
      ];

  @override
  Future<List<UnitCandidate>> findOwnedUnits() async => [
        for (final u in _units())
          if (account != null && u.ownerEmail == account) u,
      ];

  Iterable<UnitCandidate> _units() sync* {
    for (final f in files.values) {
      if (f.name != 'unit_config.json' || f.content == null) continue;
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(f.content!) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final unit = files[f.parent]?.parent;
      if (unit == null) continue;
      final name = json['unitName'];
      final code = json['inviteCode'];
      final created = json['createdAt'];
      yield UnitCandidate(
        folderId: unit,
        unitName: name is String ? name : '',
        ownerEmail: files[unit]!.owner,
        inviteCode: code is String ? code : null,
        createdAt: created is String ? DateTime.tryParse(created) : null,
      );
    }
  }

  @override
  Future<String> writeJsonFile(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) async {
    final existing = _children(folderId)
        .where((f) => !f.isFolder && f.name == fileName)
        .firstOrNull;
    if (existing != null) return (await updateJsonFile(existing.id, data)).id;
    return (await createJsonFile(folderId, fileName, data)).id;
  }

  @override
  Future<({String id, DateTime? modifiedTime})> createJsonFile(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) async {
    _maybeFail();
    writes++;
    final id = _newId('file');
    final modified = _tick();
    files[id] = FakeFile(id, fileName, folderId)
      ..content = jsonEncode(data)
      ..modified = modified;
    return (id: id, modifiedTime: modified);
  }

  @override
  Future<({String id, DateTime? modifiedTime})> updateJsonFile(
    String fileId,
    Map<String, dynamic> data, {
    String? fileName,
  }) async {
    _maybeFail();
    writes++;
    final f = files[fileId]!;
    if (fileName != null) f.name = fileName;
    f
      ..content = jsonEncode(data)
      ..modified = _tick();
    return (id: fileId, modifiedTime: f.modified);
  }

  @override
  Future<Map<String, dynamic>?> readJsonFile(String fileId) async {
    reads++;
    try {
      return jsonDecode(files[fileId]!.content!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> readJsonFileByName(
    String folderId,
    String fileName,
  ) async {
    final f = _children(folderId)
        .where((f) => !f.isFolder && f.name == fileName)
        .firstOrNull;
    return f == null ? null : readJsonFile(f.id);
  }

  @override
  Future<List<drive.File>> listJsonFiles(String folderId) async => [
        for (final f in _children(folderId))
          if (!f.isFolder)
            drive.File()
              ..id = f.id
              ..name = f.name
              ..modifiedTime = f.modified,
      ];

  @override
  void resetClient() {}

  /// Udostępnienia folderów — z treścią e-maila albo bez (`null`).
  final shares = <({String folderId, String email, String? message})>[];

  @override
  Future<void> shareFolderWithUser(
    String folderId,
    String email, {
    String? message,
  }) async =>
      shares.add((folderId: folderId, email: email, message: message));

  /// Foldery, których „nie widzi" zalogowane konto. Atrapa nie zna kont,
  /// więc test wskazuje je wprost.
  final inaccessible = <String>{};

  @override
  Future<bool> isFolderAccessible(String folderId) async =>
      files[folderId]?.isFolder == true && !inaccessible.contains(folderId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFile {
  final String id;
  String name;
  final String? parent;
  final bool isFolder;
  String? content;
  DateTime? modified;

  /// Właściciel według Dysku — do testów obrony przed podsuniętym folderem.
  String? owner;

  FakeFile(this.id, this.name, this.parent,
      {this.isFolder = false, this.owner});
}

/// Zalogowane konto bez prawdziwego Google.
class FakeAuth implements GoogleAuthService {
  @override
  String? userEmail;

  /// Konto, które „wybierze" użytkownik przy logowaniu albo zmianie konta;
  /// `null` — zamknie okno wyboru bez wybrania.
  String? nextAccount;

  FakeAuth(this.userEmail);

  @override
  bool get isSignedIn => userEmail != null;

  @override
  String? get displayName => null;

  @override
  Future<bool> signIn() async {
    userEmail = nextAccount;
    return userEmail != null;
  }

  @override
  Future<bool> switchAccount() => signIn();

  @override
  Future<void> refreshAuth({bool force = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
