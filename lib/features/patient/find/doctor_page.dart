import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../state/directory_store.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/doctor_card.dart';
import '../../../widgets/doctor_portrait.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/page_header.dart';

class DoctorPage extends ConsumerStatefulWidget {
  const DoctorPage({super.key, required this.doctorId, this.hospitalId, this.preview = false});

  final String doctorId;
  final String? hospitalId;

  /// Opened by the doctor to see their own page: no booking button.
  final bool preview;

  @override
  ConsumerState<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends ConsumerState<DoctorPage> {
  String? _hid;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(directoryProvider).doctor(widget.doctorId);
    final hid = _hid ?? widget.hospitalId ?? d.hospitalIds.first;
    final type = MockData.type(d.typeId);
    final next = MockData.nextFree(d);
    final width = MediaQuery.sizeOf(context).width;
    final portraitW = (width - OpSpace.gutter * 2).clamp(0, 220).toDouble();

    return OpPage(
      title: widget.preview ? 'How patients see you' : 'Doctor',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 24, OpSpace.gutter, 32),
        children: [
          Center(child: Hero(tag: 'portrait-${d.id}', child: DoctorPortrait(doctor: d, width: portraitW))),
          const SizedBox(height: 22),
          Text('CHECKED BY OPFLOW'.tr, textAlign: TextAlign.center, style: OpText.label.copyWith(color: OpColors.amber, letterSpacing: 1.8)),
          const SizedBox(height: 6),
          Text(d.name, textAlign: TextAlign.center, style: OpText.display.copyWith(fontSize: 32)),
          const SizedBox(height: 6),
          Text('${type.simple} · ${type.proper}', textAlign: TextAlign.center, style: OpText.bodyStrong.copyWith(color: OpColors.fern)),
          Text(d.degrees, textAlign: TextAlign.center, style: OpText.small),
          const SizedBox(height: 18),
          const DoubleRule(),
          const SizedBox(height: 14),
          // Facts in a row of four, divided by hairlines.
          IntrinsicHeight(
            child: Row(
              children: [
                _Fact(label: 'Gender'.tr, value: d.gender.tr, icon: genderIcon(d.gender)),
                const VerticalDivider(width: 1),
                _Fact(label: 'Experience'.tr, value: '${d.years} yrs', icon: Icons.workspace_premium_outlined),
                const VerticalDivider(width: 1),
                _Fact(label: 'Doctor fee'.tr, value: rupees(d.fee), icon: Icons.currency_rupee),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.translate, size: 18, color: OpColors.fern),
              const SizedBox(width: 8),
              Expanded(child: Text('Speaks ${d.languages.join(', ')}', style: OpText.body.copyWith(fontSize: 15))),
            ],
          ),
          if (d.emergency != EmergencyStatus.off) ...[
            const SizedBox(height: 12),
            StatusTag(
              switch (d.emergency) {
                EmergencyStatus.availableNow => 'Emergency: available now'.tr,
                _ => 'Emergency: available till {0}'.trf([d.emergencyTill]),
              },
              tone: Tone.bad,
              icon: Icons.emergency_outlined,
            ),
          ],
          if (d.bookingsPaused) ...[
            const SizedBox(height: 16),
            InfoBox(
              tone: Tone.warn,
              icon: Icons.pause_circle_outline,
              child: Text('The doctor is not taking new bookings right now. Please check again later, or see another doctor.'.tr),
            ),
          ],
          const SizedBox(height: 28),
          const SectionLabel('OPD timings'),
          _WeekTable(doctor: d),
          if (next != null) ...[
            const SizedBox(height: 12),
            InfoBox(
              tone: Tone.good,
              icon: Icons.event_available_outlined,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Next free time: '.tr),
                TextSpan(text: '${dayLabel(next.$1)}, ${windowLabel(next.$2.start)}', style: OpText.bodyStrong.copyWith(fontSize: 15)),
              ])),
            ),
          ],
          const SizedBox(height: 28),
          SectionLabel(d.hospitalIds.length > 1 ? 'Pick a hospital' : 'Hospital'),
          for (final id in d.hospitalIds)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HospitalChoice(
                h: MockData.hospital(id),
                selected: hid == id,
                selectable: d.hospitalIds.length > 1,
                onTap: () => setState(() => _hid = id),
                onOpen: () => context.push('/hospital/$id'),
              ),
            ),
          const SizedBox(height: 20),
          const SectionLabel('About the doctor'),
          Text(d.about.isEmpty ? 'The doctor has not written about themselves yet.' : d.about,
              style: OpText.body.copyWith(fontFamily: 'Newsreader', fontSize: 18, height: 1.55)),
        ],
      ),
      bottom: widget.preview
          ? null
          : Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DOCTOR FEE'.tr, style: OpText.label.copyWith(fontSize: 11)),
                    Text(rupees(d.fee), style: OpText.mono(22, weight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OpButton(
                    label: d.bookingsPaused ? 'Bookings paused' : 'Book a time',
                    icon: d.bookingsPaused ? Icons.pause_circle_outline : Icons.event_available,
                    onPressed: next == null ? null : () => context.push('/book/${d.id}?hospital=$hid'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: OpColors.fern),
          const SizedBox(height: 4),
          Text(value, textAlign: TextAlign.center, style: OpText.mono(16, weight: FontWeight.w600)),
          Text(label, textAlign: TextAlign.center, style: OpText.small.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Monday to Sunday with the doctor's hours; today is highlighted.
class _WeekTable extends StatelessWidget {
  const _WeekTable({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final todayN = DateTime.now().weekday;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: OpColors.card, borderRadius: OpRadius.cardAll, border: Border.all(color: OpColors.line, width: 1.2)),
      child: Column(
        children: [
          for (var w = 1; w <= 7; w++) ...[
            Container(
              color: w == todayN ? OpColors.mint : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(w == todayN ? '${weekdayName(w)} ·' : weekdayName(w),
                        style: (w == todayN ? OpText.smallStrong : OpText.small.copyWith(color: OpColors.ink)).copyWith(fontSize: 14)),
                  ),
                  Expanded(
                    child: Text(
                      doctor.workDays.contains(w) ? doctorHours(doctor) : 'No OPD'.tr,
                      textAlign: TextAlign.right,
                      style: doctor.workDays.contains(w)
                          ? OpText.mono(13.5, weight: w == todayN ? FontWeight.w600 : FontWeight.w500)
                          : OpText.small.copyWith(fontSize: 13, color: OpColors.inkFaint),
                    ),
                  ),
                ],
              ),
            ),
            if (w < 7) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _HospitalChoice extends StatelessWidget {
  const _HospitalChoice({required this.h, required this.selected, required this.selectable, required this.onTap, required this.onOpen});

  final Hospital h;
  final bool selected;
  final bool selectable;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final on = selected && selectable;
    return TapScale(
      onTap: selectable ? onTap : onOpen,
      child: AnimatedContainer(
        duration: OpMotion.quick,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: on ? OpColors.mint : OpColors.card,
          borderRadius: OpRadius.cardAll,
          border: Border.all(color: on ? OpColors.fern : OpColors.line, width: on ? 2 : 1.2),
        ),
        child: Row(
          children: [
            if (selectable) ...[
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: OpColors.fern),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name, style: OpText.bodyStrong),
                  Text('{0} · {1} km'.trf([h.area, h.distanceKm]), style: OpText.small.copyWith(fontSize: 13)),
                ],
              ),
            ),
            TextButton(onPressed: onOpen, child: Text('See hospital'.tr)),
          ],
        ),
      ),
    );
  }
}
