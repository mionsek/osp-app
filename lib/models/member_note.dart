/// Ślad członka jednostki w folderze `members/` na Dysku (feature/080).
///
/// „Pokaż, kto ma dostęp" pokazuje uprawnienia do folderu, czyli kogo
/// zaproszono — a nie, kto naprawdę zainstalował aplikację i dołączył
/// (Dawid, 25.11.2026). Każdy telefon zapisuje więc o swoim koncie tylko
/// tyle: adres, kiedy dołączył, kiedy ostatnio się synchronizował i jaką ma
/// wersję aplikacji. Nic więcej — bez modelu telefonu czy lokalizacji.
class MemberNote {
  final String email;
  final DateTime? joinedAt;
  final DateTime? lastSyncAt;
  final String appVersion;

  const MemberNote({
    required this.email,
    this.joinedAt,
    this.lastSyncAt,
    this.appVersion = '',
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        if (joinedAt != null) 'joinedAt': joinedAt!.toIso8601String(),
        if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toIso8601String(),
        'appVersion': appVersion,
      };

  /// `null`, gdy plik nie wygląda na notatkę członka.
  static MemberNote? fromJson(Object? json) {
    if (json is! Map) return null;
    final email = json['email'];
    if (email is! String || !email.contains('@')) return null;
    final version = json['appVersion'];
    return MemberNote(
      email: email,
      joinedAt: DateTime.tryParse('${json['joinedAt']}'),
      lastSyncAt: DateTime.tryParse('${json['lastSyncAt']}'),
      appVersion: version is String ? version : '',
    );
  }

  /// Nazwa pliku notatki — adres małymi literami.
  static String fileName(String email) => '${email.trim().toLowerCase()}.json';
}
