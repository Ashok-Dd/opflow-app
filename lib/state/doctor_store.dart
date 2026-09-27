import '../l10n/lang.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../mock/data.dart';
import '../mock/format.dart';
import '../mock/models.dart';
import '../theme/tokens.dart';
import '../core/errors.dart';
import '../data/api.dart';
import '../data/live_socket.dart';
import '../data/config.dart';
import '../data/remote.dart';
import 'directory_store.dart';
import 'session.dart';

part 'doctor_store_api.dart';

enum OpdState { notStarted, running, onBreak, ended }

/// How a patient got into the line. Doctors cannot add patients themselves: every patient books in the app.
enum Source { online, emergency }

enum PatientState { notCome, waiting, withDoctor, done, didNotCome, cancelled, moved }

extension SourceText on Source {
  String get label => switch (this) {
        Source.online => 'Online'.tr,
        Source.emergency => 'Emergency'.tr,
      };
}

extension PatientStateText on PatientState {
  String get label => switch (this) {
        PatientState.notCome => 'Not come yet'.tr,
        PatientState.waiting => 'Waiting'.tr,
        PatientState.withDoctor => 'With doctor'.tr,
        PatientState.done => 'Done'.tr,
        PatientState.didNotCome => 'Did not come'.tr,
        PatientState.cancelled => 'Cancelled'.tr,
        PatientState.moved => 'Date changed'.tr,
      };
}

/// One patient in the doctor's line (today) or in the bookings list (other days).
class LinePatient {
  LinePatient({
    required this.id,
    required this.token,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.source,
    required this.hour,
    required this.date,
    this.state = PatientState.notCome,
    this.note = '',
    this.fee = 300,
    this.changed = false,
    this.hospitalId,
    this.hospitalName,
  }) : order = token * 10.0;

  /// Where this booking is. A doctor who works at two hospitals sees both in Bookings. Null: the hospital on screen.
  final String? hospitalId;
  final String? hospitalName;

  final String id;
  int token;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final Source source;
  int hour;
  DateTime date;
  PatientState state;
  final String note;
  final int fee;
  bool changed;

  /// Place in the line. Emergency patients go first, skipped patients go to the end.
  double order;

  /// Online tokens show as 01, 02…; emergency consultations as E1, E2…
  String get tokenLabel => source == Source.emergency ? 'E$token' : token.toString().padLeft(2, '0');
  DateTime? reachedAt;
  DateTime? calledAt;
  DateTime? doneAt;
}

class TimeBlock {
  TimeBlock({
    required this.start,
    required this.end,
    this.perHour = 8,
    this.takeEmergency = true,
    this.avgMinutes = 7,
  });

  int start;
  int end;
  int perHour;
  bool takeEmergency;
  int avgMinutes;

  TimeBlock copy() => TimeBlock(
      start: start, end: end, perHour: perHour, takeEmergency: takeEmergency, avgMinutes: avgMinutes);
}

class EarningRow {
  const EarningRow({required this.date, required this.patient, required this.fee, required this.paid, this.refunded = false});

  final DateTime date;
  final String patient;
  final int fee;

  /// Paid to the doctor's bank yet.
  final bool paid;
  final bool refunded;

  int get opflowShare => refunded ? 0 : (fee * 0.10).round();
  int get doctorShare => refunded ? 0 : fee - opflowShare;
}

class OpdSummary {
  const OpdSummary({required this.seen, required this.didNotCome, required this.avgMinutes, required this.lateBy, required this.stillWaiting});

  final int seen;
  final int didNotCome;
  final int avgMinutes;
  final int lateBy;
  final int stillWaiting;
}

/// The doctor side. All fake; a real API replaces this later.
/// One bank payout to the doctor (Cashfree): covers many visits. `failed` never reached the doctor; those
/// visits are paid again in a later payout.
class DoctorPayout {
  const DoctorPayout({required this.id, required this.amount, required this.visits, this.deducted, required this.status, this.bankReference, required this.sentAt});

  final String id;
  final String amount;
  final int visits;
  final String? deducted;
  final String status; // pending | success | failed
  final String? bankReference;
  final DateTime sentAt;
}

class DoctorPayouts {
  const DoctorPayouts({this.bankLast4, required this.hasBank, required this.bankActive, required this.items});

  final String? bankLast4;
  final bool hasBank;
  final bool bankActive;
  final List<DoctorPayout> items;
}

/// Where the doctor's account is signed in (GET /v1/doctor/devices).
class SignedInDevice {
  const SignedInDevice({required this.id, required this.device, required this.web, required this.thisDevice, required this.lastUsed});

  final String id;
  final String device;
  final bool web;
  final bool thisDevice;
  final DateTime lastUsed;
}

/// What the doctor did in a period (GET /v1/doctor/reports).
class DoctorReport {
  const DoctorReport({
    required this.days,
    required this.sessions,
    required this.booked,
    required this.seen,
    required this.missed,
    required this.cancelled,
    required this.emergency,
    this.avgConsultMinutes,
    this.showRate,
  });

  final int days;
  final int sessions;
  final int booked;
  final int seen;
  final int missed;
  final int cancelled;
  final int emergency;
  final int? avgConsultMinutes;
  final int? showRate;
}

class DoctorStore extends ChangeNotifier {
  /// False until the doctor's profile, hospitals and today's line have come from the server (API build).
  bool get isReady => true;

  /// A problem to show once (red note), then forgotten. Only the API store has them.
  String? takeNotice() => null;

  DoctorStore() {
    _seedSchedule();
    _seedToday();
  }

  /// For [ApiDoctorStore]: no sample patients, timings or fake arrivals.
  DoctorStore.base();

  /// The logged-in doctor (test account OPD-10234). Read fresh so profile edits show at once.
  Doctor get doctor => MockData.doctor('d1');
  String hospitalId = 'h1';
  Hospital get hospital => MockData.hospital(hospitalId);
  List<Hospital> get hospitals => doctor.hospitalIds.map(MockData.hospital).toList();

  // Emergency switch
  EmergencyStatus emergency = EmergencyStatus.off;
  String emergencyTill = '10 PM';
  String emergencyPlace = 'At hospital';

  void setEmergency(EmergencyStatus s, {String? till, String? place}) {
    emergency = s;
    if (till != null) emergencyTill = till;
    if (place != null) emergencyPlace = place;
    notifyListeners();
  }

  /// The state alone, under a small "EMERGENCY" in the top bar.
  String get emergencyShort => switch (emergency) {
        EmergencyStatus.off => 'Off'.tr,
        EmergencyStatus.availableNow => 'On now'.tr,
        EmergencyStatus.availableTill => 'Till {0}'.trf([emergencyTill]),
      };

  String get emergencyLabel => switch (emergency) {
        EmergencyStatus.off => 'Emergency: Off'.tr,
        EmergencyStatus.availableNow => 'Available now'.tr,
        EmergencyStatus.availableTill => 'Till {0}'.trf([emergencyTill]),
      };

  // ---------------------------------------------------------------------------
  // Pause bookings: patients can't book until the doctor resumes. Existing bookings stay.

  bool get bookingsPaused => doctor.bookingsPaused;

  Future<void> setBookingsPaused(bool paused) async {
    await DirectoryStore.instance.update(doctor.copyWith(bookingsPaused: paused));
    notifyListeners();
  }

  void switchHospital(String id) {
    if (id == hospitalId) return;
    hospitalId = id;
    _seedToday();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Today

  OpdState opd = OpdState.notStarted;
  int lateMinutes = 0;
  DateTime? startedAt;
  final line = <LinePatient>[];
  Timer? _arrivals;
  int _ids = 1000;
  final _rand = math.Random(7);

  int get opdStart => blocksFor(DateTime.now().weekday).firstOrNull?.start ?? 9;
  int get opdEnd => blocksFor(DateTime.now().weekday).firstOrNull?.end ?? 13;

  /// Start hour of a later OPD today at this hospital (e.g. 17 after a 9–1 morning), once this one has ended.
  /// Null when there is none. Mock: none.
  int? get nextOpdToday => null;

  LinePatient? get current => line.where((p) => p.state == PatientState.withDoctor).firstOrNull;

  List<LinePatient> get waitingInOrder =>
      line.where((p) => p.state == PatientState.waiting).toList()..sort((a, b) => a.order.compareTo(b.order));

  /// Who CALL NEXT calls: the next patient who has reached, else the next token still to come (same as the server).
  LinePatient? get nextToCall =>
      waitingInOrder.firstOrNull ??
      (line.where((p) => p.state == PatientState.notCome).toList()..sort((a, b) => a.order.compareTo(b.order))).firstOrNull;

  int count(PatientState s) => line.where((p) => p.state == s).length;
  int get onlineCount => line.where((p) => p.source == Source.online).length;
  int get emergencyCount => line.where((p) => p.source == Source.emergency).length;

  /// Patients grouped by hour for the line list.
  Map<int, List<LinePatient>> get lineByHour {
    final map = <int, List<LinePatient>>{};
    for (final p in [...line]..sort((a, b) => a.order.compareTo(b.order))) {
      map.putIfAbsent(p.hour, () => []).add(p);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Future<void> startOpd() async {
    await Future.delayed(OpMotion.fakeShort);
    opd = OpdState.running;
    startedAt = DateTime.now();
    // Patients of the first hour have mostly reached already.
    for (final p in line.where((p) => p.hour == opdStart && p.state == PatientState.notCome)) {
      if (_rand.nextInt(10) < 8) {
        p.state = PatientState.waiting;
        p.reachedAt = DateTime.now();
      }
    }
    _arrivals?.cancel();
    _arrivals = Timer.periodic(const Duration(seconds: 9), (_) => _someoneArrives());
    notifyListeners();
  }

  int _ticks = 0;

  void _someoneArrives() {
    if (opd != OpdState.running && opd != OpdState.onBreak) return;
    if (++_ticks == 2) _emergencyBookingArrives();
    final notCome = line.where((p) => p.state == PatientState.notCome).toList()..sort((a, b) => a.order.compareTo(b.order));
    if (notCome.isEmpty) return;
    final p = notCome.first;
    p.state = PatientState.waiting;
    p.reachedAt = DateTime.now();
    notifyListeners();
  }

  /// Finishes whoever is with the doctor and calls the next person. Returns the called patient.
  LinePatient? callNext() {
    final c = current;
    if (c != null) {
      c.state = PatientState.done;
      c.doneAt = DateTime.now();
    }
    final next = nextToCall;
    if (next != null) {
      next.reachedAt ??= DateTime.now();
      next.state = PatientState.withDoctor;
      next.calledAt = DateTime.now();
    }
    notifyListeners();
    return next;
  }

  void markDone() {
    final c = current;
    if (c == null) return;
    c.state = PatientState.done;
    c.doneAt = DateTime.now();
    notifyListeners();
  }

  void markDidNotCome(LinePatient p) {
    p.state = PatientState.didNotCome;
    notifyListeners();
  }

  /// "Skip for now": back to waiting, at the end of the line.
  void skip(LinePatient p) {
    p.state = PatientState.waiting;
    p.order = _maxOrder() + 1;
    notifyListeners();
  }

  void markReached(LinePatient p) {
    p.state = PatientState.waiting;
    p.reachedAt = DateTime.now();
    notifyListeners();
  }

  /// Call this person in now, ahead of others.
  void callNow(LinePatient p) {
    final c = current;
    if (c != null && c != p) {
      c.state = PatientState.waiting;
    }
    p.state = PatientState.withDoctor;
    p.calledAt = DateTime.now();
    notifyListeners();
  }

  void putBack(LinePatient p) {
    p.state = PatientState.waiting;
    p.order = _maxOrder() + 1;
    notifyListeners();
  }

  double _maxOrder() => line.fold<double>(0, (m, p) => math.max(m, p.order));
  double _minOrder() => line.fold<double>(0, (m, p) => math.min(m, p.order));

  /// Mock: a patient booked (and paid for) an emergency consultation in the app. They go to the top of the line.
  void _emergencyBookingArrives() {
    if (!doctor.hospitalIds.contains(hospitalId) || emergencyCount > 0) return;
    final hour = DateTime.now().hour.clamp(opdStart, opdEnd - 1);
    final p = LinePatient(
      id: 'l${_ids++}',
      token: emergencyCount + 1,
      name: 'Keerthana',
      age: 6,
      gender: 'Female',
      phone: '9876500123',
      source: Source.emergency,
      hour: hour,
      date: today(),
      state: PatientState.waiting,
      note: 'Emergency consultation: high fever and fits this morning',
      fee: doctor.fee,
    )..reachedAt = DateTime.now();
    p.order = _minOrder() - 1;
    line.add(p);
    // An emergency adds time for everyone after.
    lateMinutes += 10;
  }

  void setLate(int minutes) {
    lateMinutes = minutes;
    notifyListeners();
  }

  void toggleBreak() {
    opd = opd == OpdState.onBreak ? OpdState.running : OpdState.onBreak;
    notifyListeners();
  }

  OpdSummary summary() {
    final done = line.where((p) => p.state == PatientState.done && p.calledAt != null && p.doneAt != null).toList();
    final mins = done.isEmpty
        ? 7
        : (done.map((p) => p.doneAt!.difference(p.calledAt!).inSeconds).reduce((a, b) => a + b) / done.length / 60).round().clamp(1, 60);
    return OpdSummary(
      seen: count(PatientState.done),
      didNotCome: count(PatientState.didNotCome),
      avgMinutes: done.isEmpty ? 7 : mins,
      lateBy: lateMinutes,
      stillWaiting: count(PatientState.waiting) + count(PatientState.notCome) + count(PatientState.withDoctor),
    );
  }

  /// Ends today's OPD. People still in line are moved to tomorrow or cancelled with full money back.
  Future<void> endOpd({required bool moveLeftovers}) async {
    await Future.delayed(OpMotion.fakeLong);
    for (final p in line) {
      if (p.state == PatientState.waiting || p.state == PatientState.notCome || p.state == PatientState.withDoctor) {
        if (p.state == PatientState.withDoctor) {
          p.state = PatientState.done;
          p.doneAt = DateTime.now();
          continue;
        }
        p.state = moveLeftovers ? PatientState.moved : PatientState.cancelled;
      }
    }
    opd = OpdState.ended;
    _arrivals?.cancel();
    notifyListeners();
  }

  /// Mock only: lets the doctor start the day again.
  void resetDay() {
    _seedToday();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bookings on any day

  final _days = <String, List<LinePatient>>{};

  /// Patients booked on a day, not counting cancelled ones (the day strip).
  int bookedCount(DateTime day) => bookingsOn(day).where((p) => p.state != PatientState.cancelled).length;

  /// Someone is still coming that day (the leave calendar marks it).
  bool hasComing(DateTime day) => bookingsOn(day).any((p) => p.state == PatientState.notCome || p.state == PatientState.waiting);

  List<LinePatient> bookingsOn(DateTime day) {
    if (sameDay(day, DateTime.now())) return line.where((p) => p.source != Source.emergency).toList();
    final key = '${dateOnly(day).toIso8601String()}|$hospitalId';
    return _days.putIfAbsent(key, () => _makeDay(day));
  }

  LinePatient? findBooking(String id) {
    final all = [...line, ..._days.values.expand((l) => l)];
    return all.where((p) => p.id == id).firstOrNull;
  }

  /// Patients booked today at the doctor's OTHER hospitals, still to come. Mock: none.
  List<LinePatient> elsewhereToday() => const [];

  /// [bookingsOn], but sure to be complete (the API store waits for the server).
  Future<List<LinePatient>> loadBookingsOn(DateTime day) async => bookingsOn(day);

  /// The booking with this id, asking the server when it is not on the phone yet. Mock: [findBooking].
  Future<LinePatient?> fetchBooking(String id) async => findBooking(id);

  Future<void> cancelBooking(LinePatient p, String reason) async {
    await Future.delayed(OpMotion.fakeLong);
    p.state = PatientState.cancelled;
    notifyListeners();
  }

  Future<void> changeBooking(LinePatient p, DateTime day, int hour) async {
    await Future.delayed(OpMotion.fakeLong);
    // Remove from the old day and add to the new one.
    for (final l in [line, ..._days.values]) {
      l.remove(p);
    }
    p
      ..date = dateOnly(day)
      ..hour = hour
      ..changed = true
      ..state = PatientState.notCome;
    final target = bookingsOn(day);
    p.token = target.fold<int>(0, (m, x) => math.max(m, x.token)) + 1;
    p.order = p.token * 10.0;
    if (sameDay(day, DateTime.now())) {
      line.add(p);
    } else {
      target.add(p);
    }
    notifyListeners();
  }

  void markNoShow(LinePatient p) {
    p.state = PatientState.didNotCome;
    notifyListeners();
  }

  /// "I can't come on this day": cancel everyone with full money back.
  Future<(int, int)> cancelDay(DateTime day) async {
    await Future.delayed(OpMotion.fakeLong);
    var n = 0;
    var total = 0;
    for (final p in bookingsOn(day)) {
      if (p.state == PatientState.notCome || p.state == PatientState.waiting) {
        p.state = PatientState.cancelled;
        n++;
        total += p.fee;
      }
    }
    leaveDays.add(dateOnly(day));
    notifyListeners();
    return (n, total);
  }

  // ---------------------------------------------------------------------------
  // Timings

  /// hospitalId → weekday → blocks.
  final schedule = <String, Map<int, List<TimeBlock>>>{};
  final leaveDays = <DateTime>{};
  int openDaysBefore = 14;

  List<TimeBlock> blocksFor(int weekday, [String? hid]) => schedule[hid ?? hospitalId]?[weekday] ?? const [];

  /// True when the doctor has OPD hours on this weekday at any of their hospitals.
  bool worksOnWeekday(int weekday) =>
      schedule.isEmpty ? blocksFor(weekday).isNotEmpty : schedule.values.any((w) => (w[weekday] ?? const []).isNotEmpty);

  /// Places per hour at a hospital on a weekday (8 when unknown).
  int perHourAt(String? hid, int weekday) => blocksFor(weekday, hid).firstOrNull?.perHour ?? blocksFor(weekday).firstOrNull?.perHour ?? 8;

  /// A hospital's name, from its id (the doctor's own hospitals first).
  String hospitalName(String? hid) => hid == null ? hospital.name : (hospitals.where((h) => h.id == hid).firstOrNull?.name ?? hospital.name);

  Future<void> saveTimings(Map<int, List<TimeBlock>> week, int openBefore) async {
    await Future.delayed(OpMotion.fakeShort);
    schedule[hospitalId] = {for (final e in week.entries) e.key: e.value.map((b) => b.copy()).toList()};
    openDaysBefore = openBefore;
    notifyListeners();
  }

  Future<void> setLeave(Set<DateTime> days) async {
    await Future.delayed(OpMotion.fakeShort);
    leaveDays
      ..clear()
      ..addAll(days.map(dateOnly));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Earnings

  List<EarningRow> earnings(int days) {
    final out = <EarningRow>[];
    final r = math.Random(21);
    for (var i = 0; i < days; i++) {
      final day = today().subtract(Duration(days: i));
      if (day.weekday == 7) continue;
      final n = i == 0 ? count(PatientState.done) + 6 : 10 + r.nextInt(9);
      for (var k = 0; k < n; k++) {
        out.add(EarningRow(
          date: day,
          patient: _names[r.nextInt(_names.length)].$1,
          fee: doctor.fee,
          paid: i >= 2,
          refunded: r.nextInt(25) == 0,
        ));
      }
    }
    return out;
  }

  /// Bank payouts (GET /v1/doctor/payouts). Demo: two sample payouts.
  Future<DoctorPayouts> loadPayouts() async {
    await Future.delayed(OpMotion.fakeShort);
    final now = DateTime.now();
    return DoctorPayouts(
      bankLast4: '4321',
      hasBank: true,
      bankActive: true,
      items: [
        DoctorPayout(id: 'po2', amount: '₹6,480', visits: 24, status: 'pending', sentAt: now.subtract(const Duration(hours: 2))),
        DoctorPayout(id: 'po1', amount: '₹5,940', visits: 22, status: 'success', bankReference: 'UTR2026092712345', sentAt: now.subtract(const Duration(days: 1))),
      ],
    );
  }

  /// Phones (and the website) this account is signed in on, with the limits. Demo: just this phone.
  Future<(List<SignedInDevice>, int, int)> devices() async {
    await Future.delayed(OpMotion.fakeShort);
    return (
      [
        SignedInDevice(id: 'd1', device: 'This phone', web: false, thisDevice: true, lastUsed: DateTime.now()),
        SignedInDevice(id: 'd2', device: 'Chrome on Windows', web: true, thisDevice: false, lastUsed: DateTime.now().subtract(const Duration(hours: 5))),
      ],
      2,
      1,
    );
  }

  /// Signs another device out (it needs the OPD ID and password to come back).
  Future<void> signOutDevice(String id) async => Future.delayed(OpMotion.fakeShort);

  /// The doctor's report for the last [days] days (the same figures as the doctor website).
  Future<DoctorReport> loadReport(int days) async {
    await Future.delayed(OpMotion.fakeShort);
    final r = math.Random(days);
    final sessions = (days * 6 / 7).round();
    final booked = sessions * (20 + r.nextInt(6));
    final missed = (booked * 0.06).round();
    final cancelled = (booked * 0.02).round();
    final seen = booked - missed - cancelled;
    return DoctorReport(
      days: days,
      sessions: sessions,
      booked: booked,
      seen: seen,
      missed: missed,
      cancelled: cancelled,
      emergency: (days / 10).round(),
      avgConsultMinutes: 7,
      showRate: ((seen / (seen + missed)) * 100).round(),
    );
  }

  // ---------------------------------------------------------------------------
  // Seed data

  static const _names = [
    ('Aarav', 'Male'), ('Lasya', 'Female'), ('Bhavya', 'Female'), ('Charan', 'Male'), ('Deepika', 'Female'),
    ('Eshwar', 'Male'), ('Gowtham', 'Male'), ('Harshini', 'Female'), ('Ishaan', 'Male'), ('Jahnavi', 'Female'),
    ('Karthik', 'Male'), ('Likhitha', 'Female'), ('Manoj', 'Male'), ('Navya', 'Female'), ('Omkar', 'Male'),
    ('Pranavi', 'Female'), ('Rithvik', 'Male'), ('Sahasra', 'Female'), ('Tanvi', 'Female'), ('Uday', 'Male'),
    ('Varshith', 'Male'), ('Yamini', 'Female'), ('Zoya', 'Female'), ('Abhiram', 'Male'), ('Chaitra', 'Female'),
  ];

  static const _notes = [
    'Fever since 2 days', 'Cough and cold', 'Not eating well', 'Vaccine due', 'Stomach pain at night',
    'Rash on hands', 'Ear pain', 'Follow-up visit', 'Loose motions', 'Weight check', '', '',
  ];

  List<LinePatient> _makeDay(DateTime day) {
    final blocks = blocksFor(day.weekday);
    if (blocks.isEmpty || leaveDays.contains(dateOnly(day))) return [];
    final r = math.Random(day.day * 100 + day.month + hospitalId.hashCode);
    final out = <LinePatient>[];
    var token = 1;
    final ahead = dateOnly(day).difference(today()).inDays;
    for (final b in blocks) {
      for (var h = b.start; h < b.end; h++) {
        final n = ahead <= 2 ? 4 + r.nextInt(b.perHour - 3) : r.nextInt(b.perHour - 2);
        for (var k = 0; k < n; k++) {
          final (name, gender) = _names[r.nextInt(_names.length)];
          out.add(LinePatient(
            id: 'l${_ids++}',
            token: token++,
            name: name,
            age: 1 + r.nextInt(15),
            gender: gender,
            phone: '9${(100000000 + r.nextInt(899999999))}',
            source: Source.online,
            hour: h,
            date: dateOnly(day),
            note: _notes[r.nextInt(_notes.length)],
            fee: doctor.fee,
            changed: r.nextInt(12) == 0,
          ));
        }
      }
    }
    return out;
  }

  void _seedToday() {
    _arrivals?.cancel();
    opd = OpdState.notStarted;
    lateMinutes = 0;
    startedAt = null;
    line
      ..clear()
      ..addAll(_makeDayForToday());
  }

  List<LinePatient> _makeDayForToday() {
    final r = math.Random(99 + hospitalId.hashCode);
    final out = <LinePatient>[];
    var token = 1;
    final start = opdStart;
    final end = opdEnd;
    for (var h = start; h < end; h++) {
      final n = h == start ? 8 : (h == start + 1 ? 7 : 3 + r.nextInt(3));
      for (var k = 0; k < n; k++) {
        final (name, gender) = _names[(token * 7) % _names.length];
        out.add(LinePatient(
          id: 'l${_ids++}',
          token: token++,
          name: name,
          age: 1 + r.nextInt(15),
          gender: gender,
          phone: '9${(100000000 + r.nextInt(899999999))}',
          source: Source.online,
          hour: h,
          date: today(),
          note: _notes[r.nextInt(_notes.length)],
          fee: doctor.fee,
        ));
      }
    }
    return out;
  }

  void _seedSchedule() {
    for (final hid in doctor.hospitalIds) {
      final week = <int, List<TimeBlock>>{};
      for (var d = 1; d <= 7; d++) {
        if (hid == 'h1') {
          week[d] = d == 7 ? [] : [TimeBlock(start: 9, end: 13)];
        } else {
          week[d] = d == 7 ? [] : [TimeBlock(start: 17, end: 19, perHour: 6)];
        }
      }
      schedule[hid] = week;
    }
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    super.dispose();
  }
}

final doctorProvider = ChangeNotifierProvider<DoctorStore>((ref) => AppConfig.isApi ? ApiDoctorStore() : DoctorStore());
