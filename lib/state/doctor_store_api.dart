part of 'doctor_store.dart';

/// The doctor side on the real API. Same methods as [DoctorStore], so the screens don't change.
///
/// Console buttons change the screen at once (the same local change the mock makes), then send the command with
/// the board version the doctor was looking at; the server's answer replaces the line. If the line changed
/// meanwhile (a new emergency patient, another device), the server refuses and sends the fresh line.
class ApiDoctorStore extends DoctorStore {
  ApiDoctorStore() : super.base() {
    _side = SessionStore.instance.side;
    SessionStore.instance.addListener(_sessionChanged);
    if (_side == Side.doctor) reload();
    // The line arrives by WebSocket the moment it changes; the check stays as a safety net (every 10 s while the
    // connection is down, once a minute while it is up).
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (SessionStore.instance.side != Side.doctor) return;
      if (LiveSocket.instance.connected && ++_liveTicks % 6 != 0) return;
      _loadToday(quiet: true);
    });
    _lines = LiveSocket.instance.lines.listen(_onLine);
  }

  Api get _api => Api.instance;
  Timer? _poll;
  int _liveTicks = 0;
  StreamSubscription<Map<String, dynamic>>? _lines;

  /// A newer line from the server (another device, a new emergency patient, the doctor's own taps).
  void _onLine(Map<String, dynamic> b) {
    if (b['sessionId'] != sessionId) return;
    final v = (b['version'] as num?)?.toInt() ?? 0;
    if (v <= _version) return;
    _applyBoard(b);
    notifyListeners();
  }
  Side _side = Side.none;
  String? _doctorId;
  String? sessionId;
  int _version = 0;
  Future<void> _queue = Future.value();
  final _dayCache = <String, List<LinePatient>>{};
  final _dayLoading = <String>{};
  final _dayAt = <String, DateTime>{};
  List<EarningRow> _earnings = const [];
  int _earningsDays = 0;

  /// Something the doctor should know (e.g. "The line changed while you were busy").
  String? notice;

  @override
  String? takeNotice() {
    final n = notice;
    notice = null;
    return n;
  }

  /// True once profile, hospitals, timings and today's line have loaded from the server.
  bool ready = false;

  @override
  bool get isReady => ready;

  void _sessionChanged() {
    final s = SessionStore.instance.side;
    if (s == _side) return;
    _side = s;
    line.clear();
    _dayCache.clear();
    _dayAt.clear();
    sessionId = null;
    ready = false;
    if (s != Side.doctor) LiveSocket.instance.close();
    if (s == Side.doctor) reload();
    notifyListeners();
  }

  @override
  Doctor get doctor {
    final id = _doctorId ?? SessionStore.instance.doctorId;
    return (id == null ? null : MockData.findDoctor(id)) ??
        const Doctor(id: '', name: 'Doctor', typeId: 'general', degrees: '', years: 0, languages: [], fee: 0, hospitalIds: [], workDays: [], sessions: [], gender: '');
  }

  @override
  List<Hospital> get hospitals => [for (final id in doctor.hospitalIds) ?MockData.findHospital(id)];

  @override
  Hospital get hospital => MockData.findHospital(hospitalId) ?? (hospitals.isNotEmpty ? hospitals.first : MockData.hospital(hospitalId));

  /// Profile, hospitals, timings, leave, emergency status and today's line.
  Future<void> reload() async {
    try {
      final me = Map<String, dynamic>.from(await _api.get('/v1/doctor/me') as Map);
      final hs = (await _api.get('/v1/doctor/hospitals') as List).cast<Map>();
      _doctorId = me['id'] as String;
      Remote.instance.ownDoctorId = _doctorId;
      for (final h in hs) {
        if (MockData.findHospital(h['id'] as String) == null) {
          MockData.hospitals = [...MockData.hospitals, Remote.hospitalFrom({...Map<String, dynamic>.from(h), 'departments': const []})];
        }
      }
      final active = hs.where((h) => h['status'] == 'active').toList();
      final primary = active.where((h) => h['isPrimary'] == true).firstOrNull ?? active.firstOrNull;
      if (primary != null && !active.any((h) => h['id'] == hospitalId)) hospitalId = primary['id'] as String;

      for (final h in active) {
        final week = Map<String, dynamic>.from(await _api.get('/v1/doctor/schedule', query: {'hospital': h['id']}) as Map);
        openDaysBefore = (week['openDaysAhead'] as num?)?.toInt() ?? openDaysBefore;
        schedule[h['id'] as String] = {
          for (final d in (week['days'] as List).cast<Map>())
            (d['weekday'] as num).toInt(): [
              for (final b in (d['blocks'] as List).cast<Map>())
                TimeBlock(
                  start: int.parse((b['start'] as String).split(':')[0]),
                  end: int.parse((b['end'] as String).split(':')[0]),
                  perHour: (b['perHour'] as num).toInt(),
                  takeEmergency: b['takeEmergency'] != false,
                  avgMinutes: ((b['avgMinutes'] as num?) ?? 7).toInt(),
                ),
            ],
        };
      }
      final existing = MockData.findDoctor(_doctorId!);
      final profile = Doctor(
        id: _doctorId!,
        name: me['name'] as String,
        typeId: me['typeId'] as String,
        degrees: me['degrees'] as String,
        years: (me['yearsExperience'] as num).toInt(),
        languages: (me['languages'] as List).cast<String>(),
        fee: ((me['feePaise'] as num).toInt()) ~/ 100,
        hospitalIds: [for (final h in active) h['id'] as String],
        workDays: existing?.workDays ?? [for (var d = 1; d <= 7; d++) if (schedule.values.any((w) => (w[d] ?? const []).isNotEmpty)) d],
        sessions: existing?.sessions ?? const [],
        gender: '${(me['gender'] as String)[0].toUpperCase()}${(me['gender'] as String).substring(1)}',
        about: (me['about'] as String?) ?? '',
        regNo: '${me['regCouncil']} ${me['regNo']}',
        photoUrl: (me['photo'] as Map?)?['m'] as String?,
        bookingsPaused: me['bookingsPaused'] == true,
      );
      final i = MockData.doctors.indexWhere((d) => d.id == _doctorId);
      if (i >= 0) {
        MockData.doctors[i] = profile;
      } else {
        MockData.doctors.add(profile);
      }

      final leaves = (await _api.get('/v1/doctor/leaves') as List).cast<Map>();
      leaveDays
        ..clear()
        ..addAll(leaves.map((l) => Remote.dateOf(l['date'] as String)));
      final em = Map<String, dynamic>.from(await _api.get('/v1/doctor/emergency') as Map);
      emergency = switch (em['status']) {
        'available_now' => EmergencyStatus.availableNow,
        'available_till' => EmergencyStatus.availableTill,
        _ => EmergencyStatus.off,
      };
      if (em['untilAt'] is String) emergencyTill = clockLabel(DateTime.parse(em['untilAt'] as String).toLocal());
      await _loadToday();
      ready = true;
    } on ApiException catch (e) {
      notice = e.message;
    }
    notifyListeners();
  }

  // ── Today ──────────────────────────────────────────────────────────────────────────────────────

  Future<void> _loadToday({bool quiet = false}) async {
    try {
      final r = Map<String, dynamic>.from(await _api.get('/v1/doctor/today', query: {'hospital': hospitalId}) as Map);
      final sessions = (r['sessions'] as List).cast<Map>();
      final pick = sessions.where((s) => s['status'] != 'ended').firstOrNull ?? sessions.lastOrNull;
      _nextOpd = null;
      if (pick == null) {
        sessionId = null;
        line.clear();
        opd = OpdState.notStarted;
      } else {
        _applyBoard(Map<String, dynamic>.from(pick));
      }
      notifyListeners();
    } on ApiException catch (e) {
      if (!quiet) notice = e.message;
    }
  }

  int? _boardStart;
  int? _boardEnd;
  int? _nextOpd;

  @override
  int get opdStart => _boardStart ?? super.opdStart;
  @override
  int get opdEnd => _boardEnd ?? super.opdEnd;
  @override
  int? get nextOpdToday => opd == OpdState.ended ? _nextOpd : null;

  void _applyBoard(Map<String, dynamic> b) {
    sessionId = b['sessionId'] as String;
    final t = b['time'] as Map?;
    if (t?['startsAt'] is String) _boardStart = Remote.istHour(t!['startsAt'] as String);
    if (t?['endsAt'] is String) {
      final end = DateTime.parse(t!['endsAt'] as String).toUtc().add(const Duration(hours: 5, minutes: 30));
      _boardEnd = end.hour + (end.minute > 0 ? 1 : 0);
    }
    unawaited(LiveSocket.instance.follow([sessionId!]));
    _version = (b['version'] as num).toInt();
    opd = switch (b['status']) {
      'running' => OpdState.running,
      'paused' => OpdState.onBreak,
      'ended' || 'cancelled' => OpdState.ended,
      _ => OpdState.notStarted,
    };
    lateMinutes = ((b['lateMinutes'] as num?) ?? 0).toInt();
    final entries = (b['line'] as List).cast<Map>();
    line
      ..clear()
      ..addAll([
        for (final (i, e) in entries.indexed) _patientFrom(Map<String, dynamic>.from(e), today())..order = i.toDouble(),
      ]);
  }

  static PatientState _state(String? s) => switch (s) {
        'waiting' => PatientState.waiting,
        'with_doctor' => PatientState.withDoctor,
        'done' => PatientState.done,
        'did_not_come' => PatientState.didNotCome,
        'cancelled' => PatientState.cancelled,
        'moved' => PatientState.moved,
        _ => PatientState.notCome,
      };

  LinePatient _patientFrom(Map<String, dynamic> e, DateTime day) {
    final label = (e['tokenLabel'] as String?) ?? '';
    final startsAt = e['startsAt'] as String?;
    return LinePatient(
      id: (e['bookingId'] ?? e['id']) as String,
      token: (e['token'] as num?)?.toInt() ?? int.tryParse(label.replaceAll(RegExp(r'\D'), '')) ?? 0,
      name: (e['name'] as String?) ?? 'Patient',
      age: ((e['age'] as num?) ?? 0).toInt(),
      gender: e['gender'] == null ? '' : '${(e['gender'] as String)[0].toUpperCase()}${(e['gender'] as String).substring(1)}',
      phone: '',
      source: e['emergency'] == true ? Source.emergency : Source.online,
      hour: startsAt != null ? Remote.istHour(startsAt) : DateTime.now().hour,
      date: day,
      state: _state(e['state'] as String? ?? e['queueState'] as String?),
      note: (e['note'] as String?) ?? '',
      fee: (((e['fee'] as Map?)?['paise'] as num?) ?? doctor.fee * 100).toInt() ~/ 100,
      changed: e['changed'] == true,
      hospitalId: ((e['hospital'] as Map?)?['id'] as String?) ?? (e['hospitalId'] as String?),
      hospitalName: (e['hospital'] as Map?)?['name'] as String?,
    )
      ..reachedAt = DateTime.tryParse((e['reachedAt'] as String?) ?? '')?.toLocal()
      ..calledAt = DateTime.tryParse((e['calledAt'] as String?) ?? '')?.toLocal()
      ..doneAt = DateTime.tryParse((e['doneAt'] as String?) ?? '')?.toLocal();
  }

  /// Sends console commands one after another, each with the latest board version.
  void _send(String command, {String? bookingId, int? minutes, String? leftovers, bool position = false}) {
    final sid = sessionId;
    if (sid == null) return;
    _queue = _queue.then((_) async {
      try {
        final r = await _api.post('/v1/doctor/sessions/$sid/$command', {
          if (position) 'expectedVersion': _version,
          'bookingId': ?bookingId,
          'minutes': ?minutes,
          'leftovers': ?leftovers,
        });
        _applyBoard(Map<String, dynamic>.from(r as Map));
      } on ApiException catch (e) {
        final board = e.details?['board'];
        if (e.code == 'STALE_BOARD' && board is Map) {
          _applyBoard(Map<String, dynamic>.from(board));
          notice = 'The line changed. Please check it again.';
        } else {
          notice = e.message;
          await _loadToday(quiet: true);
        }
      }
      notifyListeners();
    });
  }

  @override
  Future<void> startOpd() async {
    opd = OpdState.running;
    startedAt = DateTime.now();
    notifyListeners();
    _send('start');
    await _queue;
  }

  @override
  LinePatient? callNext() {
    final next = super.callNext();
    _send('call-next', position: true);
    return next;
  }

  @override
  void markDone() {
    if (current == null) return;
    super.markDone();
    _send('done', position: true);
  }

  @override
  void markDidNotCome(LinePatient p) {
    super.markDidNotCome(p);
    _send('did-not-come', bookingId: p.id);
  }

  @override
  void skip(LinePatient p) {
    super.skip(p);
    _send('skip', bookingId: p.id, position: true);
  }

  @override
  void markReached(LinePatient p) {
    super.markReached(p);
    _send('mark-reached', bookingId: p.id);
  }

  @override
  void callNow(LinePatient p) {
    super.callNow(p);
    _send('call-now', bookingId: p.id, position: true);
  }

  @override
  void putBack(LinePatient p) {
    super.putBack(p);
    _send('put-back', bookingId: p.id);
  }

  @override
  void setLate(int minutes) {
    super.setLate(minutes);
    _send('late', minutes: minutes);
  }

  @override
  void toggleBreak() {
    final pausing = opd == OpdState.running;
    super.toggleBreak();
    _send(pausing ? 'pause' : 'resume');
  }

  @override
  Future<void> endOpd({required bool moveLeftovers}) async {
    _send('end', leftovers: moveLeftovers ? 'move' : 'cancel');
    await _queue;
    opd = OpdState.ended;
    // A later OPD today at this hospital (evening after a morning)? The "OPD is over" screen offers it.
    try {
      final r = Map<String, dynamic>.from(await _api.get('/v1/doctor/today', query: {'hospital': hospitalId}) as Map);
      final later = (r['sessions'] as List).cast<Map>().where((s) => s['status'] == 'scheduled' && s['sessionId'] != sessionId).firstOrNull;
      final st = (later?['time'] as Map?)?['startsAt'];
      _nextOpd = st is String ? Remote.istHour(st) : null;
    } on ApiException {
      _nextOpd = null;
    }
    notifyListeners();
  }

  @override
  void switchHospital(String id) {
    if (id == hospitalId) return;
    hospitalId = id;
    _boardStart = null;
    _boardEnd = null;
    _nextOpd = null;
    line.clear();
    sessionId = null;
    notifyListeners();
    _loadToday();
  }

  @override
  void resetDay() => _loadToday();

  @override
  void setEmergency(EmergencyStatus s, {String? till, String? place}) {
    super.setEmergency(s, till: till, place: place);
    final body = <String, Object?>{
      'status': switch (s) {
        EmergencyStatus.availableNow => 'available_now',
        EmergencyStatus.availableTill => 'available_till',
        EmergencyStatus.off => 'off',
      },
      if (s != EmergencyStatus.off) 'hospitalId': hospitalId,
      if (s == EmergencyStatus.availableTill) 'untilAt': _untilIso(emergencyTill),
      'mode': emergencyPlace.toLowerCase().contains('call') ? 'phone_first' : 'at_hospital',
    };
    _api.put('/v1/doctor/emergency', body).then((_) => null, onError: (Object e) {
      notice = friendlyMessage(e);
      notifyListeners();
    });
  }

  /// "10 PM" → the next time it is 10 PM (today, or tomorrow if already past), as ISO with offset.
  static String _untilIso(String label) {
    final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$', caseSensitive: false).firstMatch(label.trim());
    var h = int.parse(m?.group(1) ?? '10') % 12;
    if ((m?.group(3) ?? 'PM').toUpperCase() == 'PM') h += 12;
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, h, int.parse(m?.group(2) ?? '0'));
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t.toUtc().toIso8601String();
  }

  // ── Bookings on any day ────────────────────────────────────────────────────────────────────────

  // Per-day counts for the next 62 days in ONE call (like the doctor website), not one call per day: the
  // API limits calls per doctor. Fetched again after 30 s while a screen asks.
  final _counts = <String, (int, int)>{}; // date → (coming, total)
  DateTime? _countsAt;
  bool _countsLoading = false;

  void _refreshCounts() {
    if (_countsLoading || (_countsAt != null && DateTime.now().difference(_countsAt!) < const Duration(seconds: 30))) return;
    _countsLoading = true;
    _countsAt = DateTime.now();
    _api.get('/v1/doctor/bookings/counts', query: {'from': Remote.ymd(DateTime.now()), 'days': '62'}).then((r) {
      for (final e in ((r as Map)['days'] as List).cast<Map>()) {
        _counts['${e['date']}'] = (((e['coming'] as num?) ?? 0).toInt(), ((e['total'] as num?) ?? 0).toInt());
      }
      notifyListeners();
    }).catchError((_) {}).whenComplete(() => _countsLoading = false);
  }

  @override
  int bookedCount(DateTime day) {
    if (sameDay(day, DateTime.now())) return super.bookedCount(day); // today: the live line
    _refreshCounts();
    return _counts[Remote.ymd(day)]?.$2 ?? 0;
  }

  @override
  bool hasComing(DateTime day) {
    if (sameDay(day, DateTime.now())) return super.hasComing(day);
    _refreshCounts();
    return (_counts[Remote.ymd(day)]?.$1 ?? 0) > 0;
  }


  /// A day's bookings at EVERY hospital the doctor works at (a doctor at two hospitals must see both).
  /// Today, the hospital on screen comes from the live line (its states change by the minute).
  @override
  List<LinePatient> bookingsOn(DateTime day) {
    final key = Remote.ymd(day);
    final have = _dayCache[key];
    // Fetched once, then again every 30 s while shown (new bookings appear without leaving the screen).
    final stale = have == null || DateTime.now().difference(_dayAt[key] ?? DateTime(2000)) > const Duration(seconds: 30);
    if (stale && _dayLoading.add(key)) {
      _dayAt[key] = DateTime.now();
      _api.get('/v1/doctor/bookings', query: {'date': key}).then((r) {
        _dayCache[key] = [for (final e in ((r as Map)['items'] as List).cast<Map>()) _bookingFrom(Map<String, dynamic>.from(e), day)];
        notifyListeners();
      }).catchError((_) {
        _dayCache[key] ??= [];
      }).whenComplete(() => _dayLoading.remove(key));
    }
    return _withLiveLine(day, have ?? const []);
  }

  List<LinePatient> _withLiveLine(DateTime day, List<LinePatient> all) {
    if (!sameDay(day, DateTime.now()) || sessionId == null) return all;
    final here = line.where((p) => p.source != Source.emergency).toList();
    final ids = here.map((p) => p.id).toSet();
    return [...here, ...all.where((p) => p.hospitalId != hospitalId && !ids.contains(p.id))];
  }

  /// Today, at the other hospitals (so Today can say "you also have patients at …").
  @override
  List<LinePatient> elsewhereToday() =>
      bookingsOn(DateTime.now()).where((p) => p.hospitalId != null && p.hospitalId != hospitalId && p.state == PatientState.notCome).toList();

  /// The day's bookings, waiting for the server (for decisions such as leave, where "not loaded yet" must not
  /// look like "no bookings").
  @override
  Future<List<LinePatient>> loadBookingsOn(DateTime day) async {
    final key = Remote.ymd(day);
    final r = await _api.get('/v1/doctor/bookings', query: {'date': key});
    _dayCache[key] = [for (final e in ((r as Map)['items'] as List).cast<Map>()) _bookingFrom(Map<String, dynamic>.from(e), day)];
    return _withLiveLine(day, _dayCache[key]!);
  }

  LinePatient _bookingFrom(Map<String, dynamic> e, DateTime day) {
    final p = _patientFrom(e, dateOnly(day));
    if (e['status'] == 'cancelled_by_provider') p.state = PatientState.cancelled;
    if (e['status'] == 'completed') p.state = PatientState.done;
    if (e['status'] == 'no_show') p.state = PatientState.didNotCome;
    if (e['waitingForNewTime'] == true) p.state = PatientState.moved;
    return p;
  }

  @override
  LinePatient? findBooking(String id) =>
      [...line, ..._dayCache.values.expand((l) => l)].where((p) => p.id == id).firstOrNull;

  /// A booking not on the screens yet (opened from a message about another day or hospital).
  @override
  Future<LinePatient?> fetchBooking(String id) async {
    final have = findBooking(id);
    if (have != null) return have;
    final r = Map<String, dynamic>.from(await _api.get('/v1/doctor/bookings/$id') as Map);
    final p = _bookingFrom(r, Remote.dateOf(r['sessionDate'] as String));
    _dayCache['one|$id'] = [p];
    notifyListeners();
    return p;
  }

  /// Cancel one booking: the patient gets all their money back.
  @override
  Future<void> cancelBooking(LinePatient p, String reason) async {
    _countsAt = null;
    await _api.post('/v1/doctor/bookings/${p.id}/cancel', {'reason': reason.trim().length >= 3 ? reason.trim() : 'Doctor not available'});
    p.state = PatientState.cancelled;
    notifyListeners();
  }

  /// The doctor can't pick a time for the patient: the patient is asked to pick a new time themselves
  /// (or gets all their money back after 48 hours).
  @override
  Future<void> changeBooking(LinePatient p, DateTime day, int hour) async {
    _countsAt = null;
    await _api.post('/v1/doctor/bookings/${p.id}/move', {'reason': 'The doctor changed the time'});
    p
      ..state = PatientState.moved
      ..changed = true;
    notifyListeners();
  }

  @override
  void markNoShow(LinePatient p) {
    if (line.contains(p)) {
      markDidNotCome(p);
    } else {
      super.markNoShow(p);
    }
  }

  /// "I can't come on this day": everyone gets all their money back.
  @override
  Future<(int, int)> cancelDay(DateTime day) async {
    _countsAt = null;
    final r = Map<String, dynamic>.from(await _api.post('/v1/doctor/days/${Remote.ymd(day)}/cancel', {'reason': 'The doctor is not available on this day'}) as Map);
    leaveDays.add(dateOnly(day));
    _dayCache.remove(Remote.ymd(day));
    notifyListeners();
    return ((r['bookings'] as num).toInt(), ((r['refund'] as Map)['paise'] as num).toInt() ~/ 100);
  }

  // ── Timings and leave ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> saveTimings(Map<int, List<TimeBlock>> week, int openBefore) async {
    String hh(int h) => '${h.toString().padLeft(2, '0')}:00';
    final r = Map<String, dynamic>.from(await _api.put('/v1/doctor/schedule', {
      'hospitalId': hospitalId,
      'openDaysAhead': openBefore,
      'days': [
        for (final e in week.entries)
          {
            'weekday': e.key,
            'blocks': [
              for (final b in e.value) {'start': hh(b.start), 'end': hh(b.end), 'perHour': b.perHour, 'takeEmergency': b.takeEmergency, 'avgMinutes': b.avgMinutes},
            ],
          },
      ],
    }) as Map);
    schedule[hospitalId] = {for (final e in week.entries) e.key: e.value.map((b) => b.copy()).toList()};
    openDaysBefore = openBefore;
    notice = r['message'] as String?;
    Remote.instance.forgetDoctor(doctor.id);
    notifyListeners();
  }

  @override
  Future<void> setLeave(Set<DateTime> days) async {
    _countsAt = null;
    await _api.put('/v1/doctor/leaves', {
      'days': [for (final d in days) if (!dateOnly(d).isBefore(today())) {'date': Remote.ymd(d)}],
    });
    leaveDays
      ..clear()
      ..addAll(days.map(dateOnly));
    notifyListeners();
  }

  // ── Earnings (what really reaches the bank: the server's payouts) ─────────────────────────────

  @override
  List<EarningRow> earnings(int days) {
    if (days != _earningsDays) {
      _earningsDays = days;
      _api.get('/v1/doctor/earnings', query: {'days': days}).then((r) {
        _earnings = [
          for (final row in ((r as Map)['rows'] as List).cast<Map>())
            if (((row['patients'] as num?) ?? 0) > 0)
              EarningRow(
                date: Remote.dateOf(row['date'] as String),
                patient: people((row['patients'] as num).toInt()),
                fee: ((row['fees'] as Map)['paise'] as num).toInt() ~/ 100,
                paid: ((row['coming'] as Map)['paise'] as num) == 0 && ((row['inBank'] as Map)['paise'] as num) > 0,
                refunded: ((row['moneyBack'] as Map)['paise'] as num) > 0 && ((row['yours'] as Map)['paise'] as num) == ((row['moneyBack'] as Map)['paise'] as num),
              ),
        ];
        notifyListeners();
      }).catchError((_) {});
    }
    return _earnings;
  }

  @override
  Future<DoctorPayouts> loadPayouts() async {
    final r = Map<String, dynamic>.from(await _api.get('/v1/doctor/payouts') as Map);
    final bank = r['bank'] as Map?;
    String show(Object? m) => ((m as Map?)?['display'] as String?) ?? '';
    return DoctorPayouts(
      bankLast4: bank?['last4'] as String?,
      hasBank: bank != null,
      bankActive: bank?['active'] == true,
      items: [
        for (final e in (r['items'] as List).cast<Map>())
          DoctorPayout(
            id: e['id'] as String,
            amount: show(e['amount']),
            visits: (e['visits'] as num?)?.toInt() ?? 0,
            deducted: e['deducted'] == null ? null : show(e['deducted']),
            status: (e['status'] as String?) ?? 'pending',
            bankReference: e['bankReference'] as String?,
            sentAt: DateTime.tryParse('${e['createdAt']}')?.toLocal() ?? DateTime.now(),
          ),
      ],
    );
  }

  @override
  Future<(List<SignedInDevice>, int, int)> devices() async {
    final r = Map<String, dynamic>.from(await _api.get('/v1/doctor/devices') as Map);
    return (
      [
        for (final e in (r['items'] as List).cast<Map>())
          SignedInDevice(
            id: e['id'] as String,
            device: (e['device'] as String?) ?? 'Phone',
            web: e['platform'] == 'web',
            thisDevice: e['thisDevice'] == true,
            lastUsed: DateTime.tryParse('${e['lastUsedAt']}')?.toLocal() ?? DateTime.now(),
          ),
      ],
      (r['max'] as num?)?.toInt() ?? 2,
      (r['maxWeb'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<void> signOutDevice(String id) async {
    await _api.post('/v1/doctor/devices/$id/sign-out', {});
  }

  @override
  Future<DoctorReport> loadReport(int days) async {
    final r = Map<String, dynamic>.from(await _api.get('/v1/doctor/reports', query: {'days': '$days'}) as Map);
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return DoctorReport(
      days: days,
      sessions: n('sessions'),
      booked: n('booked'),
      seen: n('seen'),
      missed: n('missed'),
      cancelled: n('cancelled'),
      emergency: n('emergency'),
      avgConsultMinutes: (r['avgConsultMinutes'] as num?)?.round(),
      showRate: (r['showRate'] as num?)?.round(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lines?.cancel();
    SessionStore.instance.removeListener(_sessionChanged);
    super.dispose();
  }
}
