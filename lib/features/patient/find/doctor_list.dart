import '../../../l10n/lang.dart';
import '../../../data/remote.dart';
import '../../../data/config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../mock/data.dart';
import '../../../mock/format.dart';
import '../../../mock/models.dart';
import '../../../theme/text.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/bits.dart';
import '../../../widgets/doctor_card.dart';

/// A list of doctors, opened by type (?type=), health problem (?problem=&who=) or hospital (?hospital=).
class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key, required this.query});

  final Map<String, String> query;

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

enum _Filter { today, tomorrow, near, lowFee }

class _DoctorListScreenState extends State<DoctorListScreen> {
  bool _waiting = true;

  /// The short first pause, or (live build) the doctors still coming from the server.
  bool get _loading => _waiting || (AppConfig.isApi && !Remote.instance.loaded);
  final _filters = <_Filter>{};
  String? _language;
  String? _typeOnly;

  @override
  void initState() {
    super.initState();
    Future.delayed(OpMotion.fakeShort, () {
      if (mounted) setState(() => _waiting = false);
    });
    Remote.instance.addListener(_remoteChanged);
    Remote.instance.ensureLoaded();
  }

  void _remoteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Remote.instance.removeListener(_remoteChanged);
    super.dispose();
  }

  HealthProblem? get _problem => widget.query['problem'] == null ? null : MockData.findProblem(widget.query['problem']!);
  bool get _child => widget.query['who'] == 'child';

  List<String> get _types {
    final p = _problem;
    if (p != null) return _child ? p.childTypes : p.adultTypes;
    if (widget.query['type'] != null) return [widget.query['type']!];
    return MockData.types.map((t) => t.id).toList();
  }

  String get _title {
    if (_problem != null) return 'Doctors for ${_problem!.name.toLowerCase()}';
    if (widget.query['type'] != null) return MockData.findType(widget.query['type']!)?.simple ?? 'Doctors';
    if (widget.query['hospital'] != null) return MockData.findHospital(widget.query['hospital']!)?.name ?? 'Doctors';
    return 'Doctors';
  }

  List<Doctor> _doctors() {
    final hid = widget.query['hospital'];
    var list = MockData.doctors.where((d) {
      if (hid != null && !d.hospitalIds.contains(hid)) return false;
      final types = _typeOnly != null ? [_typeOnly!] : _types;
      if (!types.contains(d.typeId)) return false;
      if (_language != null && !d.languages.contains(_language)) return false;
      final next = MockData.nextFree(d);
      if (_filters.contains(_Filter.today) && (next == null || !sameDay(next.$1, DateTime.now()))) return false;
      if (_filters.contains(_Filter.tomorrow)) {
        final t = today().add(const Duration(days: 1));
        if (MockData.windows(d, t).where((w) => w.open).isEmpty) return false;
      }
      return true;
    }).toList();
    if (_filters.contains(_Filter.lowFee)) {
      list.sort((a, b) => a.fee.compareTo(b.fee));
    } else if (_filters.contains(_Filter.near)) {
      list.sort((a, b) => MockData.hospital(a.hospitalIds.first).distanceKm.compareTo(MockData.hospital(b.hospitalIds.first).distanceKm));
    }
    return list;
  }

  void _toggle(_Filter f) {
    setState(() {
      if (!_filters.remove(f)) {
        _filters.add(f);
        if (f == _Filter.today) _filters.remove(_Filter.tomorrow);
        if (f == _Filter.tomorrow) _filters.remove(_Filter.today);
        if (f == _Filter.lowFee) _filters.remove(_Filter.near);
        if (f == _Filter.near) _filters.remove(_Filter.lowFee);
      }
    });
  }

  Future<void> _pickLanguage() async {
    const langs = ['Telugu', 'English', 'Hindi', 'Urdu', 'Tamil'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doctor speaks'.tr, style: OpText.title),
              const SizedBox(height: 12),
              MenuGroup(children: [
                MenuRow(icon: Icons.translate, title: 'Any language'.tr, onTap: () => Navigator.pop(context, '')),
                for (final l in langs)
                  MenuRow(
                    icon: _language == l ? Icons.check_circle : Icons.circle_outlined,
                    title: l,
                    onTap: () => Navigator.pop(context, l),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _language = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final list = _loading ? const <Doctor>[] : _doctors();
    final problem = _problem;
    return OpPage(
      title: _title,
      subtitle: problem != null ? (_child ? 'For a child' : 'For an adult') : null,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 16, OpSpace.gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('These doctors can help'.tr, style: OpText.title),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OpChip(label: 'All'.tr, selected: _typeOnly == null, onTap: () => setState(() => _typeOnly = null)),
                            for (final t in _types)
                              OpChip(
                                label: MockData.type(t).simple,
                                icon: MockData.type(t).icon,
                                selected: _typeOnly == t,
                                onTap: () => setState(() => _typeOnly = t),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InfoBox(
                          icon: Icons.info_outline,
                          child: Text('OPflow does not tell you the disease. It helps you find the right doctor.'.tr),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 12, OpSpace.gutter, 8),
                    children: [
                      OpChip(label: 'Today'.tr, selected: _filters.contains(_Filter.today), onTap: () => _toggle(_Filter.today)),
                      const SizedBox(width: 8),
                      OpChip(label: 'Tomorrow'.tr, selected: _filters.contains(_Filter.tomorrow), onTap: () => _toggle(_Filter.tomorrow)),
                      const SizedBox(width: 8),
                      OpChip(label: 'Near me'.tr, icon: Icons.near_me_outlined, selected: _filters.contains(_Filter.near), onTap: () => _toggle(_Filter.near)),
                      const SizedBox(width: 8),
                      OpChip(label: 'Low fee first'.tr, selected: _filters.contains(_Filter.lowFee), onTap: () => _toggle(_Filter.lowFee)),
                      const SizedBox(width: 8),
                      OpChip(label: _language ?? 'Language', icon: Icons.translate, selected: _language != null, onTap: _pickLanguage),
                    ],
                  ),
                ),
                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 4, OpSpace.gutter, 8),
                    child: Text(list.length == 1 ? '1 doctor found'.tr : '{0} doctors found'.trf([list.length]), style: OpText.small),
                  ),
              ],
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(child: SkeletonList(rows: 3))
          else if (list.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                emoji: '🩺',
                icon: Icons.person_search_outlined,
                title: 'No doctors found'.tr,
                text: 'Try removing a filter.'.tr,
                action: 'Remove filters'.tr,
                onAction: () => setState(() {
                  _filters.clear();
                  _language = null;
                  _typeOnly = null;
                }),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(OpSpace.gutter, 0, OpSpace.gutter, 28),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => DoctorCard(
                  doctor: list[i],
                  hospitalId: widget.query['hospital'],
                  onBook: () => context.push('/book/${list[i].id}${widget.query['hospital'] != null ? '?hospital=${widget.query['hospital']}' : ''}'),
                  onTap: () => context.push(
                      '/doctor/${list[i].id}${widget.query['hospital'] != null ? '?hospital=${widget.query['hospital']}' : ''}'),
                ).staggerIn(i),
              ),
            ),
        ],
      ),
    );
  }
}
