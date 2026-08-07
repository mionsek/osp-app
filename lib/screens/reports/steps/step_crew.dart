import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/firefighter_search.dart';
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
      // Zapas na systemowy pasek nawigacji telefonu.
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
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

          // Crew validation warnings
          ..._buildCrewWarnings(crew),

          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentVehicleIndex > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _currentVehicleIndex--),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Poprzedni pojazd'),
                  ),
                ),
              if (_currentVehicleIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onAdvance(crew),
                  icon: Icon(_currentVehicleIndex <
                          widget.selectedVehicleIds.length - 1
                      ? Icons.arrow_forward
                      : Icons.check),
                  label: Text(_currentVehicleIndex <
                          widget.selectedVehicleIds.length - 1
                      ? 'Następny pojazd'
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

  List<String> _getCrewWarnings(CrewAssignment crew) {
    final warnings = <String>[];
    final total = crew.allAssignedIds.length;
    if (crew.driverId == null || crew.driverId!.isEmpty) {
      warnings.add('Brak kierowcy');
    }
    if (crew.commanderId == null || crew.commanderId!.isEmpty) {
      warnings.add('Brak dowódcy');
    }
    if (total < 3) {
      warnings.add('Minimalna obsada to 3 osoby (jest $total)');
    }
    return warnings;
  }

  Future<void> _onAdvance(CrewAssignment crew) async {
    final warnings = _getCrewWarnings(crew);
    if (warnings.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Uwaga — niepełny skład'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings
                .map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(w)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Popraw'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kontynuuj mimo to'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (_currentVehicleIndex < widget.selectedVehicleIds.length - 1) {
      setState(() => _currentVehicleIndex++);
    } else {
      widget.onNext();
    }
  }

  List<Widget> _buildCrewWarnings(CrewAssignment crew) {
    final warnings = _getCrewWarnings(crew);

    if (warnings.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                warnings.join(' · '),
                style: TextStyle(color: Colors.orange[900], fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String? _autoCreateFirefighterFromText(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    // Pole prosi o „Nazwisko Imię", więc tak też rozbijamy wpisany tekst.
    // Nazwiska dwuczłonowe („Nowak-Kowalska Anna") nadal działają, bo
    // imieniem jest tylko ostatni wyraz.
    final lastName = parts.sublist(0, parts.length - 1).join(' ');
    final firstName = parts.last;
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
              // Nazwisko przed imieniem — tak samo, jak wszędzie indziej
              // w aplikacji i jak zgłaszamy skład telefonicznie.
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Nazwisko'),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Imię'),
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

    // Dopasowanie po pełnej nazwie — akceptujemy obie kolejności, bo
    // ktoś przyzwyczajony może nadal wpisać „Imię Nazwisko".
    final lower = text.toLowerCase();
    final match = widget.firefighters.where(
      (f) =>
          f.lastNameFirst.toLowerCase() == lower ||
          f.fullName.toLowerCase() == lower,
    ).firstOrNull;

    if (match != null) {
      widget.onChanged(match.id);
      // Ta sama informacja, co przy wyborze z listy — nazwisko wpisane
      // z ręki nie powinno omijać ostrzeżenia o braku uprawnień.
      _warnIfMissingQualification(match);
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
              displayStringForOption: (ff) => ff.lastNameFirst,
              optionsBuilder: (textEditingValue) {
                // Pomijamy osoby już przypisane — w tym wyjeździe lub
                // do innego pojazdu.
                final available = widget.firefighters.where((ff) =>
                    !widget.assignedElsewhere.contains(ff.id) &&
                    !widget.assignedInThisVehicle.contains(ff.id));
                return FirefighterSearch.filter(
                    available, textEditingValue.text);
              },
              onSelected: (ff) {
                widget.onChanged(ff.id);
                setState(() {});
                _warnIfMissingQualification(ff);
              },
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                _attachFocusListener(textController, focusNode);
                if (selectedFF != null &&
                    textController.text != selectedFF.lastNameFirst) {
                  textController.text = selectedFF.lastNameFirst;
                }
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  // Z tego pola powstaje też nowy ratownik, więc wielka
                  // litera w każdym członie nazwiska i imienia.
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Wpisz nazwisko i imię...',
                    helperText: 'np. Kowalski Jan — ratownik zostanie utworzony automatycznie',
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
                          // Nazwisko wytłuszczone, a pod nim wyłącznie to,
                          // co dotyczy tego miejsca i wyłącznie wtedy, gdy
                          // dana osoba to ma. Wypisywanie przy każdym
                          // nazwisku również braków („✗ brak uprawnień")
                          // zabierało miejsce i zlewało się z nazwiskiem.
                          final hint = _seatHint(ff);
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              ff.lastNameFirst,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: hint == null
                                ? null
                                : Text(
                                    hint,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                    ),
                                  ),
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

  /// Uprawnienie wymagane na tym miejscu w zastępie.
  /// Miejsce 1 to kierowca, miejsce 2 dowódca, pozostałe — ratownicy z KPP.
  bool _hasSeatQualification(Firefighter ff) {
    if (widget.seatNumber == 1) return ff.isDriver;
    if (widget.seatNumber == 2) return ff.isCommander;
    return ff.isKPP;
  }

  String get _seatQualificationName {
    if (widget.seatNumber == 1) return 'Kierowca';
    if (widget.seatNumber == 2) return 'Dowódca';
    return 'KPP';
  }

  /// Podpowiedź pod nazwiskiem na liście wyboru — **tylko to, co dana
  /// osoba ma**, i tylko w zakresie istotnym dla tego miejsca.
  /// `null` oznacza brak podpowiedzi, czyli sam wiersz z nazwiskiem.
  String? _seatHint(Firefighter ff) {
    final parts = <String>[
      if (_hasSeatQualification(ff)) '✓ $_seatQualificationName',
      if (ff.hasMedicalExam && !ff.isMedicalExamExpired) '✓ Badania',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Ostrzeżenie po wybraniu osoby bez wymaganego uprawnienia —
  /// **bez blokowania wyboru**. Ktoś mógł zrobić kurs, którego nie ma
  /// jeszcze w aplikacji, a w akcji nie ma czasu na kartoteki.
  void _warnIfMissingQualification(Firefighter ff) {
    if (_hasSeatQualification(ff)) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: Colors.orange[800],
      duration: const Duration(seconds: 4),
      content: Text(
        '${ff.lastNameFirst} nie ma w aplikacji uprawnień '
        '„$_seatQualificationName". Możesz kontynuować — jeśli je posiada, '
        'uzupełnij dane w kartotece ratownika.',
      ),
    ));
  }

  List<Widget> _buildQualificationBadges(Firefighter ff) {
    final badges = <Widget>[];
    final isDriverSeat = widget.seatNumber == 1;
    final isCommanderSeat = widget.seatNumber == 2;

    if (isDriverSeat && ff.isDriver) {
      badges.add(_qualificationChip('✓ Uprawnienia kierowcy', Colors.green));
    } else if (isDriverSeat && !ff.isDriver) {
      badges.add(_qualificationChip('✗ Brak uprawnień kierowcy', Colors.orange));
    }

    if (isCommanderSeat && ff.isCommander) {
      badges.add(_qualificationChip('✓ Uprawnienia dowódcy', Colors.green));
    } else if (isCommanderSeat && !ff.isCommander) {
      badges.add(_qualificationChip('✗ Brak uprawnień dowódcy', Colors.orange));
    }

    if (!isDriverSeat && !isCommanderSeat && ff.isKPP) {
      badges.add(_qualificationChip('✓ KPP', Colors.blue));
    }

    if (ff.isMedicalExamExpired) {
      badges.add(_qualificationChip('[X] Brak ważnych badań lekarskich', const Color(0xFFB71C1C)));
    } else if (!ff.hasMedicalExam) {
      badges.add(_qualificationChip('[X] Brak daty badań lekarskich', Colors.grey));
    } else if (ff.isMedicalExamExpiringSoon) {
      final daysUntilExpiry = ff.medicalExamExpiry!
          .difference(DateTime.now())
          .inDays;
      badges.add(_qualificationChip('! Badania wygasną w ciągu $daysUntilExpiry dni', Colors.orange));
    } else {
      badges.add(_qualificationChip('✓ Ważne badania lekarskie', Colors.green));
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

}
