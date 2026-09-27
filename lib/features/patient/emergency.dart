import 'dart:async';

import '../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/config.dart';
import '../../data/remote.dart';
import '../../mock/data.dart';
import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/op_button.dart';
import 'package:go_router/go_router.dart';
import 'widgets.dart';

/// Red "Call 108" block used at the top of every emergency screen.
class Call108 extends StatelessWidget {
  const Call108({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: OpColors.alarm, borderRadius: OpRadius.cardAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('If someone is not breathing, not waking up, or bleeding a lot — call 108 now.'.tr,
              style: OpText.bodyStrong.copyWith(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          OpButton(
            label: 'Call 108 — Ambulance'.tr,
            icon: Icons.call,
            kind: OpButtonKind.light,
            onPressed: () => showCallSheet(context, name: 'Ambulance', phone: MockData.ambulance),
          ),
        ],
      ),
    );
  }
}

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: OpColors.paper,
        title: Row(
          children: [
            const Icon(Icons.emergency_outlined, color: OpColors.alarm),
            const SizedBox(width: 8),
            Text('Emergency help'.tr, style: OpText.heading.copyWith(color: OpColors.alarm)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 32),
        children: [
          const Call108().animate().fadeIn(duration: 250.ms).slideY(begin: -0.05, end: 0),
          const SizedBox(height: 14),
          OpCard(
            onTap: () => context.push('/emergency-now'),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: OpColors.mint, borderRadius: OpRadius.controlAll),
                  child: const Icon(Icons.medical_services_outlined, color: OpColors.forest, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Doctors available now'.tr, style: OpText.lead.copyWith(fontSize: 17)),
                      Text('Doctors who have switched on emergency help, and 24-hour hospitals'.tr, style: OpText.small.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: OpColors.forest),
              ],
            ),
          ).animate().fadeIn(delay: 120.ms, duration: 250.ms),
          const SizedBox(height: 24),
          Text('What happened?'.tr, style: OpText.title),
          const SizedBox(height: 4),
          Text('Tap one to see what to do now, and care that is open near you.'.tr, style: OpText.small.copyWith(fontSize: 15)),
          const SizedBox(height: 14),
          for (final (i, k) in MockData.emergencyKinds.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpCard(
                onTap: () => context.push('/emergency/${k.id}'),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: OpColors.alarmWash, borderRadius: OpRadius.controlAll),
                      child: Icon(k.icon, color: OpColors.alarm, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.name, style: OpText.lead.copyWith(fontSize: 17)),
                          Text(k.detail, style: OpText.small.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: OpColors.alarm),
                  ],
                ),
              ).staggerIn(i),
            ),
          const SizedBox(height: 8),
          InfoBox(
            tone: Tone.calm,
            icon: Icons.info_outline,
            child: Text('OPflow does not tell you the disease. It only shows care that is open now.'.tr),
          ),
        ],
      ),
    );
  }
}

/// Care open right now: 24-hour hospitals and the doctors whose emergency switch is on. Live from the server
/// (refreshed every 30 s and on pull-down), so a doctor who switches on appears within moments.
/// [kindId] null: every doctor available for emergencies now (the "Doctors available now" button).
class EmergencyNearScreen extends StatefulWidget {
  const EmergencyNearScreen({super.key, this.kindId});

  final String? kindId;

  @override
  State<EmergencyNearScreen> createState() => _EmergencyNearScreenState();
}

class _EmergencyNearScreenState extends State<EmergencyNearScreen> {
  bool _loading = true;
  bool _failed = false;
  List<Hospital> _hospitals = const [];
  List<Doctor> _doctors = const [];
  DateTime? _checkedAt;
  Timer? _timer;

  EmergencyKind? get _kind => widget.kindId == null ? null : MockData.findEmergencyKind(widget.kindId!);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) setState(() => _loading = _doctors.isEmpty && _hospitals.isEmpty);
    try {
      if (AppConfig.isApi) {
        final r = await Remote.instance.emergencyNear(kind: _kind?.id);
        _hospitals = r.hospitals;
        _doctors = r.doctors;
      } else {
        await Future<void>.delayed(OpMotion.fakeShort);
        _hospitals = MockData.hospitals.where((h) => h.hasEmergency).toList()..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        final kind = _kind;
        var doctors = MockData.doctors.where((d) => MockData.takesEmergencyNow(d) && (kind == null || kind.typeIds.contains(d.typeId))).toList();
        if (doctors.isEmpty && kind != null) doctors = MockData.doctors.where(MockData.takesEmergencyNow).toList();
        _doctors = doctors;
      }
      _failed = false;
      _checkedAt = DateTime.now();
    } catch (_) {
      _failed = true; // keep what is shown; 108 and the hospitals' numbers still work
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    return OpPage(
      title: kind == null ? 'Emergency doctors now'.tr : 'Open now near you'.tr,
      subtitle: kind?.name,
      body: RefreshIndicator(
        color: OpColors.alarm,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 32),
          children: [
            const Call108(),
            const SizedBox(height: 22),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 8), child: SkeletonList(rows: 3))
            else ...[
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoBox(
                    tone: Tone.warn,
                    icon: Icons.wifi_off,
                    child: Text('Could not check just now. Pull down to try again, or call 108.'.tr),
                  ),
                ),
              // Doctors first: that is what this screen is for.
              SectionLabel(kind == null ? 'Doctors available for emergencies' : 'Doctors available now'),
              if (_doctors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OpCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: OpColors.alarmWash, borderRadius: OpRadius.controlAll),
                          child: const Icon(Icons.person_search_outlined, color: OpColors.alarm),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('No doctor has switched on emergency help right now. Go to a 24-hour hospital below, or call 108.'.tr,
                              style: OpText.body.copyWith(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final (i, d) in _doctors.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: () {
                    final h = MockData.findHospital(d.hospitalIds.firstOrNull ?? '') ?? (_hospitals.isNotEmpty ? _hospitals.first : null);
                    final status = switch (d.emergency) {
                      EmergencyStatus.availableTill => 'Available till {0}'.trf([d.emergencyTill ?? '']),
                      _ => 'Available now'.tr,
                    };
                    return _CareCard(
                      title: d.name,
                      line: [MockData.type(d.typeId).simple, if (h != null) h.name, if (h != null && h.distanceKm > 0) '${h.distanceKm} km'].join(' · '),
                      status: status,
                      consultLabel: 'Emergency consultation · {0}'.trf([rupees(d.fee + MockData.emergencyCharge(d.fee))]),
                      onConsult: () => context.push('/emergency-consult/${d.id}${kind == null ? '' : '?kind=${kind.id}'}'),
                      updatedMin: null,
                      onCall: () => h == null ? null : showCallSheet(context, name: h.name, phone: h.phone),
                      onDirections: () => h == null ? null : showDirectionsSheet(context, h),
                      initials: d.initials,
                    ).staggerIn(i);
                  }(),
                ),
              const SizedBox(height: 14),
              const SectionLabel('Emergency hospitals · open 24 hours'),
              for (final (i, h) in _hospitals.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CareCard(
                    title: h.name,
                    line: h.distanceKm > 0 ? '${h.area} · ${h.distanceKm} km' : h.area,
                    status: 'Open 24 hours'.tr,
                    updatedMin: null,
                    onCall: () => showCallSheet(context, name: h.name, phone: h.phone),
                    onDirections: () => showDirectionsSheet(context, h),
                    icon: Icons.local_hospital_outlined,
                  ).staggerIn(_doctors.length + i),
                ),
              const SizedBox(height: 8),
              Text(
                _checkedAt == null
                    ? 'Doctors mark themselves available. If a status is old, it is removed on its own.'.tr
                    : 'Checked at {0}. Doctors mark themselves available; the list updates on its own.'.trf([clockLabel(_checkedAt!)]),
                style: OpText.small.copyWith(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CareCard extends StatelessWidget {
  const _CareCard({
    required this.title,
    required this.line,
    required this.status,
    required this.updatedMin,
    required this.onCall,
    required this.onDirections,
    this.icon,
    this.initials,
    this.consultLabel,
    this.onConsult,
  });

  final String title;
  final String line;
  final String status;
  final int? updatedMin;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final IconData? icon;
  final String? initials;
  final String? consultLabel;
  final VoidCallback? onConsult;

  @override
  Widget build(BuildContext context) {
    return OpCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsTile(text: initials ?? '', icon: icon, size: 48, color: OpColors.alarmWash),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: OpText.bodyStrong.copyWith(fontSize: 17)),
                    Text(line, style: OpText.small.copyWith(fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusTag(status, tone: Tone.good, icon: Icons.circle),
                        if (updatedMin != null) Text('Updated {0} min ago'.trf([updatedMin]), style: OpText.small.copyWith(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (onConsult != null) ...[
            OpButton(label: consultLabel ?? 'Emergency consultation', icon: Icons.emergency_outlined, height: 50, kind: OpButtonKind.danger, onPressed: onConsult),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OpButton(
                  label: 'Call'.tr,
                  icon: Icons.call,
                  height: 48,
                  kind: onConsult != null ? OpButtonKind.secondary : OpButtonKind.danger,
                  onPressed: onCall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: OpButton(label: 'Directions'.tr, icon: Icons.directions_outlined, height: 48, kind: OpButtonKind.secondary, onPressed: onDirections)),
            ],
          ),
        ],
      ),
    );
  }
}
