import 'package:flutter/material.dart';

import '../theme/med_icons.dart';
import 'format.dart';
import 'models.dart';
import '../data/config.dart';
import '../data/remote.dart';

/// Fake catalogue for the UI build. Every name, number and hospital here is made up.
abstract final class MockData {
  static List<DoctorType> types = const <DoctorType>[
    DoctorType('general', 'General doctor', 'General Medicine', MedIcons.stethoscope),
    DoctorType('child', 'Child doctor', 'Pediatrics', MedIcons.pediatrics),
    DoctorType('women', "Women's doctor", 'Gynecology & Obstetrics', MedIcons.gynecology),
    DoctorType('skin', 'Skin doctor', 'Dermatology', MedIcons.dermatology),
    DoctorType('bone', 'Bone doctor', 'Orthopedics', MedIcons.orthopedics),
    DoctorType('eye', 'Eye doctor', 'Ophthalmology', MedIcons.ophthalmology),
    DoctorType('ent', 'Ear-nose-throat doctor', 'ENT', MedIcons.ent),
    DoctorType('teeth', 'Teeth doctor', 'Dentistry', MedIcons.dentistry),
    DoctorType('heart', 'Heart doctor', 'Cardiology', MedIcons.cardiology),
    DoctorType('brain', 'Brain and nerve doctor', 'Neurology', MedIcons.neurology),
    DoctorType('mind', 'Mind doctor', 'Psychiatry', MedIcons.psychiatry),
    DoctorType('stomach', 'Stomach doctor', 'Gastroenterology', MedIcons.gastroenterology),
    DoctorType('lungs', 'Lungs doctor', 'Pulmonology', MedIcons.pulmonology),
    DoctorType('kidney', 'Urine and kidney doctor', 'Urology', MedIcons.urology),
    DoctorType('surgeon', 'Surgeon', 'General Surgery', MedIcons.surgical),
  ];

  /// The eight shown on the patient Home screen.
  static List<String> commonTypeIds = const ['general', 'child', 'women', 'skin', 'bone', 'eye', 'ent', 'teeth'];

  static DoctorType type(String id) => types.firstWhere((t) => t.id == id, orElse: () => types.first);
  static DoctorType? findType(String id) => types.where((t) => t.id == id).firstOrNull;

  static List<Hospital> hospitals = const <Hospital>[
    Hospital(
      id: 'h1',
      name: 'Sri Lakshmi Hospital',
      area: 'Brodipet',
      pin: '522002',
      distanceKm: 1.2,
      phone: '0863 223 4455',
      address: '4th Lane, Brodipet, Guntur 522002',
      opdTimings: 'Mon–Sat · 9 AM – 1 PM, 5 PM – 8 PM',
      hasEmergency: true,
      typeIds: ['general', 'child', 'women', 'bone', 'heart', 'surgeon'],
    ),
    Hospital(
      id: 'h2',
      name: 'City Children\'s Clinic',
      area: 'Arundelpet',
      pin: '522002',
      distanceKm: 2.1,
      phone: '0863 224 1122',
      address: '2/7 Arundelpet Main Road, Guntur 522002',
      opdTimings: 'Mon–Sun · 9 AM – 1 PM, 6 PM – 8 PM',
      hasEmergency: true,
      typeIds: ['child'],
    ),
    Hospital(
      id: 'h3',
      name: 'Amaravati Care Hospital',
      area: 'Amaravati Road',
      pin: '522034',
      distanceKm: 3.4,
      phone: '0863 235 7788',
      address: 'Near RTC Colony, Amaravati Road, Guntur 522034',
      opdTimings: 'Mon–Sat · 9 AM – 2 PM, 5 PM – 8 PM',
      hasEmergency: true,
      typeIds: ['general', 'heart', 'brain', 'lungs', 'kidney', 'stomach', 'surgeon'],
    ),
    Hospital(
      id: 'h4',
      name: 'Sai Eye & ENT Centre',
      area: 'Lakshmipuram',
      pin: '522007',
      distanceKm: 2.8,
      phone: '0863 226 9090',
      address: 'Main Road, Lakshmipuram, Guntur 522007',
      opdTimings: 'Mon–Sat · 10 AM – 2 PM',
      hasEmergency: false,
      typeIds: ['eye', 'ent'],
    ),
    Hospital(
      id: 'h5',
      name: 'Krishna Skin & Smile Clinic',
      area: 'Kothapet',
      pin: '522001',
      distanceKm: 4.6,
      phone: '0863 221 3344',
      address: 'Opp. Market, Kothapet, Guntur 522001',
      opdTimings: 'Mon–Sat · 10 AM – 1 PM, 5 PM – 8 PM',
      hasEmergency: false,
      typeIds: ['skin', 'teeth', 'mind'],
    ),
  ];

  static Hospital hospital(String id) => hospitals.firstWhere((h) => h.id == id, orElse: () => hospitals.isNotEmpty ? hospitals.first : _unknownHospital);

  /// Shown only if the server's hospital list is not loaded yet (never crash on an empty list).
  static const _unknownHospital = Hospital(
      id: '', name: 'Hospital', area: '', pin: '', distanceKm: 0, phone: '', address: '', opdTimings: '', hasEmergency: false, typeIds: []);
  static Hospital? findHospital(String id) => hospitals.where((h) => h.id == id).firstOrNull;

  static const _weekdays = [1, 2, 3, 4, 5, 6];
  static const _allDays = [1, 2, 3, 4, 5, 6, 7];

  /// Editable at runtime: a doctor's own profile changes (photo, fee…) replace their entry.
  /// See `lib/state/directory_store.dart`.
  static final doctors = <Doctor>[
    const Doctor(
      id: 'd1',
      name: 'Dr. Srinivas Rao',
      typeId: 'child',
      degrees: 'MBBS, MD (Pediatrics)',
      years: 14,
      languages: ['Telugu', 'English', 'Hindi'],
      fee: 300,
      hospitalIds: ['h1', 'h2'],
      workDays: _weekdays,
      sessions: [(9, 13), (17, 19)],
      gender: 'Male',
      regNo: 'APMC 45821',
      about: 'Child doctor for new-born babies to 16 years. Fever, cough, feeding problems, vaccines and growth checks.',
      emergency: EmergencyStatus.availableNow,
    ),
    const Doctor(
      id: 'd2',
      name: 'Dr. Lakshmi Prasanna',
      typeId: 'women',
      degrees: 'MBBS, MS (OBG)',
      years: 11,
      languages: ['Telugu', 'English'],
      fee: 400,
      hospitalIds: ['h1'],
      workDays: _weekdays,
      sessions: [(10, 14)],
      gender: 'Female',
      regNo: 'APMC 51230',
      about: 'Pregnancy care, periods problems and women\'s health.',
      emergency: EmergencyStatus.availableTill,
      emergencyTill: '10 PM',
    ),
    const Doctor(
      id: 'd3',
      name: 'Dr. K. Venkatesh',
      typeId: 'general',
      degrees: 'MBBS, MD (General Medicine)',
      years: 20,
      languages: ['Telugu', 'English'],
      fee: 250,
      hospitalIds: ['h1', 'h3'],
      workDays: _weekdays,
      sessions: [(9, 13), (17, 20)],
      gender: 'Male',
      regNo: 'APMC 30417',
      about: 'Fever, sugar, BP, body pains and all common health problems for adults.',
    ),
    const Doctor(
      id: 'd4',
      name: 'Dr. Sravani Devi',
      typeId: 'general',
      degrees: 'MBBS, DNB (Family Medicine)',
      years: 7,
      languages: ['Telugu', 'English', 'Hindi'],
      fee: 200,
      hospitalIds: ['h3'],
      workDays: _allDays,
      sessions: [(9, 13)],
      gender: 'Female',
      regNo: 'APMC 60218',
      about: 'Family doctor for all ages. Fever, cough, cold and regular health checks.',
      emergency: EmergencyStatus.availableTill,
      emergencyTill: '11 PM',
    ),
    const Doctor(
      id: 'd5',
      name: 'Dr. Anjali Reddy',
      typeId: 'skin',
      degrees: 'MBBS, MD (Dermatology)',
      years: 9,
      languages: ['Telugu', 'English'],
      fee: 350,
      hospitalIds: ['h5'],
      workDays: _weekdays,
      sessions: [(10, 13), (17, 20)],
      gender: 'Female',
      regNo: 'APMC 55412',
      about: 'Skin rash, itching, pimples, hair fall and nail problems.',
    ),
    const Doctor(
      id: 'd6',
      name: 'Dr. Ramesh Babu',
      typeId: 'bone',
      degrees: 'MBBS, MS (Ortho)',
      years: 16,
      languages: ['Telugu', 'English'],
      fee: 400,
      hospitalIds: ['h1'],
      workDays: _weekdays,
      sessions: [(9, 13)],
      gender: 'Male',
      regNo: 'APMC 38820',
      about: 'Joint pain, back pain, broken bones and sports injuries.',
      emergency: EmergencyStatus.availableNow,
    ),
    const Doctor(
      id: 'd7',
      name: 'Dr. Farah Khan',
      typeId: 'eye',
      degrees: 'MBBS, MS (Ophthalmology)',
      years: 12,
      languages: ['English', 'Hindi', 'Urdu', 'Telugu'],
      fee: 300,
      hospitalIds: ['h4'],
      workDays: _weekdays,
      sessions: [(10, 14)],
      gender: 'Female',
      regNo: 'APMC 47301',
      about: 'Eye checks, glasses, red eyes, eye pain and cataract.',
    ),
    const Doctor(
      id: 'd8',
      name: 'Dr. P. Suresh',
      typeId: 'ent',
      degrees: 'MBBS, MS (ENT)',
      years: 10,
      languages: ['Telugu', 'English'],
      fee: 300,
      hospitalIds: ['h4'],
      workDays: _weekdays,
      sessions: [(10, 14)],
      gender: 'Male',
      regNo: 'APMC 50119',
      about: 'Ear pain, hearing problems, nose block, sinus and throat pain.',
    ),
    const Doctor(
      id: 'd9',
      name: 'Dr. Harika Chowdary',
      typeId: 'teeth',
      degrees: 'BDS, MDS',
      years: 6,
      languages: ['Telugu', 'English'],
      fee: 200,
      hospitalIds: ['h5'],
      workDays: _weekdays,
      sessions: [(10, 13), (17, 20)],
      gender: 'Female',
      regNo: 'APDC 20931',
      about: 'Tooth pain, cleaning, fillings and children\'s teeth.',
    ),
    const Doctor(
      id: 'd10',
      name: 'Dr. M. Naveen Kumar',
      typeId: 'heart',
      degrees: 'MBBS, MD, DM (Cardiology)',
      years: 18,
      languages: ['Telugu', 'English'],
      fee: 600,
      hospitalIds: ['h3', 'h1'],
      workDays: [1, 3, 5],
      sessions: [(10, 13)],
      gender: 'Male',
      regNo: 'APMC 33105',
      about: 'Chest pain, BP, heart beat problems and heart checks.',
      emergency: EmergencyStatus.availableNow,
    ),
    const Doctor(
      id: 'd11',
      name: 'Dr. Y. Ravi Teja',
      typeId: 'child',
      degrees: 'MBBS, DCH',
      years: 5,
      languages: ['Telugu', 'English'],
      fee: 250,
      hospitalIds: ['h2'],
      workDays: _allDays,
      sessions: [(9, 12), (18, 20)],
      gender: 'Male',
      regNo: 'APMC 63077',
      about: 'Child fever, cold, cough, vaccines and new-born care.',
      emergency: EmergencyStatus.availableTill,
      emergencyTill: '10 PM',
    ),
    const Doctor(
      id: 'd12',
      name: 'Dr. Mohan Krishna',
      typeId: 'lungs',
      degrees: 'MBBS, MD (Pulmonology)',
      years: 13,
      languages: ['Telugu', 'English', 'Tamil'],
      fee: 450,
      hospitalIds: ['h3'],
      workDays: [1, 2, 4, 6],
      sessions: [(9, 12)],
      gender: 'Male',
      regNo: 'APMC 42290',
      about: 'Cough that does not go, wheezing, asthma and breathing problems.',
    ),
    const Doctor(
      id: 'd13',
      name: 'Dr. Swathi Varma',
      typeId: 'mind',
      degrees: 'MBBS, MD (Psychiatry)',
      years: 8,
      languages: ['Telugu', 'English'],
      fee: 500,
      hospitalIds: ['h5'],
      workDays: [2, 4, 6],
      sessions: [(17, 20)],
      gender: 'Female',
      regNo: 'APMC 57744',
      about: 'Stress, sleep problems, worry and sadness. Talk freely, it stays private.',
    ),
    const Doctor(
      id: 'd14',
      name: 'Dr. Kiran Kumar',
      typeId: 'stomach',
      degrees: 'MBBS, MD, DM (Gastro)',
      years: 15,
      languages: ['Telugu', 'English'],
      fee: 500,
      hospitalIds: ['h3'],
      workDays: _weekdays,
      sessions: [(10, 13)],
      gender: 'Male',
      regNo: 'APMC 39981',
      about: 'Stomach pain, acidity, loose motions, liver problems.',
    ),
    const Doctor(
      id: 'd15',
      name: 'Dr. Prakash Naidu',
      typeId: 'brain',
      degrees: 'MBBS, MD, DM (Neurology)',
      years: 17,
      languages: ['Telugu', 'English'],
      fee: 600,
      hospitalIds: ['h3'],
      workDays: [1, 3, 5],
      sessions: [(11, 14)],
      gender: 'Male',
      regNo: 'APMC 36652',
      about: 'Headache, fits, weakness, numbness and memory problems.',
    ),
    const Doctor(
      id: 'd16',
      name: 'Dr. Arun Kumar',
      typeId: 'kidney',
      degrees: 'MBBS, MS, MCh (Urology)',
      years: 12,
      languages: ['Telugu', 'English'],
      fee: 500,
      hospitalIds: ['h3'],
      workDays: [2, 4, 6],
      sessions: [(10, 13)],
      gender: 'Male',
      regNo: 'APMC 44718',
      about: 'Burning urine, stones, and kidney problems.',
    ),
    const Doctor(
      id: 'd17',
      name: 'Dr. Vijay Bhaskar',
      typeId: 'surgeon',
      degrees: 'MBBS, MS (General Surgery)',
      years: 19,
      languages: ['Telugu', 'English'],
      fee: 400,
      hospitalIds: ['h1', 'h3'],
      workDays: _weekdays,
      sessions: [(9, 12)],
      gender: 'Male',
      regNo: 'APMC 31950',
      about: 'Hernia, piles, lumps, wounds and small operations.',
      emergency: EmergencyStatus.availableNow,
    ),
  ];

  static Doctor doctor(String id) => doctors.firstWhere((d) => d.id == id, orElse: () => doctors.isNotEmpty ? doctors.first : _unknownDoctor);

  static const _unknownDoctor = Doctor(
      id: '', name: 'Doctor', typeId: 'general', degrees: '', years: 0, languages: [], fee: 0, hospitalIds: [], workDays: [], sessions: [], gender: '');
  static Doctor? findDoctor(String id) => doctors.where((d) => d.id == id).firstOrNull;
  static List<Doctor> doctorsOfType(String typeId) => doctors.where((d) => d.typeId == typeId).toList();
  static List<Doctor> doctorsAt(String hospitalId) => doctors.where((d) => d.hospitalIds.contains(hospitalId)).toList();

  static const perHour = 8;

  /// Emergency consultation: the patient pays the doctor's fee plus this charge. The charge is all OPflow's;
  /// the doctor's fee is split as usual (90% doctor, 10% OPflow). E.g. fee ₹500 → charge ₹100 → total ₹600.
  static int emergencyChargePercent = 20;
  static int emergencyCharge(int fee) => (fee * emergencyChargePercent / 100).round();

  /// Doctors a patient can book for an emergency consultation right now.
  static bool takesEmergencyNow(Doctor d) =>
      d.emergency == EmergencyStatus.availableNow || d.emergency == EmergencyStatus.availableTill;

  /// Whether the doctor sits on this day.
  static bool worksOn(Doctor d, DateTime day) => d.workDays.contains(day.weekday);

  /// Hour windows for a doctor on a day. Places taken are made up but stay the same for the same day.
  static List<TimeWindow> windows(Doctor d, DateTime day, {Set<String> extraTaken = const {}}) {
    if (AppConfig.isApi) return Remote.instance.windows(d.id, day);
    if (!worksOn(d, day)) return const [];
    final now = DateTime.now();
    final isToday = sameDay(day, now);
    final out = <TimeWindow>[];
    for (final (from, to) in d.sessions) {
      for (var h = from; h < to; h++) {
        final seed = (d.id.hashCode ^ (day.day * 31 + day.month * 7) ^ (h * 13)).abs();
        var booked = seed % (perHour + 2);
        // Earlier hours fill up first, and today is busier than later days.
        final ahead = dateOnly(day).difference(today()).inDays;
        if (ahead > 3) booked = (booked * 0.5).floor();
        if (h == from && ahead <= 1) booked = perHour;
        booked = booked.clamp(0, perHour);
        final key = '${d.id}|${dateOnly(day).toIso8601String()}|$h';
        if (extraTaken.contains(key)) booked = (booked + 1).clamp(0, perHour);
        // Online booking closes 30 minutes before the hour starts.
        final closes = DateTime(day.year, day.month, day.day, h).subtract(const Duration(minutes: 30));
        out.add(TimeWindow(start: h, capacity: perHour, booked: booked, over: isToday && now.isAfter(closes)));
      }
    }
    return out;
  }

  /// The first open window in the next 14 days, as (day, window).
  static (DateTime, TimeWindow)? nextFree(Doctor d) {
    if (d.bookingsPaused) return null;
    if (AppConfig.isApi) return Remote.instance.nextFree(d.id);
    for (var i = 0; i < 14; i++) {
      final day = today().add(Duration(days: i));
      for (final w in windows(d, day)) {
        if (w.open) return (day, w);
      }
    }
    return null;
  }

  static List<HealthProblem> problems = const <HealthProblem>[
    HealthProblem('fever', 'Fever', Icons.thermostat, ['general'], ['child']),
    HealthProblem('cough', 'Cough', Icons.masks_outlined, ['general', 'lungs'], ['child']),
    HealthProblem('cold', 'Cold / runny nose', Icons.ac_unit, ['general', 'ent'], ['child']),
    HealthProblem('throat', 'Sore throat', Icons.record_voice_over_outlined, ['ent', 'general'], ['child', 'ent']),
    HealthProblem('headache', 'Headache', Icons.sick_outlined, ['general', 'brain'], ['child']),
    HealthProblem('bodypain', 'Body pain', Icons.accessibility, ['general'], ['child']),
    HealthProblem('stomach', 'Stomach pain', Icons.restaurant_outlined, ['stomach', 'general'], ['child']),
    HealthProblem('vomiting', 'Vomiting', Icons.sick, ['general', 'stomach'], ['child']),
    HealthProblem('loose', 'Loose motions', Icons.wc, ['general', 'stomach'], ['child']),
    HealthProblem('constipation', 'Constipation', Icons.hourglass_bottom, ['stomach', 'general'], ['child']),
    HealthProblem('acidity', 'Acidity / burning chest', Icons.local_fire_department_outlined, ['stomach', 'general'], ['child']),
    HealthProblem('chest', 'Chest pain', Icons.favorite_border, ['heart'], ['child'], danger: true),
    HealthProblem('breathing', 'Breathing problem', Icons.air, ['lungs', 'general'], ['child'], danger: true),
    HealthProblem('dizzy', 'Dizziness', Icons.cyclone, ['general', 'brain'], ['child']),
    HealthProblem('joint', 'Joint pain', Icons.directions_walk, ['bone'], ['bone', 'child']),
    HealthProblem('back', 'Back pain', Icons.airline_seat_recline_normal, ['bone'], ['bone']),
    HealthProblem('rash', 'Skin rash', Icons.face_retouching_natural, ['skin'], ['skin', 'child']),
    HealthProblem('itching', 'Itching', Icons.back_hand_outlined, ['skin'], ['skin', 'child']),
    HealthProblem('pimples', 'Pimples', Icons.face, ['skin'], ['skin']),
    HealthProblem('hair', 'Hair fall', Icons.content_cut, ['skin'], ['skin']),
    HealthProblem('eyered', 'Red eyes', Icons.visibility_outlined, ['eye'], ['eye']),
    HealthProblem('eyepain', 'Eye pain', Icons.remove_red_eye_outlined, ['eye'], ['eye']),
    HealthProblem('ear', 'Ear pain', Icons.hearing, ['ent'], ['ent', 'child']),
    HealthProblem('tooth', 'Tooth pain', Icons.emoji_emotions_outlined, ['teeth'], ['teeth']),
    HealthProblem('urine', 'Urine problem', Icons.water_drop_outlined, ['kidney', 'general'], ['child']),
    HealthProblem('burning', 'Burning urine', Icons.local_fire_department, ['kidney', 'general'], ['child']),
    HealthProblem('periods', 'Periods problem', Icons.calendar_month_outlined, ['women'], ['women']),
    HealthProblem('pregnancy', 'Pregnancy', Icons.pregnant_woman, ['women'], ['women']),
    HealthProblem('fits', 'Fits (seizure)', Icons.bolt, ['brain'], ['child'], danger: true),
    HealthProblem('pregbleed', 'Bleeding in pregnancy', Icons.bloodtype_outlined, ['women'], ['women'], danger: true),
    HealthProblem('worry', 'Stress / cannot sleep', Icons.nightlight_outlined, ['mind'], ['mind', 'child']),
  ];

  static HealthProblem problem(String id) => problems.firstWhere((p) => p.id == id, orElse: () => problems.first);
  static HealthProblem? findProblem(String id) => problems.where((p) => p.id == id).firstOrNull;

  static List<EmergencyKind> emergencyKinds = const <EmergencyKind>[
    EmergencyKind('snake', 'Snake bite', 'Any snake bite, even with no pain', Icons.pest_control_outlined, ['general', 'surgeon']),
    EmergencyKind('heart', 'Chest pain / heart attack', 'Chest pain, pain in arm or jaw, cold sweat', Icons.favorite, ['heart', 'general']),
    EmergencyKind('stroke', 'Sudden weakness (stroke)', 'Face drooping, one side weak, trouble speaking', Icons.psychology_outlined, ['brain', 'general']),
    EmergencyKind('accident', 'Accident or heavy bleeding', 'Road accident, fall, broken bone, head injury', Icons.personal_injury_outlined, ['bone', 'surgeon']),
    EmergencyKind('burn', 'Burns', 'Fire, hot water, electricity or chemical burn', Icons.local_fire_department_outlined, ['surgeon', 'general']),
    EmergencyKind('child', 'Child is very sick', 'Not drinking, fits, very sleepy, breathing fast', Icons.child_care, ['child']),
    EmergencyKind('fits', 'Fits (seizure)', 'Shaking of the body, not responding', Icons.bolt, ['brain', 'general']),
    EmergencyKind('breathing', 'Breathing problem', 'Cannot breathe well, asthma attack', Icons.air, ['lungs', 'general']),
    EmergencyKind('pregnancy', 'Pregnancy problem', 'Bleeding, fits, very bad headache or stomach pain', Icons.pregnant_woman, ['women']),
    EmergencyKind('poison', 'Swallowed poison', 'Pesticide, kerosene, cleaning liquid, too many tablets', Icons.warning_amber_rounded, ['general']),
    EmergencyKind('animalbite', 'Dog or animal bite', 'Bite or scratch from a dog, cat or monkey', Icons.pets_outlined, ['general', 'surgeon']),
    EmergencyKind('heat', 'Heat stroke', 'Very hot body, confusion, fainting in the heat', Icons.wb_sunny_outlined, ['general']),
    EmergencyKind('eye', 'Eye injury', 'Chemical or object in the eye, sudden loss of sight', Icons.visibility_outlined, ['eye']),
    EmergencyKind('other', 'Other urgent problem', 'Anything else that cannot wait', Icons.emergency_outlined, ['general']),
  ];

  static EmergencyKind emergencyKind(String id) => emergencyKinds.firstWhere((k) => k.id == id, orElse: () => emergencyKinds.last);
  static EmergencyKind? findEmergencyKind(String id) => emergencyKinds.where((k) => k.id == id).firstOrNull;

  static const opflowHelpPhone = '1800 123 6735';
  static const ambulance = '108';
}
