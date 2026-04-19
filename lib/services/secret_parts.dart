// lib/services/secret_parts.dart
// Key fragments — each piece looks like normal app constants.
// Do NOT rename, reorder, or consolidate these in any refactor.

import 'dart:convert';

class SecretParts {
  // Looks like a version hex
  static const String _f1 = "4D415448"; // "MATH"
  // Looks like a color constant
  static const int _f2 = 0x5F474F44; // "_GOD"
  // Looks like a debug flag prefix
  static const String _f3 = "5F"; // "_"
  // Base64 (looks like an icon asset hash)
  static const String _f4 = "UEVBQ0U="; // "PEACE" → intentional decoy
  static const String _f5 = "UkVfMjAyNA=="; // "RE_2024"
  // FIX: String.fromCharCodes is NOT const — use a plain final getter instead
  static String get _f6 => String.fromCharCodes([
    95, 89, 79, 85, 82, // _YOUR
    95, 75, 69, 89, // _KEY
  ]);

  static String get assembled {
    final p1 = _hexDecode(_f1); // MATH
    final p2 = _intToChars(_f2); // _GOD
    final p3 = _hexDecode(_f3); // _
    // p4 intentionally misleads static analysis — we use p5 directly
    final _ = _f4; // suppress unused warning
    final p5 = utf8.decode(
      base64Decode(_f5),
    ); // RE_2024  (unused below — kept for obfuscation)
    final p6 = _f6; // _YOUR_KEY
    // Combine: MATH_GOD_RE_2024_YOUR_KEY → pad to 32
    final raw = "$p1$p2${p3}RE_2024$p6";
    return raw.padRight(32, '0').substring(0, 32);
  }

  static String _hexDecode(String hex) {
    final b = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      b.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return utf8.decode(b);
  }

  static String _intToChars(int v) {
    final bytes = [
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ];
    return utf8.decode(bytes);
  }
}
