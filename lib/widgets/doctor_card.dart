import '../l10n/lang.dart';
import 'package:flutter/material.dart';

import '../mock/data.dart';
import '../mock/format.dart';
import '../mock/models.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'doctor_portrait.dart';
import 'op_button.dart';

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

/// The doctor card patients see in every list: compact (about a third of a phone screen) but complete —
/// portrait, who, where, when, the next free time and the fee.
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(tag: 'portrait-${d.id}', child: DoctorPortrait(doctor: d, width: 64)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: OpText.heading.copyWith(fontSize: 18, height: 1.15)),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: type.simple.tr, style: OpText.smallStrong.copyWith(color: OpColors.fern, fontSize: 13)),
                            TextSpan(text: '  ·  ${type.proper.tr}', style: OpText.small.copyWith(fontSize: 12.5)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${d.degrees}  ·  ${'{0} yrs'.trf([d.years])}  ·  ${d.languages.take(2).join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OpText.small.copyWith(fontSize: 12, color: OpColors.inkSoft),
                        ),
                        if (emergency != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.emergency_outlined, size: 13, color: OpColors.alarm),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(emergency,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: OpText.small.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: OpColors.alarm)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Where and when
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  _InfoLine(icon: Icons.local_hospital_outlined, strong: h.name, rest: '${h.area} · ${h.distanceKm} km'),
                  const SizedBox(height: 4),
                  _InfoLine(icon: Icons.schedule, strong: doctorDays(d).tr, rest: doctorHours(d)),
                ],
              ),
            ),
            // Next free time and fee
            Container(
              decoration: BoxDecoration(
                color: OpColors.mint.withValues(alpha: 0.5),
                border: const Border(top: BorderSide(color: OpColors.lineSoft)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.bookingsPaused ? 'BOOKINGS'.tr : 'NEXT FREE TIME'.tr, style: OpText.label.copyWith(fontSize: 9.5)),
                        const SizedBox(height: 1),
                        Text(
                          d.bookingsPaused
                              ? 'Paused by the doctor'.tr
                              : (next == null ? 'Full for 2 weeks'.tr : '${dayLabel(next.$1)}  ${windowLabel(next.$2.start)}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OpText.smallStrong.copyWith(fontSize: 13.5, color: OpColors.ink),
                        ),
                        if (next != null)
                          Text('{0} left'.trf([next.$2.left]),
                              style: OpText.small.copyWith(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: next.$2.left <= 2 ? OpColors.amber : OpColors.fern)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(rupees(d.fee), style: OpText.mono(16, weight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  OpButton(label: 'Book'.tr, expand: false, height: 36, onPressed: next == null ? null : (onBook ?? onTap)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.strong, required this.rest});

  final IconData icon;
  final String strong;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: OpColors.fern)),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: strong, style: OpText.smallStrong.copyWith(fontSize: 12.5)),
              const TextSpan(text: '  '),
              TextSpan(text: rest, style: OpText.small.copyWith(fontSize: 12.5)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
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
