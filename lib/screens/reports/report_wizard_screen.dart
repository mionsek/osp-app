import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'steps/step_basic_info.dart';
import 'steps/step_crew.dart';
import 'steps/step_summary.dart';

class ReportWizardScreen extends ConsumerStatefulWidget {
  final String? reportId;
  const ReportWizardScreen({super.key, this.reportId});

  @override
  ConsumerState<ReportWizardScreen> createState() =>
      _ReportWizardScreenState();
}

class _ReportWizardScreenState extends ConsumerState<ReportWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  static const _totalSteps = 3;

  // Step 1 data
  late String _reportNumber;
  late DateTime _date;
  late TimeOfDay _departureTime;
  TimeOfDay? _returnTime;
  String _addressLocality = '';
  String _addressStreet = '';
  String _addressDescription = '';
  String _threatCategory = '';
  String? _threatSubtype;
  List<String> _selectedVehicleIds = [];

  // Step 2 data
  final Map<String, CrewAssignment> _crewAssignments = {};

  // Step 3 data
  String? _operationCommanderId;
  String _notes = '';

  bool get _isEditing => widget.reportId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = now;
    final h = now.hour - 1;
    _departureTime = TimeOfDay(hour: h < 0 ? 23 : h, minute: now.minute);
    _returnTime = TimeOfDay(hour: now.hour, minute: now.minute);

    if (_isEditing) {
      _loadExistingReport();
    } else {
      _reportNumber =
          ref.read(reportsProvider.notifier).getNextNumber();
      final config = ref.read(unitConfigProvider);
      _addressLocality = config.locality;
    }
  }

  void _loadExistingReport() {
    final db = ref.read(databaseServiceProvider);
    final report = db.getReport(widget.reportId!);
    if (report == null) return;

    _reportNumber = report.reportNumber;
    _date = report.date;
    _departureTime = TimeOfDay.fromDateTime(report.departureTime);
    _returnTime = report.returnTime != null
        ? TimeOfDay.fromDateTime(report.returnTime!)
        : null;
    _addressLocality = report.addressLocality;
    _addressStreet = report.addressStreet;
    _addressDescription = report.addressDescription;
    _threatCategory = report.threatCategory;
    _threatSubtype = report.threatSubtype;
    _selectedVehicleIds =
        report.crewAssignments.map((c) => c.vehicleId).toList();
    for (final crew in report.crewAssignments) {
      _crewAssignments[crew.vehicleId] = crew;
    }
    _operationCommanderId = report.operationCommanderId;
    _notes = report.notes ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentStep < _totalSteps - 1) {
      // Initialize crew assignments for newly selected vehicles
      if (_currentStep == 0) {
        _initializeCrewAssignments();
      }
      // Warn about understaffed crews when leaving step 2
      if (_currentStep == 1) {
        final understaffed = <String>[];
        for (final entry in _crewAssignments.entries) {
          final crew = entry.value;
          final count = crew.allAssignedIds.length;
          if (count < 3) {
            understaffed.add('${crew.vehicleName} ($count os.)');
          }
        }
        if (understaffed.isNotEmpty && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Mała obsada zastępu'),
              content: Text(
                'Następujące zastępy mają mniej niż 3 osoby:\n\n'
                '${understaffed.join('\n')}\n\n'
                'Zastęp powinien liczyć minimum 3 ratowników. Kontynuować mimo to?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Wróć i uzupełnij'),
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
      }
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _initializeCrewAssignments() {
    final vehicles = ref.read(vehiclesProvider);
    // Remove crew for deselected vehicles
    _crewAssignments.removeWhere(
        (key, _) => !_selectedVehicleIds.contains(key));
    // Add empty crew for newly selected vehicles
    for (final id in _selectedVehicleIds) {
      if (!_crewAssignments.containsKey(id)) {
        final vehicle = vehicles.firstWhere((v) => v.id == id);
        _crewAssignments[id] = CrewAssignment(
          vehicleId: id,
          vehicleName: vehicle.name,
        );
      }
    }
  }

  Set<String> _getAllAssignedFirefighterIds({String? excludeVehicleId}) {
    final ids = <String>{};
    for (final entry in _crewAssignments.entries) {
      if (entry.key == excludeVehicleId) continue;
      ids.addAll(entry.value.allAssignedIds);
    }
    return ids;
  }

  Future<void> _saveReport() async {
    // Validate no duplicate firefighter assignments across vehicles
    final allIds = <String>[];
    for (final crew in _crewAssignments.values) {
      allIds.addAll(crew.allAssignedIds);
    }
    final uniqueIds = allIds.toSet();
    if (uniqueIds.length != allIds.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Błąd: ten sam ratownik przypisany do wielu pojazdów'),
            backgroundColor: Color(0xFFB71C1C),
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final departure = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _departureTime.hour,
      _departureTime.minute,
    );
    DateTime? returnDt;
    if (_returnTime != null) {
      returnDt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _returnTime!.hour,
        _returnTime!.minute,
      );
    }

    final report = Report(
      id: _isEditing ? widget.reportId! : const Uuid().v4(),
      reportNumber: _reportNumber,
      year: _date.year,
      date: _date,
      departureTime: departure,
      returnTime: returnDt,
      addressLocality: _addressLocality,
      addressStreet: _addressStreet,
      addressDescription: _addressDescription,
      threatCategory: _threatCategory,
      threatSubtype: _threatSubtype,
      crewAssignments: _crewAssignments.values.toList(),
      operationCommanderId: _operationCommanderId,
      notes: _notes.isNotEmpty ? _notes : null,
      createdAt: _isEditing
          ? ref.read(databaseServiceProvider).getReport(widget.reportId!)?.createdAt ?? now
          : now,
      updatedAt: now,
    );

    if (_isEditing) {
      await ref.read(reportsProvider.notifier).update(report);
    } else {
      await ref.read(reportsProvider.notifier).add(report);
    }

    if (mounted) {
      context.go('/reports/view/${report.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edycja wyjazdu' : 'Nowy wyjazd'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          StepBasicInfo(
            reportNumber: _reportNumber,
            date: _date,
            departureTime: _departureTime,
            returnTime: _returnTime,
            addressLocality: _addressLocality,
            addressStreet: _addressStreet,
            addressDescription: _addressDescription,
            threatCategory: _threatCategory,
            threatSubtype: _threatSubtype,
            selectedVehicleIds: _selectedVehicleIds,
            onChanged: ({
              String? reportNumber,
              DateTime? date,
              TimeOfDay? departureTime,
              TimeOfDay? returnTime,
              bool clearReturnTime = false,
              String? addressLocality,
              String? addressStreet,
              String? addressDescription,
              String? threatCategory,
              String? threatSubtype,
              bool clearThreatSubtype = false,
              List<String>? selectedVehicleIds,
            }) {
              setState(() {
                if (reportNumber != null) _reportNumber = reportNumber;
                if (date != null) _date = date;
                if (departureTime != null) _departureTime = departureTime;
                if (returnTime != null) _returnTime = returnTime;
                if (clearReturnTime) _returnTime = null;
                if (addressLocality != null) {
                  _addressLocality = addressLocality;
                }
                if (addressStreet != null) _addressStreet = addressStreet;
                if (addressDescription != null) {
                  _addressDescription = addressDescription;
                }
                if (threatCategory != null) _threatCategory = threatCategory;
                if (threatSubtype != null) _threatSubtype = threatSubtype;
                if (clearThreatSubtype) _threatSubtype = null;
                if (selectedVehicleIds != null) {
                  _selectedVehicleIds = selectedVehicleIds;
                }
              });
            },
            onNext: _nextPage,
          ),
          StepCrew(
            crewAssignments: _crewAssignments,
            selectedVehicleIds: _selectedVehicleIds,
            getAllAssignedIds: _getAllAssignedFirefighterIds,
            onChanged: () => setState(() {}),
            onNext: _nextPage,
            onBack: _prevPage,
          ),
          StepSummary(
            reportNumber: _reportNumber,
            date: _date,
            departureTime: _departureTime,
            returnTime: _returnTime,
            addressLocality: _addressLocality,
            addressStreet: _addressStreet,
            addressDescription: _addressDescription,
            threatCategory: _threatCategory,
            threatSubtype: _threatSubtype,
            crewAssignments: _crewAssignments,
            operationCommanderId: _operationCommanderId,
            notes: _notes,
            onOperationCommanderChanged: (id) =>
                setState(() => _operationCommanderId = id),
            onNotesChanged: (value) => setState(() => _notes = value),
            onSave: _saveReport,
            onBack: _prevPage,
          ),
        ],
      ),
    );
  }
}
