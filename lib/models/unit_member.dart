/// Członek jednostki albo zaproszona osoba, która jeszcze nie dołączyła —
/// z rekordów na serwerze (`units/{u}/members` i `units/{u}/invites`).
///
/// Dawniej osobno: dostęp do folderu na Dysku (kogo zaproszono) i notatka
/// z telefonu (kto naprawdę dołączył, feature/080). Na serwerze to jeden
/// rekord członka.
class UnitMember {
  final String email;

  /// Konto na serwerze — klucz rekordu członka; `null` u zaproszonego,
  /// który jeszcze nie dołączył.
  final String? uid;

  /// Założyciel jednostki — stały administrator, nie da się go usunąć.
  final bool isOwner;

  /// Imię i nazwisko z konta Google, zapisane przy dołączeniu; puste, gdy
  /// konto go nie podało.
  final String name;

  final DateTime? joinedAt;
  final DateTime? lastSyncAt;
  final String appVersion;

  const UnitMember({
    required this.email,
    this.uid,
    this.isOwner = false,
    this.name = '',
    this.joinedAt,
    this.lastSyncAt,
    this.appVersion = '',
  });

  /// Zaproszony, który jeszcze nie dołączył.
  bool get invited => uid == null;

  /// Imię i nazwisko, a bez niego adres.
  String get label => name.trim().isEmpty ? email : name.trim();
}

/// Jednostka znaleziona po kodzie zaproszenia (albo na liście jednostek
/// konta), przed dołączeniem.
class UnitCandidate {
  /// Identyfikator jednostki na serwerze.
  final String unitId;
  final String unitName;

  /// Kto zaprosił — a przy jednostkach konta założyciel.
  final String? ownerEmail;

  /// Imię i nazwisko zapraszającego z jego konta Google — obok adresu
  /// w oknie „Dołączyć do tej jednostki?".
  final String? ownerName;

  /// Kod zaproszenia — znany od razu przy jednostkach konta, które nie są
  /// szukane po kodzie.
  final String? inviteCode;

  /// Kiedy założono jednostkę — kilka jednostek o tej samej nazwie da się
  /// odróżnić tylko po dacie i kodzie.
  final DateTime? createdAt;

  const UnitCandidate({
    required this.unitId,
    required this.unitName,
    this.ownerEmail,
    this.ownerName,
    this.inviteCode,
    this.createdAt,
  });
}
