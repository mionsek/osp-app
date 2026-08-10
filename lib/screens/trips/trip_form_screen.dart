import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// Dodawanie i edycja jednego przejazdu — jednego wiersza karty drogowej.
///
/// Sedno ekranu to licznik. Kierowca wpisuje **jedną liczbę**: stan po
/// powrocie do jednostki. Stan przed wyjazdem aplikacja podstawia z poprzedniego
/// przejazdu tego pojazdu i pokazuje jako zablokowany — do odblokowania
/// kłódką, gdy ktoś pojechał i nie odnotował.
class TripFormScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final String? initialVehicleId;

  const TripFormScreen({super.key, this.tripId, this.initialVehicleId});

  bool get isEdit => tripId != null;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _vehicleId;
  late DateTime _date;
  TimeOfDay? _departure;
  TimeOfDay? _return;
  String _purpose = TripPurposes.economic;

  final _dispatcherCtrl = TextEditingController();
  final _routeFromCtrl = TextEditingController();
  final _routeToCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _odometerEndCtrl = TextEditingController();
  final _odometerStartCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _driverId;

  /// Czy stan przed wyjazdem jest wpisywany ręcznie zamiast z łańcucha.
  bool _manualStart = false;

  VehicleTrip? _existing;
  bool _loaded = false;

  @override
  void dispose() {
    _dispatcherCtrl.dispose();
    _routeFromCtrl.dispose();
    _routeToCtrl.dispose();
    _driverCtrl.dispose();
    _odometerEndCtrl.dispose();
    _odometerStartCtrl.dispose();
    _equipmentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _loadOnce() {
    if (_loaded) return;
    _loaded = true;

    final db = ref.read(databaseServiceProvider);
    final vehicles = ref.read(vehiclesProvider);

    if (widget.isEdit) {
      final trip = db.getTrip(widget.tripId!);
      if (trip != null) {
        _existing = trip;
        _vehicleId = trip.vehicleId;
        _date = trip.date;
        _departure = TimeOfDay.fromDateTime(trip.departureTime);
        _return = trip.returnTime == null
            ? null
            : TimeOfDay.fromDateTime(trip.returnTime!);
        _purpose = trip.purpose;
        _dispatcherCtrl.text = trip.dispatcherName;
        _routeFromCtrl.text = trip.routeFrom;
        _routeToCtrl.text = trip.routeTo;
        _driverCtrl.text = trip.driverName;
        _driverId = trip.driverId;
        _manualStart = trip.odometerStartManual;
        _odometerStartCtrl.text = trip.odometerStart?.toString() ?? '';
        _odometerEndCtrl.text = trip.odometerEnd?.toString() ?? '';
        _equipmentCtrl.text = trip.specialEquipmentMinutes?.toString() ?? '';
        _notesCtrl.text = trip.notes ?? '';
        return;
      }
    }

    // Nowy przejazd
    _vehicleId = widget.initialVehicleId ??
        (vehicles.isNotEmpty ? vehicles.first.id : '');
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _departure = TimeOfDay.fromDateTime(now);

    // Trasa prawie zawsze zaczyna się w remizie.
    _routeFromCtrl.text = ref.read(unitConfigProvider).locality;
  }

  /// Stan licznika przed wyjazdem podstawiony z poprzedniego przejazdu.
  int? get _chainedStart {
    if (_vehicleId.isEmpty) return null;
    return ref.read(databaseServiceProvider).suggestedOdometerStart(
          vehicleId: _vehicleId,
          departureTime: _departureDateTime,
          excludeTripId: widget.tripId,
        );
  }

  DateTime get _departureDateTime {
    final t = _departure ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);
  }

  DateTime? get _returnDateTime {
    final t = _return;
    if (t == null) return null;
    var dt = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);
    // Powrót nad ranem po nocnym wyjeździe należy do następnego dnia.
    if (dt.isBefore(_departureDateTime)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  @override
  Widget build(BuildContext context) {
    _loadOnce();

    final vehicles = ref.watch(vehiclesProvider);
    final syncState = ref.watch(syncStateProvider);
    final canEdit =
        !widget.isEdit || syncState.canEditDocument(_existing?.createdBy);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edytuj przejazd' : 'Nowy przejazd'),
        actions: [
          if (widget.isEdit && canEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Usuń',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            if (!canEdit) _readOnlyNotice(syncState.founderEmail),
            AbsorbPointer(
              absorbing: !canEdit,
              child: Opacity(
                opacity: canEdit ? 1 : 0.6,
                child: Column(
                  children: [
                    _vehicleField(vehicles),
                    const SizedBox(height: 14),
                    _dateAndTimes(),
                    const SizedBox(height: 20),
                    _odometerSection(),
                    const SizedBox(height: 20),
                    _purposeField(),
                    const SizedBox(height: 14),
                    _routeFields(),
                    const SizedBox(height: 14),
                    _driverField(),
                    const SizedBox(height: 14),
                    _dispatcherField(),
                    const SizedBox(height: 14),
                    _equipmentField(),
                    const SizedBox(height: 14),
                    _notesField(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (canEdit)
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(widget.isEdit ? 'Zapisz zmiany' : 'Dodaj przejazd'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyNotice(String? adminEmail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ten przejazd dodał ktoś inny. Zmienić go może autor wpisu '
              'lub administrator jednostki'
              '${adminEmail != null && adminEmail.isNotEmpty ? ' ($adminEmail)' : ''}.',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleField(List<Vehicle> vehicles) {
    return DropdownButtonFormField<String>(
      initialValue: _vehicleId.isEmpty ? null : _vehicleId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Pojazd',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.fire_truck),
      ),
      items: vehicles
          .map((v) => DropdownMenuItem(
                value: v.id,
                child: Text(v.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Wybierz pojazd' : null,
      // Zmiana pojazdu zmienia łańcuch licznika, więc podpowiedź trzeba
      // przeliczyć od nowa.
      onChanged: (v) => setState(() => _vehicleId = v ?? ''),
    );
  }

  Widget _dateAndTimes() {
    return Column(
      children: [
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Data',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              '${_date.day.toString().padLeft(2, '0')}.'
              '${_date.month.toString().padLeft(2, '0')}.${_date.year}',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(isDeparture: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Odjazd',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(_departure?.format(context) ?? '—'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(isDeparture: false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Przyjazd',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    helperText: _return == null ? 'jeszcze nie wrócił' : null,
                  ),
                  child: Text(_return?.format(context) ?? '—'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Licznik — jedyne miejsce, gdzie ten ekran różni się od zwykłego formularza.
  Widget _odometerSection() {
    final chained = _chainedStart;
    final isFirstEver = chained == null && !_manualStart;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 19, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              Text('Stan licznika',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          // Stan przed wyjazdem: normalnie z łańcucha i zablokowany.
          if (!_manualStart && chained != null)
            _chainedStartRow(chained)
          else
            TextFormField(
              controller: _odometerStartCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Przed wyjazdem (km)',
                border: const OutlineInputBorder(),
                isDense: true,
                helperText: isFirstEver
                    ? 'Pierwszy przejazd tego pojazdu — wpisz stan początkowy'
                    : 'Wpisany ręcznie',
                helperMaxLines: 2,
                suffixIcon: _manualStart && chained != null
                    ? IconButton(
                        icon: const Icon(Icons.undo, size: 20),
                        tooltip: 'Wróć do wartości z poprzedniego przejazdu',
                        onPressed: () => setState(() {
                          _manualStart = false;
                          _odometerStartCtrl.clear();
                        }),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),

          const SizedBox(height: 12),
          TextFormField(
            controller: _odometerEndCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Po powrocie (km)',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Wpisuje kierowca po powrocie do jednostki',
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),

          if (_distancePreview != null) ...[
            const SizedBox(height: 10),
            Text(
              _distancePreview! < 0
                  ? 'Licznik po powrocie jest mniejszy niż przed wyjazdem'
                  : 'Przejechano ${_distancePreview!} km',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _distancePreview! < 0
                    ? const Color(0xFFB71C1C)
                    : Colors.grey[800],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chainedStartRow(int chained) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Przed wyjazdem (km)',
        border: const OutlineInputBorder(),
        isDense: true,
        helperText: 'Stan po poprzednim przejeździe tego pojazdu',
        helperMaxLines: 2,
        suffixIcon: IconButton(
          icon: const Icon(Icons.lock_outline, size: 20),
          tooltip: 'Popraw ręcznie',
          onPressed: () => setState(() {
            _manualStart = true;
            _odometerStartCtrl.text = chained.toString();
          }),
        ),
      ),
      child: Text('$chained',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  /// Stan przed wyjazdem, który faktycznie zostanie zapisany.
  ///
  /// Jedno źródło prawdy dla podglądu, ostrzeżenia i zapisu. Przy pierwszym
  /// przejeździe pojazdu nie ma łańcucha, a [_manualStart] jest jeszcze
  /// `false` — wpisana wtedy liczba i tak musi się liczyć.
  int? get _effectiveStart {
    if (_manualStart) return int.tryParse(_odometerStartCtrl.text.trim());
    return _chainedStart ?? int.tryParse(_odometerStartCtrl.text.trim());
  }

  int? get _distancePreview {
    final end = int.tryParse(_odometerEndCtrl.text.trim());
    final start = _effectiveStart;
    if (end == null || start == null) return null;
    return end - start;
  }

  Widget _purposeField() {
    return DropdownButtonFormField<String>(
      initialValue: _purpose,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Cel jazdy',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: TripPurposes.all
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(),
      onChanged: (v) => setState(() => _purpose = v ?? TripPurposes.economic),
    );
  }

  Widget _routeFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _routeFromCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Skąd',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 18),
        ),
        Expanded(
          child: TextFormField(
            controller: _routeToCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Dokąd',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _driverField() {
    final drivers = ref
        .watch(firefightersProvider)
        .where((f) => f.isDriver)
        .toList();

    return Autocomplete<Firefighter>(
      initialValue: TextEditingValue(text: _driverCtrl.text),
      displayStringForOption: (f) => f.fullName,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return drivers;
        return drivers.where((f) => f.fullName.toLowerCase().contains(q));
      },
      onSelected: (f) {
        _driverCtrl.text = f.fullName;
        _driverId = f.id;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        // Autocomplete trzyma własny kontroler; utrzymujemy go w zgodzie
        // z naszym, żeby wpisanie nazwiska z ręki też się zapisało.
        controller.addListener(() {
          _driverCtrl.text = controller.text;
          if (_driverId != null) {
            final match = drivers.where((f) => f.fullName == controller.text);
            if (match.isEmpty) _driverId = null;
          }
        });
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Kierowca',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
            helperText: 'Podpowiadani są ratownicy z uprawnieniem kierowcy',
            helperMaxLines: 2,
          ),
        );
      },
    );
  }

  Widget _dispatcherField() {
    return TextFormField(
      controller: _dispatcherCtrl,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Dysponent',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.record_voice_over),
        helperText: 'Kto zadysponował pojazd',
      ),
    );
  }

  Widget _equipmentField() {
    return TextFormField(
      controller: _equipmentCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Praca urządzeń specjalnych (minuty)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.settings_input_component),
        helperText: 'Autopompa, agregat — kolumna 10 karty drogowej',
        helperMaxLines: 2,
      ),
    );
  }

  Widget _notesField() {
    return TextFormField(
      controller: _notesCtrl,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Uwagi (opcjonalne)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.notes),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
      locale: const Locale('pl'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isDeparture}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isDeparture ? _departure : _return) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isDeparture) {
        _departure = picked;
      } else {
        _return = picked;
      }
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń przejazd'),
        content: const Text(
            'Czy na pewno usunąć ten wpis z ewidencji? Stany licznika '
            'kolejnych przejazdów zostaną przeliczone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(vehicleTripsProvider.notifier).delete(widget.tripId!);
    if (mounted) context.pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_departure == null) {
      _snack('Podaj godzinę odjazdu', isError: true);
      return;
    }

    // Sprzeczny licznik ostrzega, ale nie blokuje — papierowa karta jest
    // dokumentem źródłowym i czasem trzeba odwzorować to, co już w niej jest.
    final d = _distancePreview;
    if (d != null && d < 0) {
      final proceed = await _confirmOdometerConflict();
      if (proceed != true) return;
    }

    final syncState = ref.read(syncStateProvider);
    final now = DateTime.now();

    final odometerEnd = int.tryParse(_odometerEndCtrl.text.trim());
    final odometerStart = _effectiveStart;

    // Pierwszy przejazd pojazdu: wpisany stan początkowy jest jedynym punktem
    // odniesienia dla całego dalszego łańcucha, więc musi przetrwać przeliczanie.
    final manual = _manualStart || (_chainedStart == null && odometerStart != null);

    final trip = VehicleTrip(
      id: _existing?.id ??
          'trip_${now.millisecondsSinceEpoch}_${now.microsecond}',
      vehicleId: _vehicleId,
      date: _date,
      dispatcherName: _dispatcherCtrl.text.trim(),
      routeFrom: _routeFromCtrl.text.trim(),
      routeTo: _routeToCtrl.text.trim(),
      purpose: _purpose,
      driverName: _driverCtrl.text.trim(),
      driverId: _driverId,
      departureTime: _departureDateTime,
      returnTime: _returnDateTime,
      odometerStart: odometerStart,
      odometerEnd: odometerEnd,
      odometerStartManual: manual,
      specialEquipmentMinutes: int.tryParse(_equipmentCtrl.text.trim()),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      reportId: _existing?.reportId,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
      createdBy: _existing?.createdBy ?? (syncState.userEmail ?? ''),
      syncStatus: 'local',
    );

    final notifier = ref.read(vehicleTripsProvider.notifier);
    if (widget.isEdit) {
      await notifier.update(trip);
    } else {
      await notifier.add(trip);
    }

    if (!mounted) return;
    _snack(widget.isEdit ? 'Zapisano zmiany' : 'Przejazd dodany do ewidencji');
    context.pop();
  }

  Future<bool?> _confirmOdometerConflict() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sprawdź licznik'),
        content: const Text(
            'Stan po powrocie jest mniejszy niż przed wyjazdem. Zwykle to '
            'literówka albo zamienione wartości.\n\n'
            'Możesz zapisać mimo to — jeśli tak jest w papierowej karcie.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Popraw')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zapisz mimo to')),
        ],
      ),
    );
  }

  void _snack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFFB71C1C) : null,
      ),
    );
  }
}
