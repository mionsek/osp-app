import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/providers.dart';

class StepBasicInfo extends ConsumerStatefulWidget {
  final String reportNumber;
  final DateTime date;
  final TimeOfDay departureTime;
  final TimeOfDay? returnTime;
  final String addressLocality;
  final String addressStreet;
  final String addressDescription;
  final String threatCategory;
  final String? threatSubtype;
  final List<String> selectedVehicleIds;
  final void Function({
    String? reportNumber,
    DateTime? date,
    TimeOfDay? departureTime,
    TimeOfDay? returnTime,
    bool clearReturnTime,
    String? addressLocality,
    String? addressStreet,
    String? addressDescription,
    String? threatCategory,
    String? threatSubtype,
    bool clearThreatSubtype,
    List<String>? selectedVehicleIds,
  }) onChanged;
  final VoidCallback onNext;

  const StepBasicInfo({
    super.key,
    required this.reportNumber,
    required this.date,
    required this.departureTime,
    this.returnTime,
    required this.addressLocality,
    required this.addressStreet,
    required this.addressDescription,
    required this.threatCategory,
    this.threatSubtype,
    required this.selectedVehicleIds,
    required this.onChanged,
    required this.onNext,
  });

  @override
  ConsumerState<StepBasicInfo> createState() => _StepBasicInfoState();
}

class _StepBasicInfoState extends ConsumerState<StepBasicInfo>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _reportNumberController;
  late TextEditingController _localityController;
  late TextEditingController _streetController;
  late TextEditingController _descriptionController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reportNumberController =
        TextEditingController(text: widget.reportNumber);
    _localityController =
        TextEditingController(text: widget.addressLocality);
    _streetController =
        TextEditingController(text: widget.addressStreet);
    _descriptionController =
        TextEditingController(text: widget.addressDescription);
  }

  @override
  void dispose() {
    _reportNumberController.dispose();
    _localityController.dispose();
    _streetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validate() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.selectedVehicleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybierz przynajmniej jeden pojazd'),
          backgroundColor: Color(0xFFB71C1C),
        ),
      );
      return;
    }
    if (widget.threatCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybierz rodzaj zagrożenia'),
          backgroundColor: Color(0xFFB71C1C),
        ),
      );
      return;
    }
    widget.onNext();
  }

  Future<void> _pasteToField(
      TextEditingController controller, ValueChanged<String> onChanged) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final text = data.text!.trim();
      controller.text = text;
      controller.selection =
          TextSelection.collapsed(offset: text.length);
      onChanged(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final vehicles = ref.watch(vehiclesProvider);
    final threats = ref.watch(threatsProvider);
    final categories = threats.map((t) => t.category).toList();
    final subtypes = widget.threatCategory.isNotEmpty
        ? threats
            .where((t) => t.category == widget.threatCategory)
            .expand((t) => t.subtypes)
            .toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Krok 1 z 3 — Dane podstawowe',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Report number
            TextFormField(
              controller: _reportNumberController,
              decoration: const InputDecoration(
                labelText: 'Numer ewidencyjny',
                prefixIcon: Icon(Icons.numbers),
                hintText: '0001/2026',
              ),
              onChanged: (v) =>
                  widget.onChanged(reportNumber: v.trim()),
              maxLength: 20,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Podaj numer ewidencyjny';
                }
                if (!RegExp(r'^\d+/\d{4}$').hasMatch(v.trim())) {
                  return 'Format: liczba/rok (np. 0001/2026)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date
            _DateField(
              label: 'Data zdarzenia',
              value: widget.date,
              onChanged: (d) => widget.onChanged(date: d),
            ),
            const SizedBox(height: 16),

            // Departure time
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Godz. wyjazdu',
                    value: widget.departureTime,
                    onChanged: (t) => widget.onChanged(departureTime: t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'Godz. powrotu',
                    value: widget.returnTime,
                    onChanged: (t) => widget.onChanged(returnTime: t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _localityController,
              decoration: InputDecoration(
                labelText: 'Miejscowość',
                prefixIcon: const Icon(Icons.location_city),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Wklej z schowka',
                  onPressed: () => _pasteToField(_localityController, (v) =>
                      widget.onChanged(addressLocality: v)),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) =>
                  widget.onChanged(addressLocality: v.trim()),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Podaj miejscowość'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streetController,
              decoration: InputDecoration(
                labelText: 'Ulica i nr domu',
                prefixIcon: const Icon(Icons.place),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Wklej z schowka',
                  onPressed: () => _pasteToField(_streetController, (v) =>
                      widget.onChanged(addressStreet: v)),
                ),
              ),
              maxLength: 200,
              onChanged: (v) =>
                  widget.onChanged(addressStreet: v.trim()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Opis miejsca zdarzenia',
                prefixIcon: Icon(Icons.description),
                hintText: 'np. za stacją benzynową, przy lesie...',
              ),
              maxLength: 300,
              maxLines: 2,
              onChanged: (v) =>
                  widget.onChanged(addressDescription: v.trim()),
            ),
            const SizedBox(height: 20),

            // Threat category
            Text('Zagrożenie',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: widget.threatCategory.isNotEmpty
                  ? widget.threatCategory
                  : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.warning_amber),
                hintText: 'Wybierz zagrożenie',
              ),
              items: [
                ...categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    )),
                const DropdownMenuItem(
                  value: '__custom__',
                  child: Text('Inne — dodaj własne', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              ],
              onChanged: (value) {
                if (value == '__custom__') {
                  _showAddCustomCategoryDialog();
                } else if (value != null) {
                  widget.onChanged(
                    threatCategory: value,
                    clearThreatSubtype: true,
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // Threat subtype
            if (subtypes.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: widget.threatSubtype,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  hintText: 'Rodzaj zagrożenia',
                ),
                items: [
                  ...subtypes.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('Inne — dodaj własne',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ],
                onChanged: (value) {
                  if (value == '__custom__') {
                    _showAddCustomSubtypeDialog();
                  } else {
                    widget.onChanged(threatSubtype: value);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // Vehicles selection
            const SizedBox(height: 8),
            Text('Pojazdy biorące udział',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (vehicles.isEmpty)
              const Text('Brak pojazdów — dodaj pojazd w menu głównym',
                  style: TextStyle(color: Colors.red))
            else
              ...vehicles.map((v) => CheckboxListTile(
                    title: Text(v.name),
                    subtitle: Text('${v.seats} miejsc'),
                    value: widget.selectedVehicleIds.contains(v.id),
                    onChanged: (checked) {
                      final ids = List<String>.from(widget.selectedVehicleIds);
                      if (checked == true) {
                        ids.add(v.id);
                      } else {
                        ids.remove(v.id);
                      }
                      widget.onChanged(selectedVehicleIds: ids);
                    },
                    secondary: const Icon(Icons.fire_truck,
                        color: Color(0xFFE65100)),
                  )),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _validate,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Dalej — Zastępy'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowe zagrożenie'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nazwa zagrożenia'),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.length >= 2) {
                ref.read(threatsProvider.notifier).addCustomCategory(name);
                widget.onChanged(threatCategory: name, clearThreatSubtype: true);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomSubtypeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nowy rodzaj: ${widget.threatCategory}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nazwa rodzaju'),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.length >= 2) {
                ref
                    .read(threatsProvider.notifier)
                    .addCustomSubtype(widget.threatCategory, name);
                widget.onChanged(threatSubtype: name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Dodaj'),
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
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimeField({
    required this.label,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
          builder: (context, child) {
            return MediaQuery(
              data:
                  MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
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
        child: Text(value != null
            ? '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
            : '—'),
      ),
    );
  }
}
