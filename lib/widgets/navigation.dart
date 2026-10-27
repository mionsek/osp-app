import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ekran główny — korzeń drzewa tras (`app_router.dart`).
const homeLocation = '/';

/// Do menu głównego, z dowolnego miejsca.
void goHome(BuildContext context) => context.go(homeLocation);

/// Pytanie przed wyjściem z niezapisanego formularza albo kreatora.
Future<bool> confirmDiscard(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Wyjść bez zapisywania?'),
      content: const Text('Wpisane dane nie zostaną zapisane.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Zostań'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Wyjdź'),
        ),
      ],
    ),
  );
  return leave == true;
}

/// „Menu główne" na pasku każdego ekranu poza głównym — obok strzałki
/// wstecz, która cofa o jeden ekran.
///
/// Zgłoszenie z testu 1.7.6: po zapisie przekazania lista nie miała żadnej
/// nawigacji, a systemowe „wstecz" zamykało aplikację. Ekrany wyjazdu
/// i przekazania miały za to domek zamiast strzałki — bez cofnięcia.
class HomeButton extends StatelessWidget {
  /// Na ekranie z wpisanymi, niezapisanymi danymi — najpierw pytanie.
  final bool confirmLeave;

  const HomeButton({super.key, this.confirmLeave = false});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.home),
        tooltip: 'Menu główne',
        onPressed: () async {
          if (confirmLeave && !await confirmDiscard(context)) return;
          if (context.mounted) goHome(context);
        },
      );
}

/// Formularz albo kreator z niezapisanymi danymi: strzałka wstecz
/// i systemowe „wstecz" pytają przed wyjściem.
///
/// [onBack] — krok wstecz w kreatorze. Zwraca `true`, gdy cofnął o krok;
/// `false` na pierwszym kroku, wtedy wyjście z kreatora (z pytaniem, jeśli
/// [dirty]).
class LeaveGuard extends StatelessWidget {
  final bool dirty;
  final bool Function()? onBack;
  final Widget child;

  const LeaveGuard({
    super.key,
    required this.dirty,
    this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !dirty && onBack == null,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (onBack?.call() == true) return;
          if (dirty && !await confirmDiscard(context)) return;
          if (context.mounted) Navigator.of(context).pop();
        },
        child: child,
      );
}
