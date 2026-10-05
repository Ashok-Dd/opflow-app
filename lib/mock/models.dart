import 'package:flutter/material.dart';

import '../l10n/lang.dart';

/// A kind of doctor, shown with a simple name first ("Child doctor") and the proper name small.
class DoctorType {
  const DoctorType(this.id, this._simple, this._proper, this.icon);

  final String id;
  final String _simple;
  final String _proper;

  /// In the app's language (the stored English name never changes).
  String get simple => _simple.tr;
  String get proper => _proper.tr;
  final IconData icon;
}

class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.area,
    required this.pin,
    required this.distanceKm,
    required this.phone,
    required this.address,
    required this.opdTimings,
    required this.hasEmergency,
    required this.typeIds,
    this.lat,
    this.lng,
    this.photoUrl,
  });

  /// The photo the admin added (landscape 16:9). Null: the app draws the building instead.
  final String? photoUrl;

  /// Where the hospital is, for "Open in Maps". Null in the sample data: the address is searched instead.
  final double? lat;
  final double? lng;

  final String id;
  final String name;
  final String area;
  final String pin;
  final double distanceKm;
  final String phone;
  final String address;
  final String opdTimings;
  final bool hasEmergency;
  final List<String> typeIds;

  String get initials => name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join();
}

enum EmergencyStatus { off, availableNow, availableTill }

class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.typeId,
    required this.degrees,
    required this.years,
    required this.languages,
    required this.fee,
    required this.hospitalIds,
    required this.workDays,
    required this.sessions,
    required this.gender,
    this.about = '',
    this.emergency = EmergencyStatus.off,
    this.emergencyTill,
    this.regNo = '',
    this.photoPath,
    this.photoUrl,
    this.bookingsPaused = false,
  });

  final String id;
  final String name;
  final String typeId;
  final String degrees;
  final int years;
  final List<String> languages;
  final int fee;
  final List<String> hospitalIds;

  /// 1 = Monday … 7 = Sunday.
  final List<int> workDays;

  /// OPD blocks as (start hour, end hour), e.g. (9, 13).
  final List<(int, int)> sessions;
  final String gender;
  final String about;
  final EmergencyStatus emergency;
  final String? emergencyTill;
  final String regNo;

  /// Photo the doctor uploaded (a file on this phone). Null shows the monogram portrait.
  final String? photoPath;

  /// Photo on OPflow's server (CDN), when connected to the API.
  final String? photoUrl;

  /// The doctor paused new bookings ("Pause bookings"). Bookings already made are not affected.
  final bool bookingsPaused;

  Doctor copyWith({
    int? years,
    List<String>? languages,
    int? fee,
    String? gender,
    String? about,
    EmergencyStatus? emergency,
    String? emergencyTill,
    String? photoPath,
    String? photoUrl,
    bool clearPhoto = false,
    bool? bookingsPaused,
  }) =>
      Doctor(
        id: id,
        name: name,
        typeId: typeId,
        degrees: degrees,
        years: years ?? this.years,
        languages: languages ?? this.languages,
        fee: fee ?? this.fee,
        hospitalIds: hospitalIds,
        workDays: workDays,
        sessions: sessions,
        gender: gender ?? this.gender,
        about: about ?? this.about,
        emergency: emergency ?? this.emergency,
        emergencyTill: emergencyTill ?? this.emergencyTill,
        regNo: regNo,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
        bookingsPaused: bookingsPaused ?? this.bookingsPaused,
      );

  String get initials {
    final parts = name.replaceFirst('Dr. ', '').split(' ').where((p) => p.length > 1).toList();
    return parts.take(2).map((p) => p[0]).join();
  }
}

/// One hour of a doctor's OPD on one day.
class TimeWindow {
  const TimeWindow({required this.start, required this.capacity, required this.booked, this.over = false, this.id, this.hospitalId});

  /// The server's id for this hour (API mode), used to book it.
  final String? id;
  final String? hospitalId;
  final int start;
  final int capacity;
  final int booked;

  /// True when this hour has already passed today.
  final bool over;

  int get left => (capacity - booked).clamp(0, capacity);
  bool get full => left == 0;
  bool get open => !full && !over;
}

/// The logged-in patient. A booking is always for this person (no family members).
class PatientProfile {
  const PatientProfile({required this.name, required this.age, required this.gender});

  final String name;
  final int age;
  final String gender;

  PatientProfile copyWith({String? name, int? age, String? gender}) =>
      PatientProfile(name: name ?? this.name, age: age ?? this.age, gender: gender ?? this.gender);
}

enum BookingStatus { upcoming, done, missed, cancelledByDoctor }

class Booking {
  Booking({
    required this.id,
    required this.doctorId,
    required this.hospitalId,
    required this.date,
    required this.start,
    required this.token,
    required this.fee,
    required this.paymentId,
    this.note = '',
    this.status = BookingStatus.upcoming,
    this.changedOnce = false,
    this.bookedAt,
    this.emergency = false,
    this.emergencyCharge = 0,
    this.code,
    this.sessionId,
    this.serverWhyNoChange,
    this.needsNewTime = false,
    this.refundLabel,
  });

  /// API mode: the code printed on the ticket, the OPD session (for the live line), and the server's own
  /// answer to "can I change this?" (it knows the real rules and times).
  final String? code;
  String? sessionId;
  String? serverWhyNoChange;
  bool needsNewTime;
  String? refundLabel;

  final String id;
  String doctorId;
  String hospitalId;
  DateTime date;
  int start;
  int token;
  final int fee;
  final String paymentId;
  String note;
  BookingStatus status;
  bool changedOnce;
  DateTime? bookedAt;

  /// Emergency consultation: seen first; token shown as E1, E2…
  final bool emergency;

  /// Extra charge for an emergency consultation, all of it OPflow's (rupees).
  final int emergencyCharge;

  int get total => fee + emergencyCharge;
  String get tokenLabel => emergency ? 'E$token' : token.toString().padLeft(2, '0');

  DateTime get windowStart => DateTime(date.year, date.month, date.day, start);
}

class HealthProblem {
  const HealthProblem(this.id, this._name, this.icon, this.adultTypes, this.childTypes, {this.danger = false});

  final String id;
  final String _name;
  String get name => _name.tr;
  final IconData icon;
  final List<String> adultTypes;
  final List<String> childTypes;

  /// Problems that may be an emergency: shown a warning screen first.
  final bool danger;
}

class EmergencyKind {
  const EmergencyKind(this.id, this._name, this._detail, this.icon, this.typeIds);

  final String id;
  final String _name;
  final String _detail;
  String get name => _name.tr;
  String get detail => _detail.tr;
  final IconData icon;
  final List<String> typeIds;
}

enum MessageKind { booked, reminder, late, turn, cancelled, changed, refund, system }

/// The server's notification kind → the app's.
MessageKind messageKindFrom(String? k) => switch (k) {
      'booked' => MessageKind.booked,
      'reminder' => MessageKind.reminder,
      'late' => MessageKind.late,
      'turn' => MessageKind.turn,
      'cancelled' => MessageKind.cancelled,
      'refund' => MessageKind.refund,
      'changed' => MessageKind.changed,
      _ => MessageKind.system,
    };

class AppMessage {
  AppMessage({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.bookingId,
    this.unread = true,
  });

  final String id;
  final MessageKind kind;
  final String title;
  final String body;
  final DateTime time;
  final String? bookingId;
  bool unread;
}
