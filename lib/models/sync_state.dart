/// Represents the current state of Google Drive synchronization.
enum SyncStatus {
  disconnected, // Not signed in / no unit linked
  idle, // Signed in, no sync in progress
  syncing, // Sync in progress
  error, // Last sync failed
}

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final String? userEmail;
  final String? unitFolderId;
  final String? unitInviteCode;

  const SyncState({
    this.status = SyncStatus.disconnected,
    this.lastSyncTime,
    this.errorMessage,
    this.userEmail,
    this.unitFolderId,
    this.unitInviteCode,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? errorMessage,
    String? userEmail,
    String? unitFolderId,
    String? unitInviteCode,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
      userEmail: userEmail ?? this.userEmail,
      unitFolderId: unitFolderId ?? this.unitFolderId,
      unitInviteCode: unitInviteCode ?? this.unitInviteCode,
    );
  }

  bool get isConnected => status != SyncStatus.disconnected;
  bool get isSyncing => status == SyncStatus.syncing;
}
