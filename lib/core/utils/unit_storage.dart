/// Gdzie leżą dane wspólne jednostki — do tekstów na ekranach (feature/081).
///
/// Jednostki sprzed serwera zostają na Dysku Google, dopóki administrator
/// ich nie przeniesie, więc napisy zależą od tego, z czym telefon jest
/// połączony ([SyncService.onServer]).
class UnitStorage {
  UnitStorage._();

  /// „na Dysku jednostki” / „na serwerze jednostki” — gdzie coś jest.
  static String at(bool onServer) =>
      onServer ? 'na serwerze jednostki' : 'na Dysku jednostki';

  /// „na Dysk jednostki” / „na serwer jednostki” — dokąd coś idzie.
  static String to(bool onServer) =>
      onServer ? 'na serwer jednostki' : 'na Dysk jednostki';
}
