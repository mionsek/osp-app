import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/osp_theme.dart';
import '../core/utils/time_format.dart';
import '../providers/providers.dart';
import '../models/unit_member.dart';
import '../services/sync_service.dart';

// Okna wspólne dla wprowadzenia i Ustawień: kod zaproszenia i dołączenie
// kodem.
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
      '(Ustawienia → Członkowie jednostki → Zaproś do jednostki).';
}

/// Kod jest prawidłowy, ale zalogowanego adresu nie ma na liście
/// zaproszonych jednostki na serwerze (feature/081).
String joinNotInvitedMessage(String email) =>
    'Adresu $email nie ma na liście zaproszonych do tej jednostki. Poproś '
    'administratora, żeby zaprosił dokładnie ten adres (Ustawienia → '
    'Członkowie jednostki → Zaproś do jednostki), albo zaloguj się kontem, '
    'na które przyszło zaproszenie.';

/// Po dołączeniu do jednostki: zamyka wprowadzenie i odświeża listy danymi
/// pobranymi z serwera.
Future<void> finishJoiningUnit(WidgetRef ref) async {
  final db = ref.read(databaseServiceProvider);
  // copyWith, a nie nowy obiekt — konfiguracja pobrana z serwera zawiera
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
  ref.read(equipmentProvider.notifier).refresh();
  ref.read(equipmentWorkProvider.notifier).refresh();
  ref.read(firefightersProvider.notifier).refresh();
  ref.read(reportsProvider.notifier).refresh();
  ref.read(handoversProvider.notifier).refresh();
  ref.read(vehicleTripsProvider.notifier).refresh();
}

/// Wynik dołączania z ekranu: dołączono albo komunikat do pokazania;
/// oba puste — ktoś zrezygnował w oknie potwierdzenia.
typedef JoinAttempt = ({bool joined, String? error});

/// Szuka jednostki po kodzie, pokazuje, kto zaprosił, i dołącza dopiero
/// po potwierdzeniu — po kodzie z cudzej wiadomości łatwo trafić nie tam.
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
    case UnitNotInvited(:final email):
      return (joined: false, error: joinNotInvitedMessage(email));
    case UnitFound(:final unit):
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ConfirmUnitDialog(unit: unit),
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

  const _ConfirmUnitDialog({required this.unit});

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
            Text('Zaproszenie od', style: TextStyle(color: Colors.grey[600])),
            // Imię z konta Google zapraszającego (serwer), adres pod nim.
            if ((unit.ownerName ?? '').isNotEmpty) ...[
              Text(
                unit.ownerName!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(unit.ownerEmail ?? 'nieznany',
                  style: const TextStyle(fontSize: 13)),
            ] else
              Text(
                unit.ownerEmail ?? 'nieznany',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            const Text(
              'Dołącz tylko, jeśli znasz tę osobę — zwykle to administrator '
              'jednostki. Po dołączeniu wyjazdy, przekazania i przejazdy '
              'z tego telefonu trafią do tej jednostki, a ratownicy, pojazdy '
              'i sprzęt będą z list jednostki.',
              style: TextStyle(fontSize: 13),
            ),
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

/// Co zrobić, gdy na koncie jest już jednostka, a ktoś zakłada kolejną.
enum CreateUnitChoice { create, joined, cancelled }

/// Przed założeniem jednostki sprawdza, czy zalogowane konto już do jakiejś
/// należy, i proponuje dołączenie do niej.
///
/// Na Dysku po kilku próbach „Utwórz jednostkę" leżały cztery identyczne
/// jednostki i nie było wiadomo, która jest prawdziwa.
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
              'Konto ${widget.email} należy już do '
              '${many ? 'jednostek' : 'jednostki'}. Dołącz zamiast zakładać '
              'kolejną — inaczej będą dwie jednostki o tej samej nazwie '
              'i łatwo o pomyłkę, w której są dane.',
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
/// Wcześniej proponował tu przejście z konta jednostki na własne — zbędne
/// (Dawid, 27.11.2026): tablet loguje się kontem jednostki, telefon swoim.
Future<void> showInviteCodeDialog(BuildContext context, String code) async {
  await showDialog<void>(
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
              'Członków zapraszasz w Ustawieniach → Członkowie jednostki, '
              'a potem wysyłasz im ten kod SMS-em, komunikatorem albo '
              'e-mailem:',
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
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Rozumiem'),
        ),
      ],
    ),
  );
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
