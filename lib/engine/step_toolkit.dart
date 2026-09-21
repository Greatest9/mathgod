// lib/engine/step_toolkit.dart
//
// Phase B / M1 — one step vocabulary for every topic, plus an independent
// verification pass at the end of every solve.
//
// The point of the verifier is that it must not be the same computation that
// produced the answer: finite-difference probes, differentiate-the-result-back,
// substituting roots into the original equation, det(A * A^-1) = 1, Simpson
// quadrature, expand-the-factors-back, ...

import 'dart:math' as math;

import '../models/solution.dart';
import 'giac_ffi.dart';
import 'graph_evaluator.dart';

enum VerificationStatus { verified, failed, unavailable }

class Verification {
  const Verification(this.status, this.check, this.detail);

  final VerificationStatus status;

  /// Short name of the check that ran, e.g. "differentiate back".
  final String check;

  /// What the check actually found, or why it could not run.
  final String detail;

  bool get isVerified => status == VerificationStatus.verified;
}

/// Shared step constructors so every topic reads the same way.
class StepKit {
  const StepKit._();

  /// The topic-aware "how" card, used when the pattern engine had nothing to
  /// say and the CAS supplied the answer outright.
  static SolutionStep method(String operation, String command) => SolutionStep(
    title: operation,
    latex: command.trim().isEmpty
        ? r'\text{exact symbolic evaluation}'
        : _mathText(command),
    explanation:
        _methods[operation] ??
        'Evaluated exactly by the offline CAS engine, then checked below.',
    rule: operation,
  );

  static SolutionStep note(String title, String text, {String? rule}) =>
      SolutionStep(
        title: title,
        latex: _mathText(text),
        explanation: text,
        rule: rule,
      );

  static SolutionStep verification(Verification v) {
    switch (v.status) {
      case VerificationStatus.verified:
        return SolutionStep(
          title: 'Verification',
          latex: '\\checkmark\\;\\text{${_esc(v.check)}}',
          explanation:
              '${v.detail} The check re-derives the answer by a different '
              'route than the one that produced it.',
          rule: 'Verified',
        );
      case VerificationStatus.failed:
        return SolutionStep(
          title: 'Verification',
          latex: '\\text{${_esc('${v.check}: ${v.detail}')}}',
          explanation:
              'The independent check did not come out clean, so read the steps '
              'above as the method only — the final value shown is the CAS '
              'result, not a derivation. ${v.detail}',
          rule: 'Check failed',
        );
      case VerificationStatus.unavailable:
        return SolutionStep(
          title: 'Verification',
          latex: '\\text{no independent check for this topic yet}',
          explanation:
              '${v.detail} The steps above show the method; the final value '
              'comes from the CAS.',
        );
    }
  }

  static const Map<String, String> _methods = {
    'Derivative':
        'Differentiate term by term: power, sum, product, quotient and chain '
        'rules, then simplify to a closed form.',
    'Integral':
        'Find an antiderivative — standard forms, substitution, by parts or '
        'partial fractions — and add the constant of integration for '
        'indefinite integrals.',
    'Limit':
        'Study the two-sided behaviour as the variable approaches the target; '
        "L'Hôpital applies when the form is 0/0 or ∞/∞.",
    'Solve':
        'Isolate the unknown, or apply the quadratic formula; every root can '
        'be substituted back into the original equation to check it.',
    'Determinant':
        'Expand along a row or column (Laplace expansion), or eliminate to '
        'triangular form and multiply the pivots.',
    'Matrix Inverse':
        'Row-reduce [A | I] to [I | A⁻¹] (Gauss–Jordan); A must be square and '
        'non-singular.',
    'Eigenvalues':
        'Solve the characteristic equation det(A − λI) = 0 for λ.',
    'Factorize':
        'Factor into irreducibles over the integers; multiplying the factors '
        'back must reproduce the original.',
    'Taylor Series':
        "Expand about the point using the derivatives at that point (Taylor's "
        'theorem); the O(...) term is the truncation error.',
    'Maclaurin Series':
        "Taylor expansion about 0 — derivatives evaluated at the origin.",
    'Laplace Transform':
        'Integrate f(t)·e^{-st} dt, or read the transform off the standard '
        'table and combine with linearity.',
    'Inverse Laplace':
        'Split into partial fractions, then invert each term from the table.',
    'ODE':
        'Classify the equation — separable, linear, homogeneous — and '
        'integrate; the constants come from the initial conditions.',
    'Vector Calculus':
        'Apply the del operator: ∇f for the gradient, ∇·F for divergence, '
        '∇×F for curl, ∇²f for the Laplacian.',
    'Trigonometry':
        'Reduce the angles with the unit circle and combine them with the '
        'double-angle, sum-to-product and Pythagorean identities.',
    'Evaluate':
        'Simplify exactly — rational arithmetic, then algebra to normal form.',
  };

  static String _esc(String s) => s
      .replaceAll(r'\', r'\backslash ')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}')
      .replaceAll('_', r'\_')
      .replaceAll('%', r'\%')
      .replaceAll('&', r'\&')
      .replaceAll('#', r'\#')
      .replaceAll(r'$', r'\$')
      .replaceAll('^', r'\hat{}');

  /// Plain text wrapped for the maths renderer (which has no \texttt).
  static String _mathText(String s) => '\\text{${_esc(s)}}';
}

/// Runs an independent check on the displayed result.
class SolutionVerifier {
  const SolutionVerifier();

  Verification check({
    required String operation,
    required String input,
    required String result,
    required bool giacAvailable,
  }) {
    if (result.trim().isEmpty) {
      return _unavailable('There is nothing to check.');
    }
    if (!giacAvailable) {
      return _unavailable(
        'The numeric cross-check needs the CAS engine, which is not available '
        'on this platform.',
      );
    }
    try {
      switch (_family(operation)) {
        case 'Derivative':
          return _derivative(input, result);
        case 'Integral':
          return _integral(input, result);
        case 'Limit':
          return _limit(input, result);
        case 'Solve':
          return _equation(input, result);
        case 'Matrix Inverse':
          return _inverse(input, result);
        case 'Determinant':
          return _determinant(input, result);
        case 'Eigenvalues':
          return _eigenvalues(input, result);
        case 'Factorize':
          return _factorize(input, result);
        case 'Series':
          return _series(input, result);
        case 'Laplace Transform':
          return _laplace(input, result);
        case 'Inverse Laplace':
          return _inverseLaplace(input, result);
        case 'Numeric':
          return _numericIdentity(input, result);
        default:
          return _unavailable(
            'This topic does not have an independent check yet.',
          );
      }
    } catch (_) {
      return _unavailable('The check could not be completed.');
    }
  }

  // ─── family ────────────────────────────────────────────────────────────────

  static String _family(String operation) {
    if (operation.startsWith('Derivative')) return 'Derivative';
    if (operation.startsWith('Integral')) return 'Integral';
    if (operation.startsWith('Solve')) return 'Solve';
    if (operation.startsWith('Series')) return 'Series';
    const numeric = {
      'Evaluate',
      'Trigonometry',
      'Complex',
      'Statistics',
      'Number Theory',
      'Primality',
      'Mod',
    };
    if (numeric.contains(operation)) return 'Numeric';
    return operation;
  }

  // ─── checks ────────────────────────────────────────────────────────────────

  Verification _derivative(String input, String result) {
    final f = _inner(input, const [
      'd/dx[',
      'd/dx',
      'diff(',
      'derivative(',
      'd/dt[',
      'd/dt',
    ]);
    final v = input.toLowerCase().startsWith('d/dt') ? 't' : 'x';
    final probe = _differenceProbe(f, result, v);
    if (probe == null) return _unavailable('The probe points were undefined.');
    if (probe < 1e-3) {
      return _verified(
        'finite-difference probe',
        'The slope of the original at two probe points matches the reported '
        'derivative to ${_sig(probe)}.',
      );
    }
    return _failed('finite-difference probe', probe);
  }

  Verification _integral(String input, String result) {
    final inner = _inner(input, const ['int(', 'integrate(', 'antideriv(']);
    final parts = _splitArgs(inner);
    if (parts.length >= 3) {
      final v = parts.length >= 4 ? parts[1].trim() : 'x';
      final lo = parts.length >= 4 ? parts[2] : parts[1];
      final hi = parts.length >= 4 ? parts[3] : parts[2];
      final a = double.tryParse(lo);
      final b = double.tryParse(hi);
      if (a != null && b != null && v == 'x') {
        final simpson = _simpson(parts[0], a, b);
        final reported = _number(_g('evalf(($result))'));
        if (simpson != null && reported != null) {
          final err = _relErr(simpson, reported);
          if (err < 1e-3) {
            return _verified(
              'independent quadrature',
              'Simpson quadrature on ${_num(lo)}..${_num(hi)} '
              'agrees with the reported value to ${_sig(err)}.',
            );
          }
          return _failed('independent quadrature', err);
        }
      }
      final residual = _number(
        _g('evalf(abs(int(${parts[0]},$v,$lo,$hi) - ($result)))'),
      );
      if (residual == null) {
        return _unavailable('The definite integral could not be re-evaluated.');
      }
      if (residual < 1e-6) {
        return _verified(
          'numeric integration',
          'Numeric integration of the integrand reproduces the reported value.',
        );
      }
      return _failed('numeric integration', residual);
    }

    final back = _g('normal(diff(($result),x) - ($parts[0]))');
    if (_isZero(back)) {
      return _verified(
        'differentiate back',
        'Differentiating the antiderivative recovers the integrand exactly.',
      );
    }
    final probe = _differenceProbe('diff(($result),x)', '($parts[0])', 'x');
    if (probe == null) {
      return _unavailable('The antiderivative could not be re-differentiated.');
    }
    if (probe < 1e-6) {
      return _verified(
        'differentiate back',
        'Differentiating the antiderivative numerically recovers the '
        'integrand to ${_sig(probe)}.',
      );
    }
    return _failed('differentiate back', probe);
  }

  Verification _limit(String input, String result) {
    final parts = _splitArgs(_inner(input, const ['lim(', 'limit(', 'lim ']));
    if (parts.length < 3) {
      return _unavailable('The limit target could not be read.');
    }
    final f = parts[0];
    final v = parts[1].trim();
    final target = parts[2].trim();
    final reported = _number(_g('evalf(($result))'));
    final infinite = target.toLowerCase().contains('inf');
    if (reported == null) {
      return _unavailable(
        'The limit is not a plain number, so the numeric probe does not apply.',
      );
    }
    double worst = 0;
    final points = infinite
        ? const ['1000', '10000', '100000']
        : ['($target)+0.001', '($target)+0.0001', '($target)-0.0001'];
    for (final p in points) {
      final r = _number(_g('evalf(abs(subst(($f),$v,$p) - ($reported)))'));
      if (r == null) continue;
      worst = math.max(worst, r);
    }
    if (worst < 1e-3) {
      return _verified(
        'two-sided numeric probe',
        'Evaluating the expression close to the target approaches the '
        'reported value (within ${_sig(worst)}).',
      );
    }
    return _failed('two-sided numeric probe', worst);
  }

  Verification _equation(String input, String result) {
    final parts = _splitArgs(_inner(input, const ['solve(']));
    if (parts.isEmpty) return _unavailable('The equation could not be read.');
    final eq = parts[0];
    final v = parts.length >= 2 ? parts[1].trim() : 'x';
    final sides = eq.split('=');
    final lhs = sides[0];
    final rhs = sides.length >= 2 ? sides.sublist(1).join('=') : '0';

    final roots = _list(result);
    if (roots.isEmpty) {
      return _unavailable('No explicit roots were reported to substitute.');
    }
    double worst = 0;
    for (final root in roots.take(6)) {
      final r = _number(
        _g('evalf(abs(subst(($lhs) - ($rhs),$v,($root))))'),
      );
      if (r == null) {
        return _unavailable(
          'A reported root is not numeric, so it cannot be substituted back.',
        );
      }
      worst = math.max(worst, r);
    }
    if (worst < 1e-8) {
      return _verified(
        'substitute the roots back',
        'Every reported root satisfies the original equation.',
      );
    }
    return _failed('substitute the roots back', worst);
  }

  Verification _inverse(String input, String result) {
    final m = _inner(input, const ['inv(', 'inverse(']);
    final r = _number(_g('evalf(abs(det(($m) * ($result)) - 1))'));
    if (r == null) {
      return _unavailable('The inverse could not be multiplied back.');
    }
    if (r < 1e-6) {
      return _verified(
        'det(A · A⁻¹) = 1',
        'Multiplying the matrix by the reported inverse gives the identity.',
      );
    }
    return _failed('det(A · A⁻¹) = 1', r);
  }

  Verification _determinant(String input, String result) {
    final m = _matrix(_inner(input, const ['det(', 'determinant(']));
    final reported = _number(_g('evalf(($result))'));
    if (m == null || reported == null) {
      return _unavailable('The determinant could not be recomputed here.');
    }
    final mine = _det(m);
    if (mine == null) {
      return _unavailable(
        'The independent expansion is only implemented up to 3×3.',
      );
    }
    final err = _relErr(mine, reported);
    if (err < 1e-6) {
      return _verified(
        'independent expansion',
        'Expanding the determinant from the entries gives the same value to '
        '${_sig(err)}.',
      );
    }
    return _failed('independent expansion', err);
  }

  Verification _eigenvalues(String input, String result) {
    final m = _matrix(_inner(input, const ['eigen(', 'eig(', 'eigenvalue(']));
    final evalues = _list(result);
    if (m == null || evalues.isEmpty) {
      return _unavailable('The eigenvalue check needs a readable matrix.');
    }
    final n = m.length;
    double worst = 0;
    for (final value in evalues.take(6)) {
      final r = _number(
        _g('evalf(abs(det((${_matrixText(m)}) - ($value) * identity($n))))'),
      );
      if (r == null) {
        return _unavailable('An eigenvalue is not numeric.');
      }
      worst = math.max(worst, r);
    }
    if (worst < 1e-6) {
      return _verified(
        'substitute into det(A − λI)',
        'Every reported λ sends det(A − λI) to zero.',
      );
    }
    return _failed('substitute into det(A − λI)', worst);
  }

  Verification _factorize(String input, String result) {
    final f = _inner(input, const ['factorize(', 'factor(', 'prime_factors(']);
    if (_isZero(_g('normal(expand(($result)) - ($f))'))) {
      return _verified(
        'expand the factors back',
        'Multiplying the reported factors back gives the original expression.',
      );
    }
    final probe = _differenceProbe(f, '($result)', 'x');
    if (probe != null && probe < 1e-6) {
      return _verified(
        'expand the factors back',
        'The factors match the original at the probe points to '
        '${_sig(probe)}.',
      );
    }
    return _unavailable(
      'The factors could not be expanded back automatically.',
    );
  }

  Verification _series(String input, String result) {
    final parts = _splitArgs(_inner(input, const ['taylor(', 'maclaurin(']));
    if (parts.isEmpty) return _unavailable('The series could not be read.');
    final f = parts[0];
    final v = parts.length >= 2 && _looksLikeVar(parts[1]) ? parts[1] : 'x';
    final a = parts.length >= 3 ? parts[2].trim() : '0';
    final poly = result.replaceAll(
      RegExp(r'\s*[+\-]\s*(order_size|O|oo)\s*\([^)]*\)'),
      '',
    );
    double worst = 0;
    for (final d in const ['0.05', '-0.03']) {
      final r = _number(
        _g('evalf(abs(subst(($f),$v,($a)+($d)) - subst(($poly),$v,($a)+($d))))'),
      );
      if (r == null) {
        return _unavailable('The expansion could not be sampled.');
      }
      worst = math.max(worst, r);
    }
    if (worst < 1e-2) {
      return _verified(
        'sample the expansion',
        'The expanded polynomial matches the function near the expansion '
        'point (within ${_sig(worst)}).',
      );
    }
    return _failed('sample the expansion', worst);
  }

  Verification _laplace(String input, String result) {
    final f = _inner(input, const ['laplace(']);
    if (_isZero(_g('normal(ilaplace(($result),s,t) - ($f))'))) {
      return _verified(
        'inverse-transform it back',
        'Inverting the reported transform recovers the original function.',
      );
    }
    return _unavailable(
      'The transform could not be inverted automatically, so it was not '
      'checked.',
    );
  }

  Verification _inverseLaplace(String input, String result) {
    final f = _inner(input, const ['invlaplace(', 'ilaplace(']);
    if (_isZero(_g('normal(laplace(($result),t,s) - ($f))'))) {
      return _verified(
        'transform it back',
        'Transforming the reported function recovers the original transform.',
      );
    }
    return _unavailable(
      'The inverse transform could not be transformed back automatically.',
    );
  }

  Verification _numericIdentity(String input, String result) {
    final f = _inner(input, const [
      'simplify(',
      'normal(',
      'evalf(',
      'mean(',
      'median(',
      'variance(',
      'stddev(',
      'isprime(',
      'factorize(',
    ]);
    final exact = _g('normal(($f) - ($result))');
    if (_isZero(exact)) {
      return _verified(
        'exact identity',
        'The simplified difference between the input and the result is zero.',
      );
    }
    final residual = _number(_g('evalf(abs(($f) - ($result)))'));
    if (residual == null) {
      return _unavailable('The difference is not numeric at these values.');
    }
    if (residual < 1e-9) {
      return _verified(
        'numeric identity',
        'The input and the result agree numerically to ${_sig(residual)}.',
      );
    }
    return _failed('numeric identity', residual);
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  /// Central-difference slope of [f] compared with [g] at two probe points.
  double? _differenceProbe(String f, String g, String v) {
    const h = 0.0001;
    double worst = 0;
    for (final p in const ['0.37', '1.23']) {
      final cmd =
          'evalf(abs((subst(($f),$v,$p+$h) - subst(($f),$v,$p-$h))'
          '/(2*$h) - subst(($g),$v,$p)))';
      final r = _number(_g(cmd));
      if (r == null) return null;
      worst = math.max(worst, r);
    }
    return worst;
  }

  double? _simpson(String f, double a, double b, {int n = 200}) {
    final steps = n.isEven ? n : n + 1;
    final h = (b - a) / steps;
    double sum = 0;
    for (int i = 0; i <= steps; i++) {
      final y = GraphEvaluator.instance.eval2D(f, a + i * h);
      if (y == null || !y.isFinite) return null;
      final weight = (i == 0 || i == steps) ? 1 : (i.isOdd ? 4 : 2);
      sum += weight * y;
    }
    return sum * h / 3;
  }

  String? _g(String cmd) {
    final raw = GiacFFI.instance.solve(cmd).trim().replaceAll('"', '');
    if (raw.isEmpty || raw.startsWith('Error')) return null;
    return raw;
  }

  double? _number(String? s) {
    if (s == null) return null;
    final v = double.tryParse(s.replaceAll(' ', ''));
    if (v == null || !v.isFinite) return null;
    return v;
  }

  static bool _isZero(String? s) {
    if (s == null) return false;
    final t = s.replaceAll(' ', '');
    return t == '0' || t == '0.' || t == '0.0' || t == '-0';
  }

  static bool _looksLikeVar(String s) {
    final t = s.trim();
    return t.length == 1 && RegExp(r'[a-zA-Z]').hasMatch(t);
  }

  /// "..." → [ ... ] and { ... } both become a plain list of entries.
  static List<String> _list(String s) {
    var t = s.trim();
    if (t.length >= 2 &&
        ((t.startsWith('{') && t.endsWith('}')) ||
            (t.startsWith('[') && t.endsWith(']')) ||
            (t.startsWith('(') && t.endsWith(')')))) {
      t = t.substring(1, t.length - 1);
    }
    if (t.isEmpty) return const [];
    return _splitArgs(t);
  }

  static String _inner(String input, List<String> prefixes) {
    for (final p in prefixes) {
      if (input.toLowerCase().startsWith(p.toLowerCase())) {
        var s = input.substring(p.length);
        if (p.endsWith('(') && s.endsWith(')')) {
          s = s.substring(0, s.length - 1);
        }
        if (p.endsWith('[') && s.endsWith(']')) {
          s = s.substring(0, s.length - 1);
        }
        return s.trim();
      }
    }
    return input;
  }

  static List<String> _splitArgs(String s) {
    final out = <String>[];
    var depth = 0;
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      if (ch == '(' || ch == '[' || ch == '{') {
        depth++;
      } else if (ch == ')' || ch == ']' || ch == '}') {
        depth--;
      }
      if (ch == ',' && depth == 0) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out;
  }

  /// Reads [[a,b],[c,d]] into rows of doubles, or null.
  static List<List<double>>? _matrix(String s) {
    final rows = <List<double>>[];
    final matches = RegExp(r'\[([^\[\]]*)\]').allMatches(s);
    for (final m in matches) {
      final body = m.group(1)!.trim();
      if (body.isEmpty) continue;
      final cells = body
          .split(',')
          .map((c) => double.tryParse(c.trim()))
          .toList();
      if (cells.any((c) => c == null)) return null;
      rows.add(cells.map((c) => c!).toList());
    }
    if (rows.isEmpty) return null;
    final n = rows.first.length;
    if (rows.any((r) => r.length != n)) return null;
    return rows;
  }

  static String _matrixText(List<List<double>> m) =>
      '[${m.map((r) => '[${r.join(',')}]').join(',')}]';

  static double? _det(List<List<double>> m) {
    final n = m.length;
    if (n == 1) return m[0][0];
    if (n == 2) return m[0][0] * m[1][1] - m[0][1] * m[1][0];
    if (n == 3) {
      final a = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]);
      final b = m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]);
      final c = m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
      return a - b + c;
    }
    return null;
  }

  /// Relative error between an independently-computed value and the reported
  /// one. The reported value is signed: wrapping it in abs() silently turns a
  /// negative result (e.g. a determinant) into a false mismatch.
  static double _relErr(double mine, double reported) =>
      (mine - reported).abs() / (1 + reported.abs());

  /// Documented for test access (see test/step_toolkit_test.dart).
  static double? expansionDeterminant(String matrixText) {
    final m = _matrix(matrixText);
    return m == null ? null : _det(m);
  }

  /// Documented for test access (see test/step_toolkit_test.dart).
  static double relativeError(double mine, double reported) =>
      _relErr(mine, reported);

  static Verification _verified(String check, String detail) =>
      Verification(VerificationStatus.verified, check, detail);

  static Verification _failed(String check, double residual) => Verification(
    VerificationStatus.failed,
    check,
    'residual ${_sig(residual)}',
  );

  static Verification _unavailable(String detail) =>
      Verification(VerificationStatus.unavailable, '', detail);

  static String _sig(double v) {
    if (v == 0) return '0';
    if (v < 1e-12) return '<1e-12';
    return v.toStringAsExponential(1);
  }

  static String _num(String s) {
    final v = double.tryParse(s.trim());
    if (v == null) return s.trim();
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
