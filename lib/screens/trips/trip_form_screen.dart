import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/bottom_inset.dart';
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
  final _idleCtrl = TextEditingController();
  final _extrasCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  /// Rozbicie pracy urządzeń specjalnych — edytowane w miejscu, więc
  /// trzymane jako lista modeli, a nie kontrolery tekstowe.
  final List<TripEquipmentUse> _equipment = [];

  String? _driverId;

  /// Czy stan przed wyjazdem jest wpisywany ręcznie zamiast z łańcucha.
  bool _manualStart = false;

  /// Czy dysponent jest wpisywany z ręki zamiast wybierany z załogi.
  bool _dispatcherManual = false;

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
    _idleCtrl.dispose();
    _extrasCtrl.dispose();
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
        _equipment
          ..clear()
          ..addAll(trip.equipmentUse.map(
              (e) => TripEquipmentUse(name: e.name, minutes: e.minutes)));
        // Przejazd sprzed listy urzadzen ma tylko liczbe minut — pokazujemy
        // ja jako jedna pozycje bez nazwy, zeby dalo sie ja uzupelnic zamiast
        // tracic.
        if (_equipment.isEmpty && (trip.specialEquipmentMinutes ?? 0) > 0) {
          _equipment.add(TripEquipmentUse(
              name: '', minutes: trip.specialEquipmentMinutes!));
        }
        _idleCtrl.text = trip.idleMinutes?.toString() ?? '';
        _extrasCtrl.text = trip.extras;
        _notesCtrl.text = trip.notes ?? '';

        _loadCrewOfLinkedReport();

        // Wyjazd alarmowy dopisuje się bez dysponenta — podpowiadamy dowódcę
        // tego zastępu, bo to on w praktyce dysponuje pojazdem.
        if (_dispatcherCtrl.text.trim().isEmpty) {
          final commander = _crewOfLinkedReport.firstOrNull;
          if (commander != null) _dispatcherCtrl.text = commander.lastNameFirst;
        }
        return;
      }
    }

    // Nowy przejazd
    _vehicleId = widget.initialVehicleId ??
        (vehicles.isNotEmpty ? vehicles.first.id : '');
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _departure = TimeOfDay.fromDateTime(now);

    // Trasa prawie zawsze zaczyna się w remizie — podpowiadamy jej adres
    // z danych jednostki, ale zostaje edytowalny.
    _routeFromCtrl.text = ref.read(unitConfigProvider).stationAddress;
  }

  /// Załoga tego pojazdu z powiązanego wyjazdu alarmowego.
  ///
  /// Kolejność ma znaczenie: **dowódca pierwszy**, bo to on trafia do pola
  /// dysponenta jako podpowiedź. Dalej kierowca i reszta zastępu.
  ///
  /// Pusta lista dla przejazdów gospodarczych — tam nie ma z czego wybierać
  /// i pole zostaje zwykłym wpisem z podpowiedziami ze wszystkich ratowników.
  List<Firefighter> _crewOfLinkedReport = const [];

  void _loadCrewOfLinkedReport() {
    final reportId = _existing?.reportId;
    if (reportId == null || _vehicleId.isEmpty) {
      _crewOfLinkedReport = const [];
      return;
    }
    final db = ref.read(databaseServiceProvider);
    final report = db.getReport(reportId);
    final crew = report?.crewAssignments
        .where((c) => c.vehicleId == _vehicleId)
        .firstOrNull;
    if (crew == null) {
      _crewOfLinkedReport = const [];
      return;
    }

    final ids = <String>[
      if (crew.commanderId != null && crew.commanderId!.isNotEmpty)
        crew.commanderId!,
      if (crew.driverId != null && crew.driverId!.isNotEmpty) crew.driverId!,
      ...crew.crewMemberIds.where((id) => id.isNotEmpty),
    ];

    final seen = <String>{};
    _crewOfLinkedReport = [
      for (final id in ids)
        if (seen.add(id)) db.getFirefighter(id),
    ].whereType<Firefighter>().toList();
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
          padding: context.scrollPadding(),
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
                    _idleField(),
                    const SizedBox(height: 14),
                    _extrasField(),
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
                // Gdy nie ma poprzedniego przejazdu, mówimy wprost, że to
                // jedyny raz. Sam komunikat „Wpisany ręcznie" brzmiał jak
                // zapowiedź, że tak już będzie zawsze.
                helperText: chained == null
                    ? 'Pierwszy przejazd tego pojazdu — przy kolejnych podstawi się sam'
                    : 'Wpisany ręcznie — zamiast stanu z poprzedniego przejazdu',
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

  /// Trasa jeden pod drugim, a nie obok siebie.
  ///
  /// Adres w rodzaju „Kielno, Oliwska 12” nie mieści się w połowie szerokości
  /// ekranu telefonu — obok siebie oba pola urywały tekst w połowie.
  Widget _routeFields() {
    return Column(
      children: [
        TextFormField(
          controller: _routeFromCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Skąd',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.trip_origin, size: 18),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Icon(Icons.arrow_downward, size: 18),
        ),
        TextFormField(
          controller: _routeToCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Dokąd',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.place_outlined, size: 18),
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
      displayStringForOption: (f) => f.lastNameFirst,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return drivers;
        return drivers.where((f) =>
            f.lastNameFirst.toLowerCase().contains(q) ||
            f.fullName.toLowerCase().contains(q));
      },
      onSelected: (f) {
        _driverCtrl.text = f.lastNameFirst;
        _driverId = f.id;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        // Autocomplete trzyma własny kontroler; utrzymujemy go w zgodzie
        // z naszym, żeby wpisanie nazwiska z ręki też się zapisało.
        //
        // Świadomie przez `onChanged`, a **nie** `controller.addListener`:
        // ten builder uruchamia się przy każdym przebudowaniu formularza,
        // więc dodawanie nasłuchu dokładałoby kolejny przy każdym `setState`,
        // bez usuwania poprzednich. Po kilkunastu przebudowaniach jedno
        // naciśnięcie klawisza odpalałoby kilkanaście reakcji.
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            _driverCtrl.text = value;
            if (_driverId != null &&
                !drivers.any((f) => f.lastNameFirst == value || f.fullName == value)) {
              _driverId = null;
            }
          },
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

  /// Dysponent — przy wyjeździe alarmowym wybierany z załogi tego zastępu.
  ///
  /// Lista jest krótka i konkretna, więc rozwijana bije wpisywanie z ręki.
  /// Zostaje pozycja „Inna osoba", bo dysponować może ktoś spoza zastępu
  /// (dyżurny, naczelnik) — wtedy odsłania się zwykłe pole tekstowe.
  Widget _dispatcherField() {
    final crew = _crewOfLinkedReport;
    if (crew.isEmpty || _dispatcherManual) {
      return TextFormField(
        controller: _dispatcherCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Dysponent',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.record_voice_over),
          helperText: 'Kto zadysponował pojazd',
          suffixIcon: crew.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.undo, size: 20),
                  tooltip: 'Wróć do listy zastępu',
                  onPressed: () => setState(() {
                    _dispatcherManual = false;
                    _dispatcherCtrl.text = crew.first.lastNameFirst;
                  }),
                ),
        ),
      );
    }

    final current = crew
        .where((f) => f.lastNameFirst == _dispatcherCtrl.text.trim())
        .firstOrNull;

    return DropdownButtonFormField<String>(
      initialValue: current?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Dysponent',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.record_voice_over),
        helperText: 'Z zastępu tego pojazdu — domyślnie dowódca',
        helperMaxLines: 2,
      ),
      items: [
        for (final f in crew)
          DropdownMenuItem(
            value: f.id,
            child: Text(
              crew.first.id == f.id ? '${f.lastNameFirst} (dowódca)' : f.lastNameFirst,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const DropdownMenuItem(
          value: _otherDispatcher,
          child: Text('Inna osoba…'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          if (value == _otherDispatcher) {
            _dispatcherManual = true;
            _dispatcherCtrl.clear();
            return;
          }
          final picked = crew.where((f) => f.id == value).firstOrNull;
          if (picked != null) _dispatcherCtrl.text = picked.lastNameFirst;
        });
      },
    );
  }

  static const String _otherDispatcher = '__other__';

  /// Praca urządzeń specjalnych — lista „urządzenie + minuty".
  ///
  /// Wcześniej było tu jedno pole na minuty, bez wskazania **czego** dotyczą.
  /// Zgłoszenie z testów: „nie ma możliwości wyboru urządzenia, co powoduje,
  /// że to trzeba pominąć i najlepiej wpisać w komentarzu autopompa 2h,
  /// agregat 1h". Rubryka była więc w praktyce nie do użycia.
  ///
  /// Na wydruk (kolumna 10) idzie suma minut, bo druk ma tam jedną liczbę.
  Widget _equipmentField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_input_component,
                  size: 20, color: Colors.grey[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Praca urządzeń specjalnych',
                  style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                ),
              ),
              if (_equipment.isNotEmpty)
                Text('${_totalEquipmentMinutes()} min',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (_equipment.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Kolumna 10 karty drogowej. Dodaj urządzenie i czas jego pracy.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          for (var i = 0; i < _equipment.length; i++) _equipmentRow(i),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _equipment.add(
                  TripEquipmentUse(name: SpecialEquipment.pump, minutes: 0))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Dodaj urządzenie'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _totalEquipmentMinutes() =>
      _equipment.fold(0, (sum, e) => sum + e.minutes);

  Widget _equipmentRow(int index) {
    final item = _equipment[index];
    final isCustom = !SpecialEquipment.all.contains(item.name);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: isCustom ? SpecialEquipment.other : item.name,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Urządzenie',
              ),
              items: SpecialEquipment.all
                  .map((n) => DropdownMenuItem(
                        value: n,
                        child: Text(n, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                // Wybór „Inne" zostawia puste pole na wpisanie własnej nazwy.
                item.name = v == SpecialEquipment.other ? '' : (v ?? '');
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.minutes == 0 ? '' : item.minutes.toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Minuty',
              ),
              onChanged: (v) =>
                  setState(() => item.minutes = int.tryParse(v.trim()) ?? 0),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Usuń',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _equipment.removeAt(index)),
          ),
        ],
          ),
          // Własna nazwa pojawia się dopiero po wybraniu „Inne" — reszta
          // wyborów jej nie potrzebuje i zajmowałaby tylko miejsce.
          if (isCustom || item.name.isEmpty) ...[
            const SizedBox(height: 8),
            _customEquipmentName(item),
          ],
        ],
      ),
    );
  }

  /// Pole na własną nazwę, gdy wybrano „Inne".
  Widget _customEquipmentName(TripEquipmentUse item) => TextFormField(
        initialValue: item.name,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          labelText: 'Nazwa urządzenia',
        ),
        onChanged: (v) => item.name = v.trim(),
      );

  /// Praca silnika na postoju — osobna kolumna druku i osobna pozycja
  /// rozliczenia, z własną normą (litry na minutę), więc nie da się jej
  /// wliczyć do minut pracy urządzeń.
  Widget _idleField() {
    return TextFormField(
      controller: _idleCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Praca silnika na postoju (minuty)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.timer_outlined),
        helperText: 'Kolumna 12 karty drogowej — rozliczana osobną normą',
        helperMaxLines: 2,
      ),
    );
  }

  /// Kolumna „Dodatki*" — wolna rubryka druku na dopiski wpływające
  /// na rozliczenie, np. dodatek zimowy.
  Widget _extrasField() {
    return TextFormField(
      controller: _extrasCtrl,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Dodatki (opcjonalne)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.add_circle_outline),
        helperText: 'Kolumna 11 karty drogowej, np. dodatek zimowy',
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
      // Zapisujemy rozbicie ORAZ sume w starym polu: karta drukuje sume,
      // a starsze wersje aplikacji u kolegow czytaja tylko stare pole.
      equipmentUse: _equipment.where((e) => e.minutes > 0).toList(),
      specialEquipmentMinutes:
          _totalEquipmentMinutes() == 0 ? null : _totalEquipmentMinutes(),
      idleMinutes: int.tryParse(_idleCtrl.text.trim()),
      extras: _extrasCtrl.text.trim(),
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
