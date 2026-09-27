import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/errors.dart';
import '../data/api.dart';
import '../data/config.dart';
import '../data/push.dart';
import '../mock/models.dart';
import 'session.dart';

/// The doctor's messages: new bookings, a patient who changed the time, an emergency patient coming,
/// "your OPD starts soon", money sent to the bank, and notes from the OPflow team.
///
/// API: the server's /v1/notifications (the same list the phone's pushes come from). Checked when the doctor
/// logs in, the moment a push arrives while the app is open, and once a minute as a safety net.
class DoctorInbox extends ChangeNotifier {
  DoctorInbox() {
    if (!AppConfig.isApi) {
      _seed();
      return;
    }
    _side = SessionStore.instance.side;
    SessionStore.instance.addListener(_sessionChanged);
    if (_side == Side.doctor) unawaited(refresh());
    _pushes = Push.arrived.stream.listen((_) {
      if (SessionStore.instance.side == Side.doctor) unawaited(_loadNew());
    });
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (SessionStore.instance.side == Side.doctor) unawaited(_loadNew());
    });
  }

  final messages = <AppMessage>[];
  bool loading = false;
  String? _cursor;
  bool _loadingMore = false;
  String? _newestAt;
  int? _serverUnread;
  Side _side = Side.none;
  Timer? _poll;
  StreamSubscription<Map<String, dynamic>>? _pushes;

  Api get _api => Api.instance;

  int get unread => _serverUnread ?? messages.where((m) => m.unread).length;
  bool get hasMore => _cursor != null;

  void _sessionChanged() {
    final s = SessionStore.instance.side;
    if (s == _side) return;
    _side = s;
    messages.clear();
    _cursor = null;
    _newestAt = null;
    _serverUnread = null;
    notifyListeners();
    if (s == Side.doctor) unawaited(refresh());
  }

  static AppMessage _from(Map m) => AppMessage(
        id: m['id'] as String,
        kind: messageKindFrom(m['kind'] as String?),
        title: m['title'] as String,
        body: m['body'] as String,
        time: DateTime.parse(m['createdAt'] as String).toLocal(),
        bookingId: m['bookingId'] as String?,
        unread: m['readAt'] == null,
      );

  /// The newest 30 messages.
  Future<void> refresh() async {
    if (!AppConfig.isApi) return;
    loading = true;
    notifyListeners();
    try {
      final r = await _api.get('/v1/notifications', query: {'limit': 30}) as Map;
      final items = (r['items'] as List).cast<Map>();
      messages
        ..clear()
        ..addAll(items.map(_from));
      _cursor = r['nextCursor'] as String?;
      _serverUnread = (r['unread'] as num?)?.toInt();
      if (items.isNotEmpty) _newestAt = items.first['createdAt'] as String;
    } on ApiException {
      // Keep what is shown; the next check retries.
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'doctorInbox.refresh');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Only what is newer than the newest message on the phone (usually nothing).
  Future<void> _loadNew() async {
    final after = _newestAt;
    if (after == null) return refresh();
    try {
      final r = await _api.get('/v1/notifications', query: {'limit': 50, 'after': after}) as Map;
      final items = (r['items'] as List).cast<Map>();
      _serverUnread = (r['unread'] as num?)?.toInt();
      if (items.isNotEmpty) {
        final known = messages.map((m) => m.id).toSet();
        messages.insertAll(0, [for (final m in items) if (!known.contains(m['id'])) _from(m)]);
        _newestAt = items.first['createdAt'] as String;
      }
      notifyListeners();
    } catch (_) {
      // Quiet: the next check retries.
    }
  }

  /// Older messages, as the list is scrolled.
  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final r = await _api.get('/v1/notifications', query: {'limit': 30, 'cursor': cursor}) as Map;
      final known = messages.map((m) => m.id).toSet();
      messages.addAll([for (final m in (r['items'] as List).cast<Map>()) if (!known.contains(m['id'])) _from(m)]);
      _cursor = r['nextCursor'] as String?;
      notifyListeners();
    } catch (_) {
      // Keep what is shown.
    } finally {
      _loadingMore = false;
    }
  }

  void markRead(AppMessage m) {
    if (!m.unread) return;
    m.unread = false;
    if (_serverUnread != null && _serverUnread! > 0) _serverUnread = _serverUnread! - 1;
    notifyListeners();
    if (AppConfig.isApi && !m.id.startsWith('n')) {
      _api.post('/v1/notifications/read', {'ids': [m.id]}).then((_) => null, onError: (_) => null);
    }
  }

  void markAllRead() {
    for (final m in messages) {
      m.unread = false;
    }
    _serverUnread = 0;
    notifyListeners();
    if (AppConfig.isApi) _api.post('/v1/notifications/read', {'all': true}).then((_) => null, onError: (_) => null);
  }

  /// Sample messages for the demo build.
  void _seed() {
    final now = DateTime.now();
    AppMessage m(int i, MessageKind k, String title, String body, Duration ago, {bool unread = false, String? booking}) =>
        AppMessage(id: 'n$i', kind: k, title: title, body: body, time: now.subtract(ago), bookingId: booking, unread: unread);
    messages.addAll([
      m(1, MessageKind.reminder, 'Your OPD starts soon', 'Sri Lakshmi Hospital at 9:00 AM. 24 patients are booked. Press Start OPD when you begin.',
          const Duration(minutes: 12), unread: true),
      m(2, MessageKind.booked, 'New booking', 'Harshini booked Today, 9 – 10 AM at Sri Lakshmi Hospital. Token 01.', const Duration(hours: 2),
          unread: true),
      m(3, MessageKind.changed, 'Patient changed the time', 'Karthik is now on Mon, 28 Sep, 10 – 11 AM. Token 05.', const Duration(hours: 5)),
      m(4, MessageKind.system, 'Money sent to your bank', '₹2,430 is on its way to your bank account. It usually arrives within 1 working day.',
          const Duration(days: 1)),
      m(5, MessageKind.system, 'You are live on OPflow', 'Patients can now find you and book your times.', const Duration(days: 6)),
    ]);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pushes?.cancel();
    if (AppConfig.isApi) SessionStore.instance.removeListener(_sessionChanged);
    super.dispose();
  }
}

final doctorInboxProvider = ChangeNotifierProvider<DoctorInbox>((ref) => DoctorInbox());
