import '../l10n/lang.dart';
import 'package:flutter/material.dart';

import '../mock/data.dart';
import '../mock/format.dart';
import '../mock/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'bits.dart';
import 'doctor_portrait.dart';
import 'op_button.dart';
import 'ticket.dart';

/// "Mon – Sat", "Every day", or "Mon, Wed, Fri".
String doctorDays(Doctor d) {
  final days = d.workDays;
  if (days.length == 7) return 'Every day';
  if (days.length == 6 && !days.contains(7)) return 'Mon – Sat';
  return days.map(weekdayShort).join(', ');
}

/// "9 AM – 1 PM, 5 PM – 7 PM"
String doctorHours(Doctor d) => d.sessions.map((s) => '${hourLabel(s.$1)} – ${hourLabel(s.$2)}').join(', ');

IconData genderIcon(String g) => switch (g) {
      'Male' => Icons.male,
      'Female' => Icons.female,
      _ => Icons.person_outline,
    };

/// The large doctor card patients see in every list: portrait, who, where, when, and the next free time.
class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, required this.onTap, this.onBook, this.hospitalId});

  final Doctor doctor;
  final VoidCallback onTap;
  final VoidCallback? onBook;
  final String? hospitalId;

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final type = MockData.type(d.typeId);
    final h = MockData.hospital(hospitalId ?? d.hospitalIds.first);
    final next = MockData.nextFree(d);
    final emergency = switch (d.emergency) {
      EmergencyStatus.availableNow => 'Emergency: available now'.tr,
      EmergencyStatus.availableTill => 'Emergency: till {0}'.trf([d.emergencyTill]),
      EmergencyStatus.off => null,
    };

    return TapScale(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: OpColors.card,
          borderRadius: OpRadius.cardAll,
          border: Border.all(color: OpColors.lineSoft),
          boxShadow: OpShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Who
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(tag: 'portrait-${d.id}', child: DoctorPortrait(doctor: d, width: 100)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CHECKED BY OPFLOW'.tr, style: OpText.label.copyWith(fontSize: 10, color: OpColors.amber, letterSpacing: 1.4)),
                        const SizedBox(height: 4),
                        Text(d.name, style: OpText.heading.copyWith(fontSize: 21, height: 1.15)),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: type.simple, style: OpText.smallStrong.copyWith(color: OpColors.fern)),
                            TextSpan(text: '  ·  ${type.proper}', style: OpText.small.copyWith(fontSize: 13)),
                          ]),
                        ),
                        Text(d.degrees, style: OpText.small.copyWith(fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            _Fact(icon: genderIcon(d.gender), text: d.gender.tr),
                            _Fact(icon: Icons.workspace_premium_outlined, text: '{0} yrs'.trf([d.years])),
                            _Fact(icon: Icons.translate, text: d.languages.take(2).join(', ')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (emergency != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: StatusTag(emergency, tone: Tone.bad, icon: Icons.emergency_outlined),
              ),
            // Where and when
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(height: 1, child: CustomPaint(painter: _Dashes())),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  _InfoLine(icon: Icons.local_hospital_outlined, strong: h.name, rest: '${h.area} · ${h.distanceKm} km'),
                  const SizedBox(height: 8),
                  _InfoLine(icon: Icons.schedule, strong: doctorDays(d), rest: doctorHours(d), mono: true),
                ],
              ),
            ),
            // Next free time and fee
            Container(
              color: OpColors.mint.withValues(alpha: 0.55),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.bookingsPaused ? 'BOOKINGS'.tr : 'NEXT FREE TIME'.tr, style: OpText.label.copyWith(fontSize: 10.5)),
                        const SizedBox(height: 2),
                        Text(
                          d.bookingsPaused
                              ? 'Paused by the doctor'.tr
                              : (next == null ? 'Full for 2 weeks' : '${dayLabel(next.$1)}  ${windowLabel(next.$2.start)}'),
                          style: OpText.mono(15, weight: FontWeight.w600),
                        ),
                        if (next != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SeatMeter(total: next.$2.capacity, taken: next.$2.booked, box: 8, animate: false),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('{0} left'.trf([next.$2.left]),
                                    style: OpText.small.copyWith(
                                        fontSize: 12, fontWeight: FontWeight.w600, color: next.$2.left <= 2 ? OpColors.amber : OpColors.fern)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rupees(d.fee), style: OpText.mono(20, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      OpButton(label: 'Book'.tr, expand: false, height: 40, onPressed: next == null ? null : (onBook ?? onTap)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: OpColors.inkSoft),
        const SizedBox(width: 3),
        Text(text, style: OpText.small.copyWith(fontSize: 12.5, color: OpColors.ink)),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.strong, required this.rest, this.mono = false});

  final IconData icon;
  final String strong;
  final String rest;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: OpColors.fern)),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: strong, style: OpText.smallStrong),
              const TextSpan(text: '  '),
              TextSpan(text: rest, style: mono ? OpText.mono(13, color: OpColors.inkSoft) : OpText.small),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => DashedLinePainter().paint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Compact portrait card for horizontal lists ("Doctors near you").
class DoctorTile extends StatelessWidget {
  const DoctorTile({super.key, required this.doctor, required this.onTap, this.width = 164});

  final Doctor doctor;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final next = MockData.nextFree(d);
    return TapScale(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: OpColors.card,
          borderRadius: OpRadius.cardAll,
          border: Border.all(color: OpColors.lineSoft),
          boxShadow: OpShadow.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoctorPortrait(doctor: d, width: width - 20, seal: false),
            const SizedBox(height: 10),
            Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.heading.copyWith(fontSize: 16.5)),
            Text(MockData.type(d.typeId).simple, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: OpText.smallStrong.copyWith(fontSize: 13, color: OpColors.fern)),
            const SizedBox(height: 6),
            Text(d.bookingsPaused ? 'Bookings paused' : (next == null ? 'Full for 2 weeks' : dayLabel(next.$1)),
                maxLines: 1, style: OpText.small.copyWith(fontSize: 12, color: d.bookingsPaused ? OpColors.amber : OpColors.ink)),
            Text(next == null ? rupees(d.fee) : '${windowLabel(next.$2.start)} · ${rupees(d.fee)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.mono(12.5, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
