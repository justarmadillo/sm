/// JavaScript numeric and string semantics that the FSRS reference
/// implementation (ts-fsrs) depends on, reproduced exactly in Dart.
///
/// This file exists because "identical port" means bit-identical results, and
/// Dart and JavaScript disagree in three places that FSRS actually touches:
/// rounding of halves, `ToUint32`/`ToInt32` coercion inside the Alea PRNG, and
/// `Number.prototype.toString()` — which feeds the PRNG seed string.
library;

/// `Math.round` — rounds halves toward `+Infinity`.
///
/// Dart's [num.round] rounds halves *away from zero*, so `-0.5` differs
/// (`0` in JS, `-1` in Dart). FSRS rounds intermediate values that can be
/// negative (difficulty deltas, damped stability), so the difference is real.
double jsRoundDouble(double x) {
  if (x.isNaN || x.isInfinite) return x;
  final floor = x.floorToDouble();
  return (x - floor >= 0.5) ? floor + 1.0 : floor;
}

/// [jsRoundDouble] returning an `int`, mirroring how ts-fsrs consumes it.
int jsRound(double x) => jsRoundDouble(x).toInt();

/// ECMAScript `ToUint32`.
int toUint32(double x) {
  if (x.isNaN || x.isInfinite || x == 0) return 0;
  final truncated = x.truncateToDouble();
  var m = truncated % 4294967296.0;
  if (m < 0) m += 4294967296.0;
  return m.toInt();
}

/// ECMAScript `ToInt32` (`x | 0`).
int toInt32(double x) {
  final u = toUint32(x);
  return u >= 2147483648 ? u - 4294967296 : u;
}

/// ECMAScript `parseInt(s, 10)`; returns `null` for JS `NaN`.
///
/// Unlike [int.parse] this accepts leading whitespace, an optional sign, and a
/// trailing garbage suffix (`'10m'` -> `10`), which is how ts-fsrs parses
/// learning steps.
int? jsParseInt(String s) {
  var i = 0;
  while (i < s.length && _isJsWhitespace(s.codeUnitAt(i))) {
    i++;
  }
  var sign = 1;
  if (i < s.length && (s[i] == '+' || s[i] == '-')) {
    if (s[i] == '-') sign = -1;
    i++;
  }
  final start = i;
  while (i < s.length) {
    final c = s.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) break;
    i++;
  }
  if (i == start) return null;
  return sign * int.parse(s.substring(start, i));
}

bool _isJsWhitespace(int c) =>
    c == 0x20 ||
    c == 0x09 ||
    c == 0x0A ||
    c == 0x0B ||
    c == 0x0C ||
    c == 0x0D ||
    c == 0xA0 ||
    c == 0xFEFF;

/// JS truthiness for a number: `value || 0`.
///
/// `NaN`, `0` and `-0` are falsy, so all three collapse to `0`. ts-fsrs relies
/// on this when clipping a parameter vector that is shorter than the clamp
/// table.
double jsNumOrZero(double? value) {
  if (value == null || value.isNaN || value == 0) return 0.0;
  return value;
}

/// `Number.prototype.toFixed(digits)`.
///
/// Dart's [num.toStringAsFixed] follows the same specification, so this is a
/// thin alias kept for traceability against the reference source.
String jsToFixed(double value, int digits) => value.toStringAsFixed(digits);

/// `+value.toFixed(digits)` — the round-trip ts-fsrs uses to snap parameters.
double jsToFixedNumber(double value, int digits) =>
    double.parse(jsToFixed(value, digits));

/// `String(value)` for a JS number (ECMA-262 `Number::toString`).
///
/// Dart's [double.toString] agrees on the significant digits but not on the
/// presentation: it prints `5.0` where JS prints `5`, and it switches to
/// exponential notation far earlier than JS does (JS only for decimal exponent
/// `>= 21` or `<= -7`). The default seed strategy interpolates
/// `difficulty * stability` into a string, so the presentation decides the
/// fuzzed interval.
String jsNumberToString(num value) {
  if (value is int) return value.toString();
  final d = value.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == 0) return '0';

  final negative = d < 0;
  final abs = negative ? -d : d;

  // Dart's shortest round-trip representation gives us the digits `s` and the
  // decimal exponent `n` such that abs == 0.s * 10^n, which is exactly the
  // (s, k, n) triple ECMA-262 defines Number::toString over.
  final repr = abs.toString();
  String digits;
  int n;
  final eIndex = repr.indexOf('e');
  if (eIndex >= 0) {
    final mantissa = repr.substring(0, eIndex);
    final exponent = int.parse(repr.substring(eIndex + 1));
    final dot = mantissa.indexOf('.');
    if (dot >= 0) {
      digits = mantissa.substring(0, dot) + mantissa.substring(dot + 1);
      n = dot + exponent;
    } else {
      digits = mantissa;
      n = mantissa.length + exponent;
    }
  } else {
    final dot = repr.indexOf('.');
    if (dot >= 0) {
      digits = repr.substring(0, dot) + repr.substring(dot + 1);
      n = dot;
    } else {
      digits = repr;
      n = repr.length;
    }
  }

  // Strip leading zeros (they shift the exponent) and trailing zeros (they are
  // not significant digits).
  var lead = 0;
  while (lead < digits.length - 1 && digits[lead] == '0') {
    lead++;
    n--;
  }
  digits = digits.substring(lead);
  var end = digits.length;
  while (end > 1 && digits[end - 1] == '0') {
    end--;
  }
  digits = digits.substring(0, end);
  if (digits == '0') return '0';

  final k = digits.length;
  final String out;
  if (k <= n && n <= 21) {
    out = digits + '0' * (n - k);
  } else if (0 < n && n <= 21) {
    out = '${digits.substring(0, n)}.${digits.substring(n)}';
  } else if (-6 < n && n <= 0) {
    out = '0.${'0' * -n}$digits';
  } else {
    final exponent = n - 1;
    final sign = exponent >= 0 ? '+' : '-';
    final magnitude = exponent.abs();
    out = k == 1
        ? '${digits}e$sign$magnitude'
        : '${digits[0]}.${digits.substring(1)}e$sign$magnitude';
  }
  return negative ? '-$out' : out;
}
