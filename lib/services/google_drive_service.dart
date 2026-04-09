import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

/// Service for CRUD operations on Google Drive.
/// All data lives in a shared unit folder.
class GoogleDriveService {
  final GoogleAuthService _authService;
  drive.DriveApi? _driveApi;

  GoogleDriveService(this._authService);

  drive.DriveApi get _api {
    _driveApi ??= drive.DriveApi(_authService.getAuthenticatedClient());
    return _driveApi!;
  }

  /// Reset cached API client (e.g. after re-sign-in).
  void resetClient() {
    _driveApi = null;
  }

  // ── Folder operations ──────────────────────────────────────────

  /// Create the unit folder on Drive. Returns folder ID.
  Future<String> createUnitFolder(String unitName) async {
    final folder = drive.File()
      ..name = 'OSP_App_$unitName'
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _api.files.create(folder);
    final folderId = created.id!;

    // Create reports subfolder
    await _createSubfolder(folderId, 'reports');

    return folderId;
  }

  Future<String> _createSubfolder(String parentId, String name) async {
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];

    final created = await _api.files.create(folder);
    return created.id!;
  }

  /// Find reports subfolder inside unit folder.
  Future<String?> findReportsFolder(String unitFolderId) async {
    final result = await _api.files.list(
      q: "'$unitFolderId' in parents and name = 'reports' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    return result.files?.isNotEmpty == true ? result.files!.first.id : null;
  }

  /// Share the unit folder with a user (by email).
  Future<void> shareFolderWithUser(String folderId, String email) async {
    final permission = drive.Permission()
      ..type = 'user'
      ..role = 'writer'
      ..emailAddress = email;

    await _api.permissions.create(permission, folderId,
        sendNotificationEmail: false);
  }

  /// Find unit folder shared with current user by invite code.
  /// The invite code is stored in unit_config.json inside the folder.
  Future<String?> findUnitByInviteCode(String code) async {
    // Search for unit_config.json files accessible to the user
    final result = await _api.files.list(
      q: "name = 'unit_config.json' and mimeType = 'application/json' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, parents)',
    );

    if (result.files == null) return null;

    for (final file in result.files!) {
      try {
        final content = await readJsonFile(file.id!);
        if (content != null && content['inviteCode'] == code) {
          // Return the parent folder ID
          return file.parents?.isNotEmpty == true ? file.parents!.first : null;
        }
      } catch (e) {
        debugPrint('Error checking file ${file.id}: $e');
      }
    }
    return null;
  }

  // ── JSON file operations ───────────────────────────────────────

  /// Write a JSON map to a file in the given folder.
  /// If the file already exists (by name), it's updated. Otherwise created.
  Future<String> writeJsonFile(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) async {
    final content = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final media = drive.Media(Stream.value(content), content.length);

    // Check if file exists
    final existingId = await _findFileId(folderId, fileName);

    if (existingId != null) {
      // Update existing
      final file = drive.File()..name = fileName;
      final updated = await _api.files.update(file, existingId,
          uploadMedia: media);
      return updated.id!;
    } else {
      // Create new
      final file = drive.File()
        ..name = fileName
        ..parents = [folderId];
      final created = await _api.files.create(file, uploadMedia: media);
      return created.id!;
    }
  }

  /// Read a JSON file by its file ID.
  Future<Map<String, dynamic>?> readJsonFile(String fileId) async {
    try {
      final media = await _api.files.get(fileId,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      final jsonString = utf8.decode(bytes);
      return json.decode(jsonString) as Map<String, dynamic>;
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
    final fileId = await _findFileId(folderId, fileName);
    if (fileId == null) return null;
    return readJsonFile(fileId);
  }

  /// List all JSON files in a folder.
  Future<List<drive.File>> listJsonFiles(String folderId) async {
    final result = await _api.files.list(
      q: "'$folderId' in parents and mimeType = 'application/json' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, modifiedTime)',
      orderBy: 'modifiedTime desc',
    );
    return result.files ?? [];
  }

  /// Delete a file by ID.
  Future<void> deleteFile(String fileId) async {
    await _api.files.delete(fileId);
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Find file ID by name in a folder.
  Future<String?> _findFileId(String folderId, String fileName) async {
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
}
