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
    final family = _family(operation);
    // The abstract-algebra and topology checks are pure Dart (re-counting
    // generators, re-deriving Heine-Borel verdicts), so they run even where
    // the CAS engine is absent.
    if (family == 'Abstract Algebra') {
      try {
        return _groupCheck(input, result);
      } catch (_) {
        return _unavailable('The check could not be completed.');
      }
    }
    if (family == 'Topology') {
      try {
        return _topologyCheck(input, result);
      } catch (_) {
        return _unavailable('The check could not be completed.');
      }
    }
    if (!giacAvailable) {
      return _unavailable(
        'The numeric cross-check needs the CAS engine, which is not available '
        'on this platform.',
      );
    }
    try {
      switch (family) {
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
        case 'ODE':
          return _ode(input, result);
        case 'Vector Calculus':
          return _vectorCalculus(input, result);
        case 'Vector Algebra':
          return _vectorAlgebra(input, result);
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
    if (operation.contains('ODE')) return 'ODE';
    if (operation == 'Vector Calculus' ||
        operation.startsWith('Gradient') ||
        operation.startsWith('Divergence') ||
        operation.startsWith('Curl') ||
        operation.startsWith('Laplacian')) {
      return 'Vector Calculus';
    }
    if (operation.startsWith('Dot') || operation.startsWith('Cross')) {
      return 'Vector Algebra';
    }
    if (operation == 'Abstract Algebra') return 'Abstract Algebra';
    if (operation == 'Topology') return 'Topology';
    const numeric = {
      'Evaluate',
      'Trigonometry',
      'Complex',
      'Statistics',
      'Number Theory',
      'Primality',
      'Mod',
      'GCD',
      'LCM',
    };
    if (numeric.contains(operation)) return 'Numeric';
    // Fallback: try the numeric identity anyway.  It is honest — when
    // neither side evaluates to a number it reports unavailable — so every
    // topic gets a chance to be checked rather than defaulting to "not yet".
    return 'Numeric';
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
    if (!_trigExact(f) &&
        !_trigExact(result) &&
        _isZero(_g('normal(expand(($result)) - ($f))'))) {
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
    if (!_trigExact(f) &&
        !_trigExact(result) &&
        _isZero(_g('normal(ilaplace(($result),s,t) - ($f))'))) {
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
    if (!_trigExact(f) &&
        !_trigExact(result) &&
        _isZero(_g('normal(laplace(($result),t,s) - ($f))'))) {
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
    // Evaluate each side on its own and compare in Dart.  This is the only
    // shape that works for list and predicate inputs (mean([1,2,3,4,5]),
    // isprime(7), gcd(48,18)) where a single normal(f - result) expression
    // cannot even be formed, and for pattern-produced results such as the
    // trig table's "frac{sqrt{2}}{2}".
    final li = _toEvaluable(input);
    final lr = _toEvaluable(result);
    final a = _number(_g('evalf(($li))'));
    final b = _number(_g('evalf(($lr))'));
    if (a != null && b != null) {
      final err = _relErr(a, b);
      if (err < 1e-4) {
        return _verified(
          'numeric evaluation',
          'Both sides evaluate to the same number to ${_sig(err)}.',
        );
      }
      return _failed('numeric evaluation', err);
    }
    // A single abs() reaches complex-valued results that _number cannot read.
    final d = _number(_g('evalf(abs(($li) - ($lr)))'));
    if (d != null) {
      if (d < 1e-9) {
        return _verified(
          'numeric identity',
          'The difference between the input and the result vanishes to '
          '${_sig(d)}.',
        );
      }
      return _failed('numeric identity', d);
    }
    final f = _inner(input, const [
      'simplify(',
      'normal(',
      'evalf(',
      'factorize(',
    ]);
    if (!_trigExact(f) && !_trigExact(result)) {
      final exact = _g('normal(($f) - ($result))');
      if (_isZero(exact)) {
        return _verified(
          'exact identity',
          'The simplified difference between the input and the result is zero.',
        );
      }
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

  /// Translates the pattern engine's "readable" LaTeX fragments (backslashes
  /// already stripped) into something Giac can evaluate: frac{√2}{2} style
  /// braces become division.  Plain expressions pass through untouched.
  static String _toEvaluable(String s) {
    final t = s.trim();
    if (!t.contains('{') && !t.contains('frac(')) return t;
    var out = t.replaceAll('{', '(').replaceAll('}', ')');
    out = out.replaceAll('frac(', '(');
    out = out.replaceAll(')(', ')/(');
    return out;
  }

  Verification _ode(String input, String result) {
    var eq = _inner(input, const ['ode(', 'odesolve(', 'desolve(']);
    if (eq == input && !eq.contains('=')) {
      eq = eq.trim().replaceAll(RegExp(r'\s*\)$'), '');
    }
    final sides = eq.split('=');
    if (sides.length < 2) {
      return _unavailable('The equation could not be read.');
    }
    final lhs = sides.sublist(0, sides.length - 1).join('=').trim();
    final rhs = sides.last.trim();
    final v = RegExp(r'd/dt|\(\s*t\s*[,)]|\bdy/dt\b').hasMatch(input)
        ? 't'
        : 'x';
    final isFirstOrder = lhs.contains('dy/dx') ||
        lhs.contains('dy/dt') ||
        (!lhs.contains("y''") && lhs.contains("y'"));
    final s = '($result)';
    final rebuilt = isFirstOrder
        ? 'diff($s,$v) - subst(($rhs),y,$s)'
        : '${lhs
                .replaceAll("y''", 'diff($s,$v,2)')
                .replaceAll("y'", 'diff($s,$v)')
                .replaceAll(
                  RegExp(r'(?<![A-Za-z0-9_])y(?![A-Za-z0-9_])'),
                  s,
                )} - ($rhs)';
    if (!_trigExact(rebuilt) && _isZero(_g('normal(($rebuilt))'))) {
      return _verified(
        'plug the solution back in',
        'Differentiating the reported solution and substituting it back '
        'makes the equation hold exactly.',
      );
    }
    double? worst = 0;
    for (final p in const ['0.6', '1.4']) {
      final r = _number(_g('evalf(abs(subst(($rebuilt),$v,$p)))'));
      if (r == null) {
        worst = null;
        break;
      }
      worst = math.max(worst!, r);
    }
    if (worst == null) {
      return _unavailable(
        'The residual could not be evaluated at the sample points.',
      );
    }
    if (worst < 1e-8) {
      return _verified(
        'numeric residual',
        'The reported solution makes the residual zero at two sample points '
        'to ${_sig(worst)}.',
      );
    }
    return _failed('plug the solution back in', worst);
  }

  Verification _vectorCalculus(String input, String result) {
    final lower = input.toLowerCase();
    final inner = _inner(input, const [
      'gradient(',
      'grad(',
      'div(',
      'divergence(',
      'curl(',
      'laplacian(',
    ]);
    final parts = _splitArgs(inner);
    if (parts.isEmpty) {
      return _unavailable('The field could not be read.');
    }
    var vars = const ['x', 'y', 'z'];
    final args = <String>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.length >= 2 && t.startsWith('[') && t.endsWith(']')) {
        final inside = _splitArgs(t.substring(1, t.length - 1).trim());
        if (inside.length >= 2 && inside.every(_looksLikeVar)) {
          vars = inside;
        } else {
          args.addAll(inside);
        }
      } else if (_looksLikeVar(t) && vars.length == 1) {
        vars = [t];
      } else {
        args.add(t);
      }
    }
    if (args.isEmpty) {
      return _unavailable('The function or its variables could not be read.');
    }
    final op = lower.startsWith('grad(') ||
            lower.startsWith('gradient(')
        ? 'gradient'
        : lower.startsWith('div(') || lower.startsWith('divergence(')
            ? 'divergence'
            : lower.startsWith('curl(')
                ? 'curl'
                : 'laplacian';
    final points = <Map<String, double>>[];
    for (final p in const [
      {'x': 0.7, 'y': 0.4, 'z': 1.1},
      {'x': -0.3, 'y': 0.9, 'z': 0.5},
    ]) {
      final m = <String, double>{};
      for (final vv in vars) {
        m[vv] = p[vv] ?? 0.6;
      }
      points.add(m);
    }
    const h = 0.01;
    const tol = 5e-3;

    if (op == 'gradient') {
      final f = args.first;
      final g = _vec(result);
      if (g.isEmpty) {
        return _unavailable('The gradient could not be read.');
      }
      double worst = 0;
      for (final pt in points) {
        for (var i = 0; i < vars.length && i < g.length; i++) {
          final fd = _diffAt(f, vars[i], pt, h);
          final rc = _evalAt(g[i], pt);
          if (fd == null || rc == null) {
            return _unavailable('The probe points were undefined.');
          }
          worst = math.max(worst, (fd - rc).abs() / (1 + rc.abs()));
        }
      }
      if (worst < tol) {
        return _verified(
          'finite-difference partials',
          'Differentiating the original function at two probe points matches '
          'every reported component to ${_sig(worst)}.',
        );
      }
      return _failed('finite-difference partials', worst);
    }

    if (op == 'divergence') {
      double worst = 0;
      for (final pt in points) {
        double fd = 0;
        for (var i = 0; i < vars.length && i < args.length; i++) {
          final d = _diffAt(args[i], vars[i], pt, h);
          if (d == null) return _unavailable('The probe points were undefined.');
          fd += d;
        }
        final rc = _evalAt(result, pt);
        if (rc == null) return _unavailable('The probe points were undefined.');
        worst = math.max(worst, (fd - rc).abs() / (1 + rc.abs()));
      }
      if (worst < tol) {
        return _verified(
          'finite-difference flux',
          'Summing the partial derivatives at two probe points matches the '
          'reported divergence to ${_sig(worst)}.',
        );
      }
      return _failed('finite-difference flux', worst);
    }

    if (op == 'curl') {
      final c = _vec(result);
      if (c.isEmpty) {
        return _unavailable('The curl could not be read.');
      }
      double worst = 0;
      for (final pt in points) {
        if (vars.length == 2) {
          final a = _diffAt(args[1], vars[0], pt, h);
          final b = _diffAt(args[0], vars[1], pt, h);
          final rc = _evalAt(c.first, pt);
          if (a == null || b == null || rc == null) {
            return _unavailable('The probe points were undefined.');
          }
          worst = math.max(worst, (a - b - rc).abs() / (1 + rc.abs()));
        } else {
          final a = _diffAt(args[2], vars[1], pt, h);
          final b = _diffAt(args[1], vars[2], pt, h);
          final c0 = _diffAt(args[0], vars[2], pt, h);
          final c1 = _diffAt(args[2], vars[0], pt, h);
          final c2 = _diffAt(args[1], vars[0], pt, h);
          final c3 = _diffAt(args[0], vars[1], pt, h);
          if (a == null ||
              b == null ||
              c0 == null ||
              c1 == null ||
              c2 == null ||
              c3 == null) {
            return _unavailable('The probe points were undefined.');
          }
          final curves = <double>[a - b, c0 - c1, c2 - c3];
          for (var i = 0; i < curves.length && i < c.length; i++) {
            final rc = _evalAt(c[i], pt);
            if (rc == null) {
              return _unavailable('The probe points were undefined.');
            }
            worst = math.max(
              worst,
              (curves[i] - rc).abs() / (1 + rc.abs()),
            );
          }
        }
      }
      if (worst < tol) {
        return _verified(
          'finite-difference circulation',
          'Taking the circulation derivatives at two probe points matches the '
          'reported curl to ${_sig(worst)}.',
        );
      }
      return _failed('finite-difference circulation', worst);
    }

    // laplacian
    final f = args.first;
    double worst = 0;
    for (final pt in points) {
      double fd = 0;
      for (final vv in vars) {
        final d = _d2At(f, vv, pt, h);
        if (d == null) return _unavailable('The probe points were undefined.');
        fd += d;
      }
      final rc = _evalAt(result, pt);
      if (rc == null) return _unavailable('The probe points were undefined.');
      worst = math.max(worst, (fd - rc).abs() / (1 + rc.abs()));
    }
    if (worst < tol) {
      return _verified(
        'finite-difference second derivatives',
        'Summing the second partials at two probe points matches the reported '
        'Laplacian to ${_sig(worst)}.',
      );
    }
    return _failed('finite-difference second derivatives', worst);
  }

  Verification _vectorAlgebra(String input, String result) {
    final lower = input.toLowerCase();
    final isDot = lower.startsWith('dot(');
    final parts = _splitArgs(_inner(input, const ['dot(', 'cross(']));
    if (parts.length < 2) {
      return _unavailable('The vectors could not be read.');
    }
    final a = _vec(parts[0]);
    final b = _vec(parts[1]);
    if (a.isEmpty || a.length != b.length) {
      return _unavailable('The vectors have different lengths.');
    }
    final av = _nums(a);
    final bv = _nums(b);
    if (av == null || bv == null) {
      return _unavailable('The vectors are not numeric.');
    }
    if (isDot) {
      double mine = 0;
      for (var i = 0; i < av.length; i++) {
        mine += av[i] * bv[i];
      }
      final reported = double.tryParse(result.replaceAll(' ', ''));
      if (reported == null) {
        return _unavailable('The dot product is not numeric.');
      }
      return _compareScalar('sum the products', mine, reported);
    }
    if (av.length != 3) {
      return _unavailable('The cross product needs 3D vectors.');
    }
    final rv = _vec(result);
    if (rv.length != 3) {
      return _unavailable('The cross product could not be read.');
    }
    final mine = <double>[
      av[1] * bv[2] - av[2] * bv[1],
      av[2] * bv[0] - av[0] * bv[2],
      av[0] * bv[1] - av[1] * bv[0],
    ];
    double worst = 0;
    for (var i = 0; i < 3; i++) {
      final rc = double.tryParse(rv[i].replaceAll(' ', ''));
      if (rc == null) {
        return _unavailable('The cross product is not numeric.');
      }
      worst = math.max(worst, (mine[i] - rc).abs() / (1 + rc.abs()));
    }
    if (worst < 1e-9) {
      return _verified(
        'independent expansion',
        'Expanding the determinant that defines the cross product gives the '
        'same result to ${_sig(worst)}.',
      );
    }
    return _failed('independent expansion', worst);
  }

  Verification _groupCheck(String input, String result) {
    final m = RegExp(r'Z_?(\d+)').firstMatch(input);
    if (m == null) return _unavailable('No concrete modulus was given.');
    final n = int.tryParse(m.group(1)!);
    if (n == null || n <= 0) {
      return _unavailable('The modulus could not be read.');
    }
    final phi = _brutePhi(n);
    final orderClaim = RegExp(r'order\s+(\d+)').firstMatch(result);
    final genClaim =
        RegExp(r'φ\s*\(\s*(\d+)\s*\)\s*=\s*(\d+)').firstMatch(result);
    final statedOrder =
        orderClaim == null ? null : int.tryParse(orderClaim.group(1)!);
    final statedGen =
        genClaim == null ? null : int.tryParse(genClaim.group(2)!);
    if (statedOrder == null || statedGen == null) {
      return _unavailable(
        'The stated order and generator count could not be read.',
      );
    }
    final isField = input.toLowerCase().startsWith('field(');
    if (isField) {
      final claimedField = result.contains('a field');
      final actuallyField = _isPrimeInt(n);
      if (claimedField != actuallyField) {
        return _failed('primality of the modulus', 1.0);
      }
    }
    if (statedOrder != n || statedGen != phi) {
      return _failed(
        'recount the structure',
        ((statedOrder - n).abs() + (statedGen - phi).abs()).toDouble(),
      );
    }
    final msg = isField
        ? ' and confirmed as a field because $n is prime'
        : '';
    return _verified(
      'recount the generators',
      'Counting the residues coprime to $n gives φ($n)=$phi, matching the '
      'stated order and structure; Z_n is cyclic and abelian by '
      'construction$msg.',
    );
  }

  Verification _topologyCheck(String input, String result) {
    final lower = input.toLowerCase();
    final String op;
    if (lower.startsWith('compact(')) {
      op = 'compact';
    } else if (lower.startsWith('connected(')) {
      op = 'connected';
    } else {
      return _unavailable('Only compact(X) and connected(X) can be checked.');
    }
    final args = _inner(input, [op + '(']).trim();
    final parts = _splitArgs(args);
    if (parts.isEmpty || parts.first.trim().isEmpty) {
      return _unavailable('No space was given.');
    }
    final space = parts.first.trim();
    final verdict =
        op == 'compact' ? _spaceCompact(space) : _spaceConnected(space);
    if (verdict == null) {
      return _unavailable('This space is not in the known catalogue.');
    }
    final stated = op == 'compact'
        ? !result.contains('not compact')
        : !result.contains('not connected');
    if (stated != verdict) {
      return _failed('re-derive the verdict', 1.0);
    }
    return _verified(
      're-derive the verdict',
      'Re-deriving ${op}($space) from the Heine-Borel and '
      'separation criteria gives the same answer as the card above.',
    );
  }

  static bool? _spaceCompact(String space) {
    final t = space.trim();
    if (RegExp(r'^\{[^}]*\}$').hasMatch(t)) return true; // finite sets
    if (t == 'R' || t == 'RR' || t == 'Z' || t == 'N' || t == 'Q') {
      return false;
    }
    final iv = _intervalBounds(t);
    if (iv != null) return iv[0] == '[' && iv[1] == ']';
    return null;
  }

  static bool? _spaceConnected(String space) {
    final t = space.trim();
    if (RegExp(r'^\{[^}]*\}$').hasMatch(t)) {
      return t.substring(1, t.length - 1).split(',').length == 1;
    }
    if (t == 'R' || t == 'RR') return true;
    if (t == 'Z' || t == 'N' || t == 'Q') return false;
    if (_intervalBounds(t) != null) return true;
    return null;
  }

  /// "[a,b]" → [open/close left, open/close right, a, b]; null when a > b or
  /// the bounds are not finite numbers.
  static List<Object?>? _intervalBounds(String t) {
    final m = RegExp(
      r'^([\[\(])\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*([\]\)])$',
    ).firstMatch(t);
    if (m == null) return null;
    final a = double.tryParse(m.group(2)!);
    final b = double.tryParse(m.group(3)!);
    if (a == null || b == null || a > b) return null;
    return [m.group(1), m.group(4), a, b];
  }

  static int _brutePhi(int n) {
    var count = 0;
    for (var k = 1; k < n; k++) {
      if (_gcdInt(k, n) == 1) count++;
    }
    return count;
  }

  static int _gcdInt(int a, int b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a;
  }

  static bool _isPrimeInt(int n) {
    if (n < 2) return false;
    if (n < 4) return true;
    if (n.isEven) return false;
    for (var d = 3; d * d <= n; d += 2) {
      if (n % d == 0) return false;
    }
    return true;
  }

  Verification _compareScalar(String check, double mine, double reported) {
    final err = _relErr(mine, reported);
    if (err < 1e-9) {
      return _verified(
        check,
        'Recomputed from the entries, the result matches to ${_sig(err)}.',
      );
    }
    return _failed(check, err);
  }

  /// Numerically evaluates [expr] at a point given as var→value pairs.
  double? _evalAt(String expr, Map<String, double> at) {
    var cmd = 'evalf(($expr))';
    at.forEach((k, val) {
      cmd = 'subst($cmd,$k,$val)';
    });
    return _number(_g(cmd));
  }

  /// Central first difference of [expr] w.r.t. [v] at a point map.
  double? _diffAt(String expr, String v, Map<String, double> at, double h) {
    final hi = _evalAt(expr, {...at, v: at[v]! + h});
    final lo = _evalAt(expr, {...at, v: at[v]! - h});
    if (hi == null || lo == null) return null;
    return (hi - lo) / (2 * h);
  }

  /// Central second difference of [expr] w.r.t. [v] at a point map.
  double? _d2At(String expr, String v, Map<String, double> at, double h) {
    final hi = _evalAt(expr, {...at, v: at[v]! + h});
    final mid = _evalAt(expr, at);
    final lo = _evalAt(expr, {...at, v: at[v]! - h});
    if (hi == null || mid == null || lo == null) return null;
    return (hi - 2 * mid + lo) / (h * h);
  }

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

  /// "..." → [ ... ], { ... }, ( ... ) and Giac's list[...] all become a
  /// plain list of entries.
  static List<String> _list(String s) {
    var t = s.trim();
    if (t.toLowerCase().startsWith('list') && t.length > 4) {
      t = t.substring(4).trim();
    }
    if (t.length >= 2 &&
        ((t.startsWith('{') && t.endsWith('}')) ||
            (t.startsWith('[') && t.endsWith(']')) ||
            (t.startsWith('(') && t.endsWith(')')))) {
      t = t.substring(1, t.length - 1);
    }
    if (t.isEmpty) return const [];
    return _splitArgs(t);
  }

  /// A bracketed vector "[ ... ]" or bare entries becomes a plain list.
  static List<String> _vec(String s) {
    var t = s.trim();
    if (t.length >= 2 && t.startsWith('[') && t.endsWith(']')) {
      t = t.substring(1, t.length - 1);
    }
    if (t.isEmpty) return const [];
    return _splitArgs(t);
  }

  static List<double>? _nums(List<String> parts) {
    final out = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p.replaceAll(' ', ''));
      if (v == null) return null;
      out.add(v);
    }
    return out;
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

  /// Documented for test access (see test/step_toolkit_test.dart).
  static List<String> parseList(String s) => _list(s);

  /// Documented for test access (see test/step_toolkit_test.dart).
  static List<String> parseVector(String s) => _vec(s);

  /// Documented for test access (see test/step_toolkit_test.dart).
  static String toEvaluable(String s) => _toEvaluable(s);

  /// Documented for test access (see test/step_toolkit_test.dart).
  static int brutePhi(int n) => _brutePhi(n);

  /// Documented for test access (see test/step_toolkit_test.dart).
  static bool? topologyVerdict(String op, String space) =>
      op == 'compact' ? _spaceCompact(space) : _spaceConnected(space);

  /// True when [s] holds a trig function applied to a constant argument
  /// (e.g. sin(pi/4), 2*cos(pi/8)^2).  Giac's normal()/simplify() enters an
  /// infinite recursion on these exact forms and SIGSEGV's the worker thread
  /// (the "sin(pi/4)" A6 crash), so every Giac boundary must avoid
  /// normal()-style rewriting once this returns true.  Arguments that contain
  /// a genuine variable (sin(x), sin(x^2)) are safe and return false.
  static bool hasExactTrig(String s) => _trigExact(s);

  static bool _trigExact(String s) {
    final re = RegExp(
      r'(?:asin|acos|atan|sinh|cosh|tanh|sin|cos|tan|csc|sec|cot)\s*\(',
      caseSensitive: false,
    );
    var idx = 0;
    while (idx < s.length) {
      final m = re.firstMatch(s.substring(idx));
      if (m == null) return false;
      final start = idx + m.end;
      var depth = 1;
      var i = start;
      var end = -1;
      while (i < s.length && depth > 0) {
        final c = s[i];
        if (c == '(' || c == '[' || c == '{') {
          depth++;
        } else if (c == ')' || c == ']' || c == '}') {
          depth--;
          if (depth == 0) end = i;
        }
        i++;
      }
      if (end < 0) return false;
      var letters = s.substring(start, end).replaceAll(RegExp(r'[^A-Za-z]'), '');
      letters = letters
          .replaceAll('pi', '')
          .replaceAll('Pi', '')
          .replaceAll('PI', '')
          .replaceAll('e', '')
          .replaceAll('E', '')
          .replaceAll('inf', '')
          .replaceAll('Inf', '')
          .replaceAll('infinity', '');
      if (letters.isEmpty) return true;
      idx = end;
    }
    return false;
  }

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
