import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/osp_theme.dart';
import '../../core/utils/bottom_inset.dart';
import '../../core/utils/time_format.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/navigation.dart';
import '../../widgets/person_field.dart';

/// Praca sprzętu bez wyjazdu wozu — rozruch kontrolny albo inna praca
/// (ćwiczenia w remizie, prace gospodarcze).
///
/// Nowy rozruch można zapisać od razu dla kilku urządzeń: rozruchy robi się
/// zwykle hurtem, całemu sprzętowi naraz.
class EquipmentWorkFormScreen extends ConsumerStatefulWidget {
  /// Edycja istniejącego wpisu.
  final String? workId;

  /// Urządzenie zaznaczone na start (wejście z karty pracy).
  final String? equipmentId;

  /// Rozruch całego sprzętu — wszystkie urządzenia zaznaczone na start.
  final bool startupForAll;

  const EquipmentWorkFormScreen({
    super.key,
    this.workId,
    this.equipmentId,
    this.startupForAll = false,
  });

  @override
  ConsumerState<EquipmentWorkFormScreen> createState() =>
      _EquipmentWorkFormScreenState();
}

class _EquipmentWorkFormScreenState
    extends ConsumerState<EquipmentWorkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minutesCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();

  EquipmentWork? _existing;
  bool _isStartup = true;
  late DateTime _date;
  String _operatorName = '';
  String? _operatorId;
  final Set<String> _selected = {};

  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  bool get _isEdit => widget.workId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);

    final existing = _isEdit
        ? ref.read(databaseServiceProvider).getEquipmentWork(widget.workId!)
        : null;
    if (existing != null) {
      _existing = existing;
      _isStartup = existing.isStartup;
      _date = existing.date;
      _minutesCtrl.text = '${existing.minutes}';
      _purposeCtrl.text = existing.isStartup ? '' : existing.purpose;
      _operatorName = existing.operatorName;
      _operatorId = existing.operatorId;
      _selected.add(existing.equipmentId);
      return;
    }

    _minutesCtrl.text = '${EquipmentWork.startupMinutes}';
    final devices = _devices();
    if (widget.startupForAll) {
      _selected.addAll(devices.map((e) => e.id));
    } else if (widget.equipmentId != null) {
      _selected.add(widget.equipmentId!);
      // Z karty urządzenia częściej dopisuje się pracę niż rozruch —
      // rozruch całego sprzętu jest na liście sprzętu.
      _isStartup = false;
      _minutesCtrl.clear();
    }
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  /// Sprzęt z własną kartą pracy.
  List<Equipment> _devices() =>
      ref.read(equipmentProvider).where((e) => e.hasWorkCard).toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    _markDirty();
    setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      _snack('Zaznacz urządzenie', isError: true);
      return;
    }
    final now = DateTime.now();
    final minutes = int.parse(_minutesCtrl.text.trim());
    final purpose =
        _isStartup ? EquipmentWork.startupPurpose : _purposeCtrl.text.trim();
    final devices = {for (final e in ref.read(equipmentProvider)) e.id: e};

    final entries = <EquipmentWork>[];
    var i = 0;
    for (final id in _selected) {
      final w = _existing ??
          EquipmentWork(
            id: 'work_${now.microsecondsSinceEpoch}_${i++}',
            equipmentId: id,
            date: _date,
            minutes: minutes,
            createdAt: now,
            updatedAt: now,
            createdBy: ref.read(syncStateProvider).userEmail ?? '',
          );
      entries.add(w
        ..equipmentName = devices[id]?.name ?? w.equipmentName
        ..date = _date
        ..minutes = minutes
        ..isStartup = _isStartup
        ..purpose = purpose
        ..operatorName = _operatorName
        ..operatorId = _operatorId);
    }
    await ref.read(equipmentWorkProvider.notifier).save(entries);

    if (!mounted) return;
    _snack(_isEdit
        ? 'Zapisano zmiany'
        : entries.length == 1
            ? 'Dopisano do karty pracy'
            : 'Dopisano do kart pracy ${entries.length} urządzeń');
    context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć wpis?'),
        content: const Text('Wiersz zniknie z karty pracy urządzenia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OspTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(equipmentWorkProvider.notifier).delete(widget.workId!);
    if (mounted) context.pop();
  }

  void _snack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? OspTheme.danger : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _existing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Praca sprzętu'),
          actions: const [HomeButton()],
        ),
        body: const Center(child: Text('Nie znaleziono wpisu')),
      );
    }

    final canEdit = !_isEdit ||
        ref.watch(syncStateProvider).canEditDocument(_existing?.createdBy);
    final devices = ref.watch(equipmentProvider).where((e) => e.hasWorkCard);

    return LeaveGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edytuj pracę sprzętu' : 'Praca sprzętu'),
          actions: [
            if (_isEdit && canEdit)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Usuń',
                onPressed: _delete,
              ),
            HomeButton(confirmLeave: _dirty),
          ],
        ),
        body: AbsorbPointer(
          absorbing: !canEdit,
          child: SingleChildScrollView(
            padding:
                EdgeInsets.fromLTRB(16, 16, 16, 24 + context.bottomInset()),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!canEdit)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Wpis kolegi — poprawić go może autor albo '
                        'administrator.',
                        style: TextStyle(color: OspTheme.attention),
                      ),
                    ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.power_settings_new),
                        label: Text('Rozruch kontrolny'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.handyman),
                        label: Text('Inna praca'),
                      ),
                    ],
                    selected: {_isStartup},
                    onSelectionChanged: (s) {
                      _markDirty();
                      setState(() {
                        _isStartup = s.first;
                        if (_isStartup && _minutesCtrl.text.trim().isEmpty) {
                          _minutesCtrl.text = '${EquipmentWork.startupMinutes}';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isStartup
                        ? 'Na karcie: „Rozruch kontrolny", paliwo w pozycji 6 '
                            'rozliczenia (zużyto na rozruchy i kontrole).'
                        : 'Praca bez wyjazdu wozu. Praca przy akcji dopisuje '
                            'się sama z ewidencji przejazdów.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  _devicesField(devices.toList()),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text(TimeFormat.date(_date)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _minutesCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minut pracy',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) > 0
                        ? null
                        : 'Podaj liczbę minut',
                  ),
                  const SizedBox(height: 16),
                  PersonField(
                    label: 'Obsługujący',
                    initialName: _operatorName,
                    people: ref.watch(firefightersProvider),
                    helperText: 'Nazwisko i imię obsługującego na karcie',
                    onChanged: (name, id) {
                      _operatorName = name;
                      _operatorId = id;
                    },
                  ),
                  if (!_isStartup) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _purposeCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Cel użycia',
                        hintText: 'np. Ćwiczenia, wypompowanie wody z piwnicy',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (canEdit)
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(_isEdit ? 'Zapisz zmiany' : 'Zapisz'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Przy nowym wpisie — lista do zaznaczenia; przy edycji — jedno
  /// urządzenie, którego nie da się zmienić (wpis należy do jego karty).
  Widget _devicesField(List<Equipment> devices) {
    if (_isEdit) {
      final id = _selected.first;
      final name = devices.where((e) => e.id == id).firstOrNull?.name ??
          _existing!.equipmentName;
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Urządzenie',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.handyman),
        ),
        child: Text(name),
      );
    }
    if (devices.isEmpty) {
      return Text(
        'Na liście sprzętu nie ma urządzeń z własnym silnikiem — dodaje je '
        'administrator w „Sprzęt".',
        style: TextStyle(color: Colors.grey[700]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text('Urządzenia',
                      style: TextStyle(fontSize: 15, color: Colors.grey[800])),
                ),
                TextButton(
                  onPressed: () {
                    _markDirty();
                    setState(() {
                      final all = devices.every((e) => _selected.contains(e.id));
                      _selected.clear();
                      if (!all) _selected.addAll(devices.map((e) => e.id));
                    });
                  },
                  child: Text(devices.every((e) => _selected.contains(e.id))
                      ? 'Odznacz wszystkie'
                      : 'Zaznacz wszystkie'),
                ),
              ],
            ),
          ),
          for (final e in devices)
            CheckboxListTile(
              dense: true,
              value: _selected.contains(e.id),
              title: Text(e.name),
              subtitle: e.model.isEmpty && e.brand.isEmpty
                  ? null
                  : Text([e.brand, e.model]
                      .where((s) => s.isNotEmpty)
                      .join(' ')),
              onChanged: (v) {
                _markDirty();
                setState(() =>
                    v == true ? _selected.add(e.id) : _selected.remove(e.id));
              },
            ),
        ],
      ),
    );
  }
}
