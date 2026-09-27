import 'dart:async';

import '../core/errors.dart';
import 'package:flutter/material.dart';

import '../mock/data.dart';
import '../mock/format.dart';
import '../mock/models.dart';
import 'api.dart';
import 'config.dart';
import '../state/session.dart';

/// Server data in the shapes the screens already use. In API mode, [MockData]'s lists (types, problems,
/// emergencies, hospitals, doctors) are replaced with what the server sends, and time windows come from here.
class Remote extends ChangeNotifier {
  Remote._();
  static final instance = Remote._();

  Api get api => Api.instance;

  bool loaded = false;
  ApiException? error;

  /// True while the doctors and hospitals are being fetched (the screens show the OP loader).
  bool busy = false;
  Future<void>? _inFlight;
  Timer? _retry;

  /// Screens call this: starts a load if nothing is loaded yet (the server may be waking up), and keeps
  /// retrying every 10 seconds until it works. Safe to call often.
  void ensureLoaded() {
    if (!AppConfig.isApi || loaded) return;
    // First time: load now. After a failure: only the 10-second retries (or "Try again"), never a tight loop.
    if (!busy && error == null) unawaited(loadDirectory());
    _retry ??= Timer.periodic(const Duration(seconds: 10), (t) {
      if (loaded) {
        t.cancel();
        _retry = null;
      } else if (!busy) {
        unawaited(loadDirectory());
      }
    });
  }
  final _nextFree = <String, (DateTime, TimeWindow)?>{};
  final _windows = <String, List<TimeWindow>>{};
  final _loading = <String>{};

  // Icons the app already draws for each id (the server only knows icon names).
  static final _typeIcons = {for (final t in MockData.types) t.id: t.icon};
  static final _problemIcons = {for (final p in MockData.problems) p.id: p.icon};
  static final _kindIcons = {for (final k in MockData.emergencyKinds) k.id: k.icon};

  /// API mode, before the first load: remember the app's icons, then empty the sample doctors and hospitals so
  /// they can never be shown or booked.
  void prepare() {
    _typeIcons.length;
    _problemIcons.length;
    _kindIcons.length;
    MockData.doctors.clear();
    MockData.hospitals = const [];
  }

  /// Tests only: stop the background retries.
  @visibleForTesting
  void stopRetrying() {
    _retry?.cancel();
    _retry = null;
  }

  /// Emergency help, live from the server: 24-hour hospitals and the doctors whose emergency switch is on
  /// right now ([kind] narrows them to the right kind of doctor). The doctor list in the app is updated too, so a
  /// doctor who just switched on (or off) shows correctly everywhere.
  Future<({List<Hospital> hospitals, List<Doctor> doctors, bool enabled})> emergencyNear({String? kind}) async {
    final s = SessionStore.instance;
    final r = Map<String, dynamic>.from(await api.get('/v1/emergency/near', auth: false, query: {
      'kind': ?kind,
      'lat': s.placeLat ?? AppConfig.nearLat,
      'lng': s.placeLng ?? AppConfig.nearLng,
    }) as Map);
    final hospitals = [for (final h in ((r['hospitals'] as List?) ?? const []).cast<Map>()) hospitalFrom(Map<String, dynamic>.from(h))];
    for (final h in hospitals) {
      if (MockData.findHospital(h.id) == null) MockData.hospitals = [...MockData.hospitals, h];
    }
    final doctors = [for (final d in ((r['doctors'] as List?) ?? const []).cast<Map>()) doctorFrom(Map<String, dynamic>.from(d))];
    final on = {for (final d in doctors) d.id: d};
    for (var i = 0; i < MockData.doctors.length; i++) {
      final d = MockData.doctors[i];
      final now = on[d.id];
      if (now != null) {
        MockData.doctors[i] = d.copyWith(emergency: now.emergency, emergencyTill: now.emergencyTill);
      } else if (kind == null && d.emergency != EmergencyStatus.off) {
        MockData.doctors[i] = d.copyWith(emergency: EmergencyStatus.off); // switched off since the list loaded
      }
    }
    for (final d in doctors) {
      if (MockData.findDoctor(d.id) == null) MockData.doctors.add(d);
    }
    notifyListeners();
    return (hospitals: hospitals, doctors: doctors, enabled: r['enabled'] != false);
  }

  /// Catalog, hospitals and doctors. Safe to call again (pull to refresh); calls at the same time share one load.
  Future<void> loadDirectory() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    busy = true;
    notifyListeners();
    try {
      final cat = Map<String, dynamic>.from(await api.get('/v1/catalog', auth: false) as Map);
      MockData.types = [
        for (final t in (cat['doctorTypes'] as List).cast<Map>())
          DoctorType(t['id'] as String, t['simpleName'] as String, t['properName'] as String, _typeIcons[t['id']] ?? Icons.medical_services_outlined),
      ];
      MockData.commonTypeIds = (cat['commonTypeIds'] as List).cast<String>();
      MockData.problems = [
        for (final p in (cat['healthProblems'] as List).cast<Map>())
          HealthProblem(p['id'] as String, p['name'] as String, _problemIcons[p['id']] ?? Icons.healing,
              (p['adultTypeIds'] as List).cast<String>(), (p['childTypeIds'] as List).cast<String>(),
              danger: p['isDanger'] == true),
      ];
      MockData.emergencyKinds = [
        for (final k in (cat['emergencyKinds'] as List).cast<Map>())
          EmergencyKind(k['id'] as String, k['name'] as String, k['detail'] as String, _kindIcons[k['id']] ?? Icons.emergency_outlined,
              (k['typeIds'] as List).cast<String>()),
      ];
      final rules = (cat['rules'] as Map?) ?? const {};
      if (rules['emergencyChargePercent'] is num) MockData.emergencyChargePercent = (rules['emergencyChargePercent'] as num).toInt();

      // The patient's area (asked at sign-up); Guntur centre until one is chosen.
      final s = SessionStore.instance;
      final near = '${s.placeLat ?? AppConfig.nearLat},${s.placeLng ?? AppConfig.nearLng}';
      final hs = await api.get('/v1/hospitals', query: {'near': near, 'limit': 50}, auth: false) as Map;
      MockData.hospitals = [for (final h in (hs['items'] as List).cast<Map>()) hospitalFrom(Map<String, dynamic>.from(h))];

      final ds = await api.get('/v1/doctors', query: {'near': near, 'limit': 50}, auth: false) as Map;
      final doctors = <Doctor>[];
      _nextFree.clear();
      for (final raw in (ds['items'] as List).cast<Map>()) {
        final c = Map<String, dynamic>.from(raw);
        doctors.add(doctorFrom(c));
        _nextFree[c['id'] as String] = _nextFreeFrom(c['nextFree']);
      }
      final keep = MockData.doctors.where((d) => !doctors.any((x) => x.id == d.id) && _isOwnDoctor(d.id)).toList();
      MockData.doctors
        ..clear()
        ..addAll(doctors)
        ..addAll(keep);
      _windows.clear();
      loaded = true;
      error = null;
    } on ApiException catch (e) {
      error = e;
    } catch (e, st) {
      // No internet, a broken answer…: the screens offer "Try again" either way.
      ErrorReporter.report(e, st, where: 'remote.loadDirectory');
      error = ApiException('LOAD_FAILED', 'Could not load doctors. Please check your internet.', retryable: true);
    } finally {
      busy = false;
    }
    notifyListeners();
  }

  /// The logged-in doctor may not be listed yet (not verified): keep their entry.
  String? ownDoctorId;
  bool _isOwnDoctor(String id) => id == ownDoctorId;

  (DateTime, TimeWindow)? nextFree(String doctorId) => _nextFree[doctorId];

  /// A doctor card that came with another answer (OPflow's suggestions): known to every list and card.
  Doctor rememberDoctorCard(Map<String, dynamic> c) {
    final d = doctorFrom(c);
    if (c['nextFree'] != null) _nextFree[d.id] = _nextFreeFrom(c['nextFree']);
    final i = MockData.doctors.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      MockData.doctors[i] = d;
    } else {
      MockData.doctors.add(d);
    }
    return d;
  }

  /// Hours of one day. Returns what is known now and fetches the rest; listeners are told when it arrives.
  List<TimeWindow> windows(String doctorId, DateTime day) {
    final key = '$doctorId|${ymd(day)}';
    final have = _windows[key];
    if (have == null && _loading.add(key)) {
      fetchWindows(doctorId, day).whenComplete(() => _loading.remove(key));
    }
    return have ?? const [];
  }

  bool isLoadingWindows(String doctorId, DateTime day) => _loading.contains('$doctorId|${ymd(day)}');

  Future<List<TimeWindow>> fetchWindows(String doctorId, DateTime day) async {
    final key = '$doctorId|${ymd(day)}';
    try {
      final list = await api.get('/v1/doctors/$doctorId/windows', query: {'date': ymd(day)}, auth: false) as List;
      _windows[key] = [
        for (final w in list.cast<Map>())
          TimeWindow(
            id: w['id'] as String,
            hospitalId: w['hospitalId'] as String,
            start: istHour(w['startsAt'] as String),
            capacity: (w['capacity'] as num).toInt(),
            booked: ((w['capacity'] as num) - (w['free'] as num)).toInt().clamp(0, (w['capacity'] as num).toInt()),
            over: w['bookable'] != true && (w['free'] as num) > 0,
          ),
      ];
    } on ApiException {
      _windows[key] = const [];
    }
    notifyListeners();
    return _windows[key]!;
  }

  /// After booking or changing a time: that doctor's places changed.
  void forgetDoctor(String doctorId) {
    _windows.removeWhere((k, _) => k.startsWith('$doctorId|'));
  }

  // ── Mapping ────────────────────────────────────────────────────────────────────────────────────

  static String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The hour (0–23) of a server time, in India.
  static int istHour(String iso) => DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 30)).hour;

  static DateTime istDate(String iso) {
    final t = DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(t.year, t.month, t.day);
  }

  static DateTime dateOf(String ymd) {
    final p = ymd.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static String _cap(String? s) => s == null || s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}';

  static Hospital hospitalFrom(Map<String, dynamic> h) => Hospital(
        id: h['id'] as String,
        name: h['name'] as String,
        area: (h['area'] as String?) ?? '',
        pin: (h['pin'] as String?) ?? '',
        distanceKm: ((h['distanceKm'] as num?) ?? 0).toDouble(),
        phone: (h['phone'] as String?) ?? '',
        address: (h['address'] as String?) ?? '',
        opdTimings: (h['opdTimings'] as String?) ?? '',
        hasEmergency: h['hasEmergency'] == true,
        typeIds: ((h['departments'] as List?) ?? const []).cast<String>(),
        lat: ((h['location'] as Map?)?['lat'] as num?)?.toDouble(),
        lng: ((h['location'] as Map?)?['lng'] as num?)?.toDouble(),
      );

  static Doctor doctorFrom(Map<String, dynamic> c) {
    final week = ((c['week'] as List?) ?? const []).cast<Map>();
    final days = <int>{for (final w in week) (w['weekday'] as num).toInt()}.toList()..sort();
    final blocks = <(int, int)>{
      for (final w in week) (int.parse((w['start'] as String).split(':')[0]), int.parse((w['end'] as String).split(':')[0])),
    }.toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final em = c['emergency'] as Map?;
    final photo = c['photo'] as Map?;
    return Doctor(
      id: c['id'] as String,
      name: c['name'] as String,
      typeId: ((c['type'] as Map?)?['id'] as String?) ?? (c['typeId'] as String? ?? 'general'),
      degrees: (c['degrees'] as String?) ?? '',
      years: ((c['yearsExperience'] as num?) ?? 0).toInt(),
      languages: ((c['languages'] as List?) ?? const []).cast<String>(),
      fee: ((((c['fee'] as Map?)?['paise']) as num?) ?? 0) ~/ 100,
      hospitalIds: [for (final h in ((c['hospitals'] as List?) ?? const []).cast<Map>()) h['id'] as String],
      workDays: days,
      sessions: blocks,
      gender: _cap(c['gender'] as String?),
      about: (c['about'] as String?) ?? '',
      emergency: em == null
          ? EmergencyStatus.off
          : em['status'] == 'available_till'
              ? EmergencyStatus.availableTill
              : EmergencyStatus.availableNow,
      emergencyTill: em?['until'] is String ? clockLabel(DateTime.parse(em!['until'] as String).toLocal()) : null,
      photoUrl: photo?['m'] as String?,
      bookingsPaused: c['bookingsPaused'] == true,
    );
  }

  static (DateTime, TimeWindow)? _nextFreeFrom(Object? raw) {
    if (raw is! Map) return null;
    final cap = (raw['capacity'] as num).toInt();
    return (
      dateOf(raw['date'] as String),
      TimeWindow(
        id: raw['windowId'] as String,
        hospitalId: raw['hospitalId'] as String?,
        start: istHour(raw['startsAt'] as String),
        capacity: cap,
        booked: (cap - (raw['free'] as num).toInt()).clamp(0, cap),
      ),
    );
  }

  @override
  // ignore: must_call_super
  void dispose() {}
}
