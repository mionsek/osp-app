import 'package:flutter/material.dart';

import '../core/theme/osp_theme.dart';

/// Przycisk paska akcji: ikona z podpisem.
class StripAction {
  final IconData icon;
  final String label;

  /// Dłuższy opis po przytrzymaniu, np. „Drukuj (2 egzemplarze)".
  final String? tooltip;

  /// `null` — przycisk wyszarzony (np. statystyki pustego roku).
  final VoidCallback? onPressed;

  /// Usuwanie — czerwony, zawsze ostatni.
  final bool danger;

  const StripAction({
    required this.icon,
    required this.label,
    this.tooltip,
    required this.onPressed,
    this.danger = false,
  });
}

/// Jasny pasek akcji pod czerwonym paskiem tytułu — `AppBar.bottom`.
///
/// Uwaga Dawida z 6.11.2026: ikony obok tytułu ucinały go („Ewidencj…",
/// „Przekazanie …"), a druk był raz w ikonach na górze, raz w przyciskach
/// na samym dole przewijanej treści. Teraz na czerwonym pasku są tylko
/// strzałka wstecz, tytuł i domek, a wszystko, co się robi z dokumentem —
/// tutaj, w tym samym miejscu na każdym ekranie, z podpisem pod ikoną
/// i bez przewijania.
///
/// Kolejność stała: Drukuj, Bluetooth, Wyślij, Excel, potem Edytuj i Usuń.
class ActionStrip extends StatelessWidget implements PreferredSizeWidget {
  final List<StripAction> actions;
  const ActionStrip(this.actions, {super.key});

  static const double height = 58;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OspTheme.surface,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final a in actions)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: _StripButton(a),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// „Usuń" pod przyciskiem zapisu formularza — w formularzach nie ma paska
/// akcji, a na czerwonym pasku zostają tylko tytuł i nawigacja.
class DeleteEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const DeleteEntryButton({
    super.key,
    this.label = 'Usuń',
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.delete),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: OspTheme.danger,
            side: const BorderSide(color: OspTheme.danger),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      );
}

class _StripButton extends StatelessWidget {
  final StripAction action;
  const _StripButton(this.action);

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null;
    final color = !enabled
        ? Colors.grey[400]!
        : action.danger
            ? OspTheme.danger
            : Colors.grey[850]!;
    final button = InkWell(
      onTap: action.onPressed,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Tooltip(
      message: action.tooltip ?? action.label,
      child: button,
    );
  }
}
