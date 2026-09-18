// lib/engine/graph_evaluator.dart
import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

import 'giac_ffi.dart';

/// Point evaluator shared by the 2D and 3D graphers.
///
/// Native Giac is the primary path (`evalf(subst(...))`); when Giac cannot
/// produce a plain number the evaluation falls back to the pure-Dart
/// math_expressions package with a couple of shorthands normalized first.
/// Returns null for undefined points so callers can leave gaps.
class GraphEvaluator {
  GraphEvaluator._();

  static final GraphEvaluator instance = GraphEvaluator._();

  final Map<String, _Fallback> _fallbacks = {};

  double? eval2D(String expr, double x) => _eval(expr, {'x': x});

  double? eval3D(String expr, double x, double y) =>
      _eval(expr, {'x': x, 'y': y});

  double? _eval(String expr, Map<String, double> vars) {
    if (expr.trim().isEmpty) return null;
    final giac = _tryGiac(expr, vars);
    if (giac != null && giac.isFinite) return giac;
    return _tryFallback(expr, vars);
  }

  double? _tryGiac(String expr, Map<String, double> vars) {
    try {
      final giac = GiacFFI.instance;
      var cmd = expr.replaceAll('π', 'pi');
      for (final entry in vars.entries.toList().reversed) {
        cmd = 'subst($cmd, ${entry.key}, ${entry.value})';
      }
      final raw = giac.solve('evalf($cmd)').trim();
      if (raw.isEmpty || raw.startsWith('Error')) return null;
      final lower = raw.toLowerCase();
      if (lower.contains('inf') ||
          lower.contains('nan') ||
          lower.contains('undef')) {
        return null;
      }
      return double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  double? _tryFallback(String expr, Map<String, double> vars) {
    try {
      final fb = _fallbacks.putIfAbsent(expr, () => _Fallback.read(expr));
      if (fb.expression == null) return null;
      final cm = ContextModel();
      for (final entry in vars.entries) {
        cm.bindVariable(Variable(entry.key), Number(entry.value));
      }
      final v = fb.expression!.evaluate(EvaluationType.REAL, cm);
      if (v is num && v.isFinite) return v.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _Fallback {
  _Fallback(this.expression);

  final Expression? expression;

  static _Fallback read(String expr) {
    try {
      return _Fallback(GrammarParser().parse(_normalize(expr)));
    } catch (_) {
      return _Fallback(null);
    }
  }

  static final RegExp _implicit = RegExp(r'(\d|\))([a-zA-Z(])');
  static final RegExp _standaloneE = RegExp(r'\be\b');
  static final RegExp _piName = RegExp(r'\bpi\b');

  static String _normalize(String expr) {
    var s = expr;
    s = s.replaceAllMapped(_implicit, (m) => '${m[1]}*${m[2]}');
    s = s.replaceAllMapped(_standaloneE, (_) => '${math.e}');
    s = s.replaceAllMapped(_piName, (_) => '${math.pi}');
    s = s.replaceAll('π', '${math.pi}');
    return s;
  }
}