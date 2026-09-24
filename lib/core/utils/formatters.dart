import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  /// Display name for a signed-in account: the Firebase display name if set,
  /// otherwise the part of the email before "@".
  static String accountName(User user) {
    final n = user.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final email = user.email ?? '';
    if (email.isEmpty) return 'User';
    return email.contains('@') ? email.split('@').first : email;
  }

  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _time = DateFormat('hh:mm a');
  static final _letter = RegExp(r'[A-Za-z\)\]]');

  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String time(DateTime d) => _time.format(d);

  static bool isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// "Today", "Yesterday" or the full date.
  static String day(DateTime d) {
    final n = DateTime.now();
    final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(d);
  }

  /// 8.5 -> "8.5", 12 -> "12.0", 0.125 -> "0.125".
  static String qty(double v) {
    final r = (v * 1000).round() / 1000;
    if (r == r.roundToDouble()) return r.toStringAsFixed(1);
    return r.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  static String withUnit(double v, String unit) => '${qty(v)} $unit';

  static String signed(double v, String unit, {required bool negative}) =>
      '${negative ? '-' : '+'}${withUnit(v, unit)}';

  static String initials(String? name) {
    final parts =
        (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static const _sub = <String, String>{
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  };

  /// "H2SO4" -> "H₂SO₄", "Ca(OH)2" -> "Ca(OH)₂". Digits that do not follow an element/bracket
  /// (e.g. the 5 in "CuSO4·5H2O") are left as coefficients.
  static String formula(String raw) {
    final buf = StringBuffer();
    var afterElement = false;
    for (final ch in raw.split('')) {
      if (afterElement && _sub.containsKey(ch)) {
        buf.write(_sub[ch]);
        continue;
      }
      buf.write(ch);
      afterElement = _letter.hasMatch(ch);
    }
    return buf.toString();
  }
}
