const _faDigits = '۰۱۲۳۴۵۶۷۸۹';

/// تبدیل ارقام انگلیسی به فارسی
String fa(dynamic v) {
  final s = (v ?? '').toString();
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = '0123456789'.indexOf(c);
    b.write(i >= 0 ? _faDigits[i] : c);
  }
  return b.toString();
}

List<int> _toJalali(int gy, int gm, int gd) {
  const g = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 +
      365 * gy +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      g[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  late int jm, jd;
  if (days < 186) {
    jm = 1 + days ~/ 31;
    jd = 1 + days % 31;
  } else {
    jm = 7 + (days - 186) ~/ 30;
    jd = 1 + (days - 186) % 30;
  }
  return [jy, jm, jd];
}

/// تاریخ سرور (UTC به صورت "YYYY-MM-DD HH:MM:SS") را به شمسی و ساعت محلی تبدیل می‌کند
String faDate(dynamic raw, {bool time = true}) {
  final s = (raw ?? '').toString();
  if (s.isEmpty) return '—';
  try {
    final d = DateTime.parse('${s.replaceFirst(' ', 'T')}Z').toLocal();
    final j = _toJalali(d.year, d.month, d.day);
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${j[0]}/${two(j[1])}/${two(j[2])}';
    return fa(time ? '$date  ${two(d.hour)}:${two(d.minute)}' : date);
  } catch (_) {
    return s;
  }
}

/// 09121234567 از +989121234567
String localPhone(dynamic p) {
  final s = (p ?? '').toString();
  if (s.startsWith('+98')) return '0${s.substring(3)}';
  return s;
}
