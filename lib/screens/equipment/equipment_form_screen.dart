import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/bottom_inset.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/navigation.dart';

/// Dodawanie i edycja sprzętu.
///
/// Przypisany wóz, normy i dane identyfikacyjne są opcjonalne — sprzęt nie
/// musi jeździć na stałe na jednym wozie, a kartę pracy można uzupełnić
/// długopisem.
class EquipmentFormScreen extends ConsumerStatefulWidget {
  final String? equipmentId;
  const EquipmentFormScreen({super.key, this.equipmentId});

  @override
  ConsumerState<EquipmentFormScreen> createState() =>
      _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Wpisano coś, czego jeszcze nie zapisano — wyjście pyta o zgodę.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  final _nameCtrl = TextEditingController();
  final _normCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  String? _vehicleId;
  bool _poweredByVehicle = false;
  String _fuelType = '';

  bool get _isEditing => widget.equipmentId != null;

  static String _num(double? v) =>
      v == null ? '' : v.toString().replaceAll('.', ',');

  static double? _parseNum(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    if (!_isEditing) return;
    final e = ref.read(databaseServiceProvider).getEquipment(widget.equipmentId!);
    if (e == null) return;
    _nameCtrl.text = e.name;
    _normCtrl.text = _num(e.fuelPerHour);
    _brandCtrl.text = e.brand;
    _modelCtrl.text = e.model;
    _serialCtrl.text = e.serialNumber;
    _vehicleId = e.vehicleId;
    _poweredByVehicle = e.poweredByVehicle;
    _fuelType = e.fuelType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _normCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(equipmentProvider.notifier);
    // Sprzęt zasilany z wozu liczy się normą autopompy wozu — własne paliwo
    // i norma nie mają wtedy znaczenia.
    final ownEngine = !_poweredByVehicle;

    final existing = _isEditing
        ? ref.read(databaseServiceProvider).getEquipment(widget.equipmentId!)
        : null;
    final e = existing ?? Equipment(id: const Uuid().v4(), name: '');
    e
      ..name = _nameCtrl.text.trim()
      ..vehicleId = _vehicleId
      ..poweredByVehicle = _poweredByVehicle
      ..fuelType = ownEngine ? _fuelType : ''
      ..fuelPerHour = ownEngine ? _parseNum(_normCtrl.text) : null
      ..brand = _brandCtrl.text.trim()
      ..model = _modelCtrl.text.trim()
      ..serialNumber = _serialCtrl.text.trim();
    if (existing == null) {
      await notifier.add(e);
    } else {
      await notifier.update(e);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    // Wóz usunięty po przypisaniu — sprzęt wraca do „bez przypisanego wozu".
    final vehicleId =
        vehicles.any((v) => v.id == _vehicleId) ? _vehicleId : null;

    return LeaveGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edytuj sprzęt' : 'Nowy sprzęt'),
          actions: [HomeButton(confirmLeave: _dirty)],
        ),
        body: SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(24, 24, 24, 24 + context.bottomInset()),
          child: Form(
            key: _formKey,
            onChanged: _markDirty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa',
                    hintText: 'np. Agregat prądotwórczy, Pilarka',
                    prefixIcon: Icon(Icons.handyman),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 60,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Podaj nazwę sprzętu';
                    }
                    if (v.trim().length < 2) {
                      return 'Nazwa musi mieć min. 2 znaki';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: vehicleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Wóz',
                    prefixIcon: Icon(Icons.fire_truck),
                    helperText: 'Na jakim wozie jeździ na stałe — '
                        'przy jego przejazdach będzie na górze listy',
                    helperMaxLines: 2,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Bez przypisanego wozu'),
                    ),
                    for (final v in vehicles)
                      DropdownMenuItem<String?>(
                        value: v.id,
                        child: Text(v.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _poweredByVehicle,
                  title: const Text('Napędzany silnikiem wozu'),
                  subtitle: const Text(
                    'Autopompa, wyciągarka — paliwo z baku wozu, minuty na '
                    'karcie drogowej. Sprzęt z własnym silnikiem (agregat, '
                    'pilarka) ma osobną kartę pracy.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  onChanged: (v) {
                    _markDirty();
                    setState(() => _poweredByVehicle = v);
                  },
                ),
                if (!_poweredByVehicle) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _fuelType,
                    decoration: const InputDecoration(
                      labelText: 'Rodzaj paliwa',
                      prefixIcon: Icon(Icons.local_gas_station),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('—')),
                      for (final f in EquipmentFuel.all)
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: (v) => setState(() => _fuelType = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _normCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Norma zużycia paliwa (litry na godzinę)',
                      hintText: 'np. 1,2',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final n = _parseNum(text);
                      if (n == null || n <= 0) return 'Wpisz liczbę, np. 1,2';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Marka i typ osobno — tak jak w nagłówku karty pracy.
                TextFormField(
                  controller: _brandCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Marka (opcjonalnie)',
                    hintText: 'np. Stihl, Niagara',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Typ (opcjonalnie)',
                    hintText: 'np. MS 462',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serialCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nr fabryczny / inwentarzowy (opcjonalnie)',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _onSave,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj sprzęt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
