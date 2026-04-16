import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  bool _isSigningIn = false;
  bool _isCreating = false;
  bool _isJoining = false;

  final _prefixController =
      TextEditingController(text: 'Ochotnicza Straż Pożarna');
  final _localityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _joinFormKey = GlobalKey<FormState>();
  String? _joinError;

  bool _isCreateMode = true;

  @override
  void dispose() {
    _pageController.dispose();
    _prefixController.dispose();
    _localityController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningIn = true);
    try {
      final success = await ref.read(syncStateProvider.notifier).signIn();
      if (success && mounted) {
        _goToPage(2);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logowanie nie powiodło się')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _handleCreateUnit() async {
    if (!_formKey.currentState!.validate()) return;

    final prefix = _prefixController.text.trim();
    final locality = _localityController.text.trim();
    final fullName = locality.isEmpty ? prefix : '$prefix $locality';

    setState(() => _isCreating = true);
    try {
      final syncState = ref.read(syncStateProvider);

      final configNotifier = ref.read(unitConfigProvider.notifier);
      final db = ref.read(databaseServiceProvider);
      await configNotifier.completeOnboarding(prefix, locality);
      await db.initializeDefaultThreats();
      ref.read(threatsProvider.notifier).refresh();

      if (syncState.userEmail != null) {
        final code =
            await ref.read(syncStateProvider.notifier).createUnit(fullName);
        if (mounted) await _showInviteCodeDialog(code);
      }

      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _handleCreateOffline() async {
    if (!_formKey.currentState!.validate()) return;

    final prefix = _prefixController.text.trim();
    final locality = _localityController.text.trim();

    final configNotifier = ref.read(unitConfigProvider.notifier);
    final db = ref.read(databaseServiceProvider);
    await configNotifier.completeOnboarding(prefix, locality);
    await db.initializeDefaultThreats();
    ref.read(threatsProvider.notifier).refresh();

    if (mounted) context.go('/home');
  }

  Future<void> _handleJoinUnit() async {
    if (!_joinFormKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
      _joinError = null;
    });
    try {
      final code = _codeController.text.trim().toUpperCase();
      final success =
          await ref.read(syncStateProvider.notifier).joinUnit(code);

      if (success && mounted) {
        final configNotifier = ref.read(unitConfigProvider.notifier);
        final db = ref.read(databaseServiceProvider);
        final config = db.getConfig();
        await configNotifier.save(UnitConfig(
          namePrefix: config.namePrefix,
          locality: config.locality,
          onboardingCompleted: true,
          isAdmin: false,
        ));
        await db.initializeDefaultThreats();
        ref.read(threatsProvider.notifier).refresh();
        ref.read(vehiclesProvider.notifier).refresh();
        ref.read(firefightersProvider.notifier).refresh();
        ref.read(reportsProvider.notifier).refresh();

        if (mounted) context.go('/home');
      } else if (mounted) {
        setState(() => _joinError = 'Nie znaleziono jednostki z tym kodem');
      }
    } catch (e) {
      if (mounted) setState(() => _joinError = 'Błąd: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _showInviteCodeDialog(String code) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Kod zaproszenia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Podaj ten kod innym strażakom z Twojej jednostki, '
              'aby mogli dołączyć do wspólnych danych:',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32)),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Color(0xFF2E7D32),
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
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }

  String get _fullName {
    final prefix = _prefixController.text.trim();
    final locality = _localityController.text.trim();
    if (locality.isEmpty) return prefix;
    return '$prefix $locality';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    final isSignedIn = syncState.userEmail != null;

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomePage(),
            _isCreateMode
                ? _buildAccountChoicePage()
                : _buildJoinSignInPage(),
            _isCreateMode
                ? _buildCreatePage(isSignedIn)
                : _buildJoinPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.local_fire_department,
            size: 80,
            color: Color(0xFFB71C1C),
          ),
          const SizedBox(height: 24),
          Text(
            'Witaj w aplikacji OSP',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Raporty z wyjazdów ratowniczych',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _ChoiceCard(
            icon: Icons.add_circle_outline,
            title: 'Utwórz nową jednostkę',
            subtitle: 'Dla prezesa/naczelnika — skonfiguruj dane jednostki '
                'i wygeneruj kod zaproszenia.',
            onTap: () {
              setState(() => _isCreateMode = true);
              _goToPage(1);
            },
          ),
          const SizedBox(height: 16),
          _ChoiceCard(
            icon: Icons.group_add,
            title: 'Dołącz do jednostki',
            subtitle: 'Wpisz kod zaproszenia otrzymany od '
                'administratora jednostki.',
            onTap: () {
              setState(() => _isCreateMode = false);
              _goToPage(1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountChoicePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Wybierz konto Google',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Dane jednostki będą przechowywane na Dysku Google '
              'wybranego konta. Wszyscy strażacy z jednostki będą '
              'korzystać z tego samego folderu.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _ChoiceCard(
            icon: Icons.apartment,
            title: 'Użyj konta jednostki',
            subtitle: 'Zalecane — np. ospkielno@gmail.com\n'
                'Dane będą na wspólnym koncie jednostki.',
            onTap: _isSigningIn ? () {} : _handleGoogleSignIn,
            badge: 'zalecane',
          ),
          const SizedBox(height: 16),
          _ChoiceCard(
            icon: Icons.person,
            title: 'Użyj prywatnego konta',
            subtitle: 'np. jan.kowalski@gmail.com\n'
                'Dane będą na Twoim prywatnym koncie.',
            onTap: _isSigningIn ? () {} : _handleGoogleSignIn,
          ),
          if (_isSigningIn) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            Text(
              'Logowanie...',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => _goToPage(2),
            child: const Text('Kontynuuj bez logowania (tryb offline)'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _goToPage(0),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Wróć'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinSignInPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.login,
            size: 64,
            color: Color(0xFFB71C1C),
          ),
          const SizedBox(height: 24),
          Text(
            'Zaloguj się',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Zaloguj się kontem Google, aby dołączyć '
            'do istniejącej jednostki.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isSigningIn ? null : _handleGoogleSignIn,
            icon: _isSigningIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
                _isSigningIn ? 'Logowanie...' : 'Zaloguj się kontem Google'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => _goToPage(0),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Wróć'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePage(bool isSignedIn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Nowa jednostka',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _prefixController,
              decoration: const InputDecoration(
                labelText: 'Nazwa jednostki',
                hintText: 'Ochotnicza Straż Pożarna',
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Podaj nazwę jednostki';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _localityController,
              decoration: const InputDecoration(
                labelText: 'Miejscowość',
                hintText: 'np. Kielno',
              ),
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Podaj miejscowość';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pełna nazwa:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fullName.isEmpty ? '—' : _fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isCreating
                  ? null
                  : (isSignedIn ? _handleCreateUnit : _handleCreateOffline),
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isCreating ? 'Tworzenie...' : 'Utwórz jednostkę'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _goToPage(1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Wróć'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _joinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Dołącz do jednostki',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Wpisz 6-znakowy kod zaproszenia otrzymany od '
              'administratora Twojej jednostki.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Kod zaproszenia',
                hintText: 'np. ABC123',
                prefixIcon: const Icon(Icons.vpn_key),
                errorText: _joinError,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return 'Kod musi mieć 6 znaków';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isJoining ? null : _handleJoinUnit,
              icon: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add),
              label: Text(_isJoining ? 'Dołączanie...' : 'Dołącz'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _goToPage(1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Wróć'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: const Color(0xFFB71C1C)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
