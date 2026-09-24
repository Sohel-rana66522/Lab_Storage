/// Unit handling. A chemical is tracked in ONE unit; entries in a compatible
/// unit (same dimension) are converted before the stock maths runs.
class Units {
  Units._();

  static const all = <String>['L', 'mL', 'kg', 'g', 'mg'];

  static const _factor = <String, double>{
    'L': 1,
    'mL': 0.001,
    'kg': 1,
    'g': 0.001,
    'mg': 0.000001,
  };

  static const _dimension = <String, String>{
    'L': 'volume',
    'mL': 'volume',
    'kg': 'mass',
    'g': 'mass',
    'mg': 'mass',
  };

  static const _labels = <String, String>{
    'L': 'Liter (L)',
    'mL': 'Milliliter (mL)',
    'kg': 'Kilogram (kg)',
    'g': 'Gram (g)',
    'mg': 'Milligram (mg)',
  };

  static String label(String u) => _labels[u] ?? u;

  static bool isCompatible(String a, String b) =>
      _dimension[a] != null && _dimension[a] == _dimension[b];

  static List<String> compatible(String unit) =>
      all.where((u) => isCompatible(u, unit)).toList();

  static double convert(double value, String from, String to) {
    if (from == to) return round(value);
    final f = _factor[from], t = _factor[to];
    if (f == null || t == null || !isCompatible(from, to)) {
      throw ArgumentError('Cannot convert $from to $to');
    }
    return round(value * f / t);
  }

  /// Keeps floating point noise out of stored balances (6 decimal places).
  static double round(double v) => (v * 1e6).round() / 1e6;
}
