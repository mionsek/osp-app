import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class StepCrew extends ConsumerStatefulWidget {
  final Map<String, CrewAssignment> crewAssignments;
  final List<String> selectedVehicleIds;
  final Set<String> Function({String? excludeVehicleId}) getAllAssignedIds;
  final VoidCallback onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepCrew({
    super.key,
    required this.crewAssignments,
    required this.selectedVehicleIds,
    required this.getAllAssignedIds,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<StepCrew> createState() => _StepCrewState();
}

class _StepCrewState extends ConsumerState<StepCrew>
    with AutomaticKeepAliveClientMixin {
  int _currentVehicleIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final vehicles = ref.watch(vehiclesProvider);
    final firefighters = ref.watch(firefightersProvider);

    if (widget.selectedVehicleIds.isEmpty) {
      return const Center(child: Text('Brak wybranych pojazdów'));
    }

    final vehicleId = widget.selectedVehicleIds[_currentVehicleIndex];
    final vehicle = vehicles.firstWhere((v) => v.id == vehicleId,
        orElse: () => Vehicle(id: '', name: '?', seats: 0));
    final crew = widget.crewAssignments[vehicleId]!;

    // IDs assigned to OTHER vehicles
    final assignedElsewhere =
        widget.getAllAssignedIds(excludeVehicleId: vehicleId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Krok 2 z 3 — Zastępy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pojazd ${_currentVehicleIndex + 1} z ${widget.selectedVehicleIds.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),

          // Vehicle header
          Card(
            color: const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.fire_truck,
                      color: Color(0xFFE65100), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    vehicle.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Seat 1 — Driver
          _SeatSelector(
            seatNumber: 1,
            role: '🚗 Kierowca',
            selectedId: crew.driverId,
            firefighters: firefighters,
            assignedElsewhere: assignedElsewhere,
            assignedInThisVehicle: _getAssignedInVehicle(crew, excludeField: 'driver'),
            onChanged: (id) {
              crew.driverId = id;
              widget.onChanged();
            },
            onAddNew: () => _showAddFirefighterDialog(context, ref),
            onAutoCreateFromText: _autoCreateFirefighterFromText,
          ),
          const SizedBox(height: 12),

          // Seat 2 — Commander
          _SeatSelector(
            seatNumber: 2,
            role: '🎖️ Dowódca',
            selectedId: crew.commanderId,
            firefighters: firefighters,
            assignedElsewhere: assignedElsewhere,
            assignedInThisVehicle: _getAssignedInVehicle(crew, excludeField: 'commander'),
            onChanged: (id) {
              crew.commanderId = id;
              widget.onChanged();
            },
            onAddNew: () => _showAddFirefighterDialog(context, ref),
            onAutoCreateFromText: _autoCreateFirefighterFromText,
          ),
          const SizedBox(height: 12),

          // Remaining seats
          ...List.generate(vehicle.seats - 2, (i) {
            final crewIndex = i;
            final selectedId = crewIndex < crew.crewMemberIds.length
                ? crew.crewMemberIds[crewIndex]
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SeatSelector(
                seatNumber: i + 3,
                role: 'Ratownik',
                selectedId: selectedId,
                firefighters: firefighters,
                assignedElsewhere: assignedElsewhere,
                assignedInThisVehicle: _getAssignedInVehicle(crew, excludeCrewIndex: crewIndex),
                onChanged: (id) {
                  // Ensure list is long enough
                  while (crew.crewMemberIds.length <= crewIndex) {
                    crew.crewMemberIds.add('');
                  }
                  crew.crewMemberIds[crewIndex] = id ?? '';
                  // Remove trailing empty entries
                  while (crew.crewMemberIds.isNotEmpty &&
                      crew.crewMemberIds.last.isEmpty) {
                    crew.crewMemberIds.removeLast();
                  }
                  widget.onChanged();
                },
                onAddNew: () => _showAddFirefighterDialog(context, ref),
                onAutoCreateFromText: _autoCreateFirefighterFromText,
              ),
            );
          }),

          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentVehicleIndex > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _currentVehicleIndex--),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Poprzedni wóz'),
                  ),
                ),
              if (_currentVehicleIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_currentVehicleIndex <
                        widget.selectedVehicleIds.length - 1) {
                      setState(() => _currentVehicleIndex++);
                    } else {
                      widget.onNext();
                    }
                  },
                  icon: Icon(_currentVehicleIndex <
                          widget.selectedVehicleIds.length - 1
                      ? Icons.arrow_forward
                      : Icons.check),
                  label: Text(_currentVehicleIndex <
                          widget.selectedVehicleIds.length - 1
                      ? 'Następny wóz'
                      : 'Podsumowanie'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Wróć do danych podstawowych'),
          ),
        ],
      ),
    );
  }

  Set<String> _getAssignedInVehicle(CrewAssignment crew,
      {String? excludeField, int? excludeCrewIndex}) {
    final ids = <String>{};
    if (excludeField != 'driver' && crew.driverId != null && crew.driverId!.isNotEmpty) {
      ids.add(crew.driverId!);
    }
    if (excludeField != 'commander' && crew.commanderId != null && crew.commanderId!.isNotEmpty) {
      ids.add(crew.commanderId!);
    }
    for (var i = 0; i < crew.crewMemberIds.length; i++) {
      if (i != excludeCrewIndex && crew.crewMemberIds[i].isNotEmpty) {
        ids.add(crew.crewMemberIds[i]);
      }
    }
    return ids;
  }

  String? _autoCreateFirefighterFromText(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final firstName = parts.first;
    final lastName = parts.sublist(1).join(' ');
    if (firstName.length < 2 || lastName.length < 2) return null;
    final ff = Firefighter(
      id: const Uuid().v4(),
      firstName: firstName,
      lastName: lastName,
      rank: '',
    );
    ref.read(firefightersProvider.notifier).add(ff);
    return ff.id;
  }

  void _showAddFirefighterDialog(BuildContext context, WidgetRef ref) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Dodaj ratownika'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Imię'),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Nazwisko'),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                final fn = firstNameController.text.trim();
                final ln = lastNameController.text.trim();
                if (fn.length >= 2 && ln.length >= 2) {
                  final ff = Firefighter(
                    id: const Uuid().v4(),
                    firstName: fn,
                    lastName: ln,
                    rank: '',
                  );
                  ref.read(firefightersProvider.notifier).add(ff);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Dodaj i zapamiętaj'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatSelector extends StatefulWidget {
  final int seatNumber;
  final String role;
  final String? selectedId;
  final List<Firefighter> firefighters;
  final Set<String> assignedElsewhere;
  final Set<String> assignedInThisVehicle;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAddNew;
  final String? Function(String text) onAutoCreateFromText;

  const _SeatSelector({
    required this.seatNumber,
    required this.role,
    this.selectedId,
    required this.firefighters,
    required this.assignedElsewhere,
    required this.assignedInThisVehicle,
    required this.onChanged,
    required this.onAddNew,
    required this.onAutoCreateFromText,
  });

  @override
  State<_SeatSelector> createState() => _SeatSelectorState();
}

class _SeatSelectorState extends State<_SeatSelector> {
  final _searchController = TextEditingController();
  FocusNode? _autoFocusNode;
  TextEditingController? _autoTextController;

  void _attachFocusListener(TextEditingController tc, FocusNode fn) {
    if (_autoFocusNode != fn) {
      _autoFocusNode?.removeListener(_onFocusChange);
      _autoFocusNode = fn;
      _autoTextController = tc;
      fn.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (_autoFocusNode?.hasFocus == false) {
      _tryAutoResolve();
    }
  }

  void _tryAutoResolve() {
    final text = _autoTextController?.text.trim() ?? '';
    if (text.isEmpty) return;
    if (widget.selectedId != null && widget.selectedId!.isNotEmpty) return;

    // Try exact match by full name
    final match = widget.firefighters.where(
      (f) => f.fullName.toLowerCase() == text.toLowerCase(),
    ).firstOrNull;

    if (match != null) {
      widget.onChanged(match.id);
      return;
    }

    // Auto-create if text looks like a name (has a space)
    if (text.contains(' ')) {
      final id = widget.onAutoCreateFromText(text);
      if (id != null) {
        widget.onChanged(id);
      }
    }
  }

  @override
  void dispose() {
    _autoFocusNode?.removeListener(_onFocusChange);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFF = widget.selectedId != null && widget.selectedId!.isNotEmpty
        ? widget.firefighters
            .where((f) => f.id == widget.selectedId)
            .firstOrNull
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: selectedFF != null
                      ? const Color(0xFF2E7D32)
                      : Colors.grey[300],
                  child: Text(
                    '${widget.seatNumber}',
                    style: TextStyle(
                      color: selectedFF != null ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.role,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (selectedFF != null) ..._buildQualificationBadges(selectedFF),
                    ],
                  ),
                ),
                if (selectedFF != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => widget.onChanged(null),
                    tooltip: 'Usuń przypisanie',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Autocomplete<Firefighter>(
              displayStringForOption: (ff) => ff.fullName,
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                return widget.firefighters.where((ff) {
                  final isAssignedElsewhere =
                      widget.assignedElsewhere.contains(ff.id);
                  final isAssignedInVehicle =
                      widget.assignedInThisVehicle.contains(ff.id);
                  if (isAssignedElsewhere || isAssignedInVehicle) return false;
                  if (query.isEmpty) return true;
                  return ff.fullName.toLowerCase().contains(query);
                });
              },
              onSelected: (ff) {
                widget.onChanged(ff.id);
                setState(() {});
              },
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                _attachFocusListener(textController, focusNode);
                if (selectedFF != null &&
                    textController.text != selectedFF.fullName) {
                  textController.text = selectedFF.fullName;
                }
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Wpisz imię i nazwisko...',
                    helperText: 'np. Jan Kowalski — ratownik zostanie utworzony automatycznie',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: widget.onAddNew,
                      tooltip: 'Dodaj nowego ratownika',
                    ),
                    isDense: true,
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final ff = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(ff.fullName),
                            subtitle: _buildQualificationText(ff) != null
                                ? Text(_buildQualificationText(ff)!,
                                    style: const TextStyle(fontSize: 12))
                                : null,
                            onTap: () => onSelected(ff),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQualificationBadges(Firefighter ff) {
    final badges = <Widget>[];
    final isDriverSeat = widget.seatNumber == 1;
    final isCommanderSeat = widget.seatNumber == 2;

    if (isDriverSeat && ff.isDriver) {
      badges.add(_qualificationChip('✓ Kierowca', Colors.green));
    } else if (isDriverSeat && !ff.isDriver) {
      badges.add(_qualificationChip('✗ Brak upr. kierowcy', Colors.orange));
    }

    if (isCommanderSeat && ff.isCommander) {
      badges.add(_qualificationChip('✓ Dowódca', Colors.green));
    } else if (isCommanderSeat && !ff.isCommander) {
      badges.add(_qualificationChip('✗ Brak upr. dowódcy', Colors.orange));
    }

    if (ff.isKPP) {
      badges.add(_qualificationChip('KPP', Colors.blue));
    }

    return badges;
  }

  Widget _qualificationChip(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? _buildQualificationText(Firefighter ff) {
    final quals = <String>[];
    if (ff.isDriver) quals.add('Kierowca');
    if (ff.isCommander) quals.add('Dowódca');
    if (ff.isKPP) quals.add('KPP');
    return quals.isEmpty ? null : quals.join(' · ');
  }
}
