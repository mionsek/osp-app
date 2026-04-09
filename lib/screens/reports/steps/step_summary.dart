import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class StepSummary extends ConsumerWidget {
  final String reportNumber;
  final DateTime date;
  final TimeOfDay departureTime;
  final TimeOfDay? returnTime;
  final String addressLocality;
  final String addressStreet;
  final String addressDescription;
  final String threatCategory;
  final String? threatSubtype;
  final Map<String, CrewAssignment> crewAssignments;
  final String? operationCommanderId;
  final String notes;
  final ValueChanged<String?> onOperationCommanderChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;

  const StepSummary({
    super.key,
    required this.reportNumber,
    required this.date,
    required this.departureTime,
    this.returnTime,
    required this.addressLocality,
    required this.addressStreet,
    this.addressDescription = '',
    required this.threatCategory,
    this.threatSubtype,
    required this.crewAssignments,
    this.operationCommanderId,
    required this.notes,
    required this.onOperationCommanderChanged,
    required this.onNotesChanged,
    required this.onSave,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firefighters = ref.watch(firefightersProvider);

    // Collect all assigned firefighters for commander dropdown
    final allAssignedIds = <String>{};
    for (final crew in crewAssignments.values) {
      allAssignedIds.addAll(crew.allAssignedIds);
    }
    final assignedFirefighters =
        firefighters.where((f) => allAssignedIds.contains(f.id)).toList();

    final totalFirefighters = allAssignedIds.length;

    String formatTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    Firefighter? findFF(String? id) {
      if (id == null || id.isEmpty) return null;
      return firefighters.where((f) => f.id == id).firstOrNull;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Krok 3 z 3 — Podsumowanie',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),

          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow('Nr ewidencyjny', reportNumber),
                  _SummaryRow(
                      'Data', DateFormat('dd.MM.yyyy').format(date)),
                  _SummaryRow(
                    'Godziny',
                    '${formatTime(departureTime)} – ${returnTime != null ? formatTime(returnTime!) : "—"}',
                  ),
                  _SummaryRow(
                    'Adres',
                    [addressLocality, addressStreet]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                  ),
                  if (addressDescription.isNotEmpty)
                    _SummaryRow('Opis miejsca', addressDescription),
                  _SummaryRow(
                    'Zagrożenie',
                    [threatCategory, threatSubtype]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' → '),
                  ),
                  _SummaryRow(
                      'Liczba pojazdów', '${crewAssignments.length}'),
                  _SummaryRow(
                      'Liczba ratowników', '$totalFirefighters'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Crew details per vehicle
          ...crewAssignments.values.map((crew) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fire_truck,
                              color: Color(0xFFE65100)),
                          const SizedBox(width: 8),
                          Text(
                            crew.vehicleName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (crew.driverId != null)
                        _CrewMemberRow(
                            '🚗 Kierowca', findFF(crew.driverId)),
                      if (crew.commanderId != null)
                        _CrewMemberRow(
                            '🎖️ Dowódca', findFF(crew.commanderId)),
                      ...crew.crewMemberIds
                          .where((id) => id.isNotEmpty)
                          .map((id) =>
                              _CrewMemberRow('     Ratownik', findFF(id))),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 16),

          // Operation commander
          Text('Kierujący działaniem ratowniczym',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: operationCommanderId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.military_tech),
              hintText: 'Wybierz KDR',
            ),
            items: assignedFirefighters
                .map((ff) => DropdownMenuItem(
                      value: ff.id,
                      child: Text(ff.fullName),
                    ))
                .toList(),
            onChanged: onOperationCommanderChanged,
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            decoration: const InputDecoration(
              labelText: 'Uwagi',
              prefixIcon: Icon(Icons.note),
              hintText: 'Dodatkowe informacje...',
            ),
            maxLines: 3,
            maxLength: 500,
            controller: TextEditingController(text: notes),
            onChanged: onNotesChanged,
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save),
            label: const Text('Zapisz raport'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Wróć do zastępów'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CrewMemberRow extends StatelessWidget {
  final String role;
  final Firefighter? firefighter;
  const _CrewMemberRow(this.role, this.firefighter);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(role)),
          Expanded(
            child: Text(
              firefighter?.fullName ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
