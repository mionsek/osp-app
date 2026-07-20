import 'package:hive/hive.dart';

part 'property_handover.g.dart';

/// Potwierdzenie przekazania terenu, obiektu lub mienia objętego działaniem
/// ratowniczym (§ 21 ust. 2 pkt 2 rozporządzenia MSWiA z 17.09.2021 r.).
///
/// Osobny dokument od „Potwierdzenia udziału w działaniu ratowniczym" —
/// dotyczy przekazania nadzoru nad terenem/mieniem po zdarzeniu, a nie
/// samego wyjazdu.
@HiveType(typeId: 6)
class PropertyHandover extends HiveObject {
  @HiveField(0)
  String id;

  /// Opcjonalne powiązanie z wyjazdem (Report.id) — używane tylko do
  /// wstępnego wypełnienia miejsca/daty zdarzenia, bez twardej zależności.
  @HiveField(1)
  String? reportId;

  /// „Dotyczy zdarzenia w..." (miejscowość, adres).
  @HiveField(2)
  String eventLocation;

  /// „W dniu..."
  @HiveField(3)
  DateTime eventDate;

  /// „o godzinie..." (data + godzina, tak jak departureTime w Report).
  @HiveField(4)
  DateTime eventTime;

  /// Rodzaj podmiotu przejmującego — jedna z [HandoverRecipientTypes.all].
  @HiveField(5)
  String recipientType;

  /// Opis własny, gdy [recipientType] == HandoverRecipientTypes.other.
  @HiveField(6)
  String? recipientTypeOther;

  /// Imię i nazwisko przejmującego.
  @HiveField(7)
  String recipientName;

  /// Adres służbowy lub zamieszkania przejmującego.
  @HiveField(8)
  String recipientAddress;

  /// Numer telefonu przejmującego.
  @HiveField(9)
  String recipientPhone;

  /// Opis terenu/obiektu/mienia przekazanego do nadzoru.
  @HiveField(10)
  String propertyDescription;

  /// Uwagi szczegółowe (opcjonalne).
  @HiveField(11)
  String? notes;

  /// Przekazujący — strażak z listy ratowników (stopień + imię i nazwisko).
  @HiveField(12)
  String? handoverFirefighterId;

  /// Miejscowość w stopce „Miejscowość... dnia..." (domyślnie z UnitConfig).
  @HiveField(13)
  String signLocality;

  /// Data w stopce „Miejscowość... dnia..." (domyślnie dzisiejsza).
  @HiveField(14)
  DateTime signDate;

  @HiveField(15)
  DateTime createdAt;

  @HiveField(16)
  DateTime updatedAt;

  @HiveField(17)
  String createdBy;

  /// Status synchronizacji: 'local', 'queued', 'sent'.
  @HiveField(18)
  String syncStatus;

  PropertyHandover({
    required this.id,
    this.reportId,
    this.eventLocation = '',
    required this.eventDate,
    required this.eventTime,
    required this.recipientType,
    this.recipientTypeOther,
    this.recipientName = '',
    this.recipientAddress = '',
    this.recipientPhone = '',
    this.propertyDescription = '',
    this.notes,
    this.handoverFirefighterId,
    this.signLocality = '',
    required this.signDate,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.syncStatus = 'local',
  });

  /// Etykieta rodzaju przejmującego do wyświetlenia/druku.
  String get recipientTypeLabel =>
      recipientTypeOther != null && recipientTypeOther!.trim().isNotEmpty
          ? recipientTypeOther!.trim()
          : recipientType;
}
