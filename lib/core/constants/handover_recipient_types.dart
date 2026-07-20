/// Zamknięta lista rodzajów podmiotu przejmującego teren/obiekt/mienie,
/// zgodna z § 21 ust. 2 pkt 2 rozporządzenia MSWiA z 17 września 2021 r.
/// (formularz „Potwierdzenie przekazania terenu, obiektu lub mienia").
///
/// Na papierowym formularzu jest to pozycja „niepotrzebne skreślić" —
/// w druku PDF niewybrane opcje są przekreślone, a wybrana pogrubiona.
class HandoverRecipientTypes {
  HandoverRecipientTypes._();

  static const String owner = 'Właściciel';
  static const String manager = 'Zarządca';
  static const String user = 'Użytkownik';
  static const String governmentAdminRep =
      'Przedstawiciel organu administracji rządowej';
  static const String localGovRep = 'Przedstawiciel samorządu terytorialnego';
  static const String police = 'Policja';
  static const String municipalGuard = 'Straż gminna/miejska';
  static const String other = 'Inne';

  /// Kolejność zgodna z formularzem — istotna przy druku (przekreślanie).
  static const List<String> all = [
    owner,
    manager,
    user,
    governmentAdminRep,
    localGovRep,
    police,
    municipalGuard,
    other,
  ];
}
