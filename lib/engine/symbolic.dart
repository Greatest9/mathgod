// lib/engine/symbolic.dart
//
// Phase B / M2 — a tiny symbolic engine in Dart.
//
//   • Exact rational arithmetic  — 1/3 stays 1/3, never 0.3333.
//   • A small AST  —  Number | Var | Add | Mul | Pow | Fn.
//   • diff() with rule emission  —  every differentiation step carries the
//     name of the rule that produced it (Power, Sum, Product, Quotient,
//     Chain, Const, Trig, Exp, Log).
//
// The engine is used by the pattern fallback to turn generic "apply the
// right rule" cards into real per-term traces.  Only single-variable inputs
// are differentiated; anything the parser cannot own yields null and the
// caller keeps its existing behaviour.

import '../models/solution.dart';

// ═══ Exact rational numbers ══════════════════════════════════════════════════

/// Immutable rational.  Denominator is always positive; the pair is reduced.
class Q {
  const Q(this.n, this.d) : assert(d != 0);
  final int n;
  final int d;

  static Q fromInt(int v) => Q(v, 1);

  Q _r(int a, int b) {
    if (b < 0) {
      a = -a;
      b = -b;
    }
    final g = _gcd(a.abs(), b);
    return Q(b == 0 ? 0 : a ~/ g, b == 0 ? 1 : b ~/ g);
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  bool get isZero => n == 0;
  bool get isOne => n == d;
  bool get isNeg => n < 0;
  bool get isInteger => d == 1;

  Q operator +(Q o) => _r(n * o.d + o.n * d, d * o.d);
  Q operator -(Q o) => _r(n * o.d - o.n * d, d * o.d);
  Q operator *(Q o) => _r(n * o.n, d * o.d);
  Q operator /(Q o) => _r(n * o.d, d * o.n);
  Q get neg => Q(-n, d);

  Q pow2(int e) {
    if (e >= 0) return _r(_pow(n, e), _pow(d, e));
    // negative: n^e/d^e = d^(-e)/n^(-e)
    return _r(_pow(d, -e), _pow(n, -e));
  }

  static int _pow(int b, int e) {
    var r = 1;
    for (var i = 0; i < e; i++) {
      r *= b;
    }
    return r;
  }

  double toDouble() => n / d;

  String toLatex() {
    if (isInteger) return '$n';
    return '\\frac{$n}{$d}';
  }

  String toReadable() => isInteger ? '$n' : '$n/$d';

  @override
  bool operator ==(Object o) => o is Q && o.n == n && o.d == d;

  @override
  int get hashCode => Object.hash(n, d);

  @override
  String toString() => toReadable();
}

// ═══ AST ═════════════════════════════════════════════════════════════════════

sealed class Ex {
  Ex canonical() => this;
  String toLatex() => toReadable();
  String toReadable() => '';
  int degree() => 0;
  String _key() => toReadable();

  /// Negation as -1 times the node.  Specialised where the results are
  /// cleaner (pure numbers, sums).
  Ex negate() => MulEx([NumEx(Q.fromInt(-1)), this]).canonical();

  /// The integer value of this node, when it is a plain integer constant.
  /// Used by the parser to accept only integer exponents.
  int? asIntExponent() {
    if (this is NumEx && (this as NumEx).v.isInteger) {
      return (this as NumEx).v.n;
    }
    return null;
  }
}

class NumEx extends Ex {
  NumEx(this.v);
  final Q v;

  @override
  Ex canonical() => this;

  @override
  Ex negate() => NumEx(v.neg);

  @override
  bool operator ==(Object o) => o is NumEx && o.v == v;

  @override
  int get hashCode => v.hashCode;

  @override
  String toLatex() => v.toLatex();

  @override
  String toReadable() => v.toReadable();

  @override
  String _key() => 'num:${v.toReadable()}';
}

class VarEx extends Ex {
  VarEx(this.name);
  final String name;

  @override
  String toLatex() => name == 'pi' ? '\\pi' : name;

  @override
  String toReadable() => name == 'pi' ? 'pi' : name;

  @override
  int degree() => 1;

  @override
  String _key() => 'v:$name';

  @override
  bool operator ==(Object o) => o is VarEx && o.name == name;

  @override
  int get hashCode => name.hashCode;
}

class FnEx extends Ex {
  FnEx(this.name, this.arg);
  final String name; // sin cos tan sec ln exp ...
  final Ex arg;

  @override
  Ex canonical() {
    final a = arg.canonical();
    final s = FnEx(name, a)._simple();
    return s?.canonical() ?? FnEx(name, a);
  }

  Ex? _simple() {
    if (arg case NumEx(v: final v)) {
      if (name == 'exp' && v.isZero) return NumEx(Q.fromInt(1));
      if (name == 'sin' && v.isZero) return NumEx(Q.fromInt(0));
      if (name == 'cos' && v.isZero) return NumEx(Q.fromInt(1));
      if (name == 'tan' && v.isZero) return NumEx(Q.fromInt(0));
      if (name == 'ln' && v.isOne) return NumEx(Q.fromInt(0));
    }
    return null;
  }

  @override
  String toLatex() {
    final a = arg.toLatex();
    if (name == 'exp') return 'e^{$a}';
    return '\\${name}($a)';
  }

  @override
  String toReadable() {
    final a = arg.toReadable();
    if (name == 'exp') {
      final atom = arg is NumEx || arg is VarEx;
      return 'e^${atom ? a : '($a)'}';
    }
    return '$name($a)';
  }

  @override
  String _key() => 'fn:$name(${arg._key()})';

  @override
  bool operator ==(Object o) => o is FnEx && o.name == name && o.arg == arg;

  @override
  int get hashCode => Object.hash(name, arg);
}

class PowEx extends Ex {
  PowEx(this.base, this.exp);
  final Ex base;
  final int exp;

  @override
  Ex canonical() {
    final b = base.canonical();
    if (exp == 0) return NumEx(Q.fromInt(1));
    if (exp == 1) return b;
    if (b case NumEx(v: final v)) return NumEx(v.pow2(exp));
    if (b case PowEx(base: final bb, exp: final ee)) {
      return PowEx(bb, ee * exp).canonical();
    }
    if (b case MulEx(factors: final fs)) {
      return MulEx(fs.map((f) => PowEx(f, exp)).toList()).canonical();
    }
    return PowEx(b, exp);
  }

  @override
  String toLatex() {
    if (exp < 0) return '\\frac{1}{${_renderAbs()}}';
    return _renderAbs();
  }

  String _renderAbs() {
    final e = exp.abs();
    final b = base.toLatex();
    final atom = base is NumEx || base is VarEx || base is FnEx;
    final body = (atom || e == 1) ? b : '\\left($b\\right)';
    return e == 1 ? body : '$body^{$e}';
  }

  @override
  String toReadable() {
    if (exp < 0) return '1/${_readAbs()}';
    return _readAbs();
  }

  /// The positive-power body — used as a single denominator term.
  String toReadableAbs() => _readAbs();

  String _readAbs() {
    final e = exp.abs();
    final b = base.toReadable();
    final atom = base is NumEx || base is VarEx || base is FnEx;
    final body = (atom || e == 1) ? b : '($b)';
    return e == 1 ? body : '$body^$e';
  }

  @override
  int degree() => base.degree() * exp;

  @override
  String _key() => 'pow:${base._key()}^$exp';

  @override
  bool operator ==(Object o) => o is PowEx && o.base == base && o.exp == exp;

  @override
  int get hashCode => Object.hash(base, exp);
}

class MulEx extends Ex {
  MulEx(this.factors);
  final List<Ex> factors;

  @override
  Ex canonical() {
    // Flatten, collect the numeric coefficient and like bases.
    Q coeff = Q.fromInt(1);
    final rest = <Ex>[];
    final byBase = <String, (Ex, int)>{}; // key → (base-ish, exponent)

    void walk(Ex e) {
      if (e is NumEx) {
        coeff = coeff * e.v;
      } else if (e is MulEx) {
        for (final f in e.factors) {
          walk(f);
        }
      } else {
        final c = e.canonical();
        if (c is NumEx) {
          coeff = coeff * c.v;
        } else if (c is PowEx) {
          final k = c.base._key();
          byBase[k] = (byBase[k]?.$1 ?? c.base, (byBase[k]?.$2 ?? 0) + c.exp);
        } else if (c is MulEx) {
          for (final f in c.factors) {
            walk(f);
          }
        } else {
          final k = c._key();
          byBase[k] ??= (c, 0);
          final (_, e2) = byBase[k]!;
          byBase[k] = (c, e2 + 1);
        }
      }
    }

    for (final f in factors) {
      walk(f);
    }

    if (coeff.isZero) return NumEx(Q.fromInt(0));

    if (!coeff.isOne) rest.add(NumEx(coeff));
    for (final entry in byBase.entries) {
      final (b, e) = entry.value;
      if (e == 0) continue;
      rest.add(e == 1 ? b : PowEx(b, e));
    }

    if (rest.isEmpty) return NumEx(Q.fromInt(1));
    if (rest.length == 1) return rest[0].canonical();

    // Deterministic order: numbers first, then variable-based factors
    // (before functions, which read more naturally last), then by key.
    rest.sort((a, b) {
      if (a is NumEx) return -1;
      if (b is NumEx) return 1;
      final ra = _rank(a);
      final rb = _rank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a._key().compareTo(b._key());
    });
    return MulEx(rest);
  }

  static int _rank(Ex e) {
    if (e is VarEx) return 0;
    if (e is PowEx && (e.base is VarEx || e.base is NumEx)) return 0;
    return 1;
  }

  @override
  String toLatex() {
    final neg = factors.whereType<PowEx>().where((p) => p.exp < 0).toList();
    if (neg.isNotEmpty) {
      final pos = factors.where((f) => !(f is PowEx && f.exp < 0)).toList();
      final numL = pos.isEmpty ? '1' : _productLatex(pos);
      final denL = neg.map(_denLatex).join('\\cdot ');
      final negNum = numL.startsWith('-');
      final body = '\\frac{${negNum ? numL.substring(1) : numL}}{$denL}';
      return negNum ? '-$body' : body;
    }
    return _productLatex(factors);
  }

  static String _denLatex(PowEx p) {
    final e = p.exp.abs();
    final b = p.base.toLatex();
    final atom = p.base is NumEx || p.base is VarEx || p.base is FnEx;
    final body = (atom || e == 1) ? b : '\\left($b\\right)';
    return e == 1 ? body : '$body^{$e}';
  }

  static String _productLatex(List<Ex> fs) {
    final entries = <(Ex, String)>[];
    for (final f in fs) {
      if (f is NumEx && f.v.isOne) continue;
      final s = f is AddEx ? '\\left(${f.toLatex()}\\right)' : f.toLatex();
      entries.add((f, s));
    }
    if (entries.isEmpty) return '1';
    final out = StringBuffer(entries.first.$2);
    for (var i = 1; i < entries.length; i++) {
      final prev = entries[i - 1].$1;
      final curr = entries[i].$1;
      final prevAtom =
          prev is NumEx || prev is VarEx || prev is FnEx || prev is PowEx;
      final currAtom =
          curr is NumEx || curr is VarEx || curr is FnEx || curr is PowEx;
      out.write((prevAtom && currAtom) ? '' : '\\cdot ');
      out.write(entries[i].$2);
    }
    return out.toString();
  }

  @override
  String toReadable() {
    final neg = factors.whereType<PowEx>().where((p) => p.exp < 0).toList();
    if (neg.isNotEmpty) {
      final pos = factors.where((f) => !(f is PowEx && f.exp < 0)).toList();
      final numL = pos.isEmpty ? '1' : pos.map(_readFactor).join('*');
      final denL = neg.map((p) => p.toReadableAbs()).join('*');
      final den = denL.contains('*') ? '($denL)' : denL;
      return '$numL/$den';
    }
    final fs = factors
        .where((f) => !(f is NumEx && f.v.isOne))
        .toList();
    if (fs.isEmpty) return '1';
    return fs.map(_readFactor).join('*');
  }

  static String _readFactor(Ex f) =>
      f is AddEx ? '(${f.toReadable()})' : f.toReadable();

  @override
  int degree() => factors.fold(0, (a, f) => a + f.degree());

  @override
  String _key() {
    final parts = factors.map((f) => f._key()).join('*');
    return 'mul:$parts';
  }

  @override
  bool operator ==(Object o) =>
      o is MulEx && _listEq(o.factors, factors);

  @override
  int get hashCode => Object.hashAll(factors);
}

class AddEx extends Ex {
  AddEx(this.terms);
  final List<Ex> terms;

  @override
  Ex canonical() {
    final flat = <Ex>[];
    void walk(Ex e) {
      if (e is AddEx) {
        for (final t in e.terms) {
          walk(t);
        }
      } else {
        flat.add(e);
      }
    }

    for (final t in terms) {
      walk(t);
    }

    // Split each term into (numeric coefficient, symbolic part).
    final byKey = <String, (Q, Ex)>{};
    final order = <String>[];

    for (final t in flat) {
      // Expand a Mul into coeff + body using its canonical Num first factor.
      var c = Q.fromInt(1);
      var body = t;
      var tc = t.canonical();
      if (tc is MulEx) {
        final fs = tc.factors;
        if (fs.isNotEmpty && fs.first is NumEx) {
          c = (fs.first as NumEx).v;
          if (fs.length == 1) {
            body = NumEx(c);
            c = Q.fromInt(1);
          } else {
            body = MulEx(fs.sublist(1)).canonical();
          }
        }
      } else if (tc is NumEx) {
        c = tc.v;
        body = NumEx(Q.fromInt(1)); // a bare constant is its own term
      }

      final k = body._key();
      final prev = byKey[k];
      if (prev == null) order.add(k);
      byKey[k] = ((prev?.$1 ?? Q.fromInt(0)) + c, body);
    }

    final out = <Ex>[];
    for (final k in order) {
      final (c, body) = byKey[k]!;
      if (c.isZero) continue;
      if (body is NumEx && body.v.isOne) {
        out.add(NumEx(c));
      } else if (c.isOne) {
        out.add(body);
      } else {
        out.add(MulEx([NumEx(c), body]).canonical());
      }
    }

    if (out.isEmpty) return NumEx(Q.fromInt(0));
    if (out.length == 1) return out[0].canonical();

    // Highest degree first; ties broken by sort key for determinism.
    out.sort((a, b) {
      final d = b.degree().compareTo(a.degree());
      if (d != 0) return d;
      return a._key().compareTo(b._key());
    });
    return AddEx(out);
  }

  @override
  String toLatex() {
    final buf = StringBuffer();
    var first = true;
    for (final t in terms) {
      final s = t.toLatex();
      if (first) {
        buf.write(s);
        first = false;
      } else if (s.startsWith('-')) {
        buf.write(' - ');
        buf.write(s.substring(1));
      } else {
        buf.write(' + ');
        buf.write(s);
      }
    }
    return buf.toString();
  }

  @override
  String toReadable() {
    final buf = StringBuffer();
    var first = true;
    for (final t in terms) {
      final s = t.toReadable();
      if (first) {
        buf.write(s);
        first = false;
      } else if (s.startsWith('-')) {
        buf.write(' - ');
        buf.write(s.substring(1));
      } else {
        buf.write(' + ');
        buf.write(s);
      }
    }
    return buf.toString();
  }

  @override
  int degree() => terms.fold(0, (a, t) => (a > t.degree()) ? a : t.degree());

  @override
  String _key() => 'add:${terms.map((t) => t._key()).join('+')}';

  @override
  bool operator ==(Object o) =>
      o is AddEx && _listEq(o.terms, terms);

  @override
  int get hashCode => Object.hashAll(terms);
}

bool _listEq(List<Ex> a, List<Ex> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ═══ Parser ═══════════════════════════════════════════════════════════════════

class _Parser {
  _Parser(String src) {
    _src = src.replaceAll(' ', '');
    _pos = 0;
  }

  late String _src;
  late int _pos;

  static const _fnNames = {
    'sin', 'cos', 'tan', 'cot', 'sec', 'csc',
    'arcsin', 'arccos', 'arctan', 'exp', 'ln', 'log',
  };

  Ex? run() {
    final t = _parseAdd();
    if (t == null) return null;
    _skipWs();
    return _pos < _src.length ? null : t;
  }

  String? _peek() => _pos < _src.length ? _src[_pos] : null;

  void _skipWs() {
    while (_pos < _src.length && _src[_pos] == ' ') {
      _pos++;
    }
  }

  String _ident() {
    var j = _pos;
    while (j < _src.length && RegExp(r'[A-Za-z]').hasMatch(_src[j])) {
      j++;
    }
    final s = _src.substring(_pos, j).toLowerCase();
    _pos = j;
    return s;
  }

  Ex? _parseAdd() {
    final first = _parseMul();
    if (first == null) return null;
    var lhs = first;
    while (true) {
      _skipWs();
      final c = _peek();
      if (c == null || c == ')' || c == ',') return lhs;
      if (c == '+') {
        _pos++;
        final rhs = _parseMul();
        if (rhs == null) return null;
        lhs = AddEx([lhs, rhs]);
      } else if (c == '-') {
        _pos++;
        final rhs = _parseMul();
        if (rhs == null) return null;
        lhs = AddEx([lhs, rhs.negate()]);
      } else {
        // juxtaposition: implicit multiplication
        final rhs = _parseMul();
        if (rhs == null) return null;
        lhs = MulEx([lhs, rhs]);
      }
    }
  }

  Ex? _parseMul() {
    final first = _parseUnary();
    if (first == null) return null;
    var lhs = first;
    while (true) {
      _skipWs();
      final c = _peek();
      if (c == null || c == ')' || c == '+' || c == '-' || c == ',')
        return lhs;
      if (c == '*') {
        _pos++;
        final rhs = _parseUnary();
        if (rhs == null) return null;
        lhs = MulEx([lhs, rhs]);
      } else if (c == '/') {
        _pos++;
        final rhs = _parseUnary();
        if (rhs == null) return null;
        lhs = MulEx([lhs, PowEx(rhs, -1)]);
      } else {
        final rhs = _parseUnary();
        if (rhs == null) return null;
        lhs = MulEx([lhs, rhs]);
      }
    }
  }

  Ex? _parseUnary() {
    _skipWs();
    final c = _peek();
    if (c == '+') {
      _pos++;
      return _parseUnary();
    }
    if (c == '-') {
      _pos++;
      final e = _parseUnary();
      return e?.negate();
    }
    return _parsePow();
  }

  Ex? _parsePow() {
    final b = _parseAtom();
    if (b == null) return null;
    _skipWs();
    if (_peek() == '^') {
      _pos++;
      final e = _parseUnary();
      if (e == null) return null;
      final n = e.asIntExponent();
      if (n == null) return null; // only integer exponents supported
      return PowEx(b, n);
    }
    return b;
  }

  Ex? _parseAtom() {
    _skipWs();
    final c = _peek();
    if (c == '(') {
      _pos++;
      final e = _parseAdd();
      if (e == null) return null;
      _skipWs();
      if (_peek() != ')') return null;
      _pos++;
      return e;
    }
    if (c == null) return null;
    if (c.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        c.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
      return _parseNumber();
    }
    if (RegExp(r'[A-Za-z]').hasMatch(c)) {
      final id = _ident();
      _skipWs();
      if (_peek() == '(') {
        final fname = _fnNames.contains(id) ? id : null;
        if (fname == null) return null;
        _pos++;
        final arg = _parseAdd();
        if (arg == null) return null;
        _skipWs();
        if (_peek() != ')') return null;
        _pos++;
        return FnEx(fname == 'log' ? 'ln' : fname, arg);
      }
      // bare identifiers / constants
      if (id == 'pi') return VarEx('pi');
      if (id == 'e') return VarEx('e');
      if (RegExp(r'^[a-z]$').hasMatch(id)) return VarEx(id);
      return null; // unknown multi-letter identifier
    }
    return null;
  }

  Ex? _parseNumber() {
    var j = _pos;
    while (j < _src.length &&
        ((_src.codeUnitAt(j) >= '0'.codeUnitAt(0) &&
                _src.codeUnitAt(j) <= '9'.codeUnitAt(0)) ||
            _src[j] == '.')) {
      j++;
    }
    final s = _src.substring(_pos, j);
    _pos = j;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;
    if (s.contains('.')) {
      final parts = s.split('.');
      final whole = parts[0];
      final frac = parts[1];
      if (frac.isEmpty) return NumEx(Q.fromInt(int.parse(whole)));
      final d = int.parse('1${'0' * frac.length}');
      final nNum = int.parse(whole) * d + int.parse(frac);
      return NumEx(Q(nNum, d)._r(nNum, d));
    }
    return NumEx(Q.fromInt(int.parse(s)));
  }
}

// ═══ Diff with rule emission ══════════════════════════════════════════════════

class DerivStep {
  const DerivStep(this.title, this.latex, this.explanation, {this.rule});
  final String title;
  final String latex;
  final String explanation;
  final String? rule;
}

class DerivResult {
  const DerivResult(
    this.steps,
    this.resultLatex,
    this.resultReadable, {
    required this.input,
  });
  final List<SolutionStep> steps;
  final String resultLatex;
  final String resultReadable;
  final String input;
}

/// Facade for the pattern solver.
class SymbolicEngine {
  const SymbolicEngine._();

  /// Differentiate [expr] with respect to [v].  Null when the expression is
  /// outside the engine's grammar.
  static DerivResult? differentiate(String expr, {String v = 'x'}) {
    final p = _Parser(expr.toLowerCase().replaceAll('e^(', 'exp('));
    final f = p.run()?.canonical();
    if (f == null) return null;

    final steps = <SolutionStep>[
      SolutionStep(
        title: 'Differentiate',
        latex: _dd(f),
        explanation: 'Apply the standard rules to $expr with respect to $v.',
      ),
    ];

    final Ex d;
    try {
      d = _diff(f, v, steps);
    } on _UnsupportedError {
      return null;
    }
    final result = d.canonical();

    steps.add(
      SolutionStep(
        title: 'Result',
        latex:
            '${_dd(f)} = ${_clean(result.toLatex())}',
        explanation:
            'Closed form after applying every rule above.',
        rule: 'Derivative',
      ),
    );

    return DerivResult(
      steps,
      _clean(result.toLatex()),
      result.toReadable(),

      input: expr,
    );
  }

  static String _clean(String s) => s
      .replaceAll('\\cdot ', '\\cdot ')
      .replaceAll(r'\ ', ' ');
}

/// The engine parsed the expression but the differentiation rules do not cover
/// it (e.g. arcsin).  Thrown out of [_diff] and turned into a null result.
class _UnsupportedError implements Exception {
  const _UnsupportedError();
}

/// Differentiate [f] wrt [v], appending rule cards to [steps].
Ex _diff(Ex f, String v, List<SolutionStep> steps) {
  switch (f) {
    case NumEx():
      steps.add(_step(
        'Constant Rule',
        '${_dd(f)} = 0',
        'The derivative of a constant is zero.',
        'Constant Rule',
      ));
      return NumEx(Q.fromInt(0));

    case VarEx(name: final n):
      if (n == v) {
        steps.add(_step(
          'Power Rule',
          '${_dd(f)} = 1',
          'A plain variable is x¹: derivative is 1.',
          'Power Rule',
        ));
        return NumEx(Q.fromInt(1));
      }
      steps.add(_step(
        'Constant Rule',
        '${_dd(f)} = 0',
        'Any letter other than $v is treated as a constant here.',
        'Constant Rule',
      ));
      return NumEx(Q.fromInt(0));

    case AddEx():
      final parts = <String>[];
      for (final t in f.terms) {
        parts.add(_dd(t));
      }
      steps.add(_step(
        'Sum Rule',
        '${_dd(f)} = ${parts.join(' + ')}',
        'Differentiate each term separately, then add the results.',
        'Sum Rule',
      ));
      final diffed = f.terms.map((t) => _diff(t, v, steps)).toList();
      return AddEx(diffed);

    case MulEx():
      final neg = f.factors.whereType<PowEx>().where((p) => p.exp < 0).toList();
      if (neg.isNotEmpty) {
        // Quotient rule: write the product as N·D^{−k} = N/D^k, then apply
        // (N'D − N·D')/D².  D is rebuilt with *positive* exponents so the
        // denominator stays the "low" the rule is named after.
        final aList = f.factors
            .where((x) => !(x is PowEx && x.exp < 0))
            .toList();
        final aEx = (aList.length == 1 ? aList[0] : MulEx(aList)).canonical();
        final bEx = (neg.length == 1
                ? PowEx(neg[0].base, -neg[0].exp)
                : MulEx(neg.map((p) => PowEx(p.base, -p.exp)).toList()))
            .canonical();
        final aKey = aEx.toLatex();
        final bKey = bEx.toLatex();
        steps.add(_step(
          'Quotient Rule',
          '${_dd(f)} = \\frac{${_dd(aEx)}\\cdot $bKey - $aKey\\cdot ${_dd(bEx)}}{${_powBase(bEx)}^{2}}',
          'Low d-high minus high d-low, over low squared; divide first, then subtract.',
          'Quotient Rule',
        ));
        final da = _diff(aEx, v, steps);
        final db = _diff(bEx, v, steps);
        final inv2 = PowEx(bEx, -2);
        final term1 = MulEx([da, bEx, inv2]).canonical();
        final term2 = MulEx([aEx, db, inv2]).canonical();
        return AddEx([term1, term2.negate()]).canonical();
      }
      // product rule
      final names = f.factors.map((x) => x.toLatex()).toList();
      final parts = <String>[];
      for (var i = 0; i < f.factors.length; i++) {
        final prod = <String>[];
        for (var j = 0; j < f.factors.length; j++) {
          prod.add(i == j ? _dd(f.factors[j]) : names[j]);
        }
        parts.add(prod.join('\\cdot '));
      }
      steps.add(_step(
        'Product Rule',
        '${_dd(f)} = ${parts.join(' + ')}',
        'Derivative of first times second, plus first times derivative of '
            'second (extended to all factors).',
        'Product Rule',
      ));
      final diffed = f.factors.map((t) => _diff(t, v, steps)).toList();
      final out = <Ex>[];
      for (var i = 0; i < diffed.length; i++) {
        final prod = <Ex>[];
        for (var j = 0; j < diffed.length; j++) {
          prod.add(i == j ? diffed[j] : f.factors[j]);
        }
        out.add(MulEx(prod));
      }
      return AddEx(out).canonical();

    case PowEx():
      final b = f.base;
      final n = f.exp;
      final stepLatex = (b is VarEx && b.name == v)
          ? '${_dd(f)} = $n\\cdot ${_pow(b, n - 1)}'
          : '${_dd(f)} = $n\\cdot ${_pow(b, n - 1)}\\cdot ${_dd(b)}';
      steps.add(_step(
        'Power Rule',
        stepLatex,
        (b is VarEx && b.name == v)
            ? 'Bring the exponent down and subtract one.'
            : 'Bring the exponent down, subtract one, and apply the chain rule '
                'to the base.',
        'Power Rule',
      ));
      if (b is VarEx && b.name == v) {
        return MulEx([NumEx(Q.fromInt(n)), PowEx(b, n - 1)]).canonical();
      }
      final db = _diff(b, v, steps);
      return MulEx([NumEx(Q.fromInt(n)), PowEx(b, n - 1), db]).canonical();

    case FnEx():
      final a = f.arg;
      final da = _diff(a, v, steps);
      final isChain = !(a is VarEx && a.name == v);
      switch (f.name) {
        case 'sin':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Trigonometric Rule',
            '${_dd(f)} = ${_fn('cos', a)}\\cdot ${_dd(a)}',
            'The derivative of sin(u) is cos(u), times the derivative of u.',
            'Trig Derivative',
          ));
          return MulEx([FnEx('cos', a), da]).canonical();
        case 'cos':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Trigonometric Rule',
            '${_dd(f)} = -${_fn('sin', a)}\\cdot ${_dd(a)}',
            'The derivative of cos(u) is −sin(u), times the derivative of u.',
            'Trig Derivative',
          ));
          return MulEx([NumEx(Q.fromInt(-1)), FnEx('sin', a), da]).canonical();
        case 'tan':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Trigonometric Rule',
            '${_dd(f)} = sec^{2}(${a.toLatex()})\\cdot ${_dd(a)}',
            'tan derives to sec², which you can also write 1 + tan².',
            'Trig Derivative',
          ));
          return MulEx([PowEx(FnEx('sec', a), 2), da]).canonical();
        case 'cot':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Trigonometric Rule',
            '${_dd(f)} = -csc^{2}(${a.toLatex()})\\cdot ${_dd(a)}',
            'cot derives to −csc².',
            'Trig Derivative',
          ));
          return MulEx([NumEx(Q.fromInt(-1)), PowEx(FnEx('csc', a), 2), da])
              .canonical();
        case 'sec':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Trigonometric Rule',
            '${_dd(f)} = $a.toLatex()\\cdot \\tan(${a.toLatex()})\\cdot ${_dd(a)}',
            'sec derives to sec·tan.',
            'Trig Derivative',
          ));
          return MulEx([FnEx('sec', a), FnEx('tan', a), da]).canonical();
        case 'csc':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Trigonometric Rule',
            '${_dd(f)} = -csc(${a.toLatex()})\\cdot \\cot(${a.toLatex()})\\cdot ${_dd(a)}',
            'csc derives to −csc·cot.',
            'Trig Derivative',
          ));
          return MulEx([
            NumEx(Q.fromInt(-1)),
            FnEx('csc', a),
            FnEx('cot', a),
            da,
          ]).canonical();
        case 'arcsin':
        case 'arccos':
        case 'arctan':
          break;
        case 'exp':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Exponential Rule',
            '${_dd(f)} = ${_eTo(a.toLatex())}\\cdot ${_dd(a)}',
            'e to the power of u derives to itself, times the derivative of u.',
            'Exp Derivative',
          ));
          return MulEx([FnEx('exp', a), da]).canonical();
        case 'ln':
          steps.add(_step(
            isChain ? 'Chain Rule' : 'Logarithmic Rule',
            '${_dd(f)} = \\frac{${_dd(a)}}{$a.toLatex()}',
            'ln(u) derives to u′/u.',
            'Log Derivative',
          ));
          return MulEx([da, PowEx(a, -1)]).canonical();
      }
      throw const _UnsupportedError();
  }
}

String _pow(Ex b, int e) => PowEx(b, e).canonical().toLatex();

String _dd(Ex e) {
  final body = e.canonical().toLatex();
  return '\\frac{d}{dx}\\left[$body\\right]';
}

String _fn(String name, Ex a) => FnEx(name, a).toLatex();

String _eTo(String arg) => 'e^{$arg}';

String _powBase(Ex e) => '\\left(${e.toLatex()}\\right)';

SolutionStep _step(String title, String latex, String explanation,
        [String? rule]) =>
    SolutionStep(
      title: title,
      latex: latex,
      explanation: explanation,
      rule: rule,
    );