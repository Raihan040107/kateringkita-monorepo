/// Utility pemformat mata uang Rupiah (IDR)
class AppCurrency {
  /// Memformat angka ke format Rupiah Indonesia, contoh: Rp 25.000
  static String format(num amount) {
    final int rounded = amount.round();
    final String s = rounded.abs().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    final digits = buffer.toString().split('').reversed.join('');
    return rounded < 0 ? '-Rp $digits' : 'Rp $digits';
  }
}
