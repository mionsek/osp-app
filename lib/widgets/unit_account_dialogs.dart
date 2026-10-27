import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/osp_theme.dart';
import '../core/utils/time_format.dart';
import '../providers/providers.dart';
import '../services/google_drive_service.dart';
import '../services/sync_service.dart';

// Okna wspólne dla wprowadzenia i Ustawień: kod zaproszenia, dołączenie
// kodem i przejście z konta jednostki na własne konto.
//
// Wcześniej dołączyć albo założyć jednostkę dało się wyłącznie przy pierwszym
// uruchomieniu — kto wybrał wtedy tryb offline albo zalogował się dopiero
// w Ustawieniach, nie miał już jak tego zrobić.

/// Komunikat, gdy kod nie pasuje do żadnej jednostki widocznej dla konta.
///
/// Najczęstszą przyczyną nie jest literówka, tylko brak zaproszenia na ten
/// adres — dlatego podajemy go wprost, żeby było wiadomo, o co poprosić.
String joinNotFoundMessage(String? email) {
  final who = (email == null || email.isEmpty) ? 'tego konta' : email;
  return 'Nie znaleziono jednostki z tym kodem dla $who. Sprawdź kod '
      'i poproś administratora, żeby zaprosił ten adres '
      '(Ustawienia → Członkowie jednostki → Zaproś strażaka).';
}

/// Po dołączeniu do jednostki: zamyka wprowadzenie i odświeża listy danymi
/// pobranymi z Dysku.
Future<void> finishJoiningUnit(WidgetRef ref) async {
  final db = ref.read(databaseServiceProvider);
  // copyWith, a nie nowy obiekt — konfiguracja pobrana z Dysku zawiera
  // m.in. pełną nazwę jednostki, której nie wolno zgubić.
  await ref.read(unitConfigProvider.notifier).save(db.getConfig().copyWith(
        onboardingCompleted: true,
        isAdmin: false,
      ));
  await db.initializeDefaultThreats();
  refreshLocalDataProviders(ref);
}

/// Listy na ekranach trzymają migawkę bazy — po dołączeniu do jednostki
/// albo usunięciu danych z telefonu trzeba je odczytać na nowo.
void refreshLocalDataProviders(WidgetRef ref) {
  ref.read(unitConfigProvider.notifier).refresh();
  ref.read(threatsProvider.notifier).refresh();
  ref.read(vehiclesProvider.notifier).refresh();
  ref.read(firefightersProvider.notifier).refresh();
  ref.read(reportsProvider.notifier).refresh();
  ref.read(handoversProvider.notifier).refresh();
  ref.read(vehicleTripsProvider.notifier).refresh();
}

/// Wynik dołączania z ekranu: dołączono albo komunikat do pokazania;
/// oba puste — ktoś zrezygnował w oknie potwierdzenia.
typedef JoinAttempt = ({bool joined, String? error});

/// Szuka jednostki po kodzie, pokazuje, czyj to folder, i dołącza dopiero
/// po potwierdzeniu.
///
/// Kod krąży po czatach, a obcy, który go zna, może udostępnić ofierze
/// własny folder z tym samym kodem — telefon wysłałby wtedy dane jednostki
/// do niego. Właściciel folderu pochodzi z Dysku i tego nie da się podrobić,
/// dlatego widać go przed dołączeniem. Gdy kod pasuje do kilku folderów,
/// nie zgadujemy, który jest prawdziwy.
Future<JoinAttempt> joinUnitWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  final notifier = ref.read(syncStateProvider.notifier);
  final lookup = await notifier.lookupUnit(code);
  if (!context.mounted) return (joined: false, error: null);

  switch (lookup) {
    case UnitNotFound():
      return (
        joined: false,
        error: joinNotFoundMessage(ref.read(syncStateProvider).userEmail),
      );
    case UnitAmbiguous():
      return (
        joined: false,
        error: 'Ten kod pasuje do więcej niż jednej jednostki widocznej dla '
            'tego konta — to może być kopia folderu albo próba podszycia '
            'się. Nie dołączam. Poproś administratora o nowe zaproszenie.',
      );
    case UnitFound(:final unit):
      final localOnly = await notifier.localOnlyListEntries(unit.folderId);
      if (!context.mounted) return (joined: false, error: null);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ConfirmUnitDialog(unit: unit, localOnly: localOnly),
      );
      if (confirmed != true || !context.mounted) {
        return (joined: false, error: null);
      }
      await notifier.joinFoundUnit(unit, code);
      await finishJoiningUnit(ref);
      return (joined: true, error: null);
  }
}

class _ConfirmUnitDialog extends StatelessWidget {
  final UnitCandidate unit;
  final LocalListEntries localOnly;

  const _ConfirmUnitDialog({required this.unit, required this.localOnly});

  @override
  Widget build(BuildContext context) {
    final name = unit.unitName.trim().isEmpty ? '(bez nazwy)' : unit.unitName;
    return AlertDialog(
      title: const Text('Dołączyć do tej jednostki?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jednostka', style: TextStyle(color: Colors.grey[600])),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('Właściciel folderu na Dysku',
                style: TextStyle(color: Colors.grey[600])),
            Text(
              unit.ownerEmail ?? 'nieznany',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dołącz tylko, jeśli znasz to konto — zwykle to konto jednostki '
              'albo jej administratora. Po dołączeniu wyjazdy, przekazania '
              'i przejazdy z tego telefonu trafią do tego folderu.',
              style: TextStyle(fontSize: 13),
            ),
            if (!localOnly.isEmpty) ...[
              const SizedBox(height: 12),
              _ListReplacementNotice(localOnly),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Dołącz'),
        ),
      ],
    );
  }
}

/// Ostrzeżenie przed dołączeniem: ratownicy i pojazdy z telefonu, których
/// jednostka nie ma, znikną z niego — obowiązuje lista jednostki.
class _ListReplacementNotice extends StatelessWidget {
  final LocalListEntries entries;

  const _ListReplacementNotice(this.entries);

  static String _names(List<String> names) {
    const shown = 5;
    if (names.length <= shown) return names.join(', ');
    return '${names.take(shown).join(', ')} i ${names.length - shown} innych';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OspTheme.attentionSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ratownicy i pojazdy spoza tej jednostki zostaną usunięci '
            'z telefonu — obowiązuje lista jednostki, którą prowadzi '
            'administrator:',
            style: TextStyle(fontSize: 13),
          ),
          if (entries.firefighters.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Ratownicy: ${_names(entries.firefighters)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          if (entries.vehicles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Pojazdy: ${_names(entries.vehicles)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// Co zrobić, gdy na koncie jest już jednostka, a ktoś zakłada kolejną.
enum CreateUnitChoice { create, joined, cancelled }

/// Przed założeniem jednostki sprawdza, czy na zalogowanym koncie już jakaś
/// jest, i proponuje dołączenie do niej.
///
/// Każde „Utwórz jednostkę" zakłada nowy folder, więc po kilku próbach na
/// Dysku konta jednostki leżały cztery identyczne `OSP_App_…` i nie było
/// wiadomo, który jest prawdziwy.
Future<CreateUnitChoice> confirmCreateOrJoinOwnUnit(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(syncStateProvider.notifier);
  final units = await notifier.ownUnits();
  if (!context.mounted) return CreateUnitChoice.cancelled;
  if (units.isEmpty) return CreateUnitChoice.create;

  final picked = await showDialog<_OwnUnitPick>(
    context: context,
    builder: (_) => _OwnUnitsDialog(
      units: units,
      email: ref.read(syncStateProvider).userEmail ?? '',
    ),
  );
  if (picked == null || !context.mounted) return CreateUnitChoice.cancelled;
  final unit = picked.unit;
  if (unit == null) return CreateUnitChoice.create;

  final localOnly = await notifier.localOnlyListEntries(unit.folderId);
  if (!context.mounted) return CreateUnitChoice.cancelled;
  if (!localOnly.isEmpty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dołączyć do tej jednostki?'),
        content: SingleChildScrollView(child: _ListReplacementNotice(localOnly)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dołącz'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return CreateUnitChoice.cancelled;
    }
  }

  await notifier.joinFoundUnit(unit, unit.inviteCode!);
  await finishJoiningUnit(ref);
  return CreateUnitChoice.joined;
}

/// Wybór z okna jednostek konta: jednostka do dołączenia albo `null` —
/// mimo to założyć nową.
class _OwnUnitPick {
  final UnitCandidate? unit;
  const _OwnUnitPick(this.unit);
}

class _OwnUnitsDialog extends StatefulWidget {
  final List<UnitCandidate> units;
  final String email;

  const _OwnUnitsDialog({required this.units, required this.email});

  @override
  State<_OwnUnitsDialog> createState() => _OwnUnitsDialogState();
}

class _OwnUnitsDialogState extends State<_OwnUnitsDialog> {
  late UnitCandidate _selected = widget.units.first;

  @override
  Widget build(BuildContext context) {
    final many = widget.units.length > 1;
    return AlertDialog(
      title: Text(many
          ? 'Na tym koncie są już jednostki'
          : 'Na tym koncie jest już jednostka'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Na Dysku konta ${widget.email} '
              '${many ? 'są już jednostki' : 'jest już jednostka'}. '
              'Dołącz do niej zamiast zakładać kolejną — inaczej przybędzie '
              'folder o tej samej nazwie i łatwo o pomyłkę, w którym są '
              'dane.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final unit in widget.units)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  unit == _selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: OspTheme.info,
                ),
                title: Text(
                  unit.unitName.trim().isEmpty ? '(bez nazwy)' : unit.unitName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text([
                  'kod ${unit.inviteCode}',
                  if (unit.createdAt != null)
                    'założona ${TimeFormat.date(unit.createdAt!)}',
                ].join(' · ')),
                onTap: many ? () => setState(() => _selected = unit) : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _OwnUnitPick(null)),
          child: const Text('Utwórz nową'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_OwnUnitPick(_selected)),
          child: const Text('Dołącz'),
        ),
      ],
    );
  }
}

/// Kod zaproszenia zaraz po założeniu jednostki.
///
/// Z [offerPersonalSwitch] pyta też, czy przejść na własne konto: raporty
/// podpisują się kontem, na którym się jest, a jednostkę często zakłada się
/// na wspólnym koncie (np. ospkielno@gmail.com). Zwraca `true`, gdy ktoś
/// wybrał przejście.
Future<bool> showInviteCodeDialog(
  BuildContext context,
  String code, {
  bool offerPersonalSwitch = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Kod zaproszenia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Strażaków zapraszasz w Ustawieniach → Członkowie jednostki. '
              'Każdy dostanie e-mail z tym kodem:',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OspTheme.successSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OspTheme.success),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: OspTheme.success,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kod znajdziesz też w Ustawieniach.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (offerPersonalSwitch) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OspTheme.infoSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Wyjazdy i przekazania podpisują się kontem, na którym '
                  'jesteś zalogowany. Jeśli założyłeś jednostkę na wspólnym '
                  'koncie jednostki, przełącz się na swoje — wtedy dodasz '
                  'je jako Ty, a nie jako jednostka.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: offerPersonalSwitch
          ? [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Zostaję na tym koncie'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Przełącz na swoje konto'),
              ),
            ]
          : [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Rozumiem'),
              ),
            ],
    ),
  );
  return result ?? false;
}

/// Dołączenie do jednostki kodem z Ustawień. `true` — dołączono.
Future<bool> showJoinUnitDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const _JoinUnitDialog(),
    ) ??
    false;

class _JoinUnitDialog extends ConsumerStatefulWidget {
  const _JoinUnitDialog();

  @override
  ConsumerState<_JoinUnitDialog> createState() => _JoinUnitDialogState();
}

class _JoinUnitDialogState extends ConsumerState<_JoinUnitDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Kod musi mieć 6 znaków');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = await joinUnitWithConfirmation(context, ref, code);
      if (!mounted) return;
      if (attempt.joined) {
        Navigator.of(context).pop(true);
      } else if (attempt.error != null) {
        setState(() => _error = attempt.error);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Nie udało się: ${describeSyncError(e)}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dołącz do jednostki'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wpisz 6-znakowy kod z zaproszenia. Wyjazdy i przejazdy '
              'zapisane dotąd na tym telefonie trafią do jednostki przy '
              'najbliższej synchronizacji.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Kod zaproszenia',
                hintText: 'np. ABC123',
                prefixIcon: const Icon(Icons.vpn_key),
                errorText: _error,
                errorMaxLines: 5,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              autofocus: true,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _join(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _join,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Dołącz'),
        ),
      ],
    );
  }
}

/// Przejście z konta, na którym założono jednostkę, na prywatne konto.
///
/// Pyta o adres, udostępnia mu jednostkę z uprawnieniami administratora,
/// a potem otwiera wybór konta Google. Wynik pokazuje na pasku.
Future<void> runSwitchToPersonalAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final email = await showDialog<String>(
    context: context,
    builder: (_) => const _PersonalAccountDialog(),
  );
  if (email == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Udostępniam jednostkę i zmieniam konto…')),
          ],
        ),
      ),
    ),
  );

  String message;
  try {
    final result = await ref
        .read(syncStateProvider.notifier)
        .switchToPersonalAccount(email);
    message = switch (result) {
      AccountSwitchResult.done => 'Zalogowano jako $email. Jednostka bez '
          'zmian — nowe wyjazdy podpiszą się Twoim kontem, a uprawnienia '
          'administratora masz nadal.',
      AccountSwitchResult.sameAccount => 'Już jesteś zalogowany na $email.',
      AccountSwitchResult.cancelled => 'Nie wybrano konta — aplikacja jest '
          'wylogowana. Zaloguj się w Ustawieniach kontem $email; dostęp do '
          'jednostki jest już nadany.',
      AccountSwitchResult.otherAccount => 'Wybrano inne konto niż $email '
          '— ono nie ma dostępu do jednostki. W Ustawieniach użyj „Zmień '
          'konto" i wybierz $email.',
      AccountSwitchResult.noAccess => 'Konto $email jeszcze nie widzi '
          'jednostki. Spróbuj za chwilę „Synchronizuj teraz".',
    };
  } catch (e) {
    message = 'Nie udało się przełączyć konta: $e';
  }

  navigator.pop();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 8),
  ));
}

class _PersonalAccountDialog extends StatefulWidget {
  const _PersonalAccountDialog();

  @override
  State<_PersonalAccountDialog> createState() => _PersonalAccountDialogState();
}

class _PersonalAccountDialogState extends State<_PersonalAccountDialog> {
  final _email = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      setState(() => _error = 'To nie wygląda na adres e-mail.');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Przełącz na swoje konto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Podaj adres swojego konta Google. Udostępnię mu jednostkę '
              'i nadam uprawnienia administratora, a potem poproszę '
              'o wybranie tego konta. Obecne konto zostaje założycielem '
              'jednostki.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: InputDecoration(
                labelText: 'Twój adres e-mail (Gmail)',
                hintText: 'np. jan.kowalski@gmail.com',
                errorText: _error,
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Dalej'),
        ),
      ],
    );
  }
}
