import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class FirefighterFormScreen extends ConsumerStatefulWidget {
  final String? firefighterId;
  const FirefighterFormScreen({super.key, this.firefighterId});

  @override
  ConsumerState<FirefighterFormScreen> createState() =>
      _FirefighterFormScreenState();
}

class _FirefighterFormScreenState extends ConsumerState<FirefighterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isDriver = false;
  bool _isCommander = false;
  bool _isKPP = false;
  bool get _isEditing => widget.firefighterId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final ff = db.getFirefighter(widget.firefighterId!);
      if (ff != null) {
        _firstNameController.text = ff.firstName;
        _lastNameController.text = ff.lastName;
        _isDriver = ff.isDriver;
        _isCommander = ff.isCommander;
        _isKPP = ff.isKPP;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final ff = db.getFirefighter(widget.firefighterId!);
      if (ff != null) {
        ff.firstName = firstName;
        ff.lastName = lastName;
        ff.isDriver = _isDriver;
        ff.isCommander = _isCommander;
        ff.isKPP = _isKPP;
        await ref.read(firefightersProvider.notifier).update(ff);
      }
    } else {
      final ff = Firefighter(
        id: const Uuid().v4(),
        firstName: firstName,
        lastName: lastName,
        rank: '',
        isDriver: _isDriver,
        isCommander: _isCommander,
        isKPP: _isKPP,
      );
      await ref.read(firefightersProvider.notifier).add(ff);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj ratownika' : 'Nowy ratownik'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Imię',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj imię';
                  }
                  if (value.trim().length < 2) {
                    return 'Imię musi mieć min. 2 znaki';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwisko',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj nazwisko';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Funkcje (opcjonalne)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                title: const Text('Kierowca'),
                secondary: const Icon(Icons.drive_eta),
                value: _isDriver,
                onChanged: (v) => setState(() => _isDriver = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Dowódca'),
                secondary: const Icon(Icons.military_tech),
                value: _isCommander,
                onChanged: (v) => setState(() => _isCommander = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Ratownik KPP'),
                secondary: const Icon(Icons.medical_services),
                value: _isKPP,
                onChanged: (v) => setState(() => _isKPP = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.save),
                label:
                    Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj ratownika'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
