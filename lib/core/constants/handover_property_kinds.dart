/// Zamknięta lista rodzajów przekazywanego przedmiotu — odpowiada formom
/// gramatycznym użytym w tytule („TERENU, OBIEKTU LUB MIENIA") i treści
/// („teren, obiekt lub mienie") formularza „Potwierdzenie przekazania
/// terenu, obiektu lub mienia".
///
/// Tak jak rodzaj podmiotu przejmującego — na wydruku PDF niewybrana
/// pozycja jest przekreślona, a wybrana pogrubiona/podkreślona.
class HandoverPropertyKinds {
  HandoverPropertyKinds._();

  static const String teren = 'Teren';
  static const String obiekt = 'Obiekt';
  static const String mienie = 'Mienie';

  static const List<String> all = [teren, obiekt, mienie];
}
