import 'dart:async';

import '../data/api.dart';
import '../data/checkout.dart';
import '../data/live_socket.dart';
import '../data/remote.dart';
import '../mock/data.dart';
import '../mock/format.dart';
import '../mock/models.dart';
import 'patient_store.dart';
import 'session.dart';

/// The patient side on the real API. Same methods as [PatientStore], so the screens don't change.
class ApiPatientStore extends PatientStore {
  ApiPatientStore() : super.base() {
    final s = SessionStore.instance;
    if (s.profileDone) me = PatientProfile(name: s.name, age: s.age, gender: s.gender);
    Remote.instance.addListener(notifyListeners); // hours of a day arrive
    _side = s.side;
    s.addListener(_sessionChanged);
    if (s.side == Side.patient) refresh();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _pollLive());
    // The live line arrives by WebSocket the moment it changes; the 15-second check stays as a safety net.
    _boards = LiveSocket.instance.boards.listen(_onBoard);
  }

  StreamSubscription<Map<String, dynamic>>? _boards;

  void _onBoard(Map<String, dynamic> r) {
    final sessionId = r['sessionId'] as String?;
    var changed = false;
    for (final b in upcoming.where((b) => b.sessionId == sessionId)) {
      live[b.id] = _liveFrom(r);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  static LiveStatus _liveFrom(Map<String, dynamic> r) => LiveStatus(
        nowSeeing: int.tryParse(((r['nowSeeing'] as String?) ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0,
        lateMinutes: ((r['lateMinutes'] as num?) ?? 0).toInt(),
        onBreak: r['onBreak'] == true,
        updated: DateTime.now(),
        ahead: (r['ahead'] as num?)?.toInt(),
        myState: r['myState'] as String?,
        lowMinutes: ((r['eta'] as Map?)?['lowMinutes'] as num?)?.toInt(),
        highMinutes: ((r['eta'] as Map?)?['highMinutes'] as num?)?.toInt(),
        message: r['message'] as String?,
      );

  Api get _api => Api.instance;
  Side _side = Side.none;

  /// Logged in or out: never show one person's bookings to the next.
  void _sessionChanged() {
    final s = SessionStore.instance;
    if (s.side == _side) return;
    _side = s.side;
    bookings.clear();
    messages.clear();
    live.clear();
    if (s.side != Side.patient) LiveSocket.instance.close();
    if (s.side == Side.patient) {
      if (s.profileDone) me = PatientProfile(name: s.name, age: s.age, gender: s.gender);
      refresh();
    }
    notifyListeners();
  }
  Timer? _poll;
  bool loading = false;

  @override
  bool get isLoading => loading;

  /// Bookings, messages and alert settings from the server.
  Future<void> refresh() async {
    if (SessionStore.instance.side != Side.patient) return;
    loading = true;
    try {
      final up = await _api.get('/v1/bookings', query: {'tab': 'upcoming', 'limit': 50}) as Map;
      // Old visits: the first page only; more come as the list is scrolled.
      final past = await _api.get('/v1/bookings', query: {'tab': 'past', 'limit': 20}) as Map;
      _pastCursor = past['nextCursor'] as String?;
      bookings
        ..clear()
        ..addAll([
          for (final b in [...(up['items'] as List), ...(past['items'] as List)].cast<Map>())
            if (_visible(b)) _booking(Map<String, dynamic>.from(b)),
        ]);
      await _loadMessages();
      final prefs = await _api.get('/v1/me/notification-prefs') as Map;
      remindMe = prefs['reminders'] != false;
      lateAlerts = prefs['lateAlerts'] != false;
      turnAlerts = prefs['turnAlerts'] != false;
      await _pollLive();
    } on ApiException {
      // Shown as "could not load" by screens that care; the app keeps working with what it has.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static bool _visible(Map b) => b['status'] != 'expired' && b['status'] != 'pending_payment';

  String? _pastCursor;
  bool _loadingPast = false;
  String? _msgCursor;
  bool _loadingMsgs = false;
  String? _newestMsgAt;
  int? _serverUnread;

  @override
  bool get hasMorePast => _pastCursor != null;
  @override
  bool get hasMoreMessages => _msgCursor != null;
  @override
  int get unread => _serverUnread ?? super.unread;

  @override
  Future<void> loadMorePast() async {
    final cursor = _pastCursor;
    if (cursor == null || _loadingPast) return;
    _loadingPast = true;
    try {
      final r = await _api.get('/v1/bookings', query: {'tab': 'past', 'limit': 20, 'cursor': cursor}) as Map;
      for (final b in (r['items'] as List).cast<Map>()) {
        if (_visible(b)) _upsert(_booking(Map<String, dynamic>.from(b)));
      }
      _pastCursor = r['nextCursor'] as String?;
      notifyListeners();
    } on ApiException {
      // Keep what is shown; scrolling again retries.
    } finally {
      _loadingPast = false;
    }
  }

  AppMessage _message(Map m) => AppMessage(
        id: m['id'] as String,
        kind: messageKindFrom(m['kind'] as String?),
        title: m['title'] as String,
        body: m['body'] as String,
        time: DateTime.parse(m['createdAt'] as String).toLocal(),
        bookingId: m['bookingId'] as String?,
        unread: m['readAt'] == null,
      );

  /// The newest 30 messages (on open and after a change). Older ones come with [loadMoreMessages].
  Future<void> _loadMessages() async {
    final r = await _api.get('/v1/notifications', query: {'limit': 30}) as Map;
    final items = (r['items'] as List).cast<Map>();
    messages
      ..clear()
      ..addAll([for (final m in items) _message(m)]);
    _msgCursor = r['nextCursor'] as String?;
    _serverUnread = (r['unread'] as num?)?.toInt();
    _newestMsgAt = items.isEmpty ? _newestMsgAt : items.first['createdAt'] as String;
  }

  /// The regular check: only messages newer than the newest one on the phone (usually none).
  Future<void> _loadNewMessages() async {
    final after = _newestMsgAt;
    if (after == null) return _loadMessages();
    final r = await _api.get('/v1/notifications', query: {'limit': 50, 'after': after}) as Map;
    final items = (r['items'] as List).cast<Map>();
    _serverUnread = (r['unread'] as num?)?.toInt();
    if (items.isEmpty) return;
    final known = messages.map((m) => m.id).toSet();
    messages.insertAll(0, [for (final m in items) if (!known.contains(m['id'])) _message(m)]);
    _newestMsgAt = items.first['createdAt'] as String;
  }

  @override
  Future<void> loadMoreMessages() async {
    final cursor = _msgCursor;
    if (cursor == null || _loadingMsgs) return;
    _loadingMsgs = true;
    try {
      final r = await _api.get('/v1/notifications', query: {'limit': 30, 'cursor': cursor}) as Map;
      final known = messages.map((m) => m.id).toSet();
      messages.addAll([for (final m in (r['items'] as List).cast<Map>()) if (!known.contains(m['id'])) _message(m)]);
      _msgCursor = r['nextCursor'] as String?;
      notifyListeners();
    } on ApiException {
      // Keep what is shown.
    } finally {
      _loadingMsgs = false;
    }
  }

  /// A booking as the screens know it. Doctors/hospitals not in today's list are added, so tickets always
  /// show the right names.
  Booking _booking(Map<String, dynamic> b) {
    final doctor = Map<String, dynamic>.from(b['doctor'] as Map);
    final hospital = Map<String, dynamic>.from(b['hospital'] as Map);
    if (MockData.findDoctor(doctor['id'] as String) == null) {
      MockData.doctors.add(Doctor(
        id: doctor['id'] as String,
        name: doctor['name'] as String,
        typeId: MockData.types.where((t) => t.simple == doctor['type']).firstOrNull?.id ?? 'general',
        degrees: '',
        years: 0,
        languages: const [],
        fee: ((b['fee'] as Map)['paise'] as num) ~/ 100,
        hospitalIds: [hospital['id'] as String],
        workDays: const [],
        sessions: const [],
        gender: '',
        photoUrl: (doctor['photo'] as Map?)?['m'] as String?,
      ));
    }
    if (MockData.findHospital(hospital['id'] as String) == null) {
      MockData.hospitals = [...MockData.hospitals, Remote.hospitalFrom(hospital)];
    }
    final status = switch (b['status']) {
      'completed' => BookingStatus.done,
      'no_show' => BookingStatus.missed,
      'cancelled_by_provider' => BookingStatus.cancelledByDoctor,
      _ => (b['queueState'] == 'done' ? BookingStatus.done : b['queueState'] == 'did_not_come' ? BookingStatus.missed : BookingStatus.upcoming),
    };
    final refunds = ((b['refunds'] as List?) ?? const []).cast<Map>();
    return Booking(
      id: b['id'] as String,
      doctorId: doctor['id'] as String,
      hospitalId: hospital['id'] as String,
      date: Remote.dateOf(b['date'] as String),
      start: Remote.istHour((b['time'] as Map)['startsAt'] as String),
      token: (b['token'] as num).toInt(),
      fee: ((b['fee'] as Map)['paise'] as num) ~/ 100,
      emergencyCharge: ((b['emergencyCharge'] as Map)['paise'] as num) ~/ 100,
      paymentId: ((b['payment'] as Map?)?['orderId'] as String?) ?? '',
      note: (b['note'] as String?) ?? '',
      status: status,
      changedOnce: b['changedOnce'] == true,
      bookedAt: DateTime.tryParse((b['createdAt'] as String?) ?? '')?.toLocal(),
      emergency: b['emergency'] == true,
      code: b['code'] as String?,
      sessionId: b['sessionId'] as String?,
      serverWhyNoChange: b['whyNoChange'] as String?,
      needsNewTime: b['needsNewTime'] == true,
      refundLabel: refunds.isEmpty ? null : refunds.last['label'] as String?,
    );
  }

  void _upsert(Booking b) {
    bookings.removeWhere((x) => x.id == b.id);
    bookings.add(b);
  }

  @override
  List<Doctor> get visitedDoctors {
    final seen = <String>{};
    return [
      for (final b in past)
        if (seen.add(b.doctorId) && MockData.findDoctor(b.doctorId) != null) MockData.findDoctor(b.doctorId)!,
    ];
  }

  // ── Booking and paying ─────────────────────────────────────────────────────────────────────────

  /// Hold the place → pay (Razorpay Checkout, or the local stand-in) → the server confirms.
  /// Returns null when the payment did not go through (no money taken; the screen offers "try again").
  /// Other problems (time just got full, bookings paused…) are thrown with the server's message.
  @override
  Future<Booking?> payAndBook({
    required Doctor doctor,
    required String hospitalId,
    required DateTime day,
    required TimeWindow window,
    required String note,
    bool fail = false,
  }) async {
    final windowId = window.id;
    if (windowId == null) throw ApiException('WINDOW_NOT_FOUND', 'This time is not available any more. Please pick another.');
    final hold = Map<String, dynamic>.from(await _api.postOnce('/v1/bookings/hold', {'windowId': windowId, 'note': ?(note.isEmpty ? null : note)}) as Map);
    return _payAndConfirm(hold, '${doctor.name} · ${dayLabel(day)}', fail, doctor.id);
  }

  @override
  Future<Booking?> payEmergency({required Doctor doctor, required String hospitalId, required String note, bool fail = false}) async {
    final hold = Map<String, dynamic>.from(await _api.postOnce('/v1/bookings/emergency', {'doctorId': doctor.id}) as Map);
    return _payAndConfirm(hold, 'Emergency consultation · ${doctor.name}', fail, doctor.id);
  }

  Future<Booking?> _payAndConfirm(Map<String, dynamic> hold, String description, bool fail, String doctorId) async {
    final payment = Map<String, dynamic>.from(hold['payment'] as Map);
    final bookingId = (hold['booking'] as Map)['id'] as String;
    CheckoutResult? paid;
    try {
      paid = await payOrder(payment, description: description, fail: fail, phone: _phone);
    } on ApiException {
      // Checkout said failed / cancelled / too long. That is not proof: UPI apps and weak signal can report a
      // failure after the money was taken. The server (and through it Razorpay) decides, below.
    }
    if (paid != null) {
      try {
        final v = Map<String, dynamic>.from(await _api.post('/v1/payments/verify', paid) as Map);
        final raw = Map<String, dynamic>.from(v['booking'] as Map);
        // Only the server's own word "confirmed" means booked (a booking waiting for payment is not).
        if (raw['status'] == 'confirmed') return _booked(_booking(raw), doctorId);
        // "processing" (UPI still settling) or anything else: settle it with the server below.
      } on ApiException {
        // The confirm call failed (no signal, slow server): settle it below. Never tell "failed" from this alone.
      }
    }
    return _settle(bookingId, doctorId, checkoutSucceeded: paid != null);
  }

  /// Asks the server "was I charged?" a few times (Razorpay's own message can take a few seconds).
  /// Booked → the booking. Clearly not paid → null ("payment did not go through"). Still unknown (no internet)
  /// → a calm message: the booking appears by itself, or the money comes back automatically.
  Future<Booking?> _settle(String bookingId, String doctorId, {required bool checkoutSucceeded}) async {
    var reached = false;
    for (var i = 0; i < 6; i++) {
      try {
        final r = Map<String, dynamic>.from(await _api.post('/v1/payments/$bookingId/check') as Map);
        reached = true;
        if (r['status'] == 'confirmed') return _booked(_booking(Map<String, dynamic>.from(r['booking'] as Map)), doctorId);
        // Not paid (yet). If Checkout itself said failed or cancelled, one clear answer is enough.
        if (!checkoutSucceeded && r['paid'] != true && i >= 1) return null;
      } on ApiException {
        // No answer this time; try again shortly.
      }
      await Future<void>.delayed(Duration(seconds: i < 2 ? 2 : 3));
    }
    if (reached && !checkoutSucceeded) return null;
    unawaited(refresh());
    throw ApiException(
      'PAYMENT_UNSURE',
      'We are still confirming your payment. Please check My bookings in a minute. If money was taken and there is no booking, it comes back automatically.',
      retryable: true,
    );
  }

  Booking _booked(Booking b, String doctorId) {
    _upsert(b);
    Remote.instance.forgetDoctor(doctorId);
    unawaited(_loadMessages().then((_) => notifyListeners()).catchError((_) {}));
    notifyListeners();
    return b;
  }

  String? get _phone {
    final p = SessionStore.instance.phone.replaceAll(RegExp(r'\D'), '');
    return p.isEmpty ? null : p;
  }

  @override
  String? whyNoChange(Booking b) => b.serverWhyNoChange;

  @override
  Future<void> changeTime(Booking b, DateTime day, TimeWindow w) async {
    if (w.id == null) throw ApiException('WINDOW_NOT_FOUND', 'This time is not available any more. Please pick another.');
    final r = Map<String, dynamic>.from(await _api.postOnce('/v1/bookings/${b.id}/reschedule', {'windowId': w.id}) as Map);
    _upsert(_booking(r));
    Remote.instance.forgetDoctor(b.doctorId);
    live.remove(b.id);
    notifyListeners();
  }

  // ── Messages and settings ──────────────────────────────────────────────────────────────────────

  @override
  void markAllRead() {
    _serverUnread = 0;
    super.markAllRead();
    _api.post('/v1/notifications/read', {'all': true}).catchError((_) => null);
  }

  @override
  void markRead(AppMessage m) {
    if (m.unread && _serverUnread != null && _serverUnread! > 0) _serverUnread = _serverUnread! - 1;
    super.markRead(m);
    _api.post('/v1/notifications/read', {'ids': [m.id]}).catchError((_) => null);
  }

  @override
  void setAlerts({bool? remind, bool? late, bool? turn}) {
    super.setAlerts(remind: remind, late: late, turn: turn);
    _api.patch('/v1/me/notification-prefs', {'reminders': remindMe, 'lateAlerts': lateAlerts, 'turnAlerts': turnAlerts}).catchError((_) => null);
  }

  // ── Live line (today's visits): the server's board, checked every 15 seconds ────────────────────

  int _polls = 0;

  Future<void> _pollLive() async {
    if (SessionStore.instance.side != Side.patient) return;
    var changed = false;
    // New messages ("Your turn is coming", "Doctor is late") every other check.
    if (++_polls % 2 == 0) {
      try {
        await _loadNewMessages();
        changed = true;
      } on ApiException {
        // keep the last list
      }
    }
    final today = upcoming.where((b) => sameDay(b.date, DateTime.now()) && b.sessionId != null).toList();
    unawaited(LiveSocket.instance.follow(today.map((b) => b.sessionId!)));
    // While the WebSocket is up it brings every change; the check then runs once a minute only.
    if (LiveSocket.instance.connected && _polls % 4 != 0) {
      if (changed) notifyListeners();
      return;
    }
    for (final b in today) {
      try {
        final r = Map<String, dynamic>.from(await _api.get('/v1/live/sessions/${b.sessionId}') as Map);
        live[b.id] = _liveFrom(r);
        changed = true;
      } on ApiException {
        // Not started yet / not reachable: keep the last known board.
      }
    }
    if (changed) notifyListeners();
  }

  @override
  Future<void> refreshLive(Booking b) async {
    await refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _boards?.cancel();
    Remote.instance.removeListener(notifyListeners);
    SessionStore.instance.removeListener(_sessionChanged);
    super.dispose();
  }
}
