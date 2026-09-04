import 'package:flutter/material.dart' show TimeOfDay;
import 'package:intl/intl.dart';

/// Wspólne formaty daty i godziny pokazywane użytkownikowi i drukowane.
///
/// Wydzielone, bo te same dwa formaty były rozsiane po całej aplikacji:
/// godzina `HH:mm` składana z `padLeft` w **sześciu** miejscach (dwa razy jako
/// lokalna funkcja `formatTime`, cztery razy wklejona w środek widżetu),
/// a `dd.MM.yyyy` zapisane jako łańcuch formatu **piętnaście** razy, w tym
/// na wydrukach. Każda kopia to osobna okazja, żeby jeden ekran zaczął
/// pokazywać godzinę inaczej niż sąsiedni albo niż druk.
///
/// Formaty są **konwencją całej aplikacji**, a nie parametrem układu strony —
/// dlatego mieszkają tutaj, w odróżnieniu od rozmiarów czcionek i szerokości
/// kolumn, które świadomie zostają przy swoich wydrukach.
class TimeFormat {
  TimeFormat._();

  /// Godzina zegarowa: `14:05`.
  static String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// To samo dla [TimeOfDay] — kreator wyjazdu i formularze trzymają godziny
  /// w tym typie, zanim złożą je z datą.
  static String hhmmOf(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Data po polsku: `19.08.2026`.
  static String date(DateTime d) => _date.format(d);

  /// Zakres godzin `14:05 – 16:30`; brak końca daje `14:05 – —`, bo wyjazd
  /// bez wpisanej godziny powrotu jest normalnym stanem, a nie błędem.
  static String range(DateTime from, DateTime? to) =>
      '${hhmm(from)} – ${to == null ? '—' : hhmm(to)}';

  /// Zakres godzin dla [TimeOfDay] — jak [range], dla danych z kreatora.
  static String rangeOf(TimeOfDay from, TimeOfDay? to) =>
      '${hhmmOf(from)} – ${to == null ? '—' : hhmmOf(to)}';

  static final DateFormat _date = DateFormat('dd.MM.yyyy');
}
