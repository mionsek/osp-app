import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/polish_text.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final String? vehicleId;
  const VehicleFormScreen({super.key, this.vehicleId});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _seats = 6;
  bool get _isEditing => widget.vehicleId != null;

  // Dane z nagłówka miesięcznej karty drogowej. Wszystkie opcjonalne —
  // bez nich karta drukuje puste kratki do wypełnienia długopisem.
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _kindCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _operationalCtrl = TextEditingController();
  final _fuelTypeCtrl = TextEditingController();
  final _fuelPer100Ctrl = TextEditingController();
  final _pumpFuelCtrl = TextEditingController();
  final _idleFuelCtrl = TextEditingController();
  final _startupFuelCtrl = TextEditingController();

  /// Sekcja z danymi do karty jest domyślnie zwinięta — przy zwykłym
  /// dodawaniu pojazdu nikt jej nie potrzebuje, a rozwinięta przytłacza
  /// formularz, w którym normalnie są dwa pola.
  bool _cardDataExpanded = false;

  static String _num(double? v) =>
      v == null ? '' : v.toString().replaceAll('.', ',');

  static double? _parseNum(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final vehicle = db.getVehicle(widget.vehicleId!);
      if (vehicle != null) {
        _nameController.text = vehicle.name;
        _seats = vehicle.seats;
        _makeCtrl.text = vehicle.make;
        _modelCtrl.text = vehicle.model;
        _kindCtrl.text = vehicle.kind;
        _plateCtrl.text = vehicle.plate;
        _operationalCtrl.text = vehicle.operationalNumber;
        _fuelTypeCtrl.text = vehicle.fuelType;
        _fuelPer100Ctrl.text = _num(vehicle.fuelPer100Km);
        _pumpFuelCtrl.text = _num(vehicle.pumpFuelPerHour);
        _idleFuelCtrl.text = _num(vehicle.idleFuelPerMinute);
        _startupFuelCtrl.text = _num(vehicle.startupFuelPerMonth);
        // Skoro pojazd ma już te dane, sekcja startuje rozwinięta —
        // ktoś, kto je wpisał, zwykle wraca tu właśnie po to.
        _cardDataExpanded = vehicle.hasCardData;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _kindCtrl.dispose();
    _plateCtrl.dispose();
    _operationalCtrl.dispose();
    _fuelTypeCtrl.dispose();
    _fuelPer100Ctrl.dispose();
    _pumpFuelCtrl.dispose();
    _idleFuelCtrl.dispose();
    _startupFuelCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();

    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final vehicle = db.getVehicle(widget.vehicleId!);
      if (vehicle != null) {
        vehicle.name = name;
        vehicle.seats = _seats;
        vehicle.make = _makeCtrl.text.trim();
        vehicle.model = _modelCtrl.text.trim();
        vehicle.kind = _kindCtrl.text.trim();
        vehicle.plate = _plateCtrl.text.trim();
        vehicle.operationalNumber = _operationalCtrl.text.trim();
        vehicle.fuelType = _fuelTypeCtrl.text.trim();
        vehicle.fuelPer100Km = _parseNum(_fuelPer100Ctrl.text);
        vehicle.pumpFuelPerHour = _parseNum(_pumpFuelCtrl.text);
        vehicle.idleFuelPerMinute = _parseNum(_idleFuelCtrl.text);
        vehicle.startupFuelPerMonth = _parseNum(_startupFuelCtrl.text);
        await ref.read(vehiclesProvider.notifier).update(vehicle);
      }
    } else {
      final vehicle = Vehicle(
        id: const Uuid().v4(),
        name: name,
        seats: _seats,
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        kind: _kindCtrl.text.trim(),
        plate: _plateCtrl.text.trim(),
        operationalNumber: _operationalCtrl.text.trim(),
        fuelType: _fuelTypeCtrl.text.trim(),
        fuelPer100Km: _parseNum(_fuelPer100Ctrl.text),
        pumpFuelPerHour: _parseNum(_pumpFuelCtrl.text),
        idleFuelPerMinute: _parseNum(_idleFuelCtrl.text),
        startupFuelPerMonth: _parseNum(_startupFuelCtrl.text),
      );
      await ref.read(vehiclesProvider.notifier).add(vehicle);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj pojazd' : 'Nowy pojazd'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nazwa pojazdu',
                  hintText: 'np. Mercedes Axor',
                  prefixIcon: Icon(Icons.fire_truck),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Podaj nazwę pojazdu';
                  }
                  if (value.trim().length < 2) {
                    return 'Nazwa musi mieć min. 2 znaki';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Liczba miejsc',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _seats,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.event_seat),
                ),
                items: List.generate(6, (i) => i + 1)
                    .map((n) => DropdownMenuItem(
                          value: n,
                          child: Text('$n ${PolishText.seats(n)}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _seats = value);
                },
              ),
              const SizedBox(height: 24),
              _cardDataSection(context),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj pojazd'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dane, które trafiają do nagłówka i rozliczenia miesięcznej karty
  /// drogowej. Zwinięte domyślnie — przy zwykłym dodawaniu pojazdu nikt ich
  /// nie potrzebuje, a rozwinięte przytłaczają formularz z dwoma polami.
  Widget _cardDataSection(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _cardDataExpanded,
        leading: const Icon(Icons.description_outlined),
        title: const Text('Dane do karty drogowej'),
        subtitle: const Text(
          'Marka, numer rejestracyjny i normy zużycia paliwa',
          style: TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text(
            'Pola opcjonalne. Puste zostaną na wydruku pustą kratką '
            'do wypełnienia długopisem.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _text(_makeCtrl, 'Marka', 'np. MITSUBISHI')),
            const SizedBox(width: 12),
            Expanded(child: _text(_modelCtrl, 'Typ', 'np. L200')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _text(_kindCtrl, 'Rodzaj', 'np. SLRr')),
            const SizedBox(width: 12),
            Expanded(child: _text(_plateCtrl, 'Nr rej.', 'np. GWE 2998X')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _text(_operationalCtrl, 'Numer operacyjny', '')),
            const SizedBox(width: 12),
            Expanded(child: _text(_fuelTypeCtrl, 'Rodzaj paliwa', 'ON / ET')),
          ]),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Normy zużycia paliwa',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Z nich aplikacja wyliczy rozliczenie na dole karty.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _text(_fuelPer100Ctrl, 'Na 100 km przebiegu (litry)', 'np. 9,5',
              number: true),
          const SizedBox(height: 12),
          _text(_pumpFuelCtrl, 'Autopompa — na godzinę pracy (litry)', '',
              number: true),
          const SizedBox(height: 12),
          _text(_idleFuelCtrl, 'Praca na postoju — na minutę (litry)',
              'np. 0,05',
              number: true),
          const SizedBox(height: 12),
          _text(_startupFuelCtrl, 'Rozruch silnika — na miesiąc (litry)',
              'np. 1',
              number: true),
        ],
      ),
    );
  }

  Widget _text(
    TextEditingController c,
    String label,
    String hint, {
    bool number = false,
  }) {
    return TextFormField(
      controller: c,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      textCapitalization:
          number ? TextCapitalization.none : TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isEmpty ? null : hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

}
