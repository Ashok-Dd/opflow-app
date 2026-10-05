import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mock/data.dart';
import '../mock/models.dart';
import '../theme/tokens.dart';
import 'package:http/http.dart' as http;
import '../data/api.dart';
import '../data/config.dart';

/// All doctors, as both sides of the app see them. A doctor's own edits (photo, fee, about…)
/// are saved on the phone and replace their entry, so patients see them straight away.
class DirectoryStore extends ChangeNotifier {
  DirectoryStore._();
  static final instance = DirectoryStore._();

  SharedPreferences? _prefs;

  List<Doctor> get doctors => MockData.doctors;
  Doctor doctor(String id) => MockData.doctor(id);
  List<Doctor> ofType(String typeId) => MockData.doctorsOfType(typeId);
  List<Doctor> at(String hospitalId) => MockData.doctorsAt(hospitalId);

  Future<void> load() async {
    if (AppConfig.isApi) return; // the server holds doctor profiles
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    for (var i = 0; i < MockData.doctors.length; i++) {
      final raw = _prefs!.getString('doctor.${MockData.doctors[i].id}');
      if (raw == null) continue;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final photo = m['photoPath'] as String?;
      MockData.doctors[i] = MockData.doctors[i].copyWith(
        years: m['years'] as int?,
        languages: (m['languages'] as List?)?.cast<String>(),
        fee: m['fee'] as int?,
        gender: m['gender'] as String?,
        about: m['about'] as String?,
        bookingsPaused: m['bookingsPaused'] as bool?,
        photoPath: photo != null && (kIsWeb || File(photo).existsSync()) ? photo : null,
        clearPhoto: photo == null,
      );
    }
  }

  Future<void> update(Doctor d) async {
    if (AppConfig.isApi) return _updateApi(d);
    await Future.delayed(OpMotion.fakeShort);
    final i = MockData.doctors.indexWhere((x) => x.id == d.id);
    if (i < 0) return;
    MockData.doctors[i] = d;
    await _prefs?.setString(
      'doctor.${d.id}',
      jsonEncode({
        'years': d.years,
        'languages': d.languages,
        'fee': d.fee,
        'gender': d.gender,
        'about': d.about,
        'photoPath': d.photoPath,
        'bookingsPaused': d.bookingsPaused,
      }),
    );
    notifyListeners();
  }

  /// API mode: the logged-in doctor's own profile. Only what changed is sent.
  Future<void> _updateApi(Doctor d) async {
    final old = MockData.findDoctor(d.id);
    final api = Api.instance;
    if (old == null || old.bookingsPaused != d.bookingsPaused) {
      await api.post('/v1/doctor/me/bookings-pause', {'paused': d.bookingsPaused});
    }
    final body = <String, Object?>{
      if (old == null || old.gender != d.gender) 'gender': d.gender.toLowerCase(),
      if (old == null || old.years != d.years) 'yearsExperience': d.years,
      if (old == null || old.languages.join(',') != d.languages.join(',')) 'languages': d.languages,
      if (old == null || old.about != d.about) 'about': d.about,
      if (old == null || old.fee != d.fee) 'feePaise': d.fee * 100,
    };
    var next = d;
    if (d.photoPath != null && d.photoPath != old?.photoPath) {
      body['photoUploadKey'] = await _uploadPhoto(d.photoPath!);
    } else if (d.photoPath == null && d.photoUrl == null && (old?.photoUrl != null || old?.photoPath != null)) {
      body['photoUploadKey'] = null;
    }
    if (body.isNotEmpty) {
      final me = Map<String, dynamic>.from(await api.patch('/v1/doctor/me', body) as Map);
      final photo = me['photo'] as Map?;
      // The server makes the sizes in the background: keep showing the local file until then.
      next = d.copyWith(photoUrl: photo?['m'] as String?);
    }
    final i = MockData.doctors.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      MockData.doctors[i] = next;
    } else {
      MockData.doctors.add(next);
    }
    notifyListeners();
  }

  /// Straight to storage with a 5-minute link (the photo never passes through the API server).
  Future<String> _uploadPhoto(String path) async {
    final Uint8List bytes = path.startsWith('data:') ? UriData.parse(path).contentAsBytes() : (kIsWeb ? await XFile(path).readAsBytes() : await File(path).readAsBytes());
    final type = path.startsWith('data:image/png') || path.endsWith('.png') ? 'image/png' : 'image/jpeg';
    final link = Map<String, dynamic>.from(await Api.instance.post('/v1/doctor/me/photo/upload-url', {'contentType': type}) as Map);
    final headers = Map<String, String>.from((link['headers'] as Map?) ?? {'content-type': type});
    final res = await http.put(Uri.parse(link['url'] as String), headers: headers, body: bytes).timeout(const Duration(seconds: 60));
    if (res.statusCode >= 300) throw ApiException('UPLOAD_FAILED', 'The photo could not be uploaded. Please try again.', retryable: true);
    return link['key'] as String;
  }

  /// Keeps the cropped photo (PNG bytes) in the app's own folder; on the web the bytes live in a data address.
  Future<String> keepPhotoBytes(Uint8List bytes, String doctorId) async {
    if (kIsWeb) return Uri.dataFromBytes(bytes, mimeType: 'image/png').toString();
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/doctor_${doctorId}_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Copies a picked photo into the app's own folder, so it stays after the gallery changes.
  Future<String> keepPhoto(XFile picked, String doctorId) async {
    if (kIsWeb) return picked.path;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/doctor_${doctorId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(path);
    return path;
  }

  /// Lives as long as the app; see [SessionStore.dispose].
  @override
  // ignore: must_call_super
  void dispose() {}
}

final directoryProvider = ChangeNotifierProvider<DirectoryStore>((ref) => DirectoryStore.instance);
