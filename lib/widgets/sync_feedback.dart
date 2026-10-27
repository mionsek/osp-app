import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/osp_theme.dart';
import '../core/utils/polish_text.dart';
import '../core/utils/time_format.dart';
import '../models/sync_state.dart';
import '../providers/providers.dart';

/// Błąd synchronizacji razem z chwilą, w której wystąpił.
///
/// Błąd zostaje na ekranie aż do następnej udanej synchronizacji. Bez
/// godziny ten sprzed kwadransa wyglądał jak świeży — tak było na zrzucie
/// z testów 1.7.3, gdzie stary błąd wisiał obok udanego zaproszenia.
String syncErrorText(SyncState s, {DateTime? now}) {
  final at = s.errorTime;
  final today = now ?? DateTime.now();
  final String when;
  if (at == null) {
    when = '';
  } else if (at.year == today.year &&
      at.month == today.month &&
      at.day == today.day) {
    when = ' o ${TimeFormat.hhmm(at)}';
  } else {
    when = ' ${TimeFormat.date(at)} o ${TimeFormat.hhmm(at)}';
  }
  return 'Synchronizacja nie powiodła się$when: '
      '${s.errorMessage ?? 'nieznany błąd'}';
}

/// Potwierdzenie udanej synchronizacji z liczbą wysłanych i pobranych zmian.
String syncSuccessText(SyncState s) {
  String changes(int n) =>
      '$n ${PolishText.plural(n, one: 'zmianę', few: 'zmiany', many: 'zmian')}';
  final parts = [
    if (s.lastSyncSent > 0) 'wysłano ${changes(s.lastSyncSent)}',
    if (s.lastSyncReceived > 0) 'pobrano ${changes(s.lastSyncReceived)}',
  ];
  return parts.isEmpty
      ? 'Zsynchronizowano — wszystko aktualne.'
      : 'Zsynchronizowano: ${parts.join(', ')}.';
}

/// „Synchronizuj teraz" z potwierdzeniem na zielono albo błędem na
/// czerwono.
///
/// Tylko przy synchronizacji uruchomionej ręcznie — automatyczna, co
/// 5 minut, przechodzi po cichu. [showErrors] wyłącza pasek z błędem tam,
/// gdzie ekran i tak pokazuje go na stałe (Ustawienia).
Future<void> runManualSync(
  BuildContext context,
  WidgetRef ref, {
  bool showErrors = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final before = ref.read(syncStateProvider).lastSyncTime;
  await ref.read(syncStateProvider.notifier).syncNow();
  final s = ref.read(syncStateProvider);

  if (s.status == SyncStatus.error) {
    if (!showErrors) return;
    messenger.showSnackBar(SnackBar(
      content: Text(syncErrorText(s)),
      backgroundColor: OspTheme.danger,
      duration: const Duration(seconds: 8),
    ));
  } else if (s.status == SyncStatus.idle && s.lastSyncTime != before) {
    // Gdy w tle trwała już synchronizacja, ta ręczna nic nie zrobiła —
    // wtedy nie ma czego potwierdzać.
    messenger.showSnackBar(SnackBar(
      content: Text(syncSuccessText(s)),
      backgroundColor: OspTheme.success,
    ));
  }
}

/// Lista, która przy otwarciu pobiera zmiany kolegów, jeśli dawno ich nie
/// pobierano (`SyncService.syncIfStale`) — po cichu, jak synchronizacja
/// w tle. Bez tego wpis kolegi pokazywał się dopiero po „chmurce".
class SyncOnOpen extends ConsumerStatefulWidget {
  final Widget child;
  const SyncOnOpen({super.key, required this.child});

  @override
  ConsumerState<SyncOnOpen> createState() => _SyncOnOpenState();
}

class _SyncOnOpenState extends ConsumerState<SyncOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncStateProvider.notifier).syncIfStale();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
