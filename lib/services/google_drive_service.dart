import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'drive_retry.dart';
import 'google_auth_service.dart';

/// Osoba mająca dostęp do folderu jednostki na Dysku.
class UnitMemberAccess {
  final String permissionId;
  final String email;

  /// Właściciela folderu (założyciela) nie da się z niego usunąć.
  final bool isOwner;

  const UnitMemberAccess({
    required this.permissionId,
    required this.email,
    required this.isOwner,
  });
}

/// Jednostka znaleziona po kodzie zaproszenia, przed dołączeniem.
class UnitCandidate {
  final String folderId;

  /// Nazwa z `unit_config.json` — tę może wpisać każdy, kto ma plik.
  final String unitName;

  /// Właściciel folderu według Dysku. W odróżnieniu od treści pliku tego
  /// nie da się podrobić, więc to on pokazuje, czyja to naprawdę jednostka.
  final String? ownerEmail;

  /// Kod zaproszenia z `unit_config.json` — znany od razu przy jednostkach
  /// własnego konta, które nie są szukane po kodzie.
  final String? inviteCode;

  /// Kiedy założono jednostkę — kilka jednostek o tej samej nazwie da się
  /// odróżnić tylko po dacie i kodzie.
  final DateTime? createdAt;

  const UnitCandidate({
    required this.folderId,
    required this.unitName,
    this.ownerEmail,
    this.inviteCode,
    this.createdAt,
  });
}

/// Service for CRUD operations on Google Drive.
/// All data lives in a shared unit folder.
///
/// Każde zapytanie przy zerwanym połączeniu albo chwilowym przeciążeniu
/// Google jest ponawiane ([retryTransient]), zanim błąd trafi wyżej.
class GoogleDriveService {
  final GoogleAuthService _authService;
  final List<Duration> _retryDelays;
  drive.DriveApi? _driveApi;

  GoogleDriveService(
    this._authService, {
    List<Duration> retryDelays = defaultDriveRetryDelays,
  }) : _retryDelays = retryDelays;

  drive.DriveApi get _api {
    _driveApi ??= drive.DriveApi(_authService.getAuthenticatedClient());
    return _driveApi!;
  }

  Future<T> _retry<T>(Future<T> Function() call) =>
      retryTransient(call, delays: _retryDelays);

  /// Reset cached API client (e.g. after re-sign-in).
  void resetClient() {
    _driveApi = null;
  }

  // ── Folder operations ──────────────────────────────────────────

  /// Create the unit folder on Drive. Returns folder ID.
  ///
  /// Sam folder jednostki nie jest ponawiany: po zerwanym połączeniu nie da
  /// się odróżnić „nie powstał" od „powstał, tylko odpowiedź nie doszła",
  /// a szukanie po nazwie trafiłoby w starsze jednostki o tej samej nazwie.
  /// Kolejna próba założenia pokaże i tak ostrzeżenie o jednostce, która
  /// już jest na tym koncie.
  Future<String> createUnitFolder(String unitName) async {
    final folder = drive.File()
      ..name = 'OSP_App_$unitName'
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _api.files.create(folder);
    final folderId = created.id!;

    // Create config subfolder
    await _createSubfolder(folderId, 'config');

    // Create reports subfolder
    await _createSubfolder(folderId, 'reports');

    // Create property handovers subfolder
    await _createSubfolder(folderId, 'handovers');

    return folderId;
  }

  /// Create a subfolder in a parent folder. Returns subfolder ID.
  Future<String> createSubfolder(String parentId, String name) async {
    return _createSubfolder(parentId, name);
  }

  /// List subfolders inside a folder.
  Future<List<drive.File>> listSubfolders(String parentId) async {
    return _listSubfolders(parentId);
  }

  /// Podfoldery mają w jednostce stałe, niepowtarzalne nazwy (`config`,
  /// `reports`, `2026`…), więc przy ponowieniu sprawdzamy najpierw, czy
  /// folder nie powstał przy próbie, której odpowiedź się zgubiła — inaczej
  /// powstałby drugi o tej samej nazwie.
  Future<String> _createSubfolder(String parentId, String name) {
    var attempt = 0;
    return _retry(() async {
      if (attempt++ > 0) {
        final existing = await _queryChildFolder(parentId, name);
        if (existing != null) return existing;
      }
      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];

      final created = await _api.files.create(folder);
      return created.id!;
    });
  }

  /// List subfolders inside a folder — najstarsze pierwsze.
  ///
  /// Gdy dwa telefony założyły folder o tej samej nazwie, każdy pisze do
  /// pierwszego z listy — przy kolejności według daty założenia jest to ten
  /// sam folder na wszystkich telefonach.
  Future<List<drive.File>> _listSubfolders(String parentId) => _listAll(
        "'$parentId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        fields: 'id, name',
        orderBy: _oldestFirst,
      );

  static const _oldestFirst = 'createdTime';

  /// Wszystkie pliki pasujące do [query], strona po stronie.
  ///
  /// Bez stronicowania Dysk oddaje najwyżej 100 plików naraz. Folder
  /// przejazdów przekracza to w kilka miesięcy, a folder raportów w roku
  /// pracowitej jednostki — reszta po cichu nie docierała do kolegów ani na
  /// nowy telefon.
  Future<List<drive.File>> _listAll(
    String query, {
    required String fields,
    String? orderBy,
  }) async {
    final files = <drive.File>[];
    String? pageToken;
    do {
      final token = pageToken;
      final result = await _retry(() => _api.files.list(
            q: query,
            spaces: 'drive',
            pageSize: 1000,
            pageToken: token,
            orderBy: orderBy,
            $fields: 'nextPageToken, files($fields)',
          ));
      files.addAll(result.files ?? const []);
      pageToken = result.nextPageToken;
    } while (pageToken != null);
    return files;
  }

  /// Podfolder o podanej nazwie (najstarszy, gdy jest kilka), bez
  /// ponawiania — do użycia wewnątrz operacji, która sama jest ponawiana.
  Future<String?> _queryChildFolder(String parentId, String name) async {
    final result = await _api.files.list(
      q: "'$parentId' in parents and name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      orderBy: _oldestFirst,
      $fields: 'files(id)',
    );
    return result.files?.isNotEmpty == true ? result.files!.first.id : null;
  }

  Future<String?> _childFolder(String parentId, String name) =>
      _retry(() => _queryChildFolder(parentId, name));

  /// Find reports subfolder inside unit folder.
  Future<String?> findReportsFolder(String unitFolderId) =>
      _childFolder(unitFolderId, 'reports');

  /// Find property handovers subfolder inside unit folder.
  Future<String?> findHandoversFolder(String unitFolderId) =>
      _childFolder(unitFolderId, 'handovers');

  /// Find config subfolder inside unit folder.
  Future<String?> findConfigFolder(String unitFolderId) =>
      _childFolder(unitFolderId, 'config');

  /// Find or create a year subfolder inside reports folder.
  Future<String> findOrCreateYearFolder(String reportsFolderId, int year) async {
    final yearStr = year.toString();
    return await _childFolder(reportsFolderId, yearStr) ??
        await _createSubfolder(reportsFolderId, yearStr);
  }

  /// Share the unit folder with a user (by email).
  ///
  /// Bez tego kolega nie dołączy do jednostki: sam kod zaproszenia nie
  /// wystarczy, bo [findUnitsByInviteCode] przeszukuje wyłącznie pliki,
  /// do których jego konto ma już dostęp na Dysku.
  ///
  /// Z [message] Google wysyła na ten adres wiadomość o udostępnieniu
  /// folderu razem z tą treścią — tak kolega dostaje kod zaproszenia.
  /// Bez niej (np. gdy ktoś udostępnia jednostkę samemu sobie) nic nie
  /// jest wysyłane.
  Future<void> shareFolderWithUser(
    String folderId,
    String email, {
    String? message,
  }) async {
    final permission = drive.Permission()
      ..type = 'user'
      ..role = 'writer'
      ..emailAddress = email;

    await _retry(() => _api.permissions.create(
          permission,
          folderId,
          sendNotificationEmail: message != null,
          emailMessage: message,
        ));
  }

  /// Osoby mające dostęp do folderu jednostki (bez właściciela).
  Future<List<UnitMemberAccess>> listFolderMembers(String folderId) async {
    final result = await _retry(() => _api.permissions.list(
          folderId,
          $fields: 'permissions(id, emailAddress, role, type)',
        ));
    final permissions = result.permissions ?? [];
    return permissions
        .where((p) => p.type == 'user' && p.emailAddress != null)
        .map((p) => UnitMemberAccess(
              permissionId: p.id ?? '',
              email: p.emailAddress!,
              isOwner: p.role == 'owner',
            ))
        .toList();
  }

  /// Odbiera dostęp do folderu jednostki.
  Future<void> revokeFolderAccess(String folderId, String permissionId) =>
      _retry(() => _api.permissions.delete(folderId, permissionId));

  /// Wszystkie jednostki widoczne dla konta, których `unit_config.json` ma
  /// podany kod zaproszenia.
  ///
  /// Wszystkie, a nie pierwsza: przy pełnym dostępie do Dysku wyszukiwanie
  /// obejmuje też foldery udostępnione przez obcych, więc ktoś znający kod
  /// mógł podsunąć własny folder z takim samym plikiem, a Dysk nie
  /// gwarantuje kolejności wyników. Ekran dołączania odmawia, gdy pasuje
  /// więcej niż jedna, i pokazuje właściciela folderu przed dołączeniem.
  Future<List<UnitCandidate>> findUnitsByInviteCode(String code) =>
      _findUnits(where: (content) => content['inviteCode'] == code);

  /// Jednostki, których folder należy do zalogowanego konta.
  ///
  /// Każde „Utwórz jednostkę" zakłada nowy folder, więc bez sprawdzenia na
  /// jednym koncie zbierały się identycznie nazwane jednostki z testów
  /// i nie było wiadomo, która jest prawdziwa.
  Future<List<UnitCandidate>> findOwnedUnits() => _findUnits(ownedOnly: true);

  /// Jednostki widoczne dla konta: każdy `unit_config.json`, którego treść
  /// przechodzi [where], a z [ownedOnly] — tylko w folderach tego konta.
  Future<List<UnitCandidate>> _findUnits({
    bool Function(Map<String, dynamic> content)? where,
    bool ownedOnly = false,
  }) async {
    final files = await _listAll(
      "name = 'unit_config.json' and mimeType = 'application/json' and trashed = false",
      fields: 'id, parents',
    );

    final found = <String, UnitCandidate>{};
    for (final file in files) {
      try {
        final content = await readJsonFile(file.id!);
        if (content == null || (where != null && !where(content))) continue;
        final parentId =
            file.parents?.isNotEmpty == true ? file.parents!.first : null;
        if (parentId == null) continue;

        // Plik leży w podfolderze `config`, więc jednostka to folder wyżej.
        // Najstarsze jednostki miały plik bezpośrednio w swoim folderze —
        // wcześniej brany był wtedy rodzic tego folderu, czyli np. cały
        // „Mój dysk".
        final parent = await _retry(
            () => _api.files.get(parentId, $fields: 'name, parents'));
        final unitFolderId = parent is drive.File &&
                parent.name == 'config' &&
                parent.parents?.isNotEmpty == true
            ? parent.parents!.first
            : parentId;
        if (found.containsKey(unitFolderId)) continue;

        final unitFolder = await _retry(() => _api.files.get(unitFolderId,
            $fields: 'owners(emailAddress), ownedByMe'));
        final folder = unitFolder is drive.File ? unitFolder : null;
        if (ownedOnly && folder?.ownedByMe != true) continue;

        final name = content['unitName'];
        final code = content['inviteCode'];
        final createdAt = content['createdAt'];
        found[unitFolderId] = UnitCandidate(
          folderId: unitFolderId,
          unitName: name is String ? name : '',
          ownerEmail: folder?.owners?.firstOrNull?.emailAddress,
          inviteCode: code is String ? code : null,
          createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
        );
      } catch (e) {
        // Brak sieci to nie „nie znaleziono" — inaczej ekran podpowiadałby
        // prośbę o zaproszenie zamiast ponownej próby.
        if (isTransientDriveError(e)) rethrow;
        debugPrint('Error checking file ${file.id}: $e');
      }
    }
    return found.values.toList();
  }

  // ── JSON file operations ───────────────────────────────────────

  /// Zapisuje plik konfiguracji jednostki pod stałą nazwą — nadpisuje
  /// istniejący albo tworzy nowy.
  ///
  /// Tylko dla plików o stałych nazwach (`firefighters.json`, `admins.json`
  /// itp.). Raporty, przekazania i przejazdy idą przez [createJsonFile]
  /// i [updateJsonFile] — rozpoznawane po identyfikatorze w treści, a nie po
  /// nazwie, która zmieniała się między wersjami aplikacji i dawała duplikaty.
  ///
  /// Ponawiane w całości, razem z wyszukaniem: plik utworzony przy próbie,
  /// której odpowiedź się zgubiła, jest wtedy nadpisywany, a nie zakładany
  /// drugi raz.
  Future<String> writeJsonFile(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) =>
      _retry(() async {
        final existingId = await _queryFileId(folderId, fileName);
        if (existingId != null) {
          return (await _update(existingId, data)).id;
        }
        return (await _create(folderId, fileName, data)).id;
      });

  /// Tworzy nowy plik JSON. Zwraca jego identyfikator i chwilę modyfikacji —
  /// po niej synchronizacja poznaje, że pliku nie trzeba czytać ponownie.
  ///
  /// Gdy odpowiedź na udane utworzenie się zgubi, ponowienie zostawi na
  /// Dysku drugi plik z tym samym rekordem. Synchronizacja to znosi —
  /// rekord rozpoznaje po identyfikatorze w treści i bierze najnowszy plik.
  Future<({String id, DateTime? modifiedTime})> createJsonFile(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) =>
      _retry(() => _create(folderId, fileName, data));

  Future<({String id, DateTime? modifiedTime})> _create(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) async {
    final file = drive.File()
      ..name = fileName
      ..parents = [folderId];
    final created = await _api.files.create(
      file,
      uploadMedia: _media(data),
      $fields: 'id, modifiedTime',
    );
    return (id: created.id!, modifiedTime: created.modifiedTime);
  }

  /// Nadpisuje treść pliku o znanym identyfikatorze; [fileName] — nową nazwę,
  /// gdy się zmieniła (np. po zmianie reguły nazywania).
  Future<({String id, DateTime? modifiedTime})> updateJsonFile(
    String fileId,
    Map<String, dynamic> data, {
    String? fileName,
  }) =>
      _retry(() => _update(fileId, data, fileName: fileName));

  Future<({String id, DateTime? modifiedTime})> _update(
    String fileId,
    Map<String, dynamic> data, {
    String? fileName,
  }) async {
    final file = drive.File();
    if (fileName != null) file.name = fileName;
    final updated = await _api.files.update(
      file,
      fileId,
      uploadMedia: _media(data),
      $fields: 'id, modifiedTime',
    );
    return (id: updated.id!, modifiedTime: updated.modifiedTime);
  }

  static drive.Media _media(Map<String, dynamic> data) {
    final content =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    return drive.Media(Stream.value(content), content.length);
  }

  /// Read a JSON file by its file ID.
  ///
  /// `null` dla pliku, którego nie da się odczytać jako JSON — synchronizacja
  /// pomija go i liczy jako uszkodzony. Zerwanego połączenia nie: to nie
  /// wina pliku, więc błąd idzie wyżej i synchronizacja zgłasza brak sieci.
  Future<Map<String, dynamic>?> readJsonFile(String fileId) async {
    final List<int> bytes;
    try {
      bytes = await _retry(() async {
        final media = await _api.files.get(fileId,
            downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final chunks = <int>[];
        await for (final chunk in media.stream) {
          chunks.addAll(chunk);
        }
        return chunks;
      });
    } catch (e) {
      if (isTransientDriveError(e)) rethrow;
      debugPrint('Error reading file $fileId: $e');
      return null;
    }
    try {
      return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading file $fileId: $e');
      return null;
    }
  }

  /// Read a JSON file by name within a folder.
  Future<Map<String, dynamic>?> readJsonFileByName(
    String folderId,
    String fileName,
  ) async {
    final fileId = await _retry(() => _queryFileId(folderId, fileName));
    if (fileId == null) return null;
    return readJsonFile(fileId);
  }

  /// List all JSON files in a folder.
  Future<List<drive.File>> listJsonFiles(String folderId) => _listAll(
        "'$folderId' in parents and mimeType = 'application/json' and trashed = false",
        fields: 'id, name, modifiedTime',
        orderBy: 'modifiedTime desc',
      );

  // ── Helpers ────────────────────────────────────────────────────

  /// Find file ID by name in a folder.
  Future<String?> _queryFileId(String folderId, String fileName) async {
    // Escape single quotes in fileName for Drive API query
    final escapedName = fileName.replaceAll("'", "\\'");
    final result = await _api.files.list(
      q: "'$folderId' in parents and name = '$escapedName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    return result.files?.isNotEmpty == true ? result.files!.first.id : null;
  }

  /// Check if a folder exists and is accessible.
  Future<bool> isFolderAccessible(String folderId) async {
    try {
      await _api.files.get(folderId, $fields: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Adres folderu jednostki w Dysku Google — do otwarcia w przeglądarce
  /// albo aplikacji Dysku.
  static Uri folderUrl(String folderId) =>
      Uri.parse('https://drive.google.com/drive/folders/$folderId');
}
