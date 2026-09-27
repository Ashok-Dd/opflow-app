import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../mock/data.dart';

/// The patient's area: its name and where it is (for "doctors near you"). Comes only from the phone's location.
class Place {
  const Place(this.name, this.lat, this.lng, {this.town});

  final String name;
  final double lat;
  final double lng;

  /// The town an area belongs to ("Brodipet" → "Guntur"). Null when unknown or the same.
  final String? town;

  String get label => town == null ? name : '$name, $town';
}

/// Why "Use my location" did not work: location switched off, not allowed (can ask again), or blocked for good.
enum LocationTrouble { off, denied, blocked, failed }

class LocationProblem implements Exception {
  const LocationProblem(this.trouble, this.message);
  final LocationTrouble trouble;
  final String message;
  @override
  String toString() => message;
}

/// The phone's location as a [Place]. Its name comes from the phone's map service; when that has none (the web
/// version, no internet), the area of the nearest hospital OPflow knows. Throws [LocationProblem].
Future<Place> placeFromPhone() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationProblem(LocationTrouble.off, 'Location is off on this phone. Please turn it on.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.deniedForever) {
    throw const LocationProblem(LocationTrouble.blocked, 'OPflow is not allowed to use your location. Please allow it in Settings.');
  }
  if (perm == LocationPermission.denied) {
    throw const LocationProblem(LocationTrouble.denied, 'Please allow OPflow to use your location to find doctors near you.');
  }
  final Position pos;
  try {
    pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
    );
  } catch (_) {
    throw const LocationProblem(LocationTrouble.failed, 'Could not find your location. Please try again in an open place.');
  }
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
      // No name from the phone's map service: named after the nearest hospital's area below.
    }
  }
  return Place(name ?? nearestHospitalArea(pos.latitude, pos.longitude) ?? 'Your location', pos.latitude, pos.longitude, town: town);
}

String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

/// Kilometres between two points (haversine).
double kmBetween(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// The area of the nearest hospital OPflow knows (real data from the server), within 25 km.
String? nearestHospitalArea(double lat, double lng) {
  String? best;
  var bestKm = 25.0;
  for (final h in MockData.hospitals) {
    if (h.lat == null || h.lng == null) continue;
    final km = kmBetween(lat, lng, h.lat!, h.lng!);
    if (km < bestKm) {
      bestKm = km;
      best = h.area;
    }
  }
  return best;
}

/// How many doctors work at a hospital within [km] of a point.
int doctorsNear(double lat, double lng, {double km = 10}) {
  final near = {
    for (final h in MockData.hospitals)
      if (h.lat != null && h.lng != null && kmBetween(lat, lng, h.lat!, h.lng!) <= km) h.id,
  };
  return MockData.doctors.where((d) => d.hospitalIds.any(near.contains)).length;
}
