// lib/engine/matrix_algebra.dart
//
// Phase B / M3 — exact matrix algebra with an annotated trace.
//
//   • Every entry is a Q (exact rational) from symbolic.dart, so 3/2 stays
//     3/2 and never becomes 1.5.  Inputs such as [[1,2],[3,4]] or
//     [[1,3/2],[2,-1]] are read into exact fractions.
//   • determinant: cofactor expansion along the first row, one card per
//     expansion plus the signed sum.  Exact for any size the caller allows.
//   • inverse: full Gauss-Jordan on [A | I] — one card per row operation,
//     exact pivot handling and fractions throughout.
//   • eigenvalues: exact characteristic polynomial; quadratic roots with
//     radicals (or pure numbers), cubics factored via the rational-root
//     theorem when they factor.
//
// Giac remains the oracle: solver_engine.dart runs the verification card
// (det(A·A⁻¹)=1, det(A−λI)=0, independent expansion) against its value.

import '../models/solution.dart';
import 'symbolic.dart';

// ─── Exact matrix ─────────────────────────────────────────────────────────────

class ExactMatrix {
  ExactMatrix(this.rows);
  final List<List<Q>> rows;

  int get n => rows.length;
  bool get isSquare => rows.isNotEmpty && rows.every((r) => r.length == n);
  Q at(int i, int j) => rows[i][j];

  ExactMatrix clone() => ExactMatrix([for (final r in rows) [...r]]);

  /// Parses "[[a,b],[c,d]]" (entries may be fractions) or returns null.
  static ExactMatrix? fromText(String s) {
    final t = s.trim();
    if (!t.startsWith('[[') || !t.endsWith(']]')) return null;
    final inner = t.substring(2, t.length - 2);
    final rowTexts = inner.split('],[');
    final rows = <List<Q>>[];
    for (final rt in rowTexts) {
      final parts = rt.split(',');
      if (parts.isEmpty) return null;
      final cells = <Q>[];
      for (final p in parts) {
        final q = parseRational(p.trim());
        if (q == null) return null;
        cells.add(q);
      }
      rows.add(cells);
    }
    if (rows.isEmpty) return null;
    final w = rows.first.length;
    if (w == 0 || rows.any((r) => r.length != w)) return null;
    return ExactMatrix(rows);
  }

  static String _cells(List<Q> r) =>
      r.map((v) => v.toLatex()).join(' & ');

  String toLatex() =>
      '\\begin{pmatrix} ${rows.map(_cells).join(' \\\\ ')} \\end{pmatrix}';

  String toReadable() =>
      '[${rows.map((r) => '[${r.map((v) => v.toReadable()).join(',')}]').join(',')}]';

  /// Exact determinant via cofactor expansion along the first row, emitting
  /// the expansion cards for the top level.
  Q? detCofactor(List<SolutionStep> steps) => _detRec(rows, steps, 0);

  Q? detCofactorSilent() => _detSilent(rows);

  Q? _detSilent(List<List<Q>> m) {
    final n = m.length;
    if (n == 0) return null;
    if (n == 1) return m[0][0];
    if (n == 2) return m[0][0] * m[1][1] - m[0][1] * m[1][0];
    var sum = Q.fromInt(0);
    for (var j = 0; j < n; j++) {
      if (m[0][j].isZero) continue;
      final minor = _minor(m, 0, j);
      final mv = _detSilent(minor);
      if (mv == null) return null;
      final term = m[0][j] * mv;
      sum = j.isEven ? sum + term : sum - term;
    }
    return sum;
  }

  Q? _detRec(List<List<Q>> m, List<SolutionStep> steps, int depth) {
    final n = m.length;
    if (n == 0) return null;
    if (n == 2) {
      final a = m[0][0], b = m[0][1], c = m[1][0], d = m[1][1];
      final v = a * d - b * c;
      if (depth == 0) {
        steps.add(SolutionStep(
          title: '2×2 Expansion',
          latex:
              '\\det=${a.toLatex()}\\cdot${d.toLatex()}-${b.toLatex()}\\cdot${c.toLatex()}',
          explanation:
              'Diagonal product ${a.toLatex()}·${d.toLatex()} minus the '
              'off-diagonal ${b.toLatex()}·${c.toLatex()}.',
          rule: '2×2',
        ));
        steps.add(SolutionStep(
          title: 'Result',
          latex: '=${v.toLatex()}',
          explanation: 'Exact value of the determinant.',
          rule: 'Determinant',
        ));
      }
      return v;
    }
    if (depth == 0) {
      steps.add(SolutionStep(
        title: 'Cofactor Expansion',
        latex:
            '\\det(A)=\\sum_{j=1}^{$n}(-1)^{1+j}a_{1j}\\cdot M_{1j}',
        explanation:
            'Expand along the first row; each minor \$M_{1j}\$ is the smaller '
            'determinant left after deleting row 1 and column j.',
        rule: 'Cofactor',
      ));
    }
    var sum = Q.fromInt(0);
    final parts = <String>[];
    for (var j = 0; j < n; j++) {
      final a1j = m[0][j];
      if (a1j.isZero) continue;
      final minor = _minor(m, 0, j);
      final mv = _detRec(minor, steps, depth + 1);
      if (mv == null) return null;
      final term = a1j * mv;
      sum = j.isEven ? sum + term : sum - term;
      parts.add(
        '${j.isEven ? '+' : '-'} ${a1j.toLatex()}\\cdot'
        '\\left(${mv.toLatex()}\\right)',
      );
    }
    if (depth == 0) {
      steps.add(SolutionStep(
        title: 'Expand the minors',
        latex: '\\det=${parts.join(' ').trimLeft().replaceFirst(RegExp(r'^\+ '), '')}',
        explanation: 'Each product is an entry times its cofactor minor.',
        rule: 'Cofactor',
      ));
      steps.add(SolutionStep(
        title: 'Result',
        latex: '=${sum.toLatex()}',
        explanation: 'Sum of the signed products.',
        rule: 'Determinant',
      ));
    }
    return sum;
  }

  static List<List<Q>> _minor(List<List<Q>> m, int r, int c) => [
    for (var i = 0; i < m.length; i++)
      if (i != r)
        [for (var j = 0; j < m.length; j++) if (j != c) m[i][j]],
  ];

  /// Inverse via Gauss-Jordan on [A | I], emitting one card per row operation.
  /// Null when A is singular or larger than [maxN].
  ExactMatrix? inverseGaussJordan(
    List<SolutionStep> steps, {
    int maxN = 4,
  }) {
    if (!isSquare || n == 0 || n > maxN) return null;
    final width = 2 * n;
    final a = List.generate(
      n,
      (i) => <Q>[
        ...rows[i],
        ...List.generate(n, (j) => Q.fromInt(i == j ? 1 : 0)),
      ],
    );
    steps.add(SolutionStep(
      title: 'Augment with I',
      latex: '[A\\,|\\,I]=${_augLatex(a, n)}',
      explanation: 'Row-reduce the left block to the identity; whatever the '
          'right block becomes is A⁻¹.',
      rule: 'Gauss-Jordan',
    ));

    for (var col = 0; col < n; col++) {
      var pivot = -1;
      for (var r = col; r < n; r++) {
        if (!a[r][col].isZero) {
          pivot = r;
          break;
        }
      }
      if (pivot < 0) {
        steps.add(SolutionStep(
          title: 'Singular',
          latex: '\\text{Column }${col + 1}\\text{ has no pivot.}',
          explanation: 'A zero pivot column means det=0 and A has no inverse.',
          rule: 'Singular',
        ));
        return null;
      }
      if (pivot != col) {
        final tmp = a[pivot];
        a[pivot] = a[col];
        a[col] = tmp;
        steps.add(SolutionStep(
          title: 'Swap rows',
          latex: 'R_{${col + 1}}\\leftrightarrow R_{${pivot + 1}}',
          explanation: 'Bring the pivot entry up to the diagonal.',
          rule: 'Row Swap',
        ));
      }
      final pivotVal = a[col][col];
      if (!pivotVal.isOne) {
        final inv = Q.fromInt(1) / pivotVal;
        a[col] = [for (final v in a[col]) v * inv];
        steps.add(SolutionStep(
          title: 'Normalise pivot',
          latex:
              'R_{${col + 1}}\\leftarrow \\frac{1}{${pivotVal.toLatex()}}R_{${col + 1}}',
          explanation: 'Scale the pivot row so the diagonal entry is 1.',
          rule: 'Row Scale',
        ));
      }
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = a[r][col];
        if (f.isZero) continue;
        for (var j = 0; j < width; j++) {
          a[r][j] = a[r][j] - f * a[col][j];
        }
        steps.add(SolutionStep(
          title: 'Eliminate',
          latex:
              'R_{${r + 1}}\\leftarrow R_{${r + 1}}-\\left(${f.toLatex()}\\right)R_{${col + 1}}',
          explanation: 'Zero the entry in column ${col + 1} of row ${r + 1}.',
          rule: 'Row Eliminate',
        ));
      }
    }

    final inv = [for (var i = 0; i < n; i++) a[i].sublist(n)];
    steps.add(SolutionStep(
      title: 'Inverse read off',
      latex: 'A^{-1}=${ExactMatrix(inv).toLatex()}',
      explanation: 'The right block is A⁻¹, so A·A⁻¹=I.',
      rule: 'Result',
    ));
    return ExactMatrix(inv);
  }

  String _augLatex(List<List<Q>> a, int n) {
    final body = a
        .map((r) =>
            '${r.sublist(0, n).map((v) => v.toLatex()).join(' & ')} & | & '
            '${r.sublist(n).map((v) => v.toLatex()).join(' & ')}')
        .join(' \\\\ ');
    return '\\begin{pmatrix} $body \\end{pmatrix}';
  }
}

// ─── Exact eigen analysis ─────────────────────────────────────────────────────

/// One root, enough for an honest exact display.  [exact] is set when the
/// root is a plain rational; [isReal] is false for complex pairs.
class EigenRoot {
  const EigenRoot({
    required this.latex,
    required this.readable,
    this.isReal = true,
    this.exact,
    this.repeated = false,
  });
  final String latex;
  final String readable;
  final bool isReal;
  final Q? exact;
  final bool repeated;
}

class _SurdPart {
  const _SurdPart(this.outside, this.inside);
  final Q outside; // coefficient in front of the radical (may be fractional)
  final int inside; // square-free integer under the radical
}

int _g(int a, int b) => b == 0 ? a.abs() : _g(b, a % b);

/// sqrt(q) as outside·√inside with inside square-free.  For q<0 the radical
/// is still positive: the caller adds the `i` when it wants a complex form.
_SurdPart _radical(Q q) {
  final num = q.n, den = q.d;
  var base = (num * den).abs();
  var out = 1;
  for (var k = 2; k * k <= base; k++) {
    while (base % (k * k) == 0) {
      base ~/= k * k;
      out *= k;
    }
  }
  return _SurdPart(Q.fromInt(out) / Q.fromInt(den), base);
}

String _surdLatex(Q out, int inside) {
  if (inside == 1) return out.toLatex();
  if (out.isOne) return '\\sqrt{$inside}';
  if (out == Q.fromInt(-1)) return '-\\sqrt{$inside}';
  return '${out.toLatex()}\\sqrt{$inside}';
}

String _surdReadable(Q out, int inside) {
  if (inside == 1) return out.toReadable();
  if (out.isOne) return '√$inside';
  if (out == Q.fromInt(-1)) return '-√$inside';
  return '${out.toReadable()}√$inside';
}

List<EigenRoot> _radicalRoots(Q a, Q b, Q c, bool complex) {
  final negB = b.neg;
  final disc = b * b - a * c * Q.fromInt(4);
  final rad = _radical(complex ? disc.neg : disc);
  final twoA = a * Q.fromInt(2);
  EigenRoot one(String op, int sign) {
    final surd = complex
        ? 'i\\,${_surdLatex(rad.outside, rad.inside)}'
        : _surdLatex(rad.outside, rad.inside);
    final readableSurd = complex
        ? 'i${_surdReadable(rad.outside, rad.inside)}'
        : _surdReadable(rad.outside, rad.inside);
    return EigenRoot(
      latex: '\\dfrac{${negB.toLatex()} $op $surd}{${twoA.toLatex()}}',
      readable: '(${negB.toReadable()} $op $readableSurd)/${twoA.toReadable()}',
      isReal: !complex,
    );
  }

  return [one('+', 1), one('-', -1)];
}

class EigenAnalysis {
  EigenAnalysis({
    required this.polynomialLatex,
    required this.polynomialReadable,
    required this.roots,
  });
  final String polynomialLatex;
  final String polynomialReadable;
  final List<EigenRoot> roots;
}

/// Polynomial arithmetic over Q[λ] — ascending coefficients, so p[0] is the
/// constant term and p[p.length-1] the leading one.
List<Q> _polyMul(List<Q> p, List<Q> q) {
  final out = List.generate(p.length + q.length - 1, (_) => Q.fromInt(0));
  for (var i = 0; i < p.length; i++) {
    for (var j = 0; j < q.length; j++) {
      out[i + j] = out[i + j] + p[i] * q[j];
    }
  }
  return out;
}

List<Q> _polyAdd(List<Q> p, List<Q> q) {
  final n = p.length > q.length ? p.length : q.length;
  final out = List.generate(
    n,
    (i) => (i < p.length ? p[i] : Q.fromInt(0)) +
        (i < q.length ? q[i] : Q.fromInt(0)),
  );
  return _polyTrim(out);
}

List<Q> _polySub(List<Q> p, List<Q> q) => _polyAdd(p, [for (final c in q) c.neg]);

List<Q> _polyTrim(List<Q> p) {
  var end = p.length;
  while (end > 1 && p[end - 1].isZero) {
    end--;
  }
  return p.sublist(0, end);
}

bool _polyIsZero(List<Q> p) => p.every((c) => c.isZero);

// Determinant of a matrix whose entries are polynomials over Q[λ].
List<Q> _detPoly(List<List<List<Q>>> pm) {
  final n = pm.length;
  if (n == 1) return pm[0][0];
  var sum = <Q>[Q.fromInt(0)];
  for (var j = 0; j < n; j++) {
    final entry = pm[0][j];
    if (_polyIsZero(entry)) continue;
    final minor = [
      for (var i = 1; i < n; i++)
        [for (var k = 0; k < n; k++) if (k != j) pm[i][k]],
    ];
    final mVal = _detPoly(minor);
    final term = _polyMul(entry, mVal);
    sum = j.isEven ? _polyAdd(sum, term) : _polySub(sum, term);
  }
  return _polyTrim(sum);
}

/// Exact characteristic polynomial det(λI − A), ascending coefficients.
/// Supported for 1×1 .. 3×3.
List<Q>? charPolynomial(ExactMatrix m) {
  if (!m.isSquare || m.n < 1 || m.n > 3) return null;
  final pm = [
    for (var i = 0; i < m.n; i++)
      [
        for (var j = 0; j < m.n; j++)
          i == j ? <Q>[m.at(i, j).neg, Q.fromInt(1)] : [m.at(i, j).neg],
      ],
  ];
  final out = _detPoly(pm);
  return out.isEmpty ? null : out;
}

/// Rational roots of a poly with small-int... cubic factoring helper.
List<Q>? _rationalRoots(List<Q> poly) {
  // scale to integer coefficients
  var lcm = 1;
  for (final c in poly) {
    lcm = (lcm * c.d) ~/ _g(lcm, c.d);
  }
  final ints = [for (final c in poly) (c * Q.fromInt(lcm)).n.abs()];
  final a0 = ints.first.abs();
  final an = ints.last.abs();
  if (a0 > 1000000 || an > 1000000) return null;
  final cands = <Q>{};
  final pDiv = <int>[];
  for (var d = 1; d * d <= a0; d++) {
    if (a0 % d == 0) {
      pDiv.add(d);
      if (d * d != a0) pDiv.add(a0 ~/ d);
    }
  }
  final qDiv = <int>[];
  for (var d = 1; d * d <= an; d++) {
    if (an % d == 0) {
      qDiv.add(d);
      if (d * d != an) qDiv.add(an ~/ d);
    }
  }
  for (final p in pDiv) {
    for (final q in qDiv) {
      final g = _g(p, q);
      cands.add(Q.fromInt(p ~/ g) / Q.fromInt(q ~/ g));
      cands.add(Q.fromInt(-p ~/ g) / Q.fromInt(q ~/ g));
    }
  }
  Q? found;
  for (final c in cands) {
    // Horner over Q
    var val = Q.fromInt(0);
    for (var i = poly.length - 1; i >= 0; i--) {
      val = val * c + poly[i];
    }
    if (val.isZero) {
      found = c;
      break;
    }
  }
  return found == null ? null : [found];
}

/// Factor (λ − r) out of [poly] (synthetic division); quotient ascending.
List<Q> _deflate(List<Q> poly, Q r) {
  final out = List<Q>.filled(poly.length - 1, Q.fromInt(0));
  out[poly.length - 2] = poly[poly.length - 1];
  for (var i = poly.length - 2; i >= 1; i--) {
    out[i - 1] = poly[i] + r * out[i];
  }
  return _polyTrim(out);
}

String _polyLatex(List<Q> p, String v) {
  final deg = p.length - 1;
  final parts = <String>[];
  for (var i = deg; i >= 0; i--) {
    final c = p[i];
    if (c.isZero) continue;
    final abs = c.isNeg ? c.neg : c;
    final mon = i == 0
        ? abs.toLatex()
        : (i == 1
            ? (abs.isOne ? v : '${abs.toLatex()}$v')
            : (abs.isOne ? '$v^{$i}' : '${abs.toLatex()}$v^{$i}'));
    if (i == deg) {
      parts.add('${c.isNeg ? '-' : ''}$mon');
    } else {
      parts.add('${c.isNeg ? '-' : '+'}$mon');
    }
  }
  return parts.isEmpty ? '0' : parts.join(' ');
}

/// Full 2×2 char-poly solve: λ² + bλ + c = 0 (monic).  Returns roots with an
/// exact display (radicals reduced, pure numbers when Δ is a perfect square,
/// complex pairs otherwise).
List<EigenRoot>? quadraticRoots(Q b, Q c) {
  final discT = b * b - c * Q.fromInt(4);
  final two = Q.fromInt(2);
  final negB = b.neg;
  // rational roots when Δ is a perfect square r = p/q
  final rad = _radical(discT);
  if (!discT.isNeg && rad.inside == 1 && !discT.isZero) {
    final s = rad.outside;
    final r1 = (negB + s) / two;
    final r2 = (negB - s) / two;
    return [
      EigenRoot(
        latex: r1.toLatex(),
        readable: r1.toReadable(),
        exact: r1,
      ),
      EigenRoot(
        latex: r2.toLatex(),
        readable: r2.toReadable(),
        exact: r2,
      ),
    ];
  }
  if (discT.isZero) {
    final r = negB / two;
    return [
      EigenRoot(
        latex: r.toLatex(),
        readable: r.toReadable(),
        exact: r,
        repeated: true,
      ),
    ];
  }
  return _radicalRoots(Q.fromInt(1), b, c, discT.isNeg);
}

/// Char poly [det, −(sum of diagonal cofactors), trace-term, 1] = 0 solved
/// exactly for 3×3: a rational root is found by the rational-root theorem and
/// the remainder is the same quadratic solver.  Null when the cubic does not
/// factor over the rationals.
List<EigenRoot>? cubicRoots(List<Q> poly) {
  if (poly.length != 4) return null;
  final roots = _rationalRoots(poly);
  if (roots == null || roots.isEmpty) return null;
  final r = roots.first;
  final rest = _deflate(poly, r);
  final out = <EigenRoot>[
    EigenRoot(
      latex: r.toLatex(),
      readable: r.toReadable(),
      exact: r,
    ),
  ];
  if (rest.length == 2) {
    // linear remainder
    final cr = (rest[0].neg) / rest[1];
    out.add(EigenRoot(
      latex: cr.toLatex(),
      readable: cr.toReadable(),
      exact: cr,
    ));
  } else if (rest.length == 3) {
    final quad = quadraticRoots(rest[1], rest[0]);
    if (quad != null) out.addAll(quad);
  }
  return out;
}

/// One-shot: exact characteristic polynomial plus root display for a 2×2/3×3
/// matrix, or null when it cannot be produced (non-square, too large, or a
/// cubic that does not factor).
EigenAnalysis? eigenAnalysis(ExactMatrix m) {
  final poly = charPolynomial(m);
  if (poly == null) return null;
  final latex = _polyLatex(poly, '\\lambda');
  final readable = _polyLatex(poly, 'λ');
  List<EigenRoot>? roots;
  if (m.n == 2) {
    roots = quadraticRoots(poly[1], poly[0]);
  } else if (m.n == 3) {
    roots = cubicRoots(poly);
  }
  if (roots == null || roots.isEmpty) return null;
  return EigenAnalysis(
    polynomialLatex: latex,
    polynomialReadable: readable,
    roots: roots,
  );
}