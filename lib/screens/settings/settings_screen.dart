import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../models/sync_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _prefixController;
  late TextEditingController _localityController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(unitConfigProvider);
    _prefixController = TextEditingController(text: config.namePrefix);
    _localityController = TextEditingController(text: config.locality);
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final newConfig = UnitConfig(
      namePrefix: _prefixController.text.trim(),
      locality: _localityController.text.trim(),
      onboardingCompleted: true,
      isAdmin: ref.read(unitConfigProvider).isAdmin,
    );
    await ref.read(unitConfigProvider.notifier).save(newConfig);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ustawienia zapisane'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(unitConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nazwa jednostki',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _prefixController,
              decoration: const InputDecoration(
                labelText: 'Prefiks nazwy',
                hintText: 'Ochotnicza Straż Pożarna',
              ),
              maxLength: 100,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Podaj nazwę jednostki'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _localityController,
              decoration: const InputDecoration(
                labelText: 'Miejscowość',
                hintText: 'np. Kielno',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Podaj miejscowość'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Pełna nazwa: ${_prefixController.text.trim()} ${_localityController.text.trim()}'
                    .trim(),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Zapisz ustawienia'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('Logo jednostki',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Icon(
                      Icons.local_fire_department,
                      size: 48,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Funkcja dostępna wkrótce'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('Dodaj logo jednostki'),
                  ),
                  Text(
                    'Opcjonalne — widoczne na raportach PDF',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('Informacje',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow('Wersja aplikacji', '1.0.0'),
            _InfoRow('Rola', config.isAdmin ? 'Administrator' : 'Użytkownik'),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _GoogleSyncSection(),
          ],
        ),
        ),
      ),
    );
  }
}

class _GoogleSyncSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Google Drive Sync',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        if (!syncState.isConnected) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Synchronizacja wyłączona. '
                      'Zaloguj się, aby współdzielić dane.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final success =
                  await ref.read(syncStateProvider.notifier).signIn();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Zalogowano')),
                );
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Zaloguj się kontem Google'),
          ),
        ] else ...[
          _InfoRow('Konto', syncState.userEmail ?? '—'),
          if (syncState.unitInviteCode != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Kod zaproszenia',
                    style: TextStyle(color: Colors.grey[600])),
                const Spacer(),
                Text(
                  syncState.unitInviteCode!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: syncState.unitInviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Kod skopiowany do schowka')),
                    );
                  },
                  tooltip: 'Kopiuj kod',
                ),
              ],
            ),
          ],
          if (syncState.lastSyncTime != null) ...[
            const SizedBox(height: 4),
            _InfoRow('Ostatnia synchronizacja',
                _formatTime(syncState.lastSyncTime!)),
          ],
          if (syncState.status == SyncStatus.error &&
              syncState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Błąd: ${syncState.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: syncState.isSyncing
                      ? null
                      : () => ref.read(syncStateProvider.notifier).syncNow(),
                  icon: syncState.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                      syncState.isSyncing ? 'Synchronizacja...' : 'Synchronizuj teraz'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Wyloguj'),
                      content:
                          const Text('Czy na pewno chcesz się wylogować? '
                              'Dane lokalne zostaną zachowane.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Anuluj'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Wyloguj'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(syncStateProvider.notifier).signOut();
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Wyloguj'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Przed chwilą';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours} godz. temu';
    return '${time.day}.${time.month.toString().padLeft(2, '0')}.${time.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
