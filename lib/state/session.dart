import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../data/places.dart';
import '../data/push.dart';
import '../data/remote.dart';
import '../theme/tokens.dart';

enum Side { none, patient, doctor }

enum DoctorLoginResult { ok, needsNewPassword, wrong }

/// Who is using the app and on which side. Mock mode: nothing is sent anywhere. API mode: real logins
/// (patient phone + OTP, doctor ID + password) with tokens in secure storage.
class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final instance = SessionStore._();

  SharedPreferences? _prefs;

  bool onboardingSeen = false;
  Side side = Side.none;

  // Patient
  String phone = '';
  String name = '';
  int age = 0;
  String gender = '';
  bool profileDone = false;
  /// The patient's area, asked at sign-up ("Brodipet, Guntur"). Empty until chosen.
  String place = '';
  /// A random id kept for as long as the app is installed (sent with sign-ins; not personal).
  static String installId = '';
  double? placeLat;
  double? placeLng;

  // Doctor
  static const demoDoctorId = 'OPD-10234';
  String _doctorPassword = 'demo1234';
  bool doctorPasswordChanged = false;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final p = _prefs!;
    onboardingSeen = p.getBool('onboardingSeen') ?? false;
    side = Side.values[p.getInt('side') ?? 0];
    phone = p.getString('phone') ?? '';
    name = p.getString('name') ?? '';
    age = p.getInt('age') ?? 0;
    gender = p.getString('gender') ?? '';
    profileDone = p.getBool('profileDone') ?? false;
    place = p.getString('place') ?? '';
    placeLat = p.getDouble('placeLat');
    placeLng = p.getDouble('placeLng');
    // One random id per install: the server knows it is the same phone when it signs in again.
    installId = p.getString('installId') ?? '';
    if (installId.length < 16) {
      final r = math.Random.secure();
      installId = 'app-${List.generate(28, (_) => r.nextInt(16).toRadixString(16)).join()}';
      await p.setString('installId', installId);
    }
    _doctorPassword = p.getString('doctorPassword') ?? 'demo1234';
    doctorPasswordChanged = p.getBool('doctorPasswordChanged') ?? false;
    doctorId = p.getString('doctorId');
    if (AppConfig.isApi) {
      await Api.instance.load();
      // Signed out elsewhere (or tokens lost): back to the start.
      if (!Api.instance.hasSession && side != Side.none) side = Side.none;
      Api.instance.onSignedOut = () {
        side = Side.none;
        _save();
        notifyListeners();
      };
    }
  }

  /// API mode: the logged-in doctor's id on the server, and the short-lived token for the first password change.
  String? doctorId;
  String? _changeToken;

  /// Why the last login did not work (locked, blocked, no internet…), in simple English.
  String? loginMessage;

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setBool('onboardingSeen', onboardingSeen);
    p.setInt('side', side.index);
    p.setString('phone', phone);
    p.setString('name', name);
    p.setInt('age', age);
    p.setString('gender', gender);
    p.setBool('profileDone', profileDone);
    p.setString('place', place);
    if (placeLat != null && placeLng != null) {
      p.setDouble('placeLat', placeLat!);
      p.setDouble('placeLng', placeLng!);
    } else {
      p.remove('placeLat');
      p.remove('placeLng');
    }
    p.setString('doctorPassword', _doctorPassword);
    p.setBool('doctorPasswordChanged', doctorPasswordChanged);
    if (doctorId != null) {
      p.setString('doctorId', doctorId!);
    } else {
      p.remove('doctorId');
    }
  }

  String get firstName => name.trim().isEmpty ? 'there' : name.trim().split(' ').first;

  void finishOnboarding() {
    onboardingSeen = true;
    _save();
    notifyListeners();
  }

  /// How the server checks the code: "sms" (a real SMS), "demo" (a test server: its demo code, or any code on
  /// a laptop). Mock mode: any 6 digits.
  String otpMode = 'demo';

  /// Until SMS is set up (laptop/test server only): the code the server made, shown under the boxes.
  String? testCode;


  String get _e164 {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return '+91${digits.length > 10 ? digits.substring(digits.length - 10) : digits}';
  }

  /// Sends the login code by SMS. Throws [ApiException] with a message to show (no internet, wait 30 s…).
  Future<void> sendOtp(String number) async {
    phone = number;
    if (!AppConfig.isApi) {
      await Future.delayed(OpMotion.fakeShort);
      return;
    }
    testCode = null;
    final r = Map<String, dynamic>.from(await Api.instance.post('/v1/auth/patient/otp', {'phone': _e164}, false) as Map);
    otpMode = (r['mode'] as String?) ?? 'demo';
    testCode = r['testCode'] as String?;
  }

  /// Mock: any 6 digits work. API: the server checks the SMS code (or, on a test server, its demo code).
  Future<bool> checkOtp(String code) async {
    if (AppConfig.isApi) return _exchange(code);
    await Future.delayed(OpMotion.fakeShort);
    if (code.length != 6) return false;
    side = Side.patient;
    _save();
    notifyListeners();
    return true;
  }

  Future<bool> _exchange(String code) async {
    loginMessage = null;
    final device = {'platform': _platform, 'appVersion': AppConfig.appVersion, 'installId': installId};
    try {
      final r = Map<String, dynamic>.from(await (otpMode == 'sms'
          ? Api.instance.post('/v1/auth/patient/otp/verify', {'phone': _e164, 'code': code, 'device': device}, false)
          // A test server: it checks this code (on a demo server it must match its DEMO_OTP_CODE).
          : Api.instance.post('/v1/auth/patient/exchange', {'idToken': 'dev:$_e164:$code', 'device': device}, false)) as Map);
      await Api.instance.saveTokens(r);
      final user = Map<String, dynamic>.from(r['user'] as Map);
      final profile = user['profile'] as Map?;
      // Start from nothing: this may be a different person than the last one on this phone.
      _forgetPerson();
      profileDone = user['needsProfile'] != true;
      if (profile != null) {
        name = profile['name'] as String;
        age = DateTime.now().year - (profile['birthYear'] as num).toInt();
        gender = _cap(profile['gender'] as String);
        final saved = profile['place'] as String?;
        if (saved != null && saved.isNotEmpty) {
          place = saved;
          placeLat = (profile['placeLat'] as num?)?.toDouble();
          placeLng = (profile['placeLng'] as num?)?.toDouble();
        }
      }
      side = Side.patient;
      _save();
      notifyListeners();
      unawaited(Push.instance.register());
      return true;
    } on ApiException catch (e) {
      // A wrong code is shown on the boxes; everything else (expired, too many tries, no internet) as a note.
      loginMessage = e.code == 'OTP_INVALID' ? null : e.message;
      return false;
    }
  }

  static String get _platform => kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> saveProfile({required String name, required int age, required String gender}) async {
    if (AppConfig.isApi) {
      await Api.instance.patch('/v1/me', {'name': name.trim(), 'age': age, 'gender': gender.toLowerCase(), ..._placeBody});
    } else {
      await Future.delayed(OpMotion.fakeShort);
    }
    this.name = name.trim();
    this.age = age;
    this.gender = gender;
    profileDone = true;
    _save();
    notifyListeners();
  }

  /// The area and its point, as the server keeps them with the profile.
  Map<String, Object?> get _placeBody => {'place': place, if (placeLat != null && placeLng != null) ...{'placeLat': placeLat, 'placeLng': placeLng}};

  /// The patient's area. Doctors "near you" are counted from it; the server keeps it with the profile.
  void setPlace(Place p) {
    place = p.label;
    placeLat = p.lat;
    placeLng = p.lng;
    _save();
    notifyListeners();
    if (!AppConfig.isApi) return;
    if (side == Side.patient && profileDone) {
      unawaited(Api.instance
          .patch('/v1/me', {'name': name.trim(), 'age': age, 'gender': gender.toLowerCase(), ..._placeBody})
          .catchError((_) => null));
    }
    unawaited(Remote.instance.loadDirectory());
  }

  Future<DoctorLoginResult> doctorLogin(String id, String password) async {
    if (AppConfig.isApi) return _doctorLoginApi(id, password);
    await Future.delayed(OpMotion.fakeLong);
    if (id.trim().toUpperCase() != demoDoctorId || password != _doctorPassword) return DoctorLoginResult.wrong;
    if (!doctorPasswordChanged) return DoctorLoginResult.needsNewPassword;
    side = Side.doctor;
    _save();
    notifyListeners();
    return DoctorLoginResult.ok;
  }

  Future<DoctorLoginResult> _doctorLoginApi(String id, String password) async {
    loginMessage = null;
    try {
      final r = Map<String, dynamic>.from(await Api.instance.post('/v1/auth/doctor/login', {
        'loginId': id.trim().toUpperCase(),
        'password': password,
        'device': {'platform': _platform, 'appVersion': AppConfig.appVersion, 'installId': installId},
      }, false) as Map);
      doctorId = (r['doctor'] as Map?)?['id'] as String?;
      if (r['mustChange'] == true) {
        _changeToken = r['changeToken'] as String?;
        return DoctorLoginResult.needsNewPassword;
      }
      await Api.instance.saveTokens(r);
      side = Side.doctor;
      _save();
      notifyListeners();
      unawaited(Push.instance.register());
      return DoctorLoginResult.ok;
    } on ApiException catch (e) {
      loginMessage = e.code == 'LOGIN_FAILED' || e.code == 'INVALID_INPUT' ? null : e.message;
      return DoctorLoginResult.wrong;
    }
  }

  /// Mock: checks the stored password. API: the server checks the old password in [setDoctorPassword].
  bool checkDoctorPassword(String password) => AppConfig.isApi || password == _doctorPassword;

  /// First login: sets the doctor's own password (API: with the change token). Later changes need [oldPassword]
  /// in API mode. Throws [ApiException] with a message to show (e.g. too easy to guess).
  Future<void> setDoctorPassword(String password, {String? oldPassword}) async {
    if (AppConfig.isApi) {
      if (_changeToken != null) {
        final r = Map<String, dynamic>.from(await Api.instance.post('/v1/auth/doctor/set-password', {
          'changeToken': _changeToken,
          'newPassword': password,
          'device': {'platform': _platform, 'appVersion': AppConfig.appVersion, 'installId': installId},
        }, false) as Map);
        _changeToken = null;
        await Api.instance.saveTokens(r);
        unawaited(Push.instance.register());
      } else {
        await Api.instance.post('/v1/doctor/password', {'currentPassword': oldPassword ?? '', 'newPassword': password});
      }
      doctorPasswordChanged = true;
      side = Side.doctor;
      _save();
      notifyListeners();
      return;
    }
    await Future.delayed(OpMotion.fakeShort);
    _doctorPassword = password;
    doctorPasswordChanged = true;
    side = Side.doctor;
    _save();
    notifyListeners();
  }

  void logout() {
    if (AppConfig.isApi) Api.instance.logout();
    side = Side.none;
    _forgetPerson();
    _save();
    notifyListeners();
  }

  /// The next person on this phone must never see the last one's name, age or area (sign-up form, "near you").
  void _forgetPerson() {
    name = '';
    age = 0;
    gender = '';
    profileDone = false;
    place = '';
    placeLat = null;
    placeLng = null;
    doctorId = null;
    testCode = null;
  }

  /// The session lives as long as the app. Riverpod calls this when a ProviderScope closes
  /// (hot restart, tests); the shared instance must stay usable for the next scope.
  @override
  // ignore: must_call_super
  void dispose() {}
}

final sessionProvider = ChangeNotifierProvider<SessionStore>((ref) => SessionStore.instance);
