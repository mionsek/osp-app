import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../models/sync_state.dart';
import '../../services/ad_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _prefixController;
  late TextEditingController _localityController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    try {
      final config = ref.read(unitConfigProvider);
      _prefixController = TextEditingController(text: config.namePrefix);
      _localityController = TextEditingController(text: config.locality);
    } catch (e) {
      debugPrint('Settings initState error: $e');
      _prefixController = TextEditingController(text: 'Ochotnicza Straż Pożarna');
      _localityController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final currentConfig = ref.read(unitConfigProvider);
    final newConfig = UnitConfig(
      namePrefix: _prefixController.text.trim(),
      locality: _localityController.text.trim(),
      onboardingCompleted: true,
      isAdmin: currentConfig.isAdmin,
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
    debugPrint('SettingsScreen.build() called');
    final config = ref.watch(unitConfigProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ustawienia'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  maxLength: 50,
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
                Text('Informacje',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '...';
                    return _InfoRow('Wersja aplikacji', version);
                  },
                ),
                _InfoRow('Rola',
                    config.isAdmin ? 'Administrator' : 'Użytkownik'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.push('/info'),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Więcej o aplikacji'),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                _PremiumSection(),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                _GoogleSyncSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSyncSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncState syncState;
    try {
      syncState = ref.watch(syncStateProvider);
    } catch (e) {
      debugPrint('syncStateProvider error: $e');
      return const Text('Nie udało się załadować danych synchronizacji.');
    }

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
                Expanded(
                  child: Text('Kod zaproszenia',
                      style: TextStyle(color: Colors.grey[600])),
                ),
                Text(
                  syncState.unitInviteCode!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
          OutlinedButton.icon(
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
          const SizedBox(height: 8),
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

class _PremiumSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends ConsumerState<_PremiumSection> {
  bool _loading = false;
  ProductDetails? _product;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final product = await ref
        .read(premiumProvider.notifier)
        .fetchProductDetails();
    if (mounted) setState(() => _product = product);
  }

  Future<void> _buy() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final success =
          await ref.read(premiumProvider.notifier).buyRemoveAds();
      if (!success && mounted) {
        setState(() => _errorMessage = 'Nie udało się uruchomić sklepu.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Błąd: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(premiumProvider.notifier).restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakupy przywrócone')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Błąd przywracania: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider);
    final unitConfig = ref.watch(unitConfigProvider);
    final isUnitFree = !shouldShowAds(unitConfig.ownerEmail);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Premium', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (isUnitFree) ...[
          _PremiumStatusTile(
            icon: Icons.verified,
            color: Colors.green,
            title: 'Brak reklam',
            subtitle: 'Twoja jednostka ma wyłączone reklamy.',
          ),
        ] else if (isPremium) ...[
          _PremiumStatusTile(
            icon: Icons.star,
            color: Colors.amber[700]!,
            title: 'Premium aktywne',
            subtitle: 'Reklamy są wyłączone. Dziękujemy za wsparcie!',
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.block, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('Wyłącz reklamy',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _product != null
                      ? 'Jednorazowy zakup — ${_product!.price}'
                      : 'Jednorazowy zakup (brak połączenia ze sklepem)',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null) ...[
            Text(_errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: _loading || _product == null ? null : _buy,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.shopping_cart),
            label: const Text('Kup — wyłącz reklamy'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loading ? null : _restore,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Przywróć zakupy'),
          ),
        ],
      ],
    );
  }
}

class _PremiumStatusTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _PremiumStatusTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: color)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {  final String label;
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
