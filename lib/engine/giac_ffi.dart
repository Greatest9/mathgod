// lib/engine/giac_ffi.dart
//
// Dart FFI bridge to the native Giac CAS library (libgiac.so on Android,
// GiacFramework.framework on iOS).
//
// This file is the ONLY place in the Dart codebase that touches dart:ffi
// directly.  Everything above this layer is pure Dart.
//
// Usage:
//   final result = GiacFFI.instance.solve('diff(sin(x^2),x)');
//   // → '2*x*cos(x^2)'   (exact, symbolic, offline)

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ─── C function signatures ────────────────────────────────────────────────────

/// char* solve_math(const char* input)
typedef _SolveMathC = Pointer<Utf8> Function(Pointer<Utf8> input);
typedef _SolveMathDart = Pointer<Utf8> Function(Pointer<Utf8> input);

/// void giac_free(char* ptr)
/// Must be called after every solve_math call to release the C-side buffer.
typedef _GiacFreeC = Void Function(Pointer<Utf8> ptr);
typedef _GiacFreeDart = void Function(Pointer<Utf8> ptr);

/// int giac_init()
/// Returns 0 on success, non-zero on failure.
typedef _GiacInitC = Int32 Function();
typedef _GiacInitDart = int Function();

// ─── Library loader ───────────────────────────────────────────────────────────

DynamicLibrary _openGiac() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libgiac.so');
  }
  if (Platform.isIOS) {
    // On iOS the framework is statically linked into the runner binary.
    return DynamicLibrary.process();
  }
  throw UnsupportedError(
    'GiacFFI: unsupported platform ${Platform.operatingSystem}',
  );
}

// ─── Singleton wrapper ────────────────────────────────────────────────────────

class GiacFFI {
  GiacFFI._() {
    _lib = _openGiac();

    _init = _lib.lookupFunction<_GiacInitC, _GiacInitDart>('giac_init');

    _solveMath = _lib.lookupFunction<_SolveMathC, _SolveMathDart>('solve_math');

    _giacFree = _lib.lookupFunction<_GiacFreeC, _GiacFreeDart>('giac_free');

    final code = _init();
    if (code != 0) {
      throw StateError('GiacFFI: giac_init() returned error code $code');
    }
  }

  static final GiacFFI instance = GiacFFI._();

  late final DynamicLibrary _lib;
  late final _GiacInitDart _init;
  late final _SolveMathDart _solveMath;
  late final _GiacFreeDart _giacFree;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Evaluate [input] using the Giac CAS and return the result as a String.
  ///
  /// [input] is a Giac expression string, e.g.:
  ///   'diff(sin(x^2), x)'         → '2*x*cos(x^2)'
  ///   'int(1/(1+x^2), x)'         → 'atan(x)'
  ///   'factor(x^3 - 6*x^2 + 11*x - 6)' → '(x-1)*(x-2)*(x-3)'
  ///   'latex(diff(sin(x),x))'     → '\\cos\\left(x\\right)'
  ///
  /// Returns an error string prefixed with 'Error:' on failure — never throws.
  String solve(String input) {
    if (input.trim().isEmpty) return '';

    final inputPtr = input.toNativeUtf8();
    Pointer<Utf8>? resultPtr;

    try {
      resultPtr = _solveMath(inputPtr);
      if (resultPtr == nullptr) return 'Error: null result from giac';
      final result = resultPtr.toDartString();
      return result;
    } catch (e) {
      return 'Error: $e';
    } finally {
      malloc.free(inputPtr);
      if (resultPtr != null && resultPtr != nullptr) {
        _giacFree(resultPtr);
      }
    }
  }

  /// Convenience: evaluate and return LaTeX-formatted result.
  /// Wraps the expression in Giac's latex() command automatically.
  String solveToLatex(String input) {
    if (input.trim().isEmpty) return '';
    return solve('latex($input)');
  }

  /// Check whether the native library loaded correctly.
  bool get isAvailable {
    try {
      // A trivial smoke-test: 1+1 should return "2"
      final r = solve('1+1');
      return r.trim() == '2';
    } catch (_) {
      return false;
    }
  }
}
