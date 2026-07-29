import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/handover_property_kinds.dart';
import '../../core/constants/handover_recipient_types.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/location_service.dart';

/// Formularz „Potwierdzenie przekazania terenu, obiektu lub mienia".
/// Jeden ekran (nie kreator) — pola są prostsze niż w wyjeździe.
class HandoverFormScreen extends ConsumerStatefulWidget {
  final String? handoverId;
  const HandoverFormScreen({super.key, this.handoverId});

  @override
  ConsumerState<HandoverFormScreen> createState() =>
      _HandoverFormScreenState();
}

class _HandoverFormScreenState extends ConsumerState<HandoverFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _eventLocationController = TextEditingController();
  final _recipientTypeOtherController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _propertyDescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _signLocalityController = TextEditingController();

  late DateTime _eventDate;
  late TimeOfDay _eventTime;
  late DateTime _signDate;
  String? _recipientType;
  String? _propertyKind;
  String? _handoverFirefighterId;
  String? _linkedReportId;
  bool _locating = false;

  bool get _isEditing => widget.handoverId != null;

  /// Podpowiada miejsce zdarzenia na podstawie GPS. Wynik wpisujemy do
  /// zwykłego pola tekstowego — użytkownik może go dowolnie poprawić, bo
  /// GPS potrafi się mylić, a bez internetu adresu w ogóle nie ustalimy.
  Future<void> _fillAddressFromGps() async {
    setState(() => _locating = true);
    try {
      final address = await LocationService.currentAddress();
      if (!mounted) return;
      if (address.isEmpty) {
        _showSnack('Nie udało się ustalić adresu — wpisz go ręcznie.');
        return;
      }
      setState(() {
        _eventLocationController.text = address.oneLine;
        if (address.locality.isNotEmpty) {
          _signLocalityController.text = address.locality;
        }
      });
      _showSnack('Wstawiono adres z GPS — sprawdź i popraw w razie potrzeby.',
          ok: true);
    } on LocationFailure catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('Błąd lokalizacji: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showSnack(String text, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.orange[800],
    ));
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _eventDate = DateTime(now.year, now.month, now.day);
    _eventTime = TimeOfDay.fromDateTime(now);
    _signDate = DateTime(now.year, now.month, now.day);

    // Miejscowość w stopce zostaje pusta — uzupełnia ją przycisk GPS
    // („Wstaw adres z GPS") albo użytkownik ręcznie. Formularz wypełnia
    // się zwykle na miejscu zdarzenia, więc miejscowość jednostki z
    // ustawień bywałaby po prostu nieprawdziwa.

    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final h = db.getHandover(widget.handoverId!);
      if (h != null) {
        _linkedReportId = h.reportId;
        _eventLocationController.text = h.eventLocation;
        _eventDate = h.eventDate;
        _eventTime = TimeOfDay.fromDateTime(h.eventTime);
        _recipientType = h.recipientType;
        _recipientTypeOtherController.text = h.recipientTypeOther ?? '';
        _recipientNameController.text = h.recipientName;
        _recipientAddressController.text = h.recipientAddress;
        _recipientPhoneController.text = h.recipientPhone;
        _propertyDescriptionController.text = h.propertyDescription;
        _propertyKind = h.propertyKind;
        _notesController.text = h.notes ?? '';
        _handoverFirefighterId = h.handoverFirefighterId;
        _signLocalityController.text = h.signLocality;
        _signDate = h.signDate;
      }
    }
  }

  @override
  void dispose() {
    _eventLocationController.dispose();
    _recipientTypeOtherController.dispose();
    _recipientNameController.dispose();
    _recipientAddressController.dispose();
    _recipientPhoneController.dispose();
    _propertyDescriptionController.dispose();
    _notesController.dispose();
    _signLocalityController.dispose();
    super.dispose();
  }

  void _applyReport(Report? report) {
    setState(() {
      _linkedReportId = report?.id;
      if (report != null) {
        final parts = [report.addressLocality, report.addressStreet]
            .where((s) => s.isNotEmpty)
            .join(', ');
        _eventLocationController.text = parts;
        _eventDate = report.date;
        _eventTime = TimeOfDay.fromDateTime(report.departureTime);
      }
    });
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final missing = <String>[
      if (_recipientNameController.text.trim().isEmpty)
        'imię i nazwisko przejmującego',
      if (_recipientPhoneController.text.trim().isEmpty)
        'numer telefonu przejmującego',
      if (_recipientType == null) 'rodzaj podmiotu przejmującego',
      if (_propertyKind == null) 'rodzaj przekazywanego (teren/obiekt/mienie)',
      if (_handoverFirefighterId == null) 'przekazujący strażak',
    ];
    if (missing.isNotEmpty) {
      final proceed = await _confirmIncomplete(missing);
      if (proceed != true) return;
    }

    final now = DateTime.now();
    final eventDateTime = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _eventTime.hour,
      _eventTime.minute,
    );
    final syncState = ref.read(syncStateProvider);

    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final h = db.getHandover(widget.handoverId!);
      if (h != null) {
        h
          ..reportId = _linkedReportId
          ..eventLocation = _eventLocationController.text.trim()
          ..eventDate = _eventDate
          ..eventTime = eventDateTime
          ..recipientType = _recipientType
          ..recipientTypeOther = _recipientType == HandoverRecipientTypes.other
              ? _recipientTypeOtherController.text.trim()
              : null
          ..recipientName = _recipientNameController.text.trim()
          ..recipientAddress = _recipientAddressController.text.trim()
          ..recipientPhone = _recipientPhoneController.text.trim()
          ..propertyDescription = _propertyDescriptionController.text.trim()
          ..propertyKind = _propertyKind
          ..notes = _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()
          ..handoverFirefighterId = _handoverFirefighterId
          ..signLocality = _signLocalityController.text.trim()
          ..signDate = _signDate
          ..updatedAt = now;
        await ref.read(handoversProvider.notifier).update(h);
        if (mounted) _afterSave(h.id);
      }
      return;
    }

    final handover = PropertyHandover(
      id: const Uuid().v4(),
      reportId: _linkedReportId,
      eventLocation: _eventLocationController.text.trim(),
      eventDate: _eventDate,
      eventTime: eventDateTime,
      recipientType: _recipientType,
      recipientTypeOther: _recipientType == HandoverRecipientTypes.other
          ? _recipientTypeOtherController.text.trim()
          : null,
      recipientName: _recipientNameController.text.trim(),
      recipientAddress: _recipientAddressController.text.trim(),
      recipientPhone: _recipientPhoneController.text.trim(),
      propertyDescription: _propertyDescriptionController.text.trim(),
      propertyKind: _propertyKind,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      handoverFirefighterId: _handoverFirefighterId,
      signLocality: _signLocalityController.text.trim(),
      signDate: _signDate,
      createdAt: now,
      updatedAt: now,
      createdBy: syncState.userEmail ?? '',
    );
    await ref.read(handoversProvider.notifier).add(handover);
    if (mounted) _afterSave(handover.id);
  }

  /// Po zapisie — tak jak przy dodawaniu wyjazdu — przechodzimy od razu do
  /// ekranu szczegółów, skąd można wydrukować lub wysłać potwierdzenie.
  void _afterSave(String handoverId) {
    final syncState = ref.read(syncStateProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(syncState.isConnected
            ? 'Przekazanie mienia zapisane. Synchronizacja z Google Drive '
                'w toku...'
            : 'Przekazanie mienia zapisane lokalnie.'),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 3),
      ),
    );
    context.go('/handovers/view/$handoverId');
  }

  Future<bool?> _confirmIncomplete(List<String> missing) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Niepełne dane'),
        content: Text(
          'Nie uzupełniono: ${missing.join(', ')}.\n\n'
          'Możesz zapisać mimo to i uzupełnić brakujące pola ręcznie na '
          'wydruku, albo wrócić i je wypełnić.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Wróć do formularza'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zapisz mimo to'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportsProvider);
    final firefighters = ref.watch(firefightersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edytuj przekazanie mienia' : 'Nowe przekazanie mienia',
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reports.isNotEmpty) ...[
                Text(
                  'Powiązany wyjazd (opcjonalnie)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _linkedReportId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_fire_department),
                    hintText: 'Brak powiązania',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Brak powiązania'),
                    ),
                    ...reports.map(
                      (r) => DropdownMenuItem<String?>(
                        value: r.id,
                        child: Text(
                          '${r.reportNumber} — ${r.addressLocality}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (id) {
                    final report =
                        id == null ? null : reports.where((r) => r.id == id).firstOrNull;
                    _applyReport(report);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Wybór wyjazdu uzupełni miejsce i datę zdarzenia poniżej — '
                  'możesz je jeszcze poprawić.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
              ],

              Text(
                'Zdarzenie',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _eventLocationController,
                decoration: InputDecoration(
                  labelText: 'Miejsce zdarzenia',
                  hintText: 'Miejscowość, adres',
                  prefixIcon: const Icon(Icons.place),
                  suffixIcon: IconButton(
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    tooltip: 'Wstaw adres z GPS',
                    onPressed: _locating ? null : _fillAddressFromGps,
                  ),
                ),
                maxLength: 150,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Podaj miejsce zdarzenia'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Data zdarzenia',
                      value: _eventDate,
                      onChanged: (d) => setState(() => _eventDate = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Godzina',
                      value: _eventTime,
                      onChanged: (t) => setState(() => _eventTime = t),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Przejmujący',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _recipientType,
                decoration: const InputDecoration(
                  labelText: 'Rodzaj podmiotu przejmującego',
                  hintText: 'Nie wybrano',
                  prefixIcon: Icon(Icons.badge),
                ),
                isExpanded: true,
                items: HandoverRecipientTypes.all
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _recipientType = v),
              ),
              if (_recipientType == null) ...[
                const SizedBox(height: 8),
                const _WarningBanner(
                  text: 'Nie wybrano rodzaju podmiotu przejmującego — na '
                      'wydruku ta pozycja zostanie pusta, do ręcznego '
                      'skreślenia długopisem.',
                ),
              ],
              if (_recipientType == HandoverRecipientTypes.other) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientTypeOtherController,
                  decoration: const InputDecoration(
                    labelText: 'Podaj rodzaj podmiotu',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  maxLength: 80,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Podaj rodzaj podmiotu'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientNameController,
                decoration: const InputDecoration(
                  labelText: 'Imię i nazwisko',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientAddressController,
                decoration: const InputDecoration(
                  labelText: 'Adres służbowy lub zamieszkania',
                  prefixIcon: Icon(Icons.home),
                ),
                maxLength: 150,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Numer telefonu',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 20,
              ),

              const SizedBox(height: 24),
              Text(
                'Przekazywane mienie',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _propertyKind,
                decoration: const InputDecoration(
                  labelText: 'Rodzaj przekazywanego',
                  hintText: 'Nie wybrano',
                  prefixIcon: Icon(Icons.category),
                ),
                isExpanded: true,
                items: HandoverPropertyKinds.all
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _propertyKind = v),
              ),
              if (_propertyKind == null) ...[
                const SizedBox(height: 8),
                const _WarningBanner(
                  text: 'Nie wybrano rodzaju (teren / obiekt / mienie) — na '
                      'wydruku żadna pozycja nie zostanie skreślona, do '
                      'ręcznego uzupełnienia długopisem.',
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _propertyDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Opis przekazywanego',
                  hintText: 'Co dokładnie jest przekazywane do nadzoru...',
                  prefixIcon: Icon(Icons.inventory_2),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 400,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Opisz przekazywany teren, obiekt lub mienie'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Uwagi szczegółowe',
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 400,
              ),

              const SizedBox(height: 24),
              Text(
                'Przekazujący i podpis',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _handoverFirefighterId,
                decoration: const InputDecoration(
                  labelText: 'Przekazujący (stopień, imię i nazwisko)',
                  prefixIcon: Icon(Icons.military_tech),
                  hintText: 'Nie wybrano',
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Nie wybrano'),
                  ),
                  ...firefighters.map((f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(f.fullNameWithRank,
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (id) => setState(() => _handoverFirefighterId = id),
              ),
              if (_handoverFirefighterId == null) ...[
                const SizedBox(height: 8),
                _WarningBanner(
                  text: firefighters.isEmpty
                      ? 'Nie masz jeszcze dodanych ratowników — pole '
                          '„Przekazujący" na wydruku zostanie puste, do '
                          'uzupełnienia długopisem.'
                      : 'Nie wybrano przekazującego — pole na wydruku '
                          'zostanie puste, do uzupełnienia długopisem.',
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _signLocalityController,
                      decoration: const InputDecoration(
                        labelText: 'Miejscowość',
                        hintText: 'z GPS lub ręcznie',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Podaj miejscowość' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Dnia',
                      value: _signDate,
                      onChanged: (d) => setState(() => _signDate = d),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.save),
                label: Text(
                  _isEditing ? 'Zapisz zmiany' : 'Zapisz przekazanie mienia',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          locale: const Locale('pl'),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat('dd.MM.yyyy').format(value)),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}
