import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

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
          ],
        ),
        ),
      ),
    );
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
