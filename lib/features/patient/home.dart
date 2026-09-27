import '../../l10n/lang.dart';
import '../../widgets/notifications_off.dart';
import '../../widgets/directory_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mock/data.dart';
import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/directory_store.dart';
import '../../state/patient_store.dart';
import '../../state/session.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/doctor_card.dart';
import '../../widgets/doctor_portrait.dart';
import '../../widgets/op_button.dart';
import '../../widgets/page_header.dart';
import 'find/find.dart' show HospitalFacade;
import 'widgets.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning'.tr;
    if (h < 17) return 'Good afternoon'.tr;
    return 'Good evening'.tr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(patientProvider);
    final session = ref.watch(sessionProvider);
    final directory = ref.watch(directoryProvider);
    final next = store.nextVisit;
    final visited = store.visitedDoctors;
    final name = store.me.name.split(' ').first;
    // Built when shown (the doctors may still be loading from the server).
    List<Doctor> nearDoctors() => [...directory.doctors]
      ..sort((a, b) => MockData.hospital(a.hospitalIds.first).distanceKm.compareTo(MockData.hospital(b.hospitalIds.first).distanceKm));
    final scale = MediaQuery.textScalerOf(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 18, OpSpace.gutter, 36),
        children: [
          // Letterhead
          PageHeader(
            eyebrow: [longDate(DateTime.now()).split(',').first, if (session.place.isNotEmpty) session.place.split(',').first].join(' · '),
            title: '${_greeting()},\n$name',
            trailing: _Bell(count: store.unread, onTap: () => context.push('/messages')),
            rule: false,
          ).staggerIn(0),
          const SizedBox(height: 18),
          const NotificationsOffCard(forDoctor: false),
          // Search opens Find.
          TapScale(
            onTap: () => context.go('/find'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: OpColors.card,
                borderRadius: OpRadius.controlAll,
                border: Border.all(color: OpColors.lineSoft),
                boxShadow: OpShadow.card,
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: OpColors.fern),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Search doctor, hospital or problem'.tr, style: OpText.body.copyWith(color: OpColors.inkFaint))),
                ],
              ),
            ),
          ).staggerIn(1),
          const SizedBox(height: 14),
          EmergencyBand(onTap: () => context.push('/emergency')).staggerIn(2),
          const SizedBox(height: 30),

          // Next visit
          if (next != null && next.needsNewTime) ...[
            const SizedBox(height: 4),
            PickNewTimeCard(booking: next),
            const SizedBox(height: 18),
          ],
          if (next != null) ...[
            SectionLabel('Your next visit',
                trailing: store.upcoming.length > 1
                    ? TextButton(onPressed: () => context.go('/bookings'), child: Text('See all {0}'.trf([store.upcoming.length])))
                    : null),
            VisitTicket(
              booking: next,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sameDay(next.date, DateTime.now())) ...[
                    liveTag(store.live[next.id], big: true),
                    const SizedBox(height: 8),
                    if (store.live[next.id] != null)
                      Text(
                        'Now seeing token {0} · {1} before you'
                            .trf([store.live[next.id]!.nowSeeing, people(store.live[next.id]!.aheadOf(next))]),
                        style: OpText.bodyStrong.copyWith(fontSize: 15),
                      ),
                    const SizedBox(height: 12),
                  ] else if (!next.needsNewTime) ...[
                    StatusTag('Please reach by {0}'.trf([clockLabel(next.windowStart.subtract(const Duration(minutes: 15)))]),
                        tone: Tone.info, icon: Icons.directions_walk),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(child: OpIconAction(icon: Icons.podcasts, label: 'See live turn'.tr, onTap: () => context.push('/booking/${next.id}'))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OpIconAction(
                          icon: Icons.directions_outlined,
                          label: 'Get directions'.tr,
                          onTap: () => showDirectionsSheet(context, MockData.hospital(next.hospitalId)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OpIconAction(
                          icon: Icons.call_outlined,
                          label: 'Call hospital'.tr,
                          onTap: () {
                            final h = MockData.hospital(next.hospitalId);
                            showCallSheet(context, name: h.name, phone: h.phone);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).staggerIn(3),
            const SizedBox(height: 32),
          ],

          // Doctors near you
          SectionLabel('Doctors near you', trailing: TextButton(onPressed: () => context.go('/find'), child: Text('See all'.tr))),
          DirectoryGate(
            height: 144 * 1.25 + 34 + scale.scale(100),
            builder: (context) {
              final near = nearDoctors();
              return SizedBox(
                // Portrait (144 × 180) + padding + four lines of text at the phone's text size.
                height: 144 * 1.25 + 34 + scale.scale(100),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: near.length.clamp(0, 10),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => DoctorTile(doctor: near[i], onTap: () => context.push('/doctor/${near[i].id}')),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Three ways to find
          const SectionLabel('How do you want to find a doctor?'),
          _WayRow(icon: Icons.medical_services_outlined, title: 'By type of doctor'.tr, text: 'Child doctor, Skin doctor …'.tr, onTap: () => context.go('/find?tab=0')),
          const SizedBox(height: 10),
          _WayRow(icon: Icons.sick_outlined, title: 'By health problem'.tr, text: 'Fever, cough, stomach pain …'.tr, onTap: () => context.go('/find?tab=1')),
          const SizedBox(height: 10),
          _WayRow(icon: Icons.local_hospital_outlined, title: 'By hospital name'.tr, text: 'Hospitals near you'.tr, onTap: () => context.go('/find?tab=2')),
          const SizedBox(height: 32),

          // Common doctors
          const SectionLabel('Common doctors'),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 520 ? 8 : 4;
            final w = (box.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in MockData.commonTypeIds)
                  SizedBox(width: w, child: _TypeTile(id: id, onTap: () => context.push('/doctors?type=$id'))),
              ],
            );
          }),
          const SizedBox(height: 32),

          // Hospitals near you
          const SectionLabel('Hospitals near you'),
          DirectoryGate(
            height: 96 + scale.scale(44),
            text: 'Finding hospitals near you…',
            builder: (context) {
              final hospitals = [...MockData.hospitals]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
              return SizedBox(
                height: 96 + scale.scale(44),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: hospitals.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _HospitalTile(h: hospitals[i], onTap: () => context.push('/hospital/${hospitals[i].id}')),
                ),
              );
            },
          ),

          // Visited
          if (visited.isNotEmpty) ...[
            const SizedBox(height: 32),
            const SectionLabel('Doctors you visited'),
            for (final d in visited.take(3))
              Padding(padding: const EdgeInsets.only(bottom: 10), child: _VisitedRow(doctor: directory.doctor(d.id))),
          ],

          // Sign-off
          const SizedBox(height: 36),
          const DoubleRule(color: OpColors.inkFaint),
          const SizedBox(height: 18),
          Text('Right patient, right doctor,\nat the right time.'.tr,
              textAlign: TextAlign.center, style: OpText.displayItalic.copyWith(fontSize: 22, color: OpColors.inkSoft)),
          const SizedBox(height: 8),
          Text('OPFLOW'.tr, textAlign: TextAlign.center, style: OpText.label.copyWith(letterSpacing: 3)),
        ],
      ),
    );
  }
}

class _HospitalTile extends StatelessWidget {
  const _HospitalTile({required this.h, required this.onTap});

  final Hospital h;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: 250,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.line, width: 1.2)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The hospital's front, as a narrow strip on the left (no empty band under the words).
            SizedBox(width: 72, child: HospitalFacade(h: h, height: double.infinity, radius: false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(h.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: OpText.heading.copyWith(fontSize: 15.5, height: 1.2)),
                    const SizedBox(height: 3),
                    Text('{0} · {1} km'.trf([h.area, h.distanceKm]), maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.small.copyWith(fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(h.hasEmergency ? Icons.emergency_outlined : Icons.check_circle_outline,
                            size: 13, color: h.hasEmergency ? OpColors.alarm : OpColors.fern),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text((h.hasEmergency ? '24 hours · Emergency' : 'Open now').tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OpText.smallStrong.copyWith(fontSize: 12, color: h.hasEmergency ? OpColors.alarm : OpColors.fern)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitedRow extends StatelessWidget {
  const _VisitedRow({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    return OpCard(
      onTap: () => context.push('/doctor/${d.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DoctorPortrait.small(doctor: d),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: OpText.bodyStrong),
                Text(MockData.type(d.typeId).simple, style: OpText.small.copyWith(fontSize: 13)),
              ],
            ),
          ),
          OpButton(label: 'Book again'.tr, expand: false, height: 40, kind: OpButtonKind.secondary, onPressed: () => context.push('/book/${d.id}')),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Semantics(
        label: 'Messages, {0} new'.trf([count]),
        button: true,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: OpColors.card,
            borderRadius: OpRadius.controlAll,
            border: Border.all(color: OpColors.line, width: 1.2),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none, color: OpColors.ink, size: 26),
              if (count > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: OpColors.alarm,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: OpColors.card, width: 1.5),
                    ),
                    child: Text('$count', style: OpText.mono(11, color: Colors.white, weight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WayRow extends StatelessWidget {
  const _WayRow({required this.icon, required this.title, required this.text, required this.onTap});

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: OpColors.mint, borderRadius: OpRadius.controlAll),
            child: Icon(icon, color: OpColors.forest, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: OpText.lead),
                Text(text, style: OpText.small),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: OpColors.fern, size: 28),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.id, required this.onTap});

  final String id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MockData.type(id);
    final short = t.simple.replaceAll('Ear-nose-throat', 'ENT');
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 58 + MediaQuery.textScalerOf(context).scale(12.5) * 2.6,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: OpColors.card,
          borderRadius: OpRadius.controlAll,
          border: Border.all(color: OpColors.line, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(t.icon, color: OpColors.fern, size: 28),
            const SizedBox(height: 6),
            Text(short,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: OpText.smallStrong.copyWith(fontSize: 12.5, height: 1.15)),
          ],
        ),
      ),
    );
  }
}
