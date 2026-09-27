// The app's own stores against a REAL OPflow API (not mock data). Skipped unless an API address is given:
//
//   backend: a throwaway database with `npm run seed:demo`, then `npm run start:dev`
//   flutter test test/api_connection_test.dart --dart-define=API_TEST=http://localhost:3000
//
// Uses plain `test()` (no widget binding), so real network calls are allowed.
import 'package:flutter_test/flutter_test.dart';
import 'package:opflow/data/api.dart';
import 'package:opflow/data/config.dart';
import 'package:opflow/data/remote.dart';
import 'package:opflow/mock/data.dart';
import 'package:opflow/mock/format.dart';
import 'package:opflow/mock/models.dart';
import 'package:opflow/state/doctor_inbox.dart';
import 'package:opflow/state/doctor_store.dart';
import 'package:opflow/state/patient_store_api.dart';
import 'package:opflow/state/session.dart';

const base = String.fromEnvironment('API_TEST');

Future<void> until(bool Function() ok, {Duration max = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(max);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) throw StateError('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  if (base.isEmpty) {
    test('API connection (skipped: pass --dart-define=API_TEST=http://localhost:3000)', () {}, skip: true);
    return;
  }

  setUpAll(() {
    AppConfig.override(api: true, base: base);
    Api.instance = Api(tokens: MemoryTokenStore());
    Remote.instance.prepare();
  });

  late Doctor rao;
  late (DateTime, TimeWindow) slot;
  late Booking booked;
  final session = SessionStore.instance;

  test('the directory comes from the server: catalog, hospitals, doctors with their next free hour', () async {
    await Remote.instance.loadDirectory();
    expect(Remote.instance.error, isNull);
    expect(MockData.types.length, 15);
    expect(MockData.hospitals.length, greaterThanOrEqualTo(5));
    rao = MockData.doctors.firstWhere((d) => d.name == 'Dr. Srinivas Rao');
    expect(rao.id.length, 36); // a server id, not the mock 'd1'
    expect(rao.workDays, isNotEmpty);
    expect(rao.fee, 300);
    final nf = MockData.nextFree(rao);
    expect(nf, isNotNull);
    slot = nf!;
    expect(slot.$2.id, isNotNull);
  });

  test('a patient logs in with their phone and saves their profile', () async {
    session.phone = '9876512345';
    expect(await session.checkOtp('123456'), isTrue);
    expect(session.side, Side.patient);
    if (!session.profileDone) await session.saveProfile(name: 'Lakshmi Devi', age: 34, gender: 'Female');
    expect(session.profileDone, isTrue);
  });

  test('the patient books the hour and pays; the ticket and the "booked" message come from the server', () async {
    final store = ApiPatientStore();
    await until(() => !store.loading);
    // The hours of that day arrive from the server.
    store.windowsAt(rao, slot.$1, slot.$2.hospitalId!);
    await until(() => store.windowsAt(rao, slot.$1, slot.$2.hospitalId!).isNotEmpty);
    final hour = store.windowsAt(rao, slot.$1, slot.$2.hospitalId!).firstWhere((w) => w.open);
    final b = await store.payAndBook(doctor: rao, hospitalId: hour.hospitalId!, day: slot.$1, window: hour, note: 'Fever for 2 days');
    expect(b, isNotNull);
    booked = b!;
    expect(booked.code, matches(RegExp(r'^OPF')));
    expect(booked.status, BookingStatus.upcoming);
    expect(booked.fee, 300);
    expect(store.upcoming.map((x) => x.id), contains(booked.id));
    // Once only: booking the same doctor on the same day again is refused with the server's words.
    final again = store.windowsAt(rao, slot.$1, slot.$2.hospitalId!).where((w) => w.open && w.id != hour.id).firstOrNull;
    if (again != null) {
      await expectLater(
        store.payAndBook(doctor: rao, hospitalId: again.hospitalId!, day: slot.$1, window: again, note: ''),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('already have a booking'))),
      );
    }
    // The "booked" message is delivered by the background jobs.
    await until(() => store.messages.any((m) => m.title == 'Booking confirmed'), max: const Duration(seconds: 20)).catchError((_) async {
      await store.refresh();
    });
    await store.refresh();
    expect(store.messages.any((m) => m.title == 'Booking confirmed'), isTrue);
    expect(store.whyNoChange(store.booking(booked.id)!), anyOf(isNull, isA<String>()));
    store.dispose();
    session.logout();
    expect(session.side, Side.none);
  });

  test('the demo doctor logs in, sets a password, and sees their profile, timings and today', () async {
    var r = await session.doctorLogin('OPD-10234', 'demo1234');
    if (r == DoctorLoginResult.needsNewPassword) {
      await session.setDoctorPassword('Doctor-2026-pass');
    } else if (r == DoctorLoginResult.wrong) {
      r = await session.doctorLogin('OPD-10234', 'Doctor-2026-pass');
      expect(r, DoctorLoginResult.ok);
    }
    expect(session.side, Side.doctor);
    final doc = ApiDoctorStore();
    await until(() => doc.ready);
    expect(doc.doctor.name, 'Dr. Srinivas Rao');
    expect(doc.hospitals, isNotEmpty);
    expect(doc.blocksFor(DateTime.monday).isNotEmpty || doc.blocksFor(DateTime.saturday).isNotEmpty, isTrue);

    // The booking made above shows on the doctor's list for that day.
    final day = doc.bookingsOn(booked.date);
    if (!sameDay(booked.date, DateTime.now()) || doc.sessionId == null) {
      await until(() => doc.bookingsOn(booked.date).isNotEmpty || doc.findBooking(booked.id) != null);
    }
    expect(doc.findBooking(booked.id) ?? day.where((p) => p.id == booked.id).firstOrNull, isNotNull);

    // Pause bookings reaches the server: patients see no next free hour.
    await doc.setBookingsPaused(true);
    await Remote.instance.loadDirectory();
    expect(MockData.nextFree(MockData.doctors.firstWhere((d) => d.name == 'Dr. Srinivas Rao')), isNull);
    await doc.setBookingsPaused(false);
    await Remote.instance.loadDirectory();
    expect(MockData.nextFree(MockData.doctors.firstWhere((d) => d.name == 'Dr. Srinivas Rao')), isNotNull);

    // Console: only when the booking is today.
    if (sameDay(booked.date, DateTime.now()) && doc.sessionId != null) {
      final p = doc.line.firstWhere((x) => x.id == booked.id);
      await doc.startOpd();
      doc.markReached(p);
      doc.callNext();
      await until(() => doc.line.any((x) => x.id == booked.id && x.state == PatientState.withDoctor));
    }
    // ── Every doctor button that talks to the server ──────────────────────────────────────────────
    // Messages: the "New booking" for the patient above reaches the doctor's list.
    final inbox = DoctorInbox();
    await until(() => inbox.messages.any((m) => m.title == 'New booking'), max: const Duration(seconds: 25)).catchError((_) => inbox.refresh());
    expect(inbox.messages.any((m) => m.title == 'New booking'), isTrue);
    final msg = inbox.messages.firstWhere((m) => m.title == 'New booking');
    expect(msg.bookingId, isNotNull);
    inbox.markAllRead();
    expect(inbox.unread, 0);

    // A booking opened from that message loads even when it is not on screen yet.
    final opened = await doc.fetchBooking(msg.bookingId!);
    expect(opened, isNotNull);
    expect(opened!.name, isNotEmpty);

    // Message settings are saved on the server.
    await Api.instance.patch('/v1/me/notification-prefs', {'eveningSummary': false});
    expect((await Api.instance.get('/v1/me/notification-prefs') as Map)['eveningSummary'], isFalse);
    await Api.instance.patch('/v1/me/notification-prefs', {'eveningSummary': true});

    // Emergency switch: on, then off, as the server sees it.
    doc.setEmergency(EmergencyStatus.availableNow, place: 'At hospital');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect((await Api.instance.get('/v1/doctor/emergency') as Map)['status'], 'available_now');
    // Patients see the doctor at once in the live emergency list (not only after restarting the app).
    final em = await Remote.instance.emergencyNear();
    expect(em.doctors.map((d) => d.id), contains(doc.doctor.id));
    doc.setEmergency(EmergencyStatus.off);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect((await Api.instance.get('/v1/doctor/emergency') as Map)['status'], 'off');

    // Timings save (the same week again), earnings and reports load.
    final week = {for (var d = 1; d <= 7; d++) d: doc.blocksFor(d).map((b) => b.copy()).toList()};
    await doc.saveTimings(week, doc.openDaysBefore);
    expect(doc.blocksFor(DateTime.now().weekday).length, week[DateTime.now().weekday]!.length);
    doc.earnings(30);
    await Api.instance.get('/v1/doctor/reports', query: {'days': 7});

    // The day's bookings, complete (leave decisions wait for these).
    final onDay = await doc.loadBookingsOn(booked.date);
    final mine = onDay.where((p) => p.id == booked.id).firstOrNull ?? doc.findBooking(booked.id);
    expect(mine, isNotNull);
    // Every booking says which hospital it is at (a doctor at two hospitals sees both in one list).
    expect(onDay.every((p) => p.hospitalId != null), isTrue);

    // Not today: "ask to pick a new time", then leave on that day is allowed (the patient is no longer on it),
    // then the leave is removed and the booking cancelled with all money back.
    if (!sameDay(booked.date, DateTime.now())) {
      await doc.changeBooking(mine!, mine.date, mine.hour);
      expect(mine.state, PatientState.moved);
      final others = (await doc.loadBookingsOn(booked.date)).where((p) => p.id != booked.id && p.state == PatientState.notCome);
      if (others.isEmpty) {
        await doc.setLeave({...doc.leaveDays, dateOnly(booked.date)});
        expect(doc.leaveDays.contains(dateOnly(booked.date)), isTrue);
        await doc.setLeave(doc.leaveDays.where((d) => !sameDay(d, booked.date)).toSet());
      }
      await doc.cancelBooking(mine, 'I am not well');
      expect(mine.state, PatientState.cancelled);
    }

    inbox.dispose();
    doc.dispose();
    session.logout();
  });
}
