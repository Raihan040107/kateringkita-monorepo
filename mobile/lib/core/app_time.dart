/// Format waktu untuk tampilan: server mengirim ISO UTC, aplikasi menampilkan WIB.
class AppTime {
  AppTime._();

  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static DateTime toWib(DateTime t) => t.toUtc().add(const Duration(hours: 7));

  static String _dd(int n) => n.toString().padLeft(2, '0');

  /// `14.05 WIB`
  static String wib(DateTime t) {
    final w = toWib(t);
    return '${_dd(w.hour)}.${_dd(w.minute)} WIB';
  }

  /// `12 Nov 2026`
  static String date(DateTime t) {
    final w = toWib(t);
    return '${w.day} ${_bulan[w.month - 1]} ${w.year}';
  }

  /// `12 Nov 2026, 14.05 WIB`
  static String dateTime(DateTime t) => '${date(t)}, ${wib(t)}';

  /// `2026-11-12T14:05:00+07:00` dari jam dinding WIB yang dipilih pengguna
  /// (tanpa melihat zona waktu perangkat).
  static String isoWib(DateTime wib) =>
      '${wib.year}-${_dd(wib.month)}-${_dd(wib.day)}'
      'T${_dd(wib.hour)}:${_dd(wib.minute)}:00+07:00';

  /// `04:59`
  static String mmss(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    return '${_dd(s ~/ 60)}:${_dd(s % 60)}';
  }
}
