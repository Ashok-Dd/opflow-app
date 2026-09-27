import '../../l10n/lang.dart';
import '../../widgets/clock_time.dart';
import '../../core/launch.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../mock/data.dart';
import '../../mock/format.dart';
import '../../mock/models.dart';
import '../../state/patient_store.dart';
import '../../theme/text.dart';
import '../../theme/tokens.dart';
import '../../widgets/bits.dart';
import '../../widgets/doctor_portrait.dart';
import '../../widgets/op_button.dart';
import '../../widgets/op_loader.dart';
import '../../widgets/ticket.dart';

// ---------------------------------------------------------------------------
// Live status of the doctor, in words.

StatusTag liveTag(LiveStatus? s, {bool big = false}) {
  if (s == null) {
    return StatusTag(
      'Doctor on time',
      tone: Tone.good,
      icon: Icons.schedule,
      big: big,
    );
  }
  if (s.onBreak) {
    return StatusTag(
      'Doctor on break',
      tone: Tone.calm,
      icon: Icons.pause_circle_outline,
      big: big,
    );
  }
  if (s.lateMinutes >= 30) {
    return StatusTag(
      'Doctor {0} min late'.trf([s.lateMinutes]),
      tone: Tone.bad,
      icon: Icons.schedule,
      big: big,
    );
  }
  if (s.lateMinutes > 0) {
    return StatusTag(
      'Doctor {0} min late'.trf([s.lateMinutes]),
      tone: Tone.warn,
      icon: Icons.schedule,
      big: big,
    );
  }
  return StatusTag(
    'Doctor on time',
    tone: Tone.good,
    icon: Icons.schedule,
    big: big,
  );
}

StatusTag bookingStatusTag(Booking b) => b.needsNewTime && b.status == BookingStatus.upcoming
    // The doctor can't see them at this time: the old time must never look like a normal booking.
    ? StatusTag('Please pick a new time'.tr, tone: Tone.warn, icon: Icons.event_repeat)
    : switch (b.status) {
  BookingStatus.upcoming => const StatusTag(
    'Booked and paid',
    tone: Tone.good,
    icon: Icons.check,
  ),
  BookingStatus.done => const StatusTag(
    'Visit done',
    tone: Tone.calm,
    icon: Icons.check_circle_outline,
  ),
  BookingStatus.missed => const StatusTag(
    'You did not come',
    tone: Tone.warn,
    icon: Icons.event_busy_outlined,
  ),
  BookingStatus.cancelledByDoctor => const StatusTag(
    'Doctor cancelled · Money back sent',
    tone: Tone.bad,
    icon: Icons.currency_rupee,
  ),
};

// ---------------------------------------------------------------------------
// The booking ticket.

class VisitTicket extends StatelessWidget {
  const VisitTicket({
    super.key,
    required this.booking,
    this.footer,
    this.notchColor,
  });

  final Booking booking;
  final Widget? footer;
  final Color? notchColor;

  @override
  Widget build(BuildContext context) {
    final d = MockData.doctor(booking.doctorId);
    final h = MockData.hospital(booking.hospitalId);
    return TicketCard(
      notchColor: notchColor,
      top: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoctorPortrait.small(doctor: d, width: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: OpText.heading.copyWith(fontSize: 19)),
                Text(
                  '${MockData.type(d.typeId).simple} · ${h.name}',
                  style: OpText.small.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel(booking.date).toUpperCase(),
                      style: OpText.label,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.emergency
                          ? 'Emergency consultation'.tr
                          : 'Your time'.tr,
                      style: OpText.small.copyWith(
                        fontSize: 13,
                        color: booking.emergency ? OpColors.alarm : null,
                      ),
                    ),
                    if (booking.emergency)
                      Text('Go now'.tr, style: OpText.heading.copyWith(fontSize: 22, color: OpColors.alarm))
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ClockRange(booking.start, booking.start + 1, size: 24),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOKEN'.tr, style: OpText.label),
                  Text(
                    booking.tokenLabel,
                    style: OpText.mono(
                      40,
                      weight: FontWeight.w600,
                      color: OpColors.forest,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emergency band on Home.

class EmergencyBand extends StatelessWidget {
  const EmergencyBand({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: OpColors.alarm,
          borderRadius: OpRadius.cardAll,
        ),
        child: Row(
          children: [
            const Icon(Icons.emergency_outlined, color: Colors.white, size: 30)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 1,
                  end: 1.12,
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency help'.tr,
                    style: OpText.lead.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Find doctors and hospitals open now'.tr,
                    style: OpText.small.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day strip: 14 day boxes.

class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.doctor,
    required this.selected,
    required this.onSelect,
    this.windowsFor,
  });

  final Doctor doctor;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final List<TimeWindow> Function(DateTime day)? windowsFor;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 14; i++) today().add(Duration(days: i))];
    // Three lines of text; the strip grows with the phone's text size (Telugu letters are taller).
    final height =
        (Lang.instance.isTelugu ? 36 : 28) +
        MediaQuery.textScalerOf(
          context,
        ).scale(Lang.instance.isTelugu ? 66 : 60);
    return SizedBox(
      height: height < 96 ? 96 : height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OpSpace.gutter),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final ws = windowsFor?.call(d) ?? MockData.windows(doctor, d);
          final works = ws.isNotEmpty;
          final open = ws
              .where((w) => w.open)
              .fold<int>(0, (a, w) => a + w.left);
          final isSel = selected != null && sameDay(selected!, d);
          final enabled = works && open > 0;
          return TapScale(
            onTap: enabled ? () => onSelect(d) : null,
            child: AnimatedContainer(
              duration: OpMotion.quick,
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? OpColors.forest
                    : (enabled ? OpColors.card : OpColors.paperDeep),
                borderRadius: OpRadius.controlAll,
                border: Border.all(
                  color: isSel ? OpColors.forest : OpColors.line,
                  width: 1.3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      i == 0 ? 'Today'.tr : (i == 1 ? 'Tmrw'.tr : shortDay(d)),
                      style: OpText.smallStrong.copyWith(
                        fontSize: 12,
                        color: isSel ? OpColors.mint : OpColors.inkSoft,
                      ),
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: OpText.mono(
                      22,
                      weight: FontWeight.w600,
                      color: isSel
                          ? OpColors.paper
                          : (enabled ? OpColors.ink : OpColors.inkFaint),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      !works
                          ? 'No OPD'.tr
                          : (open == 0 ? 'Full'.tr : '{0} free'.trf([open])),
                      style: OpText.small.copyWith(
                        fontSize: 11,
                        color: isSel
                            ? OpColors.leaf
                            : (enabled ? OpColors.fern : OpColors.inkFaint),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hour windows with seat boxes.

class WindowList extends StatelessWidget {
  const WindowList({
    super.key,
    required this.windows,
    required this.selected,
    required this.onSelect,
  });

  final List<TimeWindow> windows;
  final int? selected;
  final ValueChanged<TimeWindow> onSelect;

  @override
  Widget build(BuildContext context) {
    if (windows.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No OPD on this day'.tr,
        text: 'Please pick another day.'.tr,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < windows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WindowRow(
              w: windows[i],
              selected: windows[i].start == selected,
              onTap: () => onSelect(windows[i]),
            ).staggerIn(i),
          ),
      ],
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.w,
    required this.selected,
    required this.onTap,
  });

  final TimeWindow w;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = w.over
        ? 'Time over'
        : (w.full
              ? 'Full'
              : '${w.left} ${w.left == 1 ? 'place' : 'places'} left');
    return TapScale(
      onTap: w.open ? onTap : null,
      child: AnimatedContainer(
        duration: OpMotion.quick,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? OpColors.mint
              : (w.open ? OpColors.card : OpColors.paperDeep),
          borderRadius: OpRadius.controlAll,
          border: Border.all(
            color: selected ? OpColors.fern : OpColors.line,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: OpMotion.quick,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? OpColors.fern : Colors.transparent,
                border: Border.all(
                  color: w.open ? OpColors.fern : OpColors.inkFaint,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: OpColors.paper)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClockRange(w.start, w.start + 1, size: 19, color: w.open ? OpColors.ink : OpColors.inkFaint),
                  const SizedBox(height: 6),
                  SeatMeter(total: w.capacity, taken: w.booked, box: 11),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              note,
              style: OpText.smallStrong.copyWith(
                color: !w.open
                    ? OpColors.inkFaint
                    : (w.left <= 2 ? OpColors.amber : OpColors.fern),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Call and directions: the phone's own dialer and maps app.

Future<void> showCallSheet(
  BuildContext context, {
  required String name,
  required String phone,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OpSpace.gutter,
          0,
          OpSpace.gutter,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call {0}'.trf([name]), style: OpText.title),
            const SizedBox(height: 12),
            OpCard(
              child: Row(
                children: [
                  const Icon(Icons.call_outlined, color: OpColors.fern),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      phone,
                      style: OpText.mono(22, weight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy number'.tr,
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      Navigator.pop(context);
                      showToast(context, 'Number copied'.tr);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (canDial(phone))
              OpButton(
                label: 'Call now'.tr,
                icon: Icons.call,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  if (!await openDialer(phone)) {
                    messenger.showSnackBar(SnackBar(backgroundColor: OpColors.alarm, content: Text('Could not open the phone app. Please dial {0}.'.trf([phone]))));
                  }
                },
              )
            else
              InfoBox(icon: Icons.lock_outline, tone: Tone.calm, child: Text('The number is hidden for privacy.'.tr)),
          ],
        ),
      ),
    ),
  );
}

Future<void> showDirectionsSheet(BuildContext context, Hospital h) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OpSpace.gutter,
          0,
          OpSpace.gutter,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.name, style: OpText.title),
            const SizedBox(height: 4),
            Text(
              h.address,
              style: OpText.body.copyWith(color: OpColors.inkSoft),
            ),
            const SizedBox(height: 14),
            MapPicture(label: '{0} km from you'.trf([h.distanceKm])),
            const SizedBox(height: 16),
            OpButton(
              label: 'Open in Maps'.tr,
              icon: Icons.directions_outlined,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final ok = await openDirections(lat: h.lat, lng: h.lng, name: h.name, address: '${h.address}, ${h.area} ${h.pin}');
                if (!ok) {
                  messenger.showSnackBar(SnackBar(backgroundColor: OpColors.alarm, content: Text('Could not open Maps on this phone.'.tr)));
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// A drawn street map with a pin. Stands in for a real map image.
class MapPicture extends StatelessWidget {
  const MapPicture({super.key, required this.label, this.height = 150});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E6D8),
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _StreetsPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: OpColors.alarm, size: 40)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0,
                      end: -6,
                      duration: 700.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: OpColors.card,
                borderRadius: OpRadius.smallAll,
                border: Border.all(color: OpColors.lineSoft),
              ),
              child: Text(
                label,
                style: OpText.smallStrong.copyWith(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreetsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9;
    final small = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 4;
    final park = Paint()..color = OpColors.mint;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.62,
        size.height * 0.08,
        size.width * 0.25,
        size.height * 0.3,
      ),
      park,
    );
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x - 20, size.height), small);
    }
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), small);
    }
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.45),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.42, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Receipt sheet.

Future<void> showReceipt(BuildContext context, Booking b, String patientName) {
  final d = MockData.doctor(b.doctorId);
  final refunded = b.status == BookingStatus.cancelledByDoctor;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OpSpace.gutter,
          0,
          OpSpace.gutter,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt'.tr, style: OpText.title),
            const SizedBox(height: 12),
            KeyValueRow('Doctor', d.name, strong: true),
            KeyValueRow('Patient', patientName),
            KeyValueRow('Day', longDate(b.date)),
            KeyValueRow('Your time', windowLabel(b.start), mono: true),
            KeyValueRow('Token', b.tokenLabel, mono: true),
            const Divider(height: 24),
            KeyValueRow(
              'Doctor fee',
              rupees(b.fee),
              mono: true,
              strong: !b.emergency,
            ),
            if (b.emergency) ...[
              KeyValueRow(
                'Emergency charge',
                rupees(b.emergencyCharge),
                mono: true,
              ),
              KeyValueRow(
                'Total paid',
                rupees(b.total),
                mono: true,
                strong: true,
              ),
            ],
            KeyValueRow('Paid by', 'UPI'),
            KeyValueRow('Payment ID', b.paymentId, mono: true),
            const SizedBox(height: 12),
            refunded
                ? InfoBox(
                    tone: Tone.good,
                    icon: Icons.currency_rupee,
                    child: Text(
                      'Doctor cancelled. Full {0} sent back to your account.'
                          .trf([rupees(b.total)]),
                    ),
                  )
                : InfoBox(
                    tone: Tone.good,
                    icon: Icons.check_circle_outline,
                    child: Text('Payment done'.tr),
                  ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Pull down to refresh, with the OP loader instead of a spinner.

class OpRefresh extends StatefulWidget {
  const OpRefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;

  /// Must be a scroll view using [opRefreshPhysics].
  final Widget child;

  @override
  State<OpRefresh> createState() => _OpRefreshState();
}

const opRefreshPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

class _OpRefreshState extends State<OpRefresh> {
  double _pull = 0;
  bool _busy = false;
  bool _armed = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || _busy) return false;
    final over = -n.metrics.pixels;
    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      setState(() {
        _pull = over.clamp(0, 120);
        if (_pull > 80 &&
            n is ScrollUpdateNotification &&
            n.dragDetails != null) {
          _armed = true;
        }
      });
    }
    if (n is ScrollEndNotification ||
        (n is ScrollUpdateNotification && n.dragDetails == null && _armed)) {
      if (_armed) _run();
    }
    return false;
  }

  Future<void> _run() async {
    _armed = false;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    await widget.onRefresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final show = _busy || _pull > 8;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        if (show)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: _busy ? 1 : (_pull / 80).clamp(0, 1),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: OpColors.card,
                    borderRadius: OpRadius.controlAll,
                    border: Border.all(color: OpColors.line),
                  ),
                  child: const OpLoader(size: 30),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


/// "The doctor can't see you at this time": the patient picks any new time (no charge), or gets all their money
/// back if they don't within 48 hours.
class PickNewTimeCard extends StatelessWidget {
  const PickNewTimeCard({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OpColors.amberWash,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.amber.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_repeat, color: OpColors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text('Please pick a new time'.tr, style: OpText.heading.copyWith(fontSize: 18))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The doctor cannot see you at this time. Pick any other time with the same doctor, free of cost. If you do not pick one within 48 hours, all your money comes back.'.tr,
            style: OpText.small.copyWith(fontSize: 14.5, color: OpColors.ink),
          ),
          const SizedBox(height: 12),
          OpButton(label: 'Pick a new time'.tr, icon: Icons.event_available_outlined, onPressed: () => context.push('/booking/${booking.id}/change')),
        ],
      ),
    );
  }
}
