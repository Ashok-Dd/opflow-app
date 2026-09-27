import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// A place the patient lives in: its name and where it is (for "doctors near you").
class Place {
  const Place(this.name, this.lat, this.lng, {this.town});

  final String name;
  final double lat;
  final double lng;

  /// The town an area belongs to ("Brodipet" → "Guntur"). Null for a town itself.
  final String? town;

  String get label => town == null ? name : '$name, $town';
}

/// Areas of Guntur and nearby towns. The patient picks one, or uses the phone's location.
const places = <Place>[
  Place('Guntur', 16.3067, 80.4365),
  Place('Brodipet', 16.2999, 80.4498, town: 'Guntur'),
  Place('Arundelpet', 16.3010, 80.4475, town: 'Guntur'),
  Place('Lakshmipuram', 16.3033, 80.4290, town: 'Guntur'),
  Place('Pattabhipuram', 16.3131, 80.4254, town: 'Guntur'),
  Place('Kothapet', 16.3023, 80.4580, town: 'Guntur'),
  Place('Nallapadu', 16.2876, 80.4035, town: 'Guntur'),
  Place('Gorantla', 16.3389, 80.4309, town: 'Guntur'),
  Place('Amaravati Road', 16.3240, 80.4340, town: 'Guntur'),
  Place('Chandramouli Nagar', 16.3160, 80.4360, town: 'Guntur'),
  Place('Syamala Nagar', 16.3200, 80.4450, town: 'Guntur'),
  Place('Vidya Nagar', 16.3170, 80.4420, town: 'Guntur'),
  Place('Vijayawada', 16.5062, 80.6480),
  Place('Tenali', 16.2430, 80.6400),
  Place('Mangalagiri', 16.4300, 80.5680),
  Place('Tadepalli', 16.4800, 80.6000),
  Place('Amaravati', 16.5730, 80.3575),
  Place('Narasaraopet', 16.2350, 80.0490),
  Place('Sattenapalli', 16.3960, 80.1500),
  Place('Chilakaluripet', 16.0890, 80.1670),
  Place('Ponnur', 16.0710, 80.5520),
  Place('Bapatla', 15.9040, 80.4670),
  Place('Repalle', 16.0180, 80.8290),
  Place('Vinukonda', 16.0530, 79.7400),
  Place('Piduguralla', 16.4800, 79.8900),
  Place('Ongole', 15.5057, 80.0499),
  Place('Eluru', 16.7107, 81.0952),
  Place('Machilipatnam', 16.1875, 81.1389),
];

/// A saved label ("Brodipet, Guntur" or "Guntur") back to its place, when it is one from the list.
Place? placeByLabel(String label) {
  for (final p in places) {
    if (p.label == label || p.name == label) return p;
  }
  return null;
}

/// Why "Use my location" did not work, in words for the patient.
class LocationProblem implements Exception {
  const LocationProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The phone's location as a [Place]: the area's name from the phone's map service, or the nearest place in
/// the list when that has no name. Throws [LocationProblem] when location is off or not allowed.
Future<Place> placeFromPhone() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationProblem('Location is off on this phone. Please turn it on, or choose your area from the list.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw const LocationProblem('OPflow may not use your location. Please choose your area from the list.');
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
  );
  final near = nearestPlace(pos.latitude, pos.longitude);
  String? name;
  String? town;
  if (!kIsWeb) {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        town = _clean(m.locality) ?? _clean(m.subAdministrativeArea);
        name = _clean(m.subLocality) ?? town;
        if (name == town) town = null;
      }
    } catch (_) {
      // No name from the phone's map service: the nearest known place is used.
    }
  }
  return Place(name ?? near.name, pos.latitude, pos.longitude, town: name == null ? near.town : town);
}

String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

/// The closest place in [places] (straight-line distance).
Place nearestPlace(double lat, double lng) {
  double d(Place p) {
    final dy = p.lat - lat;
    final dx = (p.lng - lng) * math.cos(lat * math.pi / 180);
    return dx * dx + dy * dy;
  }

  return places.reduce((a, b) => d(a) <= d(b) ? a : b);
}
