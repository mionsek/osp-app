import 'package:hive/hive.dart';

part 'firefighter.g.dart';

@HiveType(typeId: 1)
class Firefighter extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String firstName;

  @HiveField(2)
  String lastName;

  @HiveField(3)
  String rank;

  @HiveField(4, defaultValue: false)
  bool isDriver;

  @HiveField(5, defaultValue: false)
  bool isCommander;

  @HiveField(6, defaultValue: false)
  bool isKPP;

  @HiveField(7)
  DateTime? medicalExamExpiry;

  Firefighter({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.rank,
    this.isDriver = false,
    this.isCommander = false,
    this.isKPP = false,
    this.medicalExamExpiry,
  });

  /// „Imię Nazwisko" — kolejność naturalna w mowie.
  ///
  /// **Nie używać do wyświetlania ani na wydrukach** — tam obowiązuje
  /// [lastNameFirst]. Zostaje do dopasowywania wpisanego tekstu, bo ktoś
  /// przyzwyczajony może wpisać nazwisko w tej kolejności.
  String get fullName => '$firstName $lastName';

  /// „Nazwisko Imię" — **jedyna poprawna kolejność do pokazania i wydruku**.
  ///
  /// Tak zgłaszamy skład telefonicznie do PSP i tak wygląda papierowa
  /// dokumentacja, więc aplikacja musi być z tym spójna. Rozjazd między
  /// wyborem (nazwisko pierwsze) a wydrukiem (imię pierwsze) był realnym
  /// zgłoszeniem z testów.
  String get lastNameFirst => '$lastName $firstName'.trim();

  /// „Nazwisko Imię, stopień" — do podpisów na drukach.
  String get fullNameWithRank =>
      rank.trim().isEmpty ? lastNameFirst : '$lastNameFirst, $rank';

  /// Funkcje pełnione w jednostce. Kierowca, dowódca i KPP to dodatkowe
  /// uprawnienia — kto nie ma żadnego, jest po prostu ratownikiem, więc
  /// nigdy nie zwracamy pustej listy.
  List<String> get functionLabels {
    final labels = <String>[
      if (isDriver) 'Kierowca',
      if (isCommander) 'Dowódca',
      if (isKPP) 'KPP',
    ];
    return labels.isEmpty ? const ['Ratownik'] : labels;
  }

  /// Funkcje w jednej linii, np. „Kierowca, KPP" albo „Ratownik".
  String get functionsLabel => functionLabels.join(', ');

  /// Ile dni przed końcem ważności badania uznajemy za „wygasające".
  ///
  /// Reguła jest jedna na całą aplikację, bo była zapisana z ręki w trzech
  /// miejscach: tutaj, w ostrzeżeniu formularza ratownika i w podpowiedzi daty
  /// w tym samym formularzu. Zmiana progu w jednym z nich dawała aplikację,
  /// która na liście ostrzega, a w formularzu jeszcze nie.
  static const Duration medicalExamWarningWindow = Duration(days: 30);

  bool get hasMedicalExam => medicalExamExpiry != null;
  bool get isMedicalExamExpired =>
      medicalExamExpiry != null && medicalExamExpiry!.isBefore(DateTime.now());
  bool get isMedicalExamExpiringSoon =>
      medicalExamExpiry != null &&
      !isMedicalExamExpired &&
      medicalExamExpiry!.isBefore(DateTime.now().add(medicalExamWarningWindow));

  /// Stan badań lekarskich jako jedna wartość — do wyboru koloru i ikony
  /// bez powtarzania kolejności warunków w każdym widoku z osobna.
  MedicalExamStatus get medicalExamStatus =>
      MedicalExamStatusX.of(medicalExamExpiry);

  @override
  String toString() => fullName;

  Firefighter copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? rank,
    bool? isDriver,
    bool? isCommander,
    bool? isKPP,
    DateTime? medicalExamExpiry,
    bool clearMedicalExamExpiry = false,
  }) {
    return Firefighter(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      rank: rank ?? this.rank,
      isDriver: isDriver ?? this.isDriver,
      isCommander: isCommander ?? this.isCommander,
      isKPP: isKPP ?? this.isKPP,
      medicalExamExpiry: clearMedicalExamExpiry
          ? null
          : (medicalExamExpiry ?? this.medicalExamExpiry),
    );
  }
}

/// Stan badań lekarskich ratownika.
///
/// Cztery przypadki, w tej kolejności sprawdzane: brak daty, po terminie,
/// wygasające w oknie [Firefighter.medicalExamWarningWindow], ważne.
enum MedicalExamStatus { unknown, expired, expiringSoon, valid }

extension MedicalExamStatusX on MedicalExamStatus {
  /// Stan wyliczony z samej daty — dla formularza, który trzyma wpisywaną
  /// datę zanim powstanie z niej [Firefighter].
  static MedicalExamStatus of(DateTime? expiry) {
    if (expiry == null) return MedicalExamStatus.unknown;
    final now = DateTime.now();
    if (expiry.isBefore(now)) return MedicalExamStatus.expired;
    if (expiry.isBefore(now.add(Firefighter.medicalExamWarningWindow))) {
      return MedicalExamStatus.expiringSoon;
    }
    return MedicalExamStatus.valid;
  }
}
