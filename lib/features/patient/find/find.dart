import '../../../l10n/lang.dart';
import '../../../widgets/directory_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../mock/models.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/doctor_card.dart';

/// Find doctor: one search box and three ways in (type of doctor, health problem, hospital).
class FindTab extends StatefulWidget {
  const FindTab({super.key, this.initialTab});

  final int? initialTab;

  @override
  State<FindTab> createState() => _FindTabState();
}

class _FindTabState extends State<FindTab> {
  late int _tab = widget.initialTab ?? 0;
  final _q = TextEditingController();
  bool _nearMe = true;

  @override
  void didUpdateWidget(FindTab old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != null && widget.initialTab != old.initialTab) {
      setState(() => _tab = widget.initialTab!);
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String get _query => _q.text.trim().toLowerCase();

  void _openProblem(HealthProblem p) {
    if (p.danger) {
      context.push('/warning?problem=${p.id}');
    } else {
      context.push('/problem/${p.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query;
    final matchedDoctors = q.length < 2
        ? const <Doctor>[]
        : MockData.doctors.where((d) => d.name.toLowerCase().contains(q)).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(eyebrow: 'Doctors · Hospitals · Problems'.tr, title: 'Find a doctor'.tr),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search doctor, hospital or problem'.tr,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _q.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear'.tr,
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_q.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OpSegments(
                    labels: const ['Type of doctor', 'Health problem', 'Hospital'],
                    icons: const [Icons.medical_services_outlined, Icons.sick_outlined, Icons.local_hospital_outlined],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  if (matchedDoctors.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const SectionLabel('Doctors'),
                    for (final d in matchedDoctors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DoctorCard(doctor: d, onTap: () => context.push('/doctor/${d.id}'), onBook: () => context.push('/book/${d.id}')),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 28),
            sliver: SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: OpMotion.page,
                switchInCurve: OpMotion.curve,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  // Wait for the doctors and hospitals from the server (the OP loader meanwhile).
                  child: DirectoryGate(
                    height: 260,
                    text: _tab == 2 ? 'Finding hospitals near you…' : 'Finding doctors near you…',
                    builder: (_) => switch (_tab) {
                      0 => _types(q),
                      1 => _problems(q),
                      _ => _hospitals(q),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _types(String q) {
    final list = MockData.types
        .where((t) => q.isEmpty || t.simple.toLowerCase().contains(q) || t.proper.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.simple.compareTo(b.simple));
    if (list.isEmpty) return _nothing();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('All types · A to Z'),
        MenuGroup(
          children: [
            for (final t in list)
              MenuRow(
                icon: t.icon,
                title: t.simple,
                detail: '{0} · {1} doctors'.trf([t.proper, MockData.doctorsOfType(t.id).length]),
                onTap: () => context.push('/doctors?type=${t.id}'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _problems(String q) {
    final list = MockData.problems.where((p) => q.isEmpty || p.name.toLowerCase().contains(q)).toList();
    if (list.isEmpty) return _nothing();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What is troubling you?'.tr, style: OpText.title),
        const SizedBox(height: 4),
        Text('Pick one. We will show doctors who can help.'.tr, style: OpText.small.copyWith(fontSize: 15)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 520 ? 5 : 3;
          final w = (box.maxWidth - (cols - 1) * 8) / cols;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, p) in list.indexed)
                SizedBox(width: w, child: _ProblemTile(p: p, onTap: () => _openProblem(p)).staggerIn(i)),
            ],
          );
        }),
        const SizedBox(height: 16),
        InfoBox(
          icon: Icons.info_outline,
          child: Text('OPflow does not tell you the disease. It helps you find the right doctor.'.tr),
        ),
      ],
    );
  }

  Widget _hospitals(String q) {
    final list = MockData.hospitals
        .where((h) =>
            q.isEmpty || h.name.toLowerCase().contains(q) || h.area.toLowerCase().contains(q) || h.pin.contains(q))
        .toList();
    if (_nearMe) list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OpChip(label: 'Near me'.tr, icon: Icons.near_me_outlined, selected: _nearMe, onTap: () => setState(() => _nearMe = true)),
            OpChip(label: 'A to Z'.tr, icon: Icons.sort_by_alpha, selected: !_nearMe, onTap: () => setState(() => _nearMe = false)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Search by hospital name, area or PIN code above.'.tr, style: OpText.small.copyWith(fontSize: 13)),
        const SizedBox(height: 12),
        if (list.isEmpty) _nothing(),
        for (final (i, h) in (_nearMe ? list : (list..sort((a, b) => a.name.compareTo(b.name)))).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HospitalRow(h: h, onTap: () => context.push('/hospital/${h.id}')).staggerIn(i),
          ),
      ],
    );
  }

  Widget _nothing() => EmptyState(
        icon: Icons.search_off,
        title: 'Nothing found'.tr,
        text: 'Try a different word, or check the spelling.'.tr,
        action: 'Clear search'.tr,
        onAction: () => setState(_q.clear),
      );
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({required this.p, required this.onTap});

  final HealthProblem p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        // Icon + two lines of text; grows with the phone's text size so words never get cut.
        height: 60 + MediaQuery.textScalerOf(context).scale(13) * 2.6,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.danger ? OpColors.alarmWash : OpColors.card,
          borderRadius: OpRadius.controlAll,
          border: Border.all(color: p.danger ? OpColors.alarm.withValues(alpha: 0.4) : OpColors.line, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(p.icon, color: p.danger ? OpColors.alarm : OpColors.fern, size: 30),
            const SizedBox(height: 8),
            Text(p.name, textAlign: TextAlign.center, maxLines: 2, style: OpText.smallStrong.copyWith(fontSize: 13, height: 1.15)),
          ],
        ),
      ),
    );
  }
}

class HospitalRow extends StatelessWidget {
  const HospitalRow({super.key, required this.h, required this.onTap});

  final Hospital h;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final doctors = MockData.doctorsAt(h.id).length;
    return OpCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HospitalFacade(h: h, height: 96, radius: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(h.name, style: OpText.heading.copyWith(fontSize: 20))),
                    Text('{0} km'.trf([h.distanceKm]), style: OpText.mono(14, weight: FontWeight.w600, color: OpColors.fern)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(h.address, style: OpText.small.copyWith(fontSize: 13.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const StatusTag('Open now', tone: Tone.good, icon: Icons.schedule),
                    if (h.hasEmergency) const StatusTag('Emergency 24 hours', tone: Tone.bad, icon: Icons.emergency_outlined),
                    StatusTag('{0} doctors · {1} departments'.trf([doctors, h.typeIds.length]), tone: Tone.calm),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A drawn hospital front (stands in for a photo): roof line, window rows, a door, and a red cross
/// sign when the hospital has emergency care.
class HospitalFacade extends StatelessWidget {
  const HospitalFacade({super.key, required this.h, this.height = 80, this.radius = true});

  final Hospital h;
  final double height;
  final bool radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: OpColors.mint,
        borderRadius: radius ? BorderRadius.circular(OpRadius.control) : null,
      ),
      child: CustomPaint(painter: _FacadePainter(seed: h.id.hashCode, emergency: h.hasEmergency, label: h.initials)),
    );
  }
}

class _FacadePainter extends CustomPainter {
  _FacadePainter({required this.seed, required this.emergency, required this.label});

  final int seed;
  final bool emergency;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Fine hatch in the sky.
    final hatch = Paint()
      ..color = OpColors.forest.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = -h; x < w; x += 7) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), hatch);
    }
    // Ground line.
    final ground = Paint()..color = OpColors.forest.withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(0, h - 3, w, 3), ground);

    // Building block, centred, width varies a little per hospital.
    final bw = w * (0.52 + (seed.abs() % 20) / 100);
    final bh = h * 0.7;
    final left = (w - bw) / 2;
    final top = h - 3 - bh;
    final body = Paint()..color = OpColors.card;
    final line = Paint()
      ..color = OpColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(left, top, bw, bh);
    canvas.drawRect(rect, body);
    canvas.drawRect(rect, line);
    // Roof band.
    canvas.drawRect(Rect.fromLTWH(left, top, bw, bh * 0.14), Paint()..color = OpColors.forest);

    // Windows.
    final win = Paint()..color = OpColors.pine.withValues(alpha: 0.28);
    final cols = (bw / 18).floor().clamp(3, 12);
    final rows = 2;
    final gw = bw / cols;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (c == cols ~/ 2) continue; // door column
        final x = left + c * gw + gw * 0.28;
        final y = top + bh * 0.24 + r * bh * 0.3;
        canvas.drawRect(Rect.fromLTWH(x, y, gw * 0.44, bh * 0.16), win);
      }
    }
    // Door.
    final dx = left + (cols ~/ 2) * gw + gw * 0.18;
    canvas.drawRect(Rect.fromLTWH(dx, top + bh * 0.52, gw * 0.64, bh * 0.48), Paint()..color = OpColors.forest);

    // Cross sign above the roof.
    final cs = h * 0.16;
    final cx = w / 2;
    final cy = top - cs * 0.9;
    if (cy - cs / 2 > 0) {
      final cross = Paint()..color = emergency ? OpColors.alarm : OpColors.fern;
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: cs * 0.34, height: cs), cross);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: cs, height: cs * 0.34), cross);
    }
  }

  @override
  bool shouldRepaint(_FacadePainter old) => old.seed != seed || old.emergency != emergency;
}
