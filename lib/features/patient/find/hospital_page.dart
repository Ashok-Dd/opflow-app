import '../../../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/op_button.dart';
import '../../../widgets/doctor_card.dart';
import '../widgets.dart';
import 'find.dart' show HospitalFacade;

class HospitalPage extends StatelessWidget {
  const HospitalPage({super.key, required this.hospitalId});

  final String hospitalId;

  @override
  Widget build(BuildContext context) {
    final h = MockData.hospital(hospitalId);
    final doctors = MockData.doctorsAt(h.id);
    return OpPage(
      title: 'Hospital'.tr,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 20, OpSpace.gutter, 28),
        children: [
          HospitalFacade(h: h, height: 150).staggerIn(0),
          const SizedBox(height: 20),
          Text(h.name, style: OpText.display.copyWith(fontSize: 30)).staggerIn(1),
          const SizedBox(height: 4),
          Text(h.address, style: OpText.body.copyWith(color: OpColors.inkSoft)).staggerIn(1),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            const StatusTag('Open now', tone: Tone.good, icon: Icons.schedule),
            if (h.hasEmergency) const StatusTag('Emergency care 24 hours', tone: Tone.bad, icon: Icons.emergency_outlined),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OpIconAction(
                  icon: Icons.call_outlined,
                  label: 'Call'.tr,
                  onTap: () => showCallSheet(context, name: h.name, phone: h.phone),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OpIconAction(
                  icon: Icons.directions_outlined,
                  label: 'Directions'.tr,
                  onTap: () => showDirectionsSheet(context, h),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MapPicture(label: '{0} km from you'.trf([h.distanceKm]), height: 140),
          const SizedBox(height: 28),
          const SectionLabel('OPD timings'),
          Text(h.opdTimings, style: OpText.monoBody),
          const SizedBox(height: 24),
          const SectionLabel('Departments'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in h.typeIds)
                OpChip(
                  label: MockData.type(t).simple,
                  icon: MockData.type(t).icon,
                  selected: false,
                  onTap: () => context.push('/doctors?hospital=${h.id}&type=$t'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SectionLabel('Doctors here ({0})'.trf([doctors.length])),
          for (final (i, d) in doctors.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DoctorCard(
                doctor: d,
                hospitalId: h.id,
                onTap: () => context.push('/doctor/${d.id}?hospital=${h.id}'),
                onBook: () => context.push('/book/${d.id}?hospital=${h.id}'),
              ).staggerIn(i),
            ),
        ],
      ),
    );
  }
}
