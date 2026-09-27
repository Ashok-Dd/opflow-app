import 'package:flutter/material.dart';
import '../data/remote.dart';
import '../data/config.dart';
import '../widgets/directory_gate.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/about_you.dart';
import '../features/auth/doctor_login.dart';
import '../features/auth/doctor_new_password.dart';
import '../features/auth/patient_otp.dart';
import '../features/auth/patient_phone.dart';
import '../features/doctor/booking_detail.dart';
import '../features/doctor/bookings.dart';
import '../features/doctor/doctor_shell.dart';
import '../features/doctor/leave.dart';
import '../features/doctor/me.dart';
import '../features/doctor/timings.dart';
import '../features/doctor/today.dart';
import '../features/patient/booking/booking_flow.dart';
import '../features/patient/booking/pay_return.dart';
import '../features/patient/picks/picks_screens.dart';
import '../features/patient/booking/change_time.dart';
import '../features/patient/bookings/booking_detail.dart';
import '../features/patient/bookings/bookings.dart';
import '../features/patient/emergency.dart';
import '../features/patient/emergency_consult.dart';
import '../features/patient/first_aid_screen.dart';
import '../features/patient/find/doctor_list.dart';
import '../features/patient/find/doctor_page.dart';
import '../features/patient/find/find.dart';
import '../features/patient/find/hospital_page.dart';
import '../features/patient/find/problem_flow.dart';
import '../features/patient/home.dart';
import '../features/patient/me/me.dart';
import '../features/patient/me/me_pages.dart';
import '../features/patient/messages.dart';
import '../features/doctor/messages.dart';
import '../features/patient/patient_shell.dart';
import '../features/start/onboarding.dart';
import '../features/start/splash.dart';
import '../features/start/who.dart';
import '../core/errors.dart';
import '../mock/data.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

final rootKey = GlobalKey<NavigatorState>();

/// Every screen in the app uses this page: a short slide with a fade.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: OpMotion.page,
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondary, child) => opSlideFade(animation, child),
    );

/// Short helper for a pushed route.
GoRoute _r(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, parentNavigatorKey: rootKey, pageBuilder: (context, s) => _page(s, build(s)));

/// Shows [build] only when [exists]; otherwise a friendly "not found" screen. Bad links never crash.
Widget _ifExists(bool exists, String what, Widget Function() build) {
  if (exists) return build();
  // API build: the doctors may still be loading (the server can take a minute to wake up).
  if (AppConfig.isApi && !Remote.instance.loaded) {
    return Scaffold(body: SafeArea(child: DirectoryGate(height: 400, text: 'Loading…', builder: (_) => build())));
  }
  return NotFoundScreen(what: what);
}

final appRouter = GoRouter(
  navigatorKey: rootKey,
  initialLocation: '/',
  // Unknown addresses (old links, typos) land on a friendly page.
  errorPageBuilder: (context, state) => _page(state, const NotFoundScreen()),
  routes: [
    // Start
    GoRoute(path: '/', pageBuilder: (c, s) => NoTransitionPage(key: s.pageKey, child: const SplashScreen())),
    GoRoute(
      path: '/welcome',
      pageBuilder: (c, s) => CustomTransitionPage(
        key: s.pageKey,
        child: const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    ),
    GoRoute(
      path: '/who',
      pageBuilder: (c, s) => CustomTransitionPage(
        key: s.pageKey,
        child: const WhoScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    ),
    _r('/emergency', (s) => const EmergencyScreen()),
    _r('/emergency-now', (s) => const EmergencyNearScreen()),
    // What to do first (Do's and Don'ts), then care open near you.
    _r('/emergency/:kind', (s) => _ifExists(MockData.findEmergencyKind(s.pathParameters['kind']!) != null, 'emergency type',
        () => FirstAidScreen(kindId: s.pathParameters['kind']!))),
    _r('/emergency-consult/:doctorId', (s) => _ifExists(MockData.findDoctor(s.pathParameters['doctorId']!) != null, 'doctor',
        () => EmergencyConsultScreen(doctorId: s.pathParameters['doctorId']!, kindId: s.uri.queryParameters['kind']))),
    _r('/emergency/:kind/near', (s) => _ifExists(MockData.findEmergencyKind(s.pathParameters['kind']!) != null, 'emergency type',
        () => EmergencyNearScreen(kindId: s.pathParameters['kind']!))),

    // Login
    _r('/login', (s) => const PatientPhoneScreen()),
    _r('/login/otp', (s) => const PatientOtpScreen()),
    _r('/login/about', (s) => const AboutYouScreen()),
    _r('/doctor-login', (s) => const DoctorLoginScreen()),
    _r('/doctor-login/new-password', (s) => const DoctorNewPasswordScreen()),

    // Patient tabs
    StatefulShellRoute(
      builder: (context, state, shell) => PatientShell(shell: shell),
      navigatorContainerBuilder: (context, shell, children) => FadeIndexedStack(index: shell.currentIndex, children: children),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeTab())]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/find', builder: (c, s) => FindTab(initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? ''))),
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/bookings', builder: (c, s) => const BookingsTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/me', builder: (c, s) => const MeTab())]),
      ],
    ),

    // Patient inner screens
    _r('/messages', (s) => const MessagesScreen()),
    _r('/doctors', (s) => DoctorListScreen(query: s.uri.queryParameters)),
    _r('/doctor/:id', (s) => _ifExists(MockData.findDoctor(s.pathParameters['id']!) != null, 'doctor', () => DoctorPage(
          doctorId: s.pathParameters['id']!,
          hospitalId: s.uri.queryParameters['hospital'],
          preview: s.uri.queryParameters['preview'] == '1',
        ))),
    _r('/hospital/:id', (s) => _ifExists(MockData.findHospital(s.pathParameters['id']!) != null, 'hospital',
        () => HospitalPage(hospitalId: s.pathParameters['id']!))),
    _r('/problem/:id', (s) => _ifExists(MockData.findProblem(s.pathParameters['id']!) != null, 'health problem',
        () => ProblemWhoScreen(problemId: s.pathParameters['id']!))),
    _r('/warning', (s) {
      final p = s.uri.queryParameters['problem'];
      return DangerScreen(problemId: p != null && MockData.findProblem(p) != null ? p : null);
    }),
    _r('/book/:doctorId', (s) {
      final d = MockData.findDoctor(s.pathParameters['doctorId']!);
      final h = s.uri.queryParameters['hospital'];
      return _ifExists(d != null, 'doctor',
          () => BookingFlow(doctorId: d!.id, hospitalId: h != null && d.hospitalIds.contains(h) ? h : null));
    }),
    _r('/booking/:id', (s) => BookingDetailScreen(bookingId: s.pathParameters['id']!)),
    _r('/right-doctor', (s) => const RightDoctorScreen()),
    _r('/right-doctor/result/:id', (s) => PickResultScreen(id: s.pathParameters['id']!)),
    _r('/right-doctor/:type', (s) => _ifExists(MockData.findType(s.pathParameters['type']!) != null, 'type of doctor',
        () => PickOfferScreen(typeId: s.pathParameters['type']!))),
    _r('/me/suggestions', (s) => const MyPicksScreen()),
    _r('/pick-return', (s) {
      final p = s.uri.queryParameters['p'] ?? '';
      if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(p)) return const NotFoundScreen(what: 'payment');
      return PickReturnScreen(id: p, checkoutSaidPaid: s.uri.queryParameters['ok'] == '1');
    }),
    _r('/pay-return', (s) {
      final b = s.uri.queryParameters['b'] ?? '';
      // Only a real booking id; anything else is a broken link (never waits for the doctor list).
      if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(b)) return const NotFoundScreen(what: 'payment');
      return PayReturnScreen(bookingId: b, checkoutSaidPaid: s.uri.queryParameters['ok'] == '1');
    }),
    _r('/booking/:id/change', (s) => ChangeTimeScreen(bookingId: s.pathParameters['id']!)),
    _r('/me/details', (s) => const MyDetailsScreen()),
    _r('/me/payments', (s) => const PaymentsScreen()),
    _r('/me/alerts', (s) => const AlertSettingsScreen()),
    _r('/me/help', (s) => const HelpScreen()),
    _r('/me/rules', (s) => const RulesScreen()),
    _r('/me/rules/:page', (s) => RulePage(pageId: s.pathParameters['page']!)),
    _r('/me/place', (s) => const PlaceScreen()),

    // Doctor tabs
    StatefulShellRoute(
      builder: (context, state, shell) => DoctorShell(shell: shell),
      navigatorContainerBuilder: (context, shell, children) => FadeIndexedStack(index: shell.currentIndex, children: children),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/d/today', builder: (c, s) => const TodayTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/d/bookings', builder: (c, s) => const DoctorBookingsTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/d/timings', builder: (c, s) => const TimingsTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/d/me', builder: (c, s) => const DoctorMeTab())]),
      ],
    ),

    // Doctor inner screens
    _r('/d/booking/:id', (s) => DoctorBookingDetail(bookingId: s.pathParameters['id']!)),
    _r('/d/leave', (s) => const LeaveScreen()),
    _r('/d/messages', (s) => const DoctorMessagesScreen()),
    _r('/d/me/profile', (s) => const DoctorProfileScreen()),
    _r('/d/me/hospitals', (s) => const DoctorHospitalsScreen()),
    _r('/d/me/earnings', (s) => const EarningsScreen()),
    _r('/d/me/reports', (s) => const ReportsScreen()),
    _r('/d/me/password', (s) => const ChangePasswordScreen()),
    _r('/d/me/alerts', (s) => const DoctorAlertsScreen()),
  ],
);

/// Keeps every tab alive (scroll position and all) and fades quickly when the tab changes.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: OpMotion.quick, value: 1);

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut).drive(Tween(begin: 0.25, end: 1)),
      child: IndexedStack(
        index: widget.index,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            TickerMode(enabled: i == widget.index, child: widget.children[i]),
        ],
      ),
    );
  }
}
