/// Stan synchronizacji z serwerem jednostki.
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

  /// Kiedy wystąpił [errorMessage]. Błąd zostaje widoczny aż do następnej
  /// udanej synchronizacji, a bez godziny stary wyglądał jak świeży.
  final DateTime? errorTime;

  /// Ile zmian ostatnia synchronizacja wysłała na serwer i ile z niego
  /// pobrała — do potwierdzenia po ręcznym „Synchronizuj teraz".
  final int lastSyncSent;
  final int lastSyncReceived;

  final String? userEmail;
  final String? unitId;
  final String? unitInviteCode;
  /// Numery wyjazdów, dla których wykryto duplikaty po ostatnim sync.
  final List<String> duplicateReportNumbers;

  /// Adres założyciela jednostki (`ownerEmail` jednostki na serwerze).
  /// Zawsze ma uprawnienia administratora i nie da się mu ich odebrać —
  /// inaczej jednostka mogłaby zostać bez żadnego administratora.
  final String? founderEmail;

  /// Adresy osób, którym założyciel nadał uprawnienia administratora
  /// (`config/admins.json`).
  final List<String> adminEmails;

  /// Konto założyciela to wspólne konto jednostki, np. na tablecie
  /// w samochodzie (`sharedFounder` w `config/admins.json`). Działa wtedy
  /// jak zwykły członek, a przy wpisach pyta, kto wpisuje — patrz
  /// [isAdmin] i [isSharedAccount].
  final bool sharedFounder;

  /// Pozostałe wspólne urządzenia jednostki — konta z rolą `shared` na
  /// serwerze (Dawid, 27.11.2026: tablet w wozie loguje się kontem
  /// jednostki, telefon — swoim, niezależnie od tego, kto założył
  /// jednostkę). Jak [sharedFounder]: uprawnienia zwykłego członka i pytanie
  /// „Kto wpisuje?".
  final List<String> sharedEmails;

  /// Wpisy z serwera pominięte przy ostatniej synchronizacji, bo nie dało
  /// się ich odczytać. Dawniej jeden taki wpis przerywał całą synchronizację.
  final int skippedFiles;

  /// Wyjazdy, którym synchronizacja nadała nowy numer (powtórzony numer
  /// z dwóch telefonów) — do pokazania, aż ktoś je przeczyta. Następna
  /// synchronizacja bez zmian numerów ich nie kasuje.
  final List<String> renumberNotes;


  const SyncState({
    this.status = SyncStatus.disconnected,
    this.lastSyncTime,
    this.errorMessage,
    this.errorTime,
    this.lastSyncSent = 0,
    this.lastSyncReceived = 0,
    this.userEmail,
    this.unitId,
    this.unitInviteCode,
    this.duplicateReportNumbers = const [],
    this.founderEmail,
    this.adminEmails = const [],
    this.sharedFounder = false,
    this.sharedEmails = const [],
    this.skippedFiles = 0,
    this.renumberNotes = const [],
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? errorMessage,
    DateTime? errorTime,
    int? lastSyncSent,
    int? lastSyncReceived,
    String? userEmail,
    String? unitId,
    String? unitInviteCode,
    List<String>? duplicateReportNumbers,
    String? founderEmail,
    List<String>? adminEmails,
    bool? sharedFounder,
    List<String>? sharedEmails,
    int? skippedFiles,
    List<String>? renumberNotes,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorTime: clearError ? null : (errorTime ?? this.errorTime),
      lastSyncSent: lastSyncSent ?? this.lastSyncSent,
      lastSyncReceived: lastSyncReceived ?? this.lastSyncReceived,
      userEmail: userEmail ?? this.userEmail,
      unitId: unitId ?? this.unitId,
      unitInviteCode: unitInviteCode ?? this.unitInviteCode,
      duplicateReportNumbers:
          duplicateReportNumbers ?? this.duplicateReportNumbers,
      founderEmail: founderEmail ?? this.founderEmail,
      adminEmails: adminEmails ?? this.adminEmails,
      sharedFounder: sharedFounder ?? this.sharedFounder,
      sharedEmails: sharedEmails ?? this.sharedEmails,
      skippedFiles: skippedFiles ?? this.skippedFiles,
      renumberNotes: renumberNotes ?? this.renumberNotes,
    );
  }

  bool get isConnected => status != SyncStatus.disconnected;
  bool get isSyncing => status == SyncStatus.syncing;

  static String _normalize(String email) => email.trim().toLowerCase();

  /// Czy zalogowana osoba może zarządzać jednostką (pojazdy, ratownicy,
  /// uprawnienia).
  ///
  /// Praca bez jednostki (tryb offline) oznacza własne, lokalne dane —
  /// wtedy nie ma kogo pytać o zgodę i wszystko jest dozwolone.
  bool get isCurrentUserAdmin {
    if (!isConnected || unitId == null) return true;
    final me = userEmail;
    if (me == null || me.isEmpty) return false;
    return isAdmin(me);
  }

  /// Czy [email] ma w jednostce uprawnienia administratora.
  ///
  /// Założyciel jest administratorem zawsze — chyba że jego konto jest
  /// wspólne ([sharedFounder]) i jest jeszcze administrator na własnym
  /// koncie. Bez takiego administratora wspólne konto zachowuje
  /// uprawnienia, żeby jednostka nigdy nie została bez nikogo, kto nią
  /// zarządza.
  bool isAdmin(String email) {
    if (isFounder(email)) return !(sharedFounder && hasPersonalAdmin);
    final normalized = _normalize(email);
    return adminEmails.any((e) => _normalize(e) == normalized);
  }

  /// Administratorzy na własnych kontach — wszyscy poza założycielem.
  List<String> get personalAdminEmails =>
      adminEmails.where((e) => !isFounder(e)).toList();

  bool get hasPersonalAdmin => personalAdminEmails.isNotEmpty;

  /// Zalogowane jest wspólne konto jednostki — wpisy nie mówią same, kto
  /// je wpisał, więc formularze pytają „Kto wpisuje?".
  bool get isSharedAccount {
    final me = userEmail;
    return isConnected &&
        unitId != null &&
        me != null &&
        isSharedDevice(me);
  }

  /// Czy [email] to wspólne urządzenie jednostki — założyciel z
  /// [sharedFounder] albo konto z [sharedEmails].
  bool isSharedDevice(String email) {
    if (isFounder(email)) return sharedFounder;
    final normalized = _normalize(email);
    return sharedEmails.any((e) => _normalize(e) == normalized);
  }

  /// Czy podany adres jest założycielem jednostki.
  bool isFounder(String email) =>
      founderEmail != null && _normalize(founderEmail!) == _normalize(email);

  /// Czy zalogowana osoba może edytować lub usunąć dokument utworzony
  /// przez [createdBy].
  ///
  /// Administrator może wszystko; pozostali tylko własne dokumenty.
  /// Zapisy bez autora (starsze albo utworzone w trybie offline) zostają
  /// edytowalne — inaczej stałyby się nieusuwalne dla wszystkich.
  bool canEditDocument(String? createdBy) {
    if (isCurrentUserAdmin) return true;
    final author = createdBy?.trim() ?? '';
    if (author.isEmpty) return true;
    return isAuthor(author);
  }

  /// Czy [createdBy] to zalogowane konto.
  bool isAuthor(String createdBy) {
    final me = userEmail;
    if (me == null || me.trim().isEmpty) return false;
    return _normalize(createdBy) == _normalize(me);
  }
}
