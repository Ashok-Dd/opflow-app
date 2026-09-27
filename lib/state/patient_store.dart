import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../mock/data.dart';
import '../mock/format.dart';
import '../mock/models.dart';
import '../theme/tokens.dart';
import '../data/config.dart';
import 'patient_store_api.dart';
import 'session.dart';

/// The doctor's running status as a patient sees it.
class LiveStatus {
  const LiveStatus({
    required this.nowSeeing,
    required this.lateMinutes,
    required this.onBreak,
    required this.updated,
    this.ahead,
    this.myState,
    this.lowMinutes,
    this.highMinutes,
    this.message,
  });

  final int nowSeeing;
  final int lateMinutes;
  final bool onBreak;
  final DateTime updated;

  /// From the server (real line order: emergency patients, skips, people who did not come). Null in the demo,
  /// where the phone works it out from the token numbers.
  final int? ahead;

  /// not_come · waiting · with_doctor · done · did_not_come · cancelled · moved
  final String? myState;
  final int? lowMinutes;
  final int? highMinutes;
  final String? message;

  /// People before this booking: the server's count when there is one.
  int aheadOf(Booking b) => ahead ?? (b.token - nowSeeing - 1).clamp(0, 99);

  /// Called in right now (the server's word; the demo compares token numbers).
  bool isMyTurn(Booking b) => myState != null ? myState == 'with_doctor' : nowSeeing >= b.token;
}

/// Everything on the patient side: profile, bookings, messages and the live line. All fake.
/// Bookings are always for the logged-in patient (there are no family members).
class PatientStore extends ChangeNotifier {
  /// True while bookings and messages are coming from the server (API build only).
  bool get isLoading => false;

  PatientStore() {
    _seed();
    _startLiveTicker();
  }

  /// For [ApiPatientStore]: no sample data and no fake live line.
  PatientStore.base();

  PatientProfile me = const PatientProfile(name: 'Ravi Kumar', age: 42, gender: 'Male');
  final bookings = <Booking>[];
  final messages = <AppMessage>[];
  final _taken = <String>{};

  bool remindMe = true;
  bool lateAlerts = true;
  bool turnAlerts = true;

  /// Live line per booking id (only for today's bookings).
  final live = <String, LiveStatus>{};
  Timer? _ticker;
  int _ids = 100;

  Booking? booking(String id) => bookings.where((b) => b.id == id).firstOrNull;

  List<Booking> get upcoming => bookings.where((b) => b.status == BookingStatus.upcoming).toList()
    ..sort((a, b) => a.windowStart.compareTo(b.windowStart));

  List<Booking> get past => bookings.where((b) => b.status != BookingStatus.upcoming).toList()
    ..sort((a, b) => b.windowStart.compareTo(a.windowStart));

  Booking? get nextVisit => upcoming.firstOrNull;

  int get unread => messages.where((m) => m.unread).length;

  /// More old bookings / messages exist on the server (loaded as the list is scrolled). Mock: never.
  bool get hasMorePast => false;
  bool get hasMoreMessages => false;
  Future<void> loadMorePast() async {}
  Future<void> loadMoreMessages() async {}

  /// Doctors this patient has seen before, newest first, without repeats.
  List<Doctor> get visitedDoctors {
    final seen = <String>{};
    final out = <Doctor>[];
    for (final b in past) {
      if (seen.add(b.doctorId)) out.add(MockData.doctor(b.doctorId));
    }
    return out;
  }

  void updateMe({required String name, required int age, required String gender}) {
    me = PatientProfile(name: name, age: age, gender: gender);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Windows (includes places this user took in the mock)

  List<TimeWindow> windows(Doctor d, DateTime day) => MockData.windows(d, day, extraTaken: _taken);

  /// Hours at one hospital (with the API, each hour belongs to one hospital; mock hours have none).
  List<TimeWindow> windowsAt(Doctor d, DateTime day, String hospitalId) =>
      windows(d, day).where((w) => w.hospitalId == null || w.hospitalId == hospitalId).toList();

  // ---------------------------------------------------------------------------
  // Booking and paying

  /// The web version after Razorpay's bank page (redirect mode). Demo mode never redirects.
  Future<Booking?> settleReturned(String bookingId, {required bool checkoutSaidPaid}) async => null;

  /// Fake payment. [fail] lets the UI show the failed screen.
  Future<Booking?> payAndBook({
    required Doctor doctor,
    required String hospitalId,
    required DateTime day,
    required TimeWindow window,
    required String note,
    bool fail = false,
  }) async {
    await Future.delayed(OpMotion.fakeLong + const Duration(milliseconds: 400));
    if (fail) return null;
    final key = '${doctor.id}|${dateOnly(day).toIso8601String()}|${window.start}';
    _taken.add(key);
    final b = Booking(
      id: 'b${_ids++}',
      doctorId: doctor.id,
      hospitalId: hospitalId,
      date: dateOnly(day),
      start: window.start,
      token: _tokenFor(doctor, day, window),
      fee: doctor.fee,
      paymentId: 'pay_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      note: note,
      bookedAt: DateTime.now(),
    );
    bookings.add(b);
    _message(MessageKind.booked, 'Booking done',
        '${doctor.name} · ${dayLabel(day)}, ${windowLabel(window.start)} · Token ${b.token}', b.id);
    if (sameDay(day, DateTime.now())) _startLive(b);
    notifyListeners();
    return b;
  }

  /// Emergency consultation: seen first today, at the doctor's hospital. The patient pays the doctor's fee plus
  /// the emergency charge (all OPflow's). [fail] lets the UI show the failed screen.
  Future<Booking?> payEmergency({required Doctor doctor, required String hospitalId, required String note, bool fail = false}) async {
    await Future.delayed(OpMotion.fakeLong + const Duration(milliseconds: 400));
    if (fail) return null;
    final now = DateTime.now();
    final taken = bookings.where((b) => b.emergency && b.doctorId == doctor.id && sameDay(b.date, now)).length;
    final b = Booking(
      id: 'b${_ids++}',
      doctorId: doctor.id,
      hospitalId: hospitalId,
      date: dateOnly(now),
      start: now.hour,
      token: taken + 1,
      fee: doctor.fee,
      emergencyCharge: MockData.emergencyCharge(doctor.fee),
      paymentId: 'pay_${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      note: note,
      bookedAt: now,
      emergency: true,
    );
    bookings.add(b);
    _message(MessageKind.booked, 'Emergency consultation booked',
        '${doctor.name} will see you first. Go to ${MockData.hospital(hospitalId).name} now · Token ${b.tokenLabel}', b.id);
    notifyListeners();
    return b;
  }

  int _tokenFor(Doctor d, DateTime day, TimeWindow w) {
    final ws = MockData.windows(d, day);
    final index = ws.indexWhere((x) => x.start == w.start);
    return (index < 0 ? 0 : index) * w.capacity + w.booked + 1;
  }

  /// Why the patient can't change this booking, or null if they can.
  String? whyNoChange(Booking b) {
    if (b.status != BookingStatus.upcoming) return 'This booking is closed.';
    if (b.emergency) return 'Emergency consultations cannot be changed. Please go to the hospital now.';
    if (b.changedOnce) return 'You already changed this booking once.';
    if (DateTime.now().isAfter(b.windowStart.subtract(const Duration(hours: 2)))) {
      return 'Changes are allowed only up to 2 hours before your time.';
    }
    return null;
  }

  Future<void> changeTime(Booking b, DateTime day, TimeWindow w) async {
    await Future.delayed(OpMotion.fakeLong);
    final d = MockData.doctor(b.doctorId);
    b
      ..date = dateOnly(day)
      ..start = w.start
      ..token = _tokenFor(d, day, w)
      ..changedOnce = true;
    _taken.add('${d.id}|${dateOnly(day).toIso8601String()}|${w.start}');
    live.remove(b.id);
    if (sameDay(day, DateTime.now())) _startLive(b);
    _message(MessageKind.changed, 'Booking changed', '${d.name} · now ${dayLabel(day)}, ${windowLabel(w.start)} · Token ${b.token}', b.id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Messages and settings

  void _message(MessageKind kind, String title, String body, String? bookingId, {DateTime? time, bool unread = true}) {
    messages.insert(
        0, AppMessage(id: 'n${_ids++}', kind: kind, title: title, body: body, time: time ?? DateTime.now(), bookingId: bookingId, unread: unread));
  }

  void markAllRead() {
    for (final m in messages) {
      m.unread = false;
    }
    notifyListeners();
  }

  void markRead(AppMessage m) {
    m.unread = false;
    notifyListeners();
  }

  void setAlerts({bool? remind, bool? late, bool? turn}) {
    remindMe = remind ?? remindMe;
    lateAlerts = late ?? lateAlerts;
    turnAlerts = turn ?? turnAlerts;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Live line (fake): the token moves forward every few seconds.

  void _startLive(Booking b) {
    live[b.id] = LiveStatus(nowSeeing: (b.token - 5).clamp(1, b.token), lateMinutes: 20, onBreak: false, updated: DateTime.now());
  }

  void _startLiveTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 7), (_) {
      var changed = false;
      for (final b in upcoming.where((b) => live.containsKey(b.id))) {
        final s = live[b.id]!;
        if (s.nowSeeing < b.token) {
          final next = s.nowSeeing + 1;
          live[b.id] = LiveStatus(
            nowSeeing: next,
            lateMinutes: next.isEven ? 15 : 20,
            onBreak: false,
            updated: DateTime.now(),
          );
          if (next == b.token - 1 && turnAlerts) {
            _message(MessageKind.turn, 'Your turn is coming', 'Only 1 person before you. Please be near the doctor\'s room.', b.id);
          }
          changed = true;
        }
      }
      if (changed) notifyListeners();
    });
  }

  /// Pull-to-refresh in the mock: waits a moment and starts the line a few tokens back so it moves again.
  Future<void> refreshLive(Booking b) async {
    await Future.delayed(OpMotion.fakeShort);
    final s = live[b.id];
    if (s == null || s.nowSeeing >= b.token) {
      _startLive(b);
    } else {
      live[b.id] = LiveStatus(nowSeeing: s.nowSeeing, lateMinutes: s.lateMinutes, onBreak: s.onBreak, updated: DateTime.now());
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  void _seed() {
    final session = SessionStore.instance;
    if (session.profileDone) {
      me = PatientProfile(name: session.name, age: session.age, gender: session.gender);
    }

    final now = DateTime.now();
    final t = today();
    final hourToday = now.hour.clamp(9, 20);

    final todayBooking = Booking(
      id: 'b1',
      doctorId: 'd3',
      hospitalId: 'h1',
      date: t,
      start: hourToday,
      token: 18,
      fee: 300,
      paymentId: 'pay_OPF7Q2K9LX',
      note: 'Fever and body pain since 2 days',
      bookedAt: now.subtract(const Duration(days: 1)),
    );
    final later = Booking(
      id: 'b2',
      doctorId: 'd7',
      hospitalId: 'h4',
      date: t.add(const Duration(days: 3)),
      start: 11,
      token: 9,
      fee: 300,
      paymentId: 'pay_OPF7A11XQ3',
      note: 'Blurry vision in left eye',
      bookedAt: now.subtract(const Duration(days: 2)),
    );
    bookings.addAll([
      todayBooking,
      later,
      Booking(
        id: 'b3',
        doctorId: 'd3',
        hospitalId: 'h1',
        date: t.subtract(const Duration(days: 12)),
        start: 10,
        token: 12,
        fee: 250,
        paymentId: 'pay_OPF6ZZ81MC',
        status: BookingStatus.done,
      ),
      Booking(
        id: 'b4',
        doctorId: 'd6',
        hospitalId: 'h1',
        date: t.subtract(const Duration(days: 5)),
        start: 9,
        token: 4,
        fee: 400,
        paymentId: 'pay_OPF6Y20PLK',
        status: BookingStatus.cancelledByDoctor,
      ),
      Booking(
        id: 'b5',
        doctorId: 'd5',
        hospitalId: 'h5',
        date: t.subtract(const Duration(days: 30)),
        start: 17,
        token: 6,
        fee: 350,
        paymentId: 'pay_OPF5M7Q0RA',
        status: BookingStatus.missed,
      ),
    ]);
    _startLive(todayBooking);

    _message(MessageKind.refund, 'Money back sent', '₹400 for Dr. Ramesh Babu is sent back to your account. It reaches in 5–7 days.', 'b4',
        time: now.subtract(const Duration(days: 5)), unread: false);
    _message(MessageKind.cancelled, 'Doctor cancelled', 'Dr. Ramesh Babu cannot come on this day. Your full money will come back.', 'b4',
        time: now.subtract(const Duration(days: 5, minutes: 3)), unread: false);
    _message(MessageKind.booked, 'Booking done', 'Dr. Farah Khan · ${dayLabel(later.date)}, 11 AM – 12 PM · Token 9', 'b2',
        time: now.subtract(const Duration(days: 2)), unread: false);
    _message(MessageKind.booked, 'Booking done', 'Dr. K. Venkatesh · Today, ${windowLabel(hourToday)} · Token 18', 'b1',
        time: now.subtract(const Duration(days: 1)), unread: false);
    _message(MessageKind.reminder, 'Your time is today', 'Your visit with Dr. K. Venkatesh is at ${windowLabel(hourToday)}. Please reach 15 min early.', 'b1',
        time: now.subtract(const Duration(hours: 2)));
    _message(MessageKind.late, 'Doctor is 20 min late', 'Dr. K. Venkatesh is running about 20 minutes late today. You can come a little later.', 'b1',
        time: now.subtract(const Duration(minutes: 25)));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final patientProvider = ChangeNotifierProvider<PatientStore>((ref) => AppConfig.isApi ? ApiPatientStore() : PatientStore());
