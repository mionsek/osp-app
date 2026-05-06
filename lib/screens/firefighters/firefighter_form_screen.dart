import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  DateTime? _medicalExamExpiry;
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
        _medicalExamExpiry = ff.medicalExamExpiry;
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
        ff.medicalExamExpiry = _medicalExamExpiry;
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
        medicalExamExpiry: _medicalExamExpiry,
      );
      await ref.read(firefightersProvider.notifier).add(ff);
    }

    if (mounted) context.pop();
  }

  Widget _buildMedicalExamField(BuildContext context) {
    Color chipColor;
    String label;
    IconData icon;
    String placeholder = DateFormat('dd.MM.yyyy').format(DateTime.now().add(const Duration(days: 30)));

    if (_medicalExamExpiry == null) {
      chipColor = Colors.grey;
      label = 'np. $placeholder';
      icon = Icons.help_outline;
    } else if (_medicalExamExpiry!.isBefore(DateTime.now())) {
      chipColor = const Color(0xFFB71C1C);
      label = 'Wygasło: ${DateFormat('dd.MM.yyyy').format(_medicalExamExpiry!)}';
      icon = Icons.error_outline;
    } else if (_medicalExamExpiry!
        .isBefore(DateTime.now().add(const Duration(days: 30)))) {
      chipColor = Colors.orange;
      label = 'Wygasa: ${DateFormat('dd.MM.yyyy').format(_medicalExamExpiry!)}';
      icon = Icons.warning_amber;
    } else {
      chipColor = const Color(0xFF2E7D32);
      label = 'Ważne do: ${DateFormat('dd.MM.yyyy').format(_medicalExamExpiry!)}';
      icon = Icons.check_circle_outline;
    }

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickMedicalExamDate(context),
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: chipColor),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: chipColor,
                  fontWeight: FontWeight.w600,
                  fontStyle: _medicalExamExpiry == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
        ),
        if (_medicalExamExpiry != null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _medicalExamExpiry = null),
            tooltip: 'Wyczyść datę',
          ),
      ],
    );
  }

  Future<void> _pickMedicalExamDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _medicalExamExpiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'Data ważności badań lekarskich',
    );
    if (picked != null) {
      setState(() => _medicalExamExpiry = picked);
    }
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
              const SizedBox(height: 24),
              Text(
                'Ważność Badań Lekarskich',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              _buildMedicalExamField(context),
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
