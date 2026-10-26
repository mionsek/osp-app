import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/osp_theme.dart';
import '../providers/providers.dart';
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
  ref.read(threatsProvider.notifier).refresh();
  ref.read(vehiclesProvider.notifier).refresh();
  ref.read(firefightersProvider.notifier).refresh();
  ref.read(reportsProvider.notifier).refresh();
  ref.read(handoversProvider.notifier).refresh();
  ref.read(vehicleTripsProvider.notifier).refresh();
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
      final joined = await ref.read(syncStateProvider.notifier).joinUnit(code);
      if (!mounted) return;
      if (!joined) {
        setState(() => _error =
            joinNotFoundMessage(ref.read(syncStateProvider).userEmail));
        return;
      }
      await finishJoiningUnit(ref);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Błąd: $e');
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
