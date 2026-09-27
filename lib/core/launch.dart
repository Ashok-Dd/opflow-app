import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer with [phone] filled in (the person presses call). No call permission is needed.
/// Returns false when the number is hidden (masked) or the phone has no dialer.
Future<bool> openDialer(String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.length < 3 || phone.toLowerCase().contains('x')) return false;
  try {
    return await launchUrl(Uri(scheme: 'tel', path: digits), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// True when [phone] can be dialled (not hidden for privacy).
bool canDial(String phone) => !phone.toLowerCase().contains('x') && phone.replaceAll(RegExp(r'[^0-9]'), '').length >= 3;

/// Directions to a place in the phone's maps app: Google Maps when it is there (Android always; iPhone if
/// installed), else Apple Maps on iPhone, else the browser. Uses the exact spot when known, else the address.
Future<bool> openDirections({double? lat, double? lng, required String name, required String address}) async {
  final dest = lat != null && lng != null ? '$lat,$lng' : '$name, $address';
  final q = Uri.encodeComponent(dest);
  final tries = <Uri>[
    if (defaultTargetPlatform == TargetPlatform.iOS) Uri.parse('comgooglemaps://?daddr=$q&directionsmode=driving'),
    if (defaultTargetPlatform == TargetPlatform.iOS) Uri.parse('https://maps.apple.com/?daddr=$q'),
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$q'),
  ];
  for (final u in tries) {
    try {
      if (u.scheme == 'comgooglemaps' && !await canLaunchUrl(u)) continue;
      if (await launchUrl(u, mode: LaunchMode.externalApplication)) return true;
    } catch (_) {
      // Try the next way.
    }
  }
  return false;
}
