import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/osp_theme.dart';
import '../core/utils/unit_storage.dart';
import '../models/sync_state.dart';
import '../providers/providers.dart';
import 'sync_feedback.dart';

/// Czy ten wyjazd albo przekazanie jest już na Dysku jednostki.
///
/// Wcześniej ekran wyjazdu pisał „Zapisano na Google Drive" po każdej udanej
/// synchronizacji — także przy wyjeździe, który dopiero czekał na wysłanie —
/// a ekran przekazania nie mówił nic. Bez połączenia z jednostką pasek się
/// nie pokazuje: nie ma dokąd wysyłać.
class UploadStatusBanner extends ConsumerWidget {
  /// „Wyjazd", „Przekazanie" — do komunikatu po błędzie.
  final String subject;

  /// Czy na Dysku nie ma jeszcze obecnej wersji.
  final bool pending;

  const UploadStatusBanner({
    super.key,
    required this.subject,
    required this.pending,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncStateProvider);
    if (!sync.isConnected || sync.unitFolderId == null) {
      return const SizedBox.shrink();
    }
    final onServer = ref.watch(syncServiceProvider).onServer;

    final (Color color, Color surface, IconData icon, String text) =
        switch ((pending, sync.isSyncing, sync.status == SyncStatus.error)) {
      (false, _, _) => (
          OspTheme.success,
          OspTheme.successSurface,
          Icons.cloud_done,
          'Zapisano ${UnitStorage.at(onServer)}',
        ),
      (true, true, _) => (
          OspTheme.info,
          OspTheme.infoSurface,
          Icons.sync,
          'Wysyłanie ${UnitStorage.to(onServer)}…',
        ),
      (true, false, true) => (
          OspTheme.danger,
          OspTheme.dangerSurface,
          Icons.cloud_off,
          '$subject jest na telefonie, ale jeszcze nie '
              '${UnitStorage.at(onServer)}. '
              '${syncErrorText(sync)}',
        ),
      (true, false, false) => (
          OspTheme.attention,
          OspTheme.attentionSurface,
          Icons.cloud_upload,
          'Czeka na wysłanie ${UnitStorage.to(onServer)}',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
          if (pending && !sync.isSyncing)
            TextButton(
              onPressed: () => runManualSync(context, ref),
              child: const Text('Wyślij teraz'),
            ),
        ],
      ),
    );
  }
}

/// Ikona przy wpisie listy, który czeka na wysłanie do jednostki.
class AwaitingUploadIcon extends ConsumerWidget {
  const AwaitingUploadIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Tooltip(
        message: 'Czeka na wysłanie '
            '${UnitStorage.to(ref.watch(syncServiceProvider).onServer)}',
        child: const Icon(Icons.cloud_upload, color: OspTheme.attention),
      );
}
