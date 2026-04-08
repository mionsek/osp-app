import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _prefixController =
      TextEditingController(text: 'Ochotnicza Straż Pożarna');
  final _localityController = TextEditingController();

  @override
  void dispose() {
    _prefixController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  String get _fullName {
    final prefix = _prefixController.text.trim();
    final locality = _localityController.text.trim();
    if (locality.isEmpty) return prefix;
    return '$prefix $locality';
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final prefix = _prefixController.text.trim();
    final locality = _localityController.text.trim();
    final configNotifier = ref.read(unitConfigProvider.notifier);
    final db = ref.read(databaseServiceProvider);
    final threatsNotifier = ref.read(threatsProvider.notifier);

    await configNotifier.completeOnboarding(prefix, locality);
    await db.initializeDefaultThreats();
    threatsNotifier.refresh();

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                  'Skonfiguruj swoją jednostkę',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
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
                  maxLength: 100,
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _onSubmit,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Dalej'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
