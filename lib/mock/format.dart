
/// Plain-language formatting for times, days and money.
library;

import '../l10n/lang.dart';

const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _longDaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _monthsTe = ['జన', 'ఫిబ్ర', 'మార్చి', 'ఏప్రి', 'మే', 'జూన్', 'జూలై', 'ఆగ', 'సెప్టెం', 'అక్టో', 'నవం', 'డిసెం'];
const _daysTe = ['సోమ', 'మంగళ', 'బుధ', 'గురు', 'శుక్ర', 'శని', 'ఆది'];
const _longDaysTe = ['సోమవారం', 'మంగళవారం', 'బుధవారం', 'గురువారం', 'శుక్రవారం', 'శనివారం', 'ఆదివారం'];

// Day and month names in the app's language.
List<String> get _months => Lang.instance.isTelugu ? _monthsTe : _monthsEn;
List<String> get _days => Lang.instance.isTelugu ? _daysTe : _daysEn;
List<String> get _longDays => Lang.instance.isTelugu ? _longDaysTe : _longDaysEn;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// 9 → "9 AM", 13 → "1 PM", 12 → "12 PM".
String hourLabel(int h) {
  final suffix = h >= 12 && h < 24 ? 'PM' : 'AM';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh $suffix';
}

/// 10 → "10 – 11 AM", 11 → "11 AM – 12 PM".
String windowLabel(int start, [int length = 1]) {
  final end = start + length;
  if ((start < 12) == (end < 12)) {
    final s = start % 12 == 0 ? 12 : start % 12;
    return '$s – ${hourLabel(end)}';
  }
  return '${hourLabel(start)} – ${hourLabel(end)}';
}

/// 9:45 style clock label.
String clockLabel(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// "Today", "Tomorrow", "Yesterday" or "Fri, 26 Sep".
String dayLabel(DateTime d) {
  final diff = dateOnly(d).difference(today()).inDays;
  if (diff == 0) return 'Today'.tr;
  if (diff == 1) return 'Tomorrow'.tr;
  if (diff == -1) return 'Yesterday'.tr;
  return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// "Friday, 26 Sep 2026"
String longDate(DateTime d) => '${_longDays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String shortDay(DateTime d) => _days[d.weekday - 1];
String monthShort(DateTime d) => _months[d.month - 1];
String weekdayName(int weekday) => _longDays[weekday - 1];
String weekdayShort(int weekday) => _days[weekday - 1];

/// "10 min ago", "2 hours ago", "Yesterday"
String agoLabel(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Just now'.tr;
  if (diff.inMinutes < 60) return '{0} min ago'.trf([diff.inMinutes]);
  if (diff.inHours < 24) return (diff.inHours == 1 ? '{0} hour ago' : '{0} hours ago').trf([diff.inHours]);
  if (diff.inDays == 1) return 'Yesterday'.tr;
  return '{0} days ago'.trf([diff.inDays]);
}

/// Indian grouping: 5400 → "₹5,400", 125000 → "₹1,25,000".
String rupees(num amount) {
  final whole = amount.round();
  final s = whole.abs().toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '${whole < 0 ? '−' : ''}₹$grouped';
}

/// "1 person" / "3 people"
String people(int n) => n == 1 ? '1 person'.tr : '{0} people'.trf([n]);

/// 9876543210 → "98xxxxx210"
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return phone;
  final d = digits.substring(digits.length - 10);
  return '${d.substring(0, 2)}xxxxx${d.substring(7)}';
}

/// 9876543210 → "98765 43210"
String prettyPhone(String phone) {
  final d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length != 10) return phone;
  return '${d.substring(0, 5)} ${d.substring(5)}';
}
