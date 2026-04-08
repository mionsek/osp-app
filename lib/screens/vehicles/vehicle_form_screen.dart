import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
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

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final db = ref.read(databaseServiceProvider);
      final vehicle = db.getVehicle(widget.vehicleId!);
      if (vehicle != null) {
        _nameController.text = vehicle.name;
        _seats = vehicle.seats;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        await ref.read(vehiclesProvider.notifier).update(vehicle);
      }
    } else {
      final vehicle = Vehicle(
        id: const Uuid().v4(),
        name: name,
        seats: _seats,
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
        padding: const EdgeInsets.all(24),
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
                          child: Text('$n ${_seatsLabel(n)}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _seats = value);
                },
              ),
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

  String _seatsLabel(int count) {
    if (count == 1) return 'miejsce';
    if (count >= 2 && count <= 4) return 'miejsca';
    return 'miejsc';
  }
}
