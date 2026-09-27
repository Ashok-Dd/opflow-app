import '../l10n/lang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/text.dart';
import '../theme/tokens.dart';
import 'op_button.dart';
import 'op_loader.dart';

// ---------------------------------------------------------------------------
// Status tag: a small rounded tag, tinted, with a coloured dot or icon.

enum Tone { good, warn, bad, calm, info }

extension ToneColors on Tone {
  Color get edge => switch (this) {
        Tone.good => OpColors.fern,
        Tone.warn => OpColors.amber,
        Tone.bad => OpColors.alarm,
        Tone.calm => OpColors.inkSoft,
        Tone.info => OpColors.forest,
      };

  Color get wash => switch (this) {
        Tone.good => OpColors.mint,
        Tone.warn => OpColors.amberWash,
        Tone.bad => OpColors.alarmWash,
        Tone.calm => OpColors.paperDeep,
        Tone.info => OpColors.mint,
      };
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.text, {super.key, this.tone = Tone.good, this.icon, this.big = false});

  final String text;
  final Tone tone;
  final IconData? icon;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(big ? 12 : 9, big ? 9 : 5, big ? 14 : 11, big ? 9 : 5),
      decoration: BoxDecoration(
        color: tone.wash,
        borderRadius: OpRadius.smallAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: big ? 18 : 15, color: tone.edge), const SizedBox(width: 6)]
          else ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: tone.edge, shape: BoxShape.circle)),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(text.tr,
                style: (big ? OpText.bodyStrong : OpText.smallStrong.copyWith(fontSize: 13)).copyWith(
                    color: tone == Tone.calm ? OpColors.ink : Color.lerp(tone.edge, OpColors.ink, 0.35))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seat meter: one small square per place. Filled = taken.

class SeatMeter extends StatelessWidget {
  const SeatMeter({super.key, required this.total, required this.taken, this.box = 12, this.animate = true});

  final int total;
  final int taken;
  final double box;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final full = taken >= total;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var i = 0; i < total; i++)
          // animate: false shows the seats at once (target 0 would leave them faded out).
          if (animate) _seat(i < taken, full).animate().fadeIn(delay: (i * 35).ms, duration: 200.ms) else _seat(i < taken, full),
      ],
    );
  }

  Widget _seat(bool isTaken, bool full) => Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: isTaken ? (full ? OpColors.inkFaint : OpColors.forest) : OpColors.card,
          borderRadius: BorderRadius.circular(box * 0.3),
          border: Border.all(color: isTaken ? Colors.transparent : OpColors.fern, width: 1.3),
        ),
      );
}

// ---------------------------------------------------------------------------
// Skeleton blocks shown while things load. They breathe softly instead of shimmering.

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 8});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: OpColors.paperDeep, borderRadius: BorderRadius.circular(radius)),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 1, end: 0.45, duration: 700.ms, curve: Curves.easeInOut);
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) => OpLoadingPanel(height: 120.0 + rows * 30);

  // The old grey placeholder rows, kept for reference.
  // ignore: unused_element
  Widget _rows() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(OpSpace.gutter),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OpColors.card,
          borderRadius: OpRadius.cardAll,
          boxShadow: OpShadow.card,
        ),
        child: const Row(
          children: [
            SkeletonBox(height: 56, width: 56, radius: 14),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 18, width: 170),
                  SizedBox(height: 10),
                  SkeletonBox(height: 13, width: 120),
                  SizedBox(height: 8),
                  SkeletonBox(height: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page scaffold for inner screens: back arrow, title, content, and a fixed bottom action area.

class OpPage extends StatelessWidget {
  const OpPage({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.actions,
    this.background = OpColors.paper,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? bottom;
  final List<Widget>? actions;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        toolbarHeight: subtitle == null ? 60 : 68,
        // Next to the back arrow, or at the page margin when there is none.
        titleSpacing: (ModalRoute.of(context)?.canPop ?? false) ? 4 : OpSpace.gutter,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: OpText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: OpText.small.copyWith(fontSize: 13)),
          ],
        ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottom == null ? null : BottomBar(child: bottom!),
    );
  }
}

/// The fixed area at the bottom of a screen that holds its main button.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.sheetTop,
        boxShadow: OpShadow.bar,
      ),
      padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 14, OpSpace.gutter, 12),
      child: SafeArea(top: false, child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Small layout pieces.

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(0, 10, 0, 14)});

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: OpColors.fern, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(text.tr.toUpperCase(), style: OpText.label.copyWith(color: OpColors.ink, letterSpacing: 1.3, fontSize: 12.5))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A card: white on the paper background, rounded, with a soft shadow.
class OpCard extends StatelessWidget {
  const OpCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.borderColor, this.raised = false});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// The one main card on a screen: a heavier bottom edge, like a card resting on paper.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final edge = borderColor ?? OpColors.lineSoft;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? OpColors.card,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: edge, width: borderColor == null ? 1 : 1.4),
        boxShadow: raised ? OpShadow.raised : OpShadow.card,
      ),
      child: child,
    );
    return onTap == null ? box : TapScale(onTap: onTap, scale: 0.985, child: box);
  }
}

/// Help or rule box with a coloured left edge.
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.child, this.tone = Tone.info, this.icon});

  final Widget child;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: tone.wash,
        borderRadius: OpRadius.controlAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: OpColors.card.withValues(alpha: 0.85), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: tone.edge),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: icon != null ? 5 : 0),
              child: DefaultTextStyle(style: OpText.body.copyWith(fontSize: 15), child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square initials tile, standing in for a doctor or hospital photo.
class InitialsTile extends StatelessWidget {
  const InitialsTile({super.key, required this.text, this.size = 56, this.color = OpColors.mint, this.icon});

  final String text;
  final double size;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: icon != null
          ? Icon(icon, color: OpColors.forest, size: size * 0.45)
          : Text(text, style: OpText.heading.copyWith(fontSize: size * 0.36, color: OpColors.forest)),
    );
  }
}

/// A rounded, selectable chip.
class OpChip extends StatelessWidget {
  const OpChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: OpMotion.quick,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? OpColors.forest : OpColors.card,
          borderRadius: OpRadius.chipAll,
          border: Border.all(color: selected ? OpColors.forest : OpColors.lineSoft, width: 1.2),
          boxShadow: selected ? OpShadow.button : OpShadow.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: selected ? OpColors.paper : OpColors.fern),
              const SizedBox(width: 6),
            ],
            Text(label, style: OpText.smallStrong.copyWith(color: selected ? OpColors.paper : OpColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Big segmented switch ("Type of doctor | Health problem | Hospital").
class OpSegments extends StatelessWidget {
  const OpSegments({super.key, required this.labels, required this.index, required this.onChanged, this.icons});

  final List<String> labels;
  final List<IconData>? icons;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: OpColors.paperDeep,
        borderRadius: OpRadius.cardAll,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: TapScale(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: OpMotion.quick,
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: i == index ? OpColors.card : Colors.transparent,
                    borderRadius: OpRadius.controlAll,
                    boxShadow: i == index ? OpShadow.card : null,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null)
                        Icon(icons![i], size: 20, color: i == index ? OpColors.forest : OpColors.inkSoft),
                      Text(labels[i],
                          textAlign: TextAlign.center,
                          style: OpText.smallStrong.copyWith(
                              fontSize: 13, color: i == index ? OpColors.forest : OpColors.inkSoft)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Step 2 of 5" with five bars.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step, required this.total, required this.title});

  final int step;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('STEP {0} OF {1}'.trf([step, total]), style: OpText.label.copyWith(color: OpColors.fern)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: OpText.smallStrong, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= total; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: OpMotion.page,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? OpColors.fern : OpColors.paperDeep,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < total) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action, this.onAction, this.emoji});

  final IconData icon;

  /// A friendly picture (e.g. '🗓️') shown large instead of the icon, floating gently.
  final String? emoji;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Container(
              width: 116,
              height: 116,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: OpColors.mint, shape: BoxShape.circle, boxShadow: OpShadow.card),
              child: Text(emoji!, style: const TextStyle(fontSize: 54, height: 1)),
            )
                .animate(onPlay: (c) => OpMotion.reduced ? null : c.repeat(reverse: true))
                .moveY(begin: 0, end: -8, duration: 1600.ms, curve: Curves.easeInOut)
          else
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: OpColors.mint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: OpColors.fern),
            ),
          const SizedBox(height: 20),
          Text(title.tr, style: OpText.heading, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(text.tr, style: OpText.small.copyWith(fontSize: 15), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 20),
            OpButton(label: action!.tr, onPressed: onAction, expand: false, height: 50),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

/// A plain settings/menu row: icon, title, optional detail, arrow.
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.icon, required this.title, this.detail, this.onTap, this.color, this.trailing});

  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (color ?? OpColors.fern) == OpColors.alarm ? OpColors.alarmWash : OpColors.mint.withValues(alpha: 0.7),
                  borderRadius: OpRadius.smallAll,
                ),
                child: Icon(icon, color: color ?? OpColors.fern, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: OpText.bodyStrong.copyWith(color: color ?? OpColors.ink)),
                    if (detail != null) Text(detail!, style: OpText.small.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: OpColors.inkFaint) : const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group of [MenuRow]s in one card with hairlines between them.
class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: OpColors.card,
        borderRadius: OpRadius.cardAll,
        border: Border.all(color: OpColors.lineSoft),
        boxShadow: OpShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(indent: 66, endIndent: 14, color: OpColors.lineSoft),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label on the left, value on the right. Used in summaries and receipts.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.mono = false, this.strong = false});

  final String label;
  final String value;
  final bool mono;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label.tr, style: OpText.small.copyWith(fontSize: 15))),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value.tr,
              textAlign: TextAlign.right,
              style: mono
                  ? OpText.monoBody.copyWith(fontWeight: strong ? FontWeight.w600 : FontWeight.w500)
                  : (strong ? OpText.bodyStrong : OpText.body.copyWith(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stepper with big − and + buttons (no typing).
class NumberStepper extends StatelessWidget {
  const NumberStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 99, this.step = 1, this.unit});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int next, bool enabled) => TapScale(
          debounce: false,
          onTap: enabled ? () => onChanged(next) : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? OpColors.mint : OpColors.paperDeep,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: enabled ? OpColors.forest : OpColors.inkFaint),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove, value - step, value - step >= min),
        SizedBox(
          width: 64,
          child: Column(
            children: [
              Text('$value', style: OpText.monoBig, textAlign: TextAlign.center),
              if (unit != null) Text(unit!, style: OpText.small.copyWith(fontSize: 11)),
            ],
          ),
        ),
        btn(Icons.add, value + step, value + step <= max),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback helpers.

void showToast(BuildContext context, String message, {IconData icon = Icons.check_circle_outline}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(milliseconds: 2400),
    content: Row(
      children: [
        Icon(icon, color: OpColors.leaf, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message.tr)),
      ],
    ),
  ));
}

/// Errors (no internet, server problems, refused actions): a red note, so they never look like success.
void showError(BuildContext context, String message, {IconData icon = Icons.error_outline}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    backgroundColor: OpColors.alarm,
    duration: const Duration(milliseconds: 3600),
    content: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message.tr, style: const TextStyle(color: Colors.white))),
      ],
    ),
  ));
}

/// A simple "Are you sure?" sheet. Returns true when the main button is pressed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String text,
  required String yes,
  String no = 'No, go back',
  bool danger = false,
  IconData? icon,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: danger ? OpColors.alarmWash : OpColors.mint, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: danger ? OpColors.alarm : OpColors.fern),
              ),
              const SizedBox(height: 14),
            ],
            Text(title, style: OpText.title),
            const SizedBox(height: 8),
            Text(text, style: OpText.body.copyWith(color: OpColors.inkSoft)),
            const SizedBox(height: 24),
            OpButton(
              label: yes,
              kind: danger ? OpButtonKind.danger : OpButtonKind.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            OpButton.secondary(label: no, onPressed: () => Navigator.pop(context, false)),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Staggered entrance for list items: slide up and fade, 40ms apart.
extension StaggerIn on Widget {
  Widget staggerIn(int index, {bool enabled = true}) {
    if (!enabled || OpMotion.reduced) return this;
    return animate()
        .fadeIn(delay: (40 * index.clamp(0, 12)).ms, duration: 280.ms)
        .slideY(begin: 0.08, end: 0, delay: (40 * index.clamp(0, 12)).ms, duration: 280.ms, curve: OpMotion.curve);
  }
}
