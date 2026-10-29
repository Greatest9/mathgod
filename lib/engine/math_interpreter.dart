// lib/engine/math_interpreter.dart
//
// Offline "natural input" interpreter for Math God.
//
// Turns what a person actually types — words, symbols, shorthand, even
// slightly misspelled commands — into the canonical command syntax that
// SolverEngine understands:
//
//   "differentiate x squared times sin x"  →  d/dx[x^2*sin(x)]
//   "integral of 2x from 0 to pi"          →  int(2*x,0,pi)
//   "limit as x approaches 0 of sin x / x" →  lim(sin(x)/x,x,0)
//   "solve 2x + 3 = 7"                     →  solve(2*x+3=7)
//   "x+y=3 and x-y=1"                      →  solve([x+y=3,x-y=1],[x,y])
//   "determinant of 1 2; 3 4"              →  det([[1,2],[3,4]])
//   "20% of 50"                            →  (20/100)*50
//
// Pure Dart. No network, no ML model, no platform channels.
// Input that is already canonical (e.g. "d/dx[x^3]") passes through untouched.

/// Result of interpreting a raw string.
class InterpretedInput {
  /// Exactly what the user typed (trimmed).
  final String original;

  /// Canonical command for [SolverEngine]. Equals [original] when nothing
  /// could (or needed to) be translated.
  final String command;

  /// Short machine label: 'derivative', 'integral', 'solve', 'passthrough' …
  final String intent;

  /// Human-readable description, e.g. "Derivative of x^2 with respect to x".
  final String summary;

  /// 0.0 – 1.0. Below ~0.4 the input was not understood.
  final double confidence;

  /// True when the user asked for a decimal / numeric answer in words.
  final bool approximate;

  /// Assumptions or limitations worth showing the user.
  final List<String> notes;

  const InterpretedInput({
    required this.original,
    required this.command,
    required this.intent,
    required this.summary,
    required this.confidence,
    this.approximate = false,
    this.notes = const [],
  });

  bool get changed => command.trim() != original.trim();
  bool get understood => confidence >= 0.4;

  @override
  String toString() => 'InterpretedInput($intent: $command)';
}

class MathInterpreter {
  MathInterpreter._();
  static final MathInterpreter instance = MathInterpreter._();

  // ═══ PUBLIC API ══════════════════════════════════════════════════════════

  InterpretedInput interpret(String raw) {
    final original = raw.trim();
    if (original.isEmpty) {
      return _pass(original, 'empty', 'Nothing to interpret', 0);
    }
    if (_looksCanonical(original)) {
      return _pass(original, 'passthrough', 'Already in Math God syntax', 1);
    }
    try {
      final r = _run(original);
      if (r != null) return r;
    } catch (_) {
      // fall through to unchanged
    }
    return _pass(
      original,
      'unknown',
      'Could not interpret this input',
      0.2,
      notes: const ['Try rephrasing, e.g. "derivative of x^2 sin x".'],
    );
  }

  // ═══ CORE PIPELINE ═══════════════════════════════════════════════════════

  InterpretedInput? _run(String original) {
    final notes = <String>[];
    var t = _stage0(original);

    // "as a decimal", "numerically", "to 5 decimal places" → approximate flag
    var approximate = false;
    final approxRe = RegExp(
      r'\b(?:as\s+a\s+decimal|in\s+decimal(?:\s+form)?|decimal(?:\s+approximation)?|'
      r'numerically|approximately|approximate|approx|to\s+\d+\s+(?:decimal\s+places|d\.?p\.?|significant\s+figures))\b',
    );
    if (approxRe.hasMatch(t)) {
      approximate = true;
      t = t.replaceAll(approxRe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    t = _fixTypos(t);

    // ── ODEs are recognised by content, not keyword ─────────────────────────
    if (RegExp(r"y\s*'|\bdy\s*/\s*dx\b|\bd\^?2\s*y\b|differential equation|\bode\b")
        .hasMatch(t)) {
      final r = _ode(t, original, notes);
      if (r != null) return _withApprox(r, approximate);
    }

    // ── Number-first forms (5!, 17 mod 5, 5 choose 2, "is 97 prime") ───────
    final special = _numberForms(t, original, notes);
    if (special != null) return _withApprox(special, approximate);

    // ── Keyword intents: earliest keyword wins ──────────────────────────────
    _Hit? best;
    for (final intent in _intents) {
      final m = intent.re.firstMatch(t);
      if (m == null) continue;
      if (best == null || m.start < best.match.start) {
        best = _Hit(intent.name, m);
      }
    }

    InterpretedInput? result;
    if (best != null) {
      result = _dispatch(best, t, original, notes);
    }
    result ??= _bare(t, original, notes);
    if (result == null) return null;
    return _withApprox(result, approximate);
  }

  InterpretedInput _withApprox(InterpretedInput r, bool approx) {
    if (!approx || r.approximate) return r;
    return InterpretedInput(
      original: r.original,
      command: r.command,
      intent: r.intent,
      summary: r.summary,
      confidence: r.confidence,
      approximate: true,
      notes: r.notes,
    );
  }

  InterpretedInput _pass(
    String original,
    String intent,
    String summary,
    double confidence, {
    List<String> notes = const [],
  }) => InterpretedInput(
    original: original,
    command: original,
    intent: intent,
    summary: summary,
    confidence: confidence,
    notes: notes,
  );

  InterpretedInput _ok(
    String original,
    String command,
    String intent,
    String summary,
    List<String> notes, {
    double confidence = 0.9,
  }) => InterpretedInput(
    original: original,
    command: command,
    intent: intent,
    summary: summary,
    confidence: confidence,
    notes: List.unmodifiable(notes),
  );

  // ═══ CANONICAL PASS-THROUGH ══════════════════════════════════════════════

  static final RegExp _canonicalHead = RegExp(
    r'^(?:d/d[xyt]\s*[\[(]|(?:diff|derivative|int|integrate|antideriv|lim|limit|'
    r'det|determinant|inv|inverse|eigen|eig|eigenvalue|laplace|ilaplace|invlaplace|'
    r'solve|taylor|maclaurin|series|sum|sequence|ode|mean|median|variance|stddev|'
    r'binomial|normal|poisson|combination|permutation|comb|perm|isprime|gcd|lcm|mod|irem|'
    r'factor|factorize|factorial|prime_factors|complex|modulus|conjugate|curl|div|gradient|grad|'
    r'laplacian|dot|cross|partial|pd|dblint|doubleint|tripleint|line_int|lineint|newton|'
    r'newtonraphson|euler|rk4|runge|fourier_series|fseries|simplify|expand|group|ring|'
    r'field|topology|compact|connected|sin|cos|tan|cot|sec|csc|arcsin|arccos|arctan)\s*\()',
    caseSensitive: false,
  );

  /// True when [s] is a single canonical call such as `int(x^2, 0, 1)` whose
  /// first bracket closes at the very end of the string.
  bool _looksCanonical(String s) {
    final m = _canonicalHead.firstMatch(s);
    if (m == null) return false;
    final open = s.indexOf(RegExp(r'[\[(]'), 0);
    if (open < 0) return false;
    var depth = 0;
    for (var i = open; i < s.length; i++) {
      final c = s[i];
      if (c == '(' || c == '[') depth++;
      if (c == ')' || c == ']') {
        depth--;
        if (depth == 0) return s.substring(i + 1).trim().isEmpty;
      }
    }
    return false;
  }

  // ═══ STAGE 0: NORMALISE ══════════════════════════════════════════════════

  static const Map<String, String> _unicode = {
    '×': '*',
    '·': '*',
    '⋅': '*',
    '÷': '/',
    '−': '-',
    '–': '-',
    '—': '-',
    '²': '^2',
    '³': '^3',
    '⁴': '^4',
    'ⁿ': '^n',
    '√': ' sqrt ',
    'π': ' pi ',
    '∞': ' inf ',
    '∫': ' integral of ',
    '∑': ' sum of ',
    '→': '->',
    '⟶': '->',
    '≤': '<=',
    '≥': '>=',
    '≠': '!=',
    '′': "'",
    '’': "'",
    '‘': "'",
    '“': '"',
    '”': '"',
    'θ': ' theta ',
    'λ': ' lambda ',
    '°': ' degrees ',
    '½': '(1/2)',
    '¼': '(1/4)',
    '¾': '(3/4)',
    '⅓': '(1/3)',
  };

  static final RegExp _leadFiller = RegExp(
    r"^(?:please|pls|hey|hi|hello|ok|okay|kindly|can you|could you|would you|will you|"
    r"i want you to|i want to|i would like you to|i would like to|i need you to|i need to|"
    r"i need|help me|help|tell me|show me|give me|let's|lets|how (?:do|can|would|should) (?:i|you|we)|"
    r"how to|what's|whats|what is|what are|what do you get (?:if|when) you|what does|"
    r"calculate|compute|evaluate|determine|work out|figure out|find out|find|the|a|an)\b[\s,:]*",
  );

  static final RegExp _trailFiller = RegExp(
    r'[\s,]*\b(?:please|pls|for me|thanks|thank you|thx)\b[\s.!]*$',
  );

  String _stage0(String raw) {
    var s = raw.trim().toLowerCase();
    _unicode.forEach((k, v) => s = s.replaceAll(k, v));

    // ∫_0^1 x^2 dx   →   integral from 0 to 1 of x^2 dx
    s = s.replaceAllMapped(
      RegExp(
        r'(?:integral of|integral|int)\s*_\s*\{?\(?([^\s^{}()]+)\)?\}?\s*\^\s*\{?\(?([^\s{}()]+)\)?\}?\s*',
      ),
      (m) => ' integral from ${m[1]} to ${m[2]} of ',
    );

    s = s.replaceAll('**', '^');
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    // strip leading/trailing chatter repeatedly
    var prev = '';
    while (prev != s) {
      prev = s;
      s = s.replaceFirst(_leadFiller, '');
      s = s.replaceFirst(_trailFiller, '');
    }
    s = s.replaceAll(RegExp(r'[?.;:,\s]+$'), '').trim();

    // percent: "20% of 50" / "15 percent of 80"
    s = s.replaceAllMapped(
      RegExp(
        r'(\d+(?:\.\d+)?)\s*(?:%|percent|per cent)\s+of\s+([\d.]+|\([^()]*\))',
      ),
      (m) => '(${m[1]}/100)*${m[2]}',
    );
    return s;
  }

  // ═══ TYPO TOLERANCE (edit distance, offline) ═════════════════════════════

  static const List<String> _vocab = [
    'derivative', 'differentiate', 'differentiation', 'integral', 'integrate',
    'integration', 'antiderivative', 'limit', 'approaches', 'factorise',
    'factorize', 'factoring', 'factorization', 'factorisation', 'expand',
    'simplify', 'simplification', 'determinant', 'inverse', 'eigenvalue',
    'eigenvalues', 'eigenvector', 'eigenvectors', 'transpose', 'laplace',
    'taylor', 'maclaurin', 'solution', 'solutions', 'equation', 'equations',
    'matrix', 'average', 'median', 'variance', 'deviation', 'standard',
    'factorial', 'squared', 'cubed', 'divided', 'multiplied', 'between',
    'respect', 'infinity', 'permutation', 'permutations', 'combination',
    'combinations', 'logarithm', 'summation', 'solve', 'prime', 'series',
    'degrees', 'trace', 'rank',
  ];

  static const Set<String> _knownWords = {
    'integer', 'integers', 'interval', 'intervals', 'derive', 'derived', 'differential', 'difference',
    'differences', 'different', 'solving', 'solved', 'solves', 'solver', 'expanding', 'expanded',
    'simplified', 'simplifying', 'equal', 'equals', 'equality', 'limits', 'limited', 'matrices',
    'primes', 'radical', 'rational', 'general', 'generally', 'several', 'together', 'function',
    'functions', 'respect', 'natural', 'sine', 'cosine', 'tangent', 'secant', 'cosecant',
    'cotangent', 'power', 'square', 'cube', 'root', 'roots', 'greatest', 'common',
    'divisor', 'multiple', 'least', 'lowest', 'highest', 'absolute', 'value', 'negative',
    'positive', 'tends', 'tending', 'going', 'goes', 'times', 'minus', 'plus',
    'over', 'from', 'with', 'where', 'such', 'following', 'polynomial', 'expression',
    'numbers', 'number', 'values', 'data', 'list', 'mean', 'modulo', 'remainder',
    'choose', 'raised', 'decimal', 'numerically', 'approximately', 'approximate', 'exponential', 'arcsine',
    'arccosine', 'arctangent', 'definite', 'indefinite', 'partial', 'second', 'third', 'fourth',
    'fifth', 'first', 'order', 'terms', 'about', 'around', 'right', 'left',
    'hand', 'sided', 'right-hand', 'left-hand', 'theta', 'lambda', 'zeros', 'zero',
    'sqrt', 'floor', 'ceil', 'sinh', 'cosh', 'tanh', 'arcsin', 'arccos',
    'arctan', 'which', 'there', 'their', 'these', 'those', 'when', 'what',
    'then', 'that', 'this', 'than', 'into', 'slope', 'change', 'rate',
    'primitive', 'gcd', 'lcm',
  };

  String _fixTypos(String s) {
    return s.replaceAllMapped(RegExp(r'[a-z]{5,}'), (m) {
      final w = m[0]!;
      if (_vocab.contains(w) || _knownWords.contains(w)) return w;
      final maxD = w.length >= 10 ? 2 : 1;
      String? best;
      var bestD = maxD + 1;
      for (final v in _vocab) {
        if ((v.length - w.length).abs() > maxD) continue;
        final d = _editDistance(w, v);
        if (d < bestD) {
          bestD = d;
          best = v;
        }
      }
      return (best != null && bestD <= maxD) ? best : w;
    });
  }

  int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = prev[j] + 1;
        if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
        if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
        cur[j] = v;
      }
      prev = cur;
    }
    return prev[b.length];
  }

  // ═══ INTENT TABLE ════════════════════════════════════════════════════════

  static final List<_Intent> _intents = [
    _Intent(
      'ilaplace',
      RegExp(
        r'\b(?:inverse\s+laplace(?:\s+transform)?|laplace\s+inverse|ilaplace|invlaplace)\b',
      ),
    ),
    _Intent('laplace', RegExp(r'\blaplace(?:\s+transform)?\b')),
    _Intent(
      'maclaurin',
      RegExp(r'\bmaclaurin(?:\s+(?:series|expansion|polynomial))?\b'),
    ),
    _Intent(
      'taylor',
      RegExp(r'\btaylor(?:\s+(?:series|expansion|polynomial))?\b'),
    ),
    _Intent('limit', RegExp(r'\b(?:limit|lim)\b')),
    _Intent(
      'derivative',
      RegExp(
        r"\b(?:(?:first|second|third|fourth|fifth|\d+(?:st|nd|rd|th))\s+)?"
        r"(?:partial\s+)?(?:derivative|differentiat(?:e|ion))\b"
        r"|\bd\^?\d?\s*/\s*d[a-z]\^?\d?"
        r"|\bslope of\b|\brate of change of\b",
      ),
    ),
    _Intent(
      'integral',
      RegExp(
        r'\b(?:(?:definite|indefinite)\s+)?(?:integral|integrate|integration|antiderivative|anti-derivative|primitive)\b',
      ),
    ),
    _Intent('sum', RegExp(r'\b(?:summation|sum)\b')),
    _Intent('det', RegExp(r'\b(?:determinant|det)\b')),
    _Intent('eigenvectors', RegExp(r'\beigen\s*vectors?\b')),
    _Intent('eigenvalues', RegExp(r'\beigen\s*values?\b|\beigs?\b')),
    _Intent('inv', RegExp(r'\b(?:inverse|invert)\b')),
    _Intent('transpose', RegExp(r'\btranspose\b')),
    _Intent('rank', RegExp(r'\brank\b')),
    _Intent('trace', RegExp(r'\btrace\b')),
    _Intent(
      'gcd',
      RegExp(
        r'\b(?:gcd|hcf|greatest\s+common\s+(?:divisor|factor)|highest\s+common\s+factor)\b',
      ),
    ),
    _Intent(
      'lcm',
      RegExp(
        r'\b(?:lcm|least\s+common\s+multiple|lowest\s+common\s+multiple)\b',
      ),
    ),
    _Intent('solve', RegExp(
        r'\bsolv(?:e|ing)\b|(?<!square )(?<!cube )(?<!nth )\broots?\b|\bzeros\b|\bsolutions?\b',
      )),
    _Intent(
      'factor',
      RegExp(
        r'\bprime\s+factor(?:s|isation|ization)?\b|\bfactor(?:s|ise|ize|ing|isation|ization)?\b',
      ),
    ),
    _Intent('expand', RegExp(r'\b(?:expand|expansion|multiply out|foil)\b')),
    _Intent('simplify', RegExp(r'\b(?:simplif(?:y|ication)|reduce)\b')),
    _Intent('mean', RegExp(r'\b(?:arithmetic mean|mean|average|avg)\b')),
    _Intent('median', RegExp(r'\bmedian\b')),
    _Intent('variance', RegExp(r'\bvariance\b')),
    _Intent(
      'stddev',
      RegExp(r'\b(?:standard\s+deviation|std\s?dev|stdev|stddev)\b'),
    ),
  ];

  InterpretedInput? _dispatch(
    _Hit hit,
    String t,
    String original,
    List<String> notes,
  ) {
    final m = hit.match;
    final rest = t.substring(m.end);
    final pre = t.substring(0, m.start);
    switch (hit.name) {
      case 'derivative':
        return _derivative(m, rest, pre, original, notes);
      case 'integral':
        return _integral(rest, pre, original, notes);
      case 'limit':
        return _limit(rest, pre, original, notes);
      case 'solve':
        return _solve(rest, pre, original, notes);
      case 'factor':
        return _factor(rest, pre, original, notes);
      case 'expand':
        return _unary('expand', 'Expand', rest, pre, original, notes);
      case 'simplify':
        return _unary('simplify', 'Simplify', rest, pre, original, notes);
      case 'laplace':
        return _transform('laplace', 'Laplace transform', rest, pre, original, notes);
      case 'ilaplace':
        return _transform('ilaplace', 'Inverse Laplace transform', rest, pre, original, notes);
      case 'taylor':
        return _series(false, rest, pre, original, notes);
      case 'maclaurin':
        return _series(true, rest, pre, original, notes);
      case 'sum':
        return _summation(rest, pre, original, notes);
      case 'det':
        return _matrixOp('det', 'Determinant', rest, pre, original, notes);
      case 'inv':
        return _matrixOp('inv', 'Inverse', rest, pre, original, notes);
      case 'eigenvalues':
        return _matrixOp('eigen', 'Eigenvalues', rest, pre, original, notes);
      case 'eigenvectors':
        notes.add('Eigenvectors are computed by the CAS engine only.');
        return _matrixOp('eigenvectors', 'Eigenvectors', rest, pre, original, notes);
      case 'transpose':
        return _matrixOp('transpose', 'Transpose', rest, pre, original, notes);
      case 'rank':
        return _matrixOp('rank', 'Rank', rest, pre, original, notes);
      case 'trace':
        return _matrixOp('trace', 'Trace', rest, pre, original, notes);
      case 'gcd':
        return _gcdLcm('gcd', 'Greatest common divisor', rest, pre, original, notes);
      case 'lcm':
        return _gcdLcm('lcm', 'Least common multiple', rest, pre, original, notes);
      case 'mean':
        return _stats('mean', 'Mean', rest, pre, original, notes);
      case 'median':
        return _stats('median', 'Median', rest, pre, original, notes);
      case 'variance':
        return _stats('variance', 'Variance', rest, pre, original, notes);
      case 'stddev':
        return _stats('stddev', 'Standard deviation', rest, pre, original, notes);
    }
    return null;
  }

  // ═══ BARE INPUT (no keyword) ═════════════════════════════════════════════

  InterpretedInput? _bare(String t, String original, List<String> notes) {
    final hasRel = RegExp(r'(?:<=|>=|!=|<|>|(?<![<>!=])=(?!=))').hasMatch(t) ||
        RegExp(r'\b(?:equals|is equal to|equal to|less than|greater than)\b').hasMatch(t);
    final cleaned = _cleanExpr(t, keepRel: true);
    if (cleaned.isEmpty) return null;
    if (_hasUnknownWords(cleaned)) return null;
    if (hasRel) {
      final parts = _splitTopLevel(t)
          .map((e) => _cleanExpr(e, keepRel: true))
          .where((e) => e.isNotEmpty)
          .toList();
      return _buildSolve(
        parts.isEmpty ? [cleaned] : parts,
        null,
        original,
        notes,
        implicit: true,
      );
    }
    final changed = cleaned != original.replaceAll(' ', '');
    return _ok(
      original,
      cleaned,
      'expression',
      'Evaluate / simplify $cleaned',
      notes,
      confidence: changed ? 0.7 : 0.8,
    );
  }

  // ═══ DERIVATIVE ══════════════════════════════════════════════════════════

  static const Map<String, int> _ordinals = {
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
  };

  InterpretedInput? _derivative(
    Match m,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final head = m[0]!;
    var order = 1;
    var variable = '';
    final ord = RegExp(r'^(first|second|third|fourth|fifth|(\d+)(?:st|nd|rd|th))\b')
        .firstMatch(head);
    if (ord != null) {
      order = _ordinals[ord[1]] ?? int.tryParse(ord[2] ?? '') ?? 1;
    }
    final dd = RegExp(r'^d\^?(\d)?\s*/\s*d([a-z])').firstMatch(head);
    if (dd != null) {
      if (dd[1] != null) order = int.parse(dd[1]!);
      variable = dd[2]!;
    }
    var partial = head.contains('partial');

    final p = _payload(rest, pre);
    var body = p.body;
    final wrt = _takeVariable(body);
    if (wrt != null) {
      variable = wrt.variable;
      body = wrt.rest;
    }
    // "second derivative of ..." may carry the order in the text itself
    final twice = RegExp(r'\b(twice|two times|thrice)\b').firstMatch(body);
    if (twice != null) {
      order = twice[1] == 'thrice' ? 3 : 2;
      body = body.replaceFirst(twice[0]!, ' ');
    }
    // "… at x = 3"  → evaluate the derivative at that point
    String? atVar, atVal;
    final at = RegExp(r'\b(?:at|when|where)\s+([a-z])\s*=\s*(\S+)\s*$').firstMatch(body);
    if (at != null) {
      atVar = at[1];
      atVal = _cleanBound(at[2]!);
      body = body.substring(0, at.start);
    }
    var expr = _cleanExpr(body);
    if (expr.isEmpty) return null;
    final vars = _varsOf(expr);

    if (variable.isEmpty) {
      variable = vars.contains('x')
          ? 'x'
          : (vars.contains('t') ? 't' : (vars.length == 1 ? vars.first : 'x'));
    }

    String cmd;
    if (order == 1 && (variable == 'x' || variable == 't')) {
      cmd = 'd/d$variable[$expr]';
    } else if (order == 1 && variable == 'y' && partial) {
      cmd = 'd/dy[$expr]';
    } else {
      // Rename a lone variable to x so the step-by-step engine can follow along.
      if (order == 1 && vars.length == 1 && vars.contains(variable)) {
        expr = _renameVar(expr, variable, 'x');
        notes.add('Treated $variable as x.');
        cmd = 'd/dx[$expr]';
        variable = 'x';
      } else {
        cmd = order == 1 ? 'diff($expr,$variable)' : 'diff($expr,$variable,$order)';
      }
    }
    if (atVar != null && atVal != null && atVal.isNotEmpty) {
      final inner = cmd.startsWith('d/d')
          ? 'diff($expr,$variable)'
          : cmd;
      return _ok(
        original,
        'subst($inner,$atVar=$atVal)',
        'derivative',
        'Derivative of $expr with respect to $variable, evaluated at $atVar = $atVal',
        [...notes, 'Evaluating at a point is done by the CAS engine.'],
      );
    }
    final ordTxt = order == 1 ? '' : '${_ordText(order)} ';
    return _ok(
      original,
      cmd,
      'derivative',
      '${_cap(ordTxt)}${ordTxt.isEmpty ? 'Derivative' : 'derivative'} of $expr with respect to $variable',
      notes,
    );
  }

  String _ordText(int n) => switch (n) {
        2 => 'second',
        3 => 'third',
        4 => 'fourth',
        5 => 'fifth',
        _ => '${n}th',
      };

  // ═══ INTEGRAL ════════════════════════════════════════════════════════════

  InterpretedInput? _integral(
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final p = _payload(rest, pre);
    var body = p.body;
    String? lo, hi;

    final fromTo = RegExp(r'\bfrom\s+(.+?)\s+to\s+(.+?)(?:\s+of\s+|\s*$)').firstMatch(body);
    final between = RegExp(r'\bbetween\s+(.+?)\s+and\s+(.+?)(?:\s+of\s+|\s*$)').firstMatch(body);
    final over = RegExp(r'\b(?:over|on)\s+(?:the\s+interval\s+)?[\[(]\s*([^,\])]+?)\s*,\s*([^\])]+?)\s*[\])]').firstMatch(body);
    final bm = fromTo ?? between ?? over;
    if (bm != null) {
      lo = bm[1]!;
      hi = bm[2]!;
      body = body.replaceRange(bm.start, bm.end, ' ');
    }

    var variable = '';
    final dv = RegExp(r'(?:^|(?<=[\s)\d]))d([a-z])\s*$').firstMatch(body.trim());
    if (dv != null) {
      variable = dv[1]!;
      body = body.trim().substring(0, dv.start);
    }
    final wrt = _takeVariable(body);
    if (wrt != null) {
      if (variable.isEmpty) variable = wrt.variable;
      body = wrt.rest;
    }
    // stray "dx" before the bounds ("x^2 dx from 0 to 1" was handled above)
    final mid = RegExp(r'(?<=[\s)\d])d([a-z])\b').firstMatch(body);
    if (mid != null && variable.isEmpty) {
      variable = mid[1]!;
      body = body.replaceRange(mid.start, mid.end, ' ');
    }

    var expr = _cleanExpr(body);
    if (expr.isEmpty) return null;
    final vars = _varsOf(expr);
    if (variable.isEmpty) {
      variable = vars.contains('x')
          ? 'x'
          : (vars.length == 1 ? vars.first : 'x');
    }

    String? a, b;
    if (lo != null && hi != null) {
      a = _cleanBound(lo);
      b = _cleanBound(hi);
    }

    String cmd;
    if (variable != 'x' && vars.length == 1 && vars.contains(variable)) {
      expr = _renameVar(expr, variable, 'x');
      if (a != null) {
        a = _renameVar(a, variable, 'x');
        b = _renameVar(b!, variable, 'x');
      }
      notes.add('Treated $variable as x.');
      variable = 'x';
    }
    if (variable == 'x') {
      cmd = a == null ? 'int($expr)' : 'int($expr,$a,$b)';
    } else {
      cmd = a == null ? 'int($expr,$variable)' : 'int($expr,$variable,$a,$b)';
    }
    final summary = a == null
        ? 'Indefinite integral of $expr d$variable'
        : 'Definite integral of $expr d$variable from $a to $b';
    return _ok(original, cmd, 'integral', summary, notes);
  }

  // ═══ LIMIT ═══════════════════════════════════════════════════════════════

  static const String _arrow =
      r'(?:->|=>|approaches|approaching|tends\s+to|tending\s+to|goes\s+to|going\s+to|to)';

  InterpretedInput? _limit(
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    var s = '$pre $rest'.trim();
    s = s.replaceFirst(RegExp(r'^(?:of|for|the)\s+'), '');

    if (RegExp(r'\b(?:from\s+(?:the\s+)?(?:left|right)|(?:left|right)[\s-]*hand(?:ed)?|one[\s-]*sided)\b').hasMatch(s)) {
      notes.add('One-sided limits are evaluated as two-sided limits.');
      s = s.replaceAll(
        RegExp(r'\b(?:from\s+(?:the\s+)?(?:left|right)|(?:left|right)[\s-]*hand(?:ed)?|one[\s-]*sided)\b'),
        ' ',
      );
    }

    String? expr, v, point;

    // A:  "<expr> as x approaches a"
    final a = RegExp(r'^(.+?)\s+as\s+([a-z])\s*' + _arrow + r'\s*(.+)$').firstMatch(s);
    // B:  "as x approaches a of <expr>"
    final b = RegExp(r'^as\s+([a-z])\s*' + _arrow + r'\s*(.+?)\s+(?:of|for|,|:)\s*(.+)$').firstMatch(s);
    // C:  "x -> a  <expr>"   or  "x->a of <expr>"
    final c = RegExp(r'^([a-z])\s*->\s*(\S+)\s+(?:of\s+)?(.+)$').firstMatch(s);
    // D:  "<expr> , x -> a"
    final d = RegExp(r'^(.+?)\s*,?\s*([a-z])\s*->\s*(.+)$').firstMatch(s);

    if (b != null) {
      v = b[1];
      point = b[2];
      expr = b[3];
    } else if (a != null) {
      expr = a[1];
      v = a[2];
      point = a[3];
    } else if (c != null) {
      v = c[1];
      point = c[2];
      expr = c[3];
    } else if (d != null) {
      expr = d[1];
      v = d[2];
      point = d[3];
    } else {
      return null;
    }

    var pt = point!.trim();
    final sided = RegExp(r'^(.*\S)\s*([+-])$').firstMatch(pt);
    if (sided != null && !RegExp(r'(?:inf|infinity)$').hasMatch(pt)) {
      notes.add('One-sided limits are evaluated as two-sided limits.');
      pt = sided[1]!;
    }
    var e = _cleanExpr(expr!);
    var p = _cleanBound(pt);
    var variable = v!;
    if (e.isEmpty || p.isEmpty) return null;

    final vars = _varsOf(e);
    if (variable != 'x' && vars.length == 1 && vars.contains(variable)) {
      e = _renameVar(e, variable, 'x');
      p = _renameVar(p, variable, 'x');
      notes.add('Treated $variable as x.');
      variable = 'x';
    }
    return _ok(
      original,
      'lim($e,$variable,$p)',
      'limit',
      'Limit of $e as $variable → $p',
      notes,
    );
  }

  // ═══ SOLVE ═══════════════════════════════════════════════════════════════

  InterpretedInput? _solve(
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    List<String>? wanted;
    final forRe = RegExp(
      r'\b(?:for|in\s+terms\s+of)\s+([a-z](?:\s*(?:,|and|&)\s*[a-z])*)(?![a-z0-9^*/+\-(])\s*[:,]?',
    );
    var restTxt = rest;
    var preTxt = pre;
    final fm = forRe.firstMatch(restTxt) ?? forRe.firstMatch(preTxt);
    if (fm != null) {
      wanted = RegExp(r'[a-z]').allMatches(fm[1]!).map((e) => e[0]!).toList();
      if (forRe.hasMatch(restTxt)) {
        restTxt = restTxt.replaceFirst(forRe, ' ');
      } else {
        preTxt = preTxt.replaceFirst(forRe, ' ');
      }
    }
    final p = _payload(restTxt, preTxt);
    var body = p.body;
    body = body
        .replaceAll(RegExp(r'\b(?:simultaneous|system of|set of|the equations?|equations?|following|where|such that|if|when|given)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts = _splitTopLevel(body)
        .map((e) => _cleanExpr(e, keepRel: true))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return _buildSolve(parts, wanted, original, notes);
  }

  InterpretedInput? _buildSolve(
    List<String> eqs,
    List<String>? wanted,
    String original,
    List<String> notes, {
    bool implicit = false,
  }) {
    final rel = RegExp(r'<=|>=|!=|<|>|=');
    final fixed = eqs.map((e) => rel.hasMatch(e) ? e : '$e=0').toList();
    final vars = <String>{};
    for (final e in fixed) {
      vars.addAll(_varsOf(e));
    }
    final sorted = vars.toList()..sort();

    if (fixed.length >= 2) {
      final unknowns = (wanted != null && wanted.length >= 2) ? wanted : sorted;
      return _ok(
        original,
        'solve([${fixed.join(',')}],[${unknowns.join(',')}])',
        'solve',
        'Solve the system ${fixed.join(' and ')} for ${unknowns.join(', ')}',
        notes,
      );
    }

    final eq = fixed.first;
    String? v = (wanted != null && wanted.isNotEmpty) ? wanted.first : null;
    if (v == null) {
      if (sorted.length == 1) {
        v = sorted.first;
      } else if (sorted.contains('x')) {
        v = 'x';
      } else if (sorted.isNotEmpty) {
        v = sorted.first;
        notes.add('Solving for ${sorted.first}.');
      }
    }
    final needVar = v != null && !(v == 'x' && sorted.length <= 1);
    final cmd = needVar && !(v == 'x') ? 'solve($eq,$v)' : 'solve($eq)';
    final cmdFinal = (v == 'x' && sorted.length > 1 && wanted != null)
        ? 'solve($eq,$v)'
        : cmd;
    return _ok(
      original,
      cmdFinal,
      'solve',
      'Solve $eq${v == null ? '' : ' for $v'}',
      notes,
      confidence: implicit ? 0.75 : 0.9,
    );
  }

  /// Split on top-level commas, semicolons and the word "and".
  List<String> _splitTopLevel(String s) {
    final out = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
      if (depth == 0) {
        if (c == ',' || c == ';') {
          out.add(buf.toString());
          buf.clear();
          i++;
          continue;
        }
        if (s.startsWith(' and ', i)) {
          out.add(buf.toString());
          buf.clear();
          i += 5;
          continue;
        }
      }
      buf.write(c);
      i++;
    }
    out.add(buf.toString());
    return out.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  // ═══ FACTOR / EXPAND / SIMPLIFY ══════════════════════════════════════════

  InterpretedInput? _factor(
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final p = _payload(rest, pre);
    final expr = _cleanExpr(p.body);
    if (expr.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(expr)) {
      return _ok(original, 'factorize($expr)', 'factor', 'Prime factorization of $expr', notes);
    }
    return _ok(original, 'factor($expr)', 'factor', 'Factor $expr', notes);
  }

  InterpretedInput? _unary(
    String fn,
    String label,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final p = _payload(rest, pre);
    final expr = _cleanExpr(p.body);
    if (expr.isEmpty) return null;
    return _ok(original, '$fn($expr)', fn, '$label $expr', notes);
  }

  // ═══ TRANSFORMS / SERIES ═════════════════════════════════════════════════

  InterpretedInput? _transform(
    String fn,
    String label,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final p = _payload(rest, pre);
    final expr = _cleanExpr(p.body);
    if (expr.isEmpty) return null;
    return _ok(original, '$fn($expr)', fn, '$label of $expr', notes);
  }

  InterpretedInput? _series(
    bool maclaurin,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    var body = _payload(rest, pre).body;

    var n = '5';
    final nm = RegExp(r'\b(?:up\s+to|to|of)?\s*(?:order|degree|n\s*=)\s*(\d+)\b|\b(\d+)\s+terms?\b|\bto\s+(\d+)\s+terms?\b')
        .firstMatch(body);
    if (nm != null) {
      n = nm[1] ?? nm[2] ?? nm[3] ?? n;
      body = body.replaceRange(nm.start, nm.end, ' ');
    }
    var center = '0';
    final cm = RegExp(r'\b(?:about|around|at|centered\s+(?:at|on))\s+(?:[a-z]\s*=\s*)?(-?[\w./]+)').firstMatch(body);
    if (cm != null) {
      center = _cleanBound(cm[1]!);
      body = body.replaceRange(cm.start, cm.end, ' ');
    }
    final expr = _cleanExpr(body);
    if (expr.isEmpty) return null;
    if (maclaurin || center == '0') {
      return _ok(
        original,
        'maclaurin($expr,$n)',
        'maclaurin',
        'Maclaurin series of $expr up to order $n',
        notes,
      );
    }
    return _ok(
      original,
      'taylor($expr,$n,$center)',
      'taylor',
      'Taylor series of $expr about $center up to order $n',
      notes,
    );
  }

  InterpretedInput? _summation(
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final body = _payload(rest, pre).body;
    final m = RegExp(r'^(.+?)\s*(?:for|where|with)?\s*\b([a-z])\s*(?:=|from)\s*(.+?)\s+(?:to|through|upto|up to)\s+(.+)$')
        .firstMatch(body);
    if (m != null) {
      final e = _cleanExpr(m[1]!);
      final v = m[2]!;
      final a = _cleanBound(m[3]!);
      final b = _cleanBound(m[4]!);
      if (e.isNotEmpty) {
        return _ok(original, 'sum($e,$v,$a,$b)', 'sum', 'Sum of $e for $v from $a to $b', notes);
      }
    }
    // "sum of 1, 2, 3, 4"
    final nums = _numbersIn(body);
    if (nums.length >= 2) {
      return _ok(original, nums.join('+'), 'sum', 'Add ${nums.join(', ')}', notes);
    }
    return null;
  }

  // ═══ MATRICES ════════════════════════════════════════════════════════════

  InterpretedInput? _matrixOp(
    String fn,
    String label,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final body = _payload(rest, pre, keepMatrixWord: true).body;
    final mat = _parseMatrix(body, notes);
    if (mat == null) {
      if (fn == 'inv') {
        // maybe "inverse of <scalar expression>" — not supported, leave alone
      }
      return null;
    }
    return _ok(original, '$fn($mat)', fn, '$label of $mat', notes);
  }

  /// Accepts [[1,2],[3,4]], {{1,2},{3,4}}, "1 2; 3 4", "1,2 | 3,4",
  /// "[1 2][3 4]", newline-separated rows, or "2x2 matrix 1 2 3 4".
  String? _parseMatrix(String input, List<String> notes) {
    var s = input.trim();
    s = s.replaceAll('{', '[').replaceAll('}', ']');

    // explicit dimensions + flat list
    final dim = RegExp(r'(\d+)\s*(?:x|by|×)\s*(\d+)\s*(?:matrix)?\s*(?:of|:|=)?\s*').firstMatch(s);
    if (dim != null && !s.contains('[')) {
      final r = int.parse(dim[1]!);
      final c = int.parse(dim[2]!);
      final nums = _numbersIn(s.substring(dim.end));
      if (r * c == nums.length && r > 0 && c > 0) {
        return _joinRows([
          for (var i = 0; i < r; i++) nums.sublist(i * c, (i + 1) * c),
        ]);
      }
      return null;
    }

    s = s.replaceAll(RegExp(r'\bmatrix\b'), ' ').trim();

    // bracketed rows
    final innerRows = RegExp(r'\[([^\[\]]+)\]').allMatches(s).toList();
    if (innerRows.isNotEmpty && s.contains(RegExp(r'\[\s*\[|\]\s*\['))) {
      final rows = innerRows.map((m) => _cells(m[1]!)).toList();
      return _validRows(rows);
    }
    // single bracket pair with ; or | separators: [1 2; 3 4]
    var flat = s;
    if (flat.startsWith('[') && flat.endsWith(']')) {
      flat = flat.substring(1, flat.length - 1);
    }
    if (flat.contains(RegExp(r'[;|\n]'))) {
      final rows = flat
          .split(RegExp(r'[;|\n]'))
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .map(_cells)
          .toList();
      return _validRows(rows);
    }
    // flat list of n² numbers → square matrix
    final nums = _numbersIn(flat);
    if (nums.length >= 4) {
      final n = _isqrt(nums.length);
      if (n * n == nums.length && RegExp(r'^[\s\d.,+\-/a-z]*$').hasMatch(flat)) {
        notes.add('Read the ${nums.length} numbers as a ${n}x$n matrix.');
        return _joinRows([
          for (var i = 0; i < n; i++) nums.sublist(i * n, (i + 1) * n),
        ]);
      }
    }
    return null;
  }

  List<String> _cells(String row) {
    final r = row.trim();
    final parts = r.contains(',') ? r.split(',') : r.split(RegExp(r'\s+'));
    return parts
        .map((c) => _cleanExpr(c))
        .where((c) => c.isNotEmpty)
        .toList();
  }

  String? _validRows(List<List<String>> rows) {
    if (rows.isEmpty) return null;
    final w = rows.first.length;
    if (w == 0 || rows.any((r) => r.length != w)) return null;
    return _joinRows(rows);
  }

  String _joinRows(List<List<String>> rows) =>
      '[${rows.map((r) => '[${r.join(',')}]').join(',')}]';

  int _isqrt(int n) {
    var r = 0;
    while ((r + 1) * (r + 1) <= n) {
      r++;
    }
    return r;
  }

  // ═══ NUMBER THEORY / COMBINATORICS / STATS ═══════════════════════════════

  InterpretedInput? _numberForms(String t, String original, List<String> notes) {
    // factorial
    final f1 = RegExp(r'^(\d+)\s*!$').firstMatch(t) ??
        RegExp(r'^(\d+)\s+factorial$').firstMatch(t) ??
        RegExp(r'^factorial(?:\s+of)?\s+(\d+)$').firstMatch(t);
    if (f1 != null) {
      return _ok(original, 'factorial(${f1[1]})', 'factorial', '${f1[1]}!', notes);
    }

    // mod / remainder
    final md = RegExp(r'^(\d+)\s*(?:mod|modulo)\s*(\d+)$').firstMatch(t) ??
        RegExp(r'^(?:the\s+)?remainder\s+(?:of|when)\s+(\d+)\s+(?:is\s+)?(?:divided\s+by|/|over)\s+(\d+)$')
            .firstMatch(t) ??
        RegExp(r'^(\d+)\s*%\s*(\d+)$').firstMatch(t);
    if (md != null) {
      return _ok(original, 'irem(${md[1]},${md[2]})', 'mod', '${md[1]} mod ${md[2]}', notes);
    }

    // n choose k / nCr / combinations of n and k
    final cr = RegExp(r'^(\d+)\s+choose\s+(\d+)$').firstMatch(t) ??
        RegExp(r'^(\d+)\s*ncr\s*(\d+)$').firstMatch(t) ??
        RegExp(r'^ncr\s*\(?\s*(\d+)\s*,\s*(\d+)\s*\)?$').firstMatch(t) ??
        RegExp(r'^(?:number\s+of\s+)?combinations?\s+(?:of\s+)?(\d+)\s*(?:,|and|choose|taken|things taken|items taken|out of)?\s*(\d+)$')
            .firstMatch(t) ??
        RegExp(r'^binomial\s+coefficient\s+(\d+)\s*(?:,|and|choose)?\s*(\d+)$').firstMatch(t);
    if (cr != null) {
      return _ok(original, 'comb(${cr[1]},${cr[2]})', 'combination', 'C(${cr[1]}, ${cr[2]})', notes);
    }
    final pr = RegExp(r'^(\d+)\s*npr\s*(\d+)$').firstMatch(t) ??
        RegExp(r'^npr\s*\(?\s*(\d+)\s*,\s*(\d+)\s*\)?$').firstMatch(t) ??
        RegExp(r'^(?:number\s+of\s+)?permutations?\s+(?:of\s+)?(\d+)\s*(?:,|and|taken|things taken|items taken|out of)?\s*(\d+)$')
            .firstMatch(t);
    if (pr != null) {
      return _ok(original, 'perm(${pr[1]},${pr[2]})', 'permutation', 'P(${pr[1]}, ${pr[2]})', notes);
    }

    // primality
    final pm = RegExp(r'^(?:is|check if|test if|whether)\s+(\d+)\s+(?:a\s+)?prime(?:\s+number)?$').firstMatch(t) ??
        RegExp(r'^(?:is|check if)\s+(\d+)\s+prime$').firstMatch(t) ??
        RegExp(r'^prime\s*(?:test|check)(?:\s+(?:of|for))?\s+(\d+)$').firstMatch(t) ??
        RegExp(r'^primality(?:\s+(?:of|test))?(?:\s+(?:of|for))?\s+(\d+)$').firstMatch(t);
    if (pm != null) {
      return _ok(original, 'isprime(${pm[1]})', 'isprime', 'Is ${pm[1]} prime?', notes);
    }
    return null;
  }

  InterpretedInput? _gcdLcm(
    String fn,
    String label,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    final nums = _numbersIn(_payload(rest, pre).body);
    if (nums.length < 2) return null;
    var cmd = '$fn(${nums[0]},${nums[1]})';
    for (var i = 2; i < nums.length; i++) {
      cmd = '$fn($cmd,${nums[i]})';
    }
    return _ok(original, cmd, fn, '$label of ${nums.join(', ')}', notes);
  }

  InterpretedInput? _stats(
    String fn,
    String label,
    String rest,
    String pre,
    String original,
    List<String> notes,
  ) {
    var body = _payload(rest, pre).body;
    body = body.replaceAll(RegExp(r'\b(?:data|set|list|numbers?|values?|these|sample|population|dataset)\b'), ' ');
    final br = RegExp(r'\[([^\[\]]+)\]').firstMatch(body);
    final nums = br != null ? _numbersIn(br[1]!) : _numbersIn(body);
    if (nums.isEmpty) return null;
    return _ok(original, '$fn([${nums.join(',')}])', fn, '$label of ${nums.join(', ')}', notes);
  }

  // ═══ ODE ═════════════════════════════════════════════════════════════════

  InterpretedInput? _ode(String t, String original, List<String> notes) {
    var s = t;
    s = s.replaceAll(RegExp(r'\bd\^?2\s*y\s*/\s*dx\^?2\b'), "y''");
    s = s.replaceAll(RegExp(r'\bdy\s*/\s*dx\b'), "y'");
    s = s.replaceAll(
      RegExp(r'\b(?:solve|find|the|general solution of|solution of|solution to|differential equation|ode)\b'),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceFirst(RegExp(r'^(?:of|for|:)\s*'), '');
    if (s.isEmpty) return null;
    if (!s.contains('=')) s = '$s=0';
    final cleaned = _cleanExpr(s, keepRel: true, keepPrime: true);
    if (cleaned.isEmpty || !cleaned.contains("y'")) return null;
    notes.add('Initial conditions are not applied; this gives the general solution.');
    return _ok(original, 'ode($cleaned)', 'ode', 'Solve the ODE $cleaned', notes, confidence: 0.8);
  }

  // ═══ PAYLOAD + PARAMETER HELPERS ═════════════════════════════════════════

  static final RegExp _leadConnector = RegExp(
    r'^[\s:,=]*(?:(?:of|for|to|the|a|an|is|that|this|following|given|function|expression|polynomial|equation|number|numbers|set|list|data|values?)\b[\s:,]*)+',
  );

  _Payload _payload(String rest, String pre, {bool keepMatrixWord = false}) {
    String lead(String s) {
      var out = s.replaceFirst(_leadConnector, '').trim();
      if (!keepMatrixWord) {
        out = out.replaceFirst(RegExp(r'^matrix\b[\s:]*'), '');
      }
      return out;
    }

    final r = lead(rest);
    if (r.isNotEmpty && !RegExp(r'^(?:with\s+respect\s+to|wrt|w\.r\.t)\b').hasMatch(r)) {
      return _Payload(r);
    }
    // postfix form: "x^2 derivative", "x^2 dx integral"; keep wrt text from rest
    final p = lead(pre);
    return _Payload(p.isEmpty ? r : '$p $r'.trim());
  }

  _Wrt? _takeVariable(String s) {
    final m = RegExp(r'\b(?:with\s+respect\s+to|respect\s+to|wrt|w\.r\.t\.?|in\s+terms\s+of)\s+([a-z])\b').firstMatch(s);
    if (m == null) return null;
    return _Wrt(m[1]!, s.replaceRange(m.start, m.end, ' ').trim());
  }

  List<String> _numbersIn(String s) => RegExp(r'-?\d+(?:\.\d+)?(?:/\d+)?')
      .allMatches(s)
      .map((m) => m[0]!)
      .toList();

  // ═══ EXPRESSION CLEANING ═════════════════════════════════════════════════

  static const Map<String, String> _numWords = {
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
    'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    'ten': '10', 'eleven': '11', 'twelve': '12', 'half': '(1/2)',
  };

  static const Map<String, String> _ordPower = {
    'second': '2', 'third': '3', 'fourth': '4', 'fifth': '5', 'sixth': '6',
    'nth': 'n',
  };

  static const Map<String, String> _fnWords = {
    'arcsine': 'asin', 'arccosine': 'acos', 'arctangent': 'atan',
    'sine': 'sin', 'cosine': 'cos', 'tangent': 'tan', 'cotangent': 'cot',
    'secant': 'sec', 'cosecant': 'csc',
    'natural logarithm': 'ln', 'natural log': 'ln', 'logarithm': 'log',
    'exponential': 'exp', 'absolute value': 'abs',
  };

  static const Set<String> _funcs = {
    'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'asin', 'acos', 'atan', 'arcsin',
    'arccos', 'arctan', 'sinh', 'cosh', 'tanh', 'ln', 'log', 'exp', 'sqrt',
    'abs', 'floor', 'ceil', 'sign', 'log10',
  };

  static const Set<String> _consts = {'pi', 'inf', 'deg'};

  static final List<String> _pieces = (() {
    final l = <String>[..._funcs, ..._consts];
    l.sort((a, b) => b.length.compareTo(a.length));
    return l;
  })();

  static final String _fnAlt = (() {
    final l = _funcs.toList()..sort((a, b) => b.length.compareTo(a.length));
    return l.join('|');
  })();

  static const String _atom = r'(?:-?[a-z0-9.]+(?:\^[a-z0-9.]+)?)';

  String _cleanExpr(String raw, {bool keepRel = false, bool keepPrime = false}) {
    var s = ' ${raw.toLowerCase()} ';

    s = s.replaceAllMapped(
      RegExp(r'\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|half)\b(?!\s*-?\s*sided)'),
      (m) => _numWords[m[1]]!,
    );
    s = s.replaceAll(RegExp(r'\bnegative\s+'), '-');

    // degrees
    s = s.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:degrees?|deg)\b'),
      (m) => '${m[1]}deg',
    );

    // e to the …
    s = s.replaceAllMapped(
      RegExp(r'\be\s+to\s+the\s+(?:power\s+of\s+)?(-?[a-z0-9.]+)'),
      (m) => 'e^(${m[1]})',
    );

    // roots
    s = s.replaceAllMapped(
      RegExp(r'\bsquare\s+root\s+of\s+(' + _atom + r'|\([^()]*\))'),
      (m) => 'sqrt(${m[1]})',
    );
    s = s.replaceAllMapped(
      RegExp(r'\bcube\s+root\s+of\s+(' + _atom + r'|\([^()]*\))'),
      (m) => '((${m[1]})^(1/3))',
    );

    // log base b of x
    s = s.replaceAllMapped(
      RegExp(r'\blog\s+base\s+(\w+)\s+of\s+(' + _atom + r'|\([^()]*\))'),
      (m) => '(ln(${m[2]})/ln(${m[1]}))',
    );

    // powers in words
    s = s.replaceAllMapped(
      RegExp(r'\bto\s+the\s+(second|third|fourth|fifth|sixth|nth|\d+(?:st|nd|rd|th))\s+power\b'),
      (m) {
        final w = m[1]!;
        final n = _ordPower[w] ?? w.replaceAll(RegExp(r'\D'), '');
        return '^$n';
      },
    );
    s = s.replaceAll(
      RegExp(r'\b(?:raised\s+to\s+(?:the\s+)?(?:power\s+of\s+)?|to\s+the\s+power\s+of\s+|to\s+the\s+power\s+)'),
      '^',
    );
    s = s.replaceAll(RegExp(r'\bsquared\b'), '^2').replaceAll(RegExp(r'\bcubed\b'), '^3');
    s = s.replaceAll(RegExp(r'\s*\^\s*'), '^');

    // function words
    _fnWords.forEach((k, v) {
      s = s.replaceAll(RegExp('\\b$k\\b'), v);
    });
    s = s.replaceAllMapped(
      RegExp(r'\b(' + _fnAlt + r')\s+(?:of\s+)?\('),
      (m) => '${m[1]}(',
    );
    // spoken fractions: "cos of pi over 3" → cos(pi/3)
    s = s.replaceAllMapped(
      RegExp(
        r'\b(' + _fnAlt + r')\s+of\s+(' + _atom + r')\s+(?:over|divided\s+by)\s+(' + _atom + r')(?![a-z0-9(])',
      ),
      (m) => '${m[1]}(${m[2]}/${m[3]})',
    );
    // "sin x", "ln of x^2", "sqrt 5"
    s = s.replaceAllMapped(
      RegExp(r'\b(' + _fnAlt + r')\s+(?:of\s+)?(?!\()(' + _atom + r')(?![a-z0-9(])'),
      (m) => '${m[1]}(${m[2]})',
    );

    // operator words
    final ops = <RegExp, String>{
      RegExp(r'\s+(?:is\s+)?less\s+than\s+or\s+equal\s+to\s+'): '<=',
      RegExp(r'\s+(?:is\s+)?greater\s+than\s+or\s+equal\s+to\s+'): '>=',
      RegExp(r'\s+(?:is\s+)?less\s+than\s+'): '<',
      RegExp(r'\s+(?:is\s+)?greater\s+than\s+'): '>',
      RegExp(r'\s+(?:is\s+equal\s+to|equals|equal\s+to)\s+'): '=',
      RegExp(r'\s+plus\s+'): '+',
      RegExp(r'\s+minus\s+'): '-',
      RegExp(r'\s+(?:times|multiplied\s+by|multiply)\s+'): '*',
      RegExp(r'\s+(?:divided\s+by|over)\s+'): '/',
    };
    ops.forEach((re, rep) => s = s.replaceAll(re, rep));

    s = s.replaceAll(RegExp(r'\b(?:the|of)\b'), ' ');
    s = s.replaceAll(RegExp(r'\s*\^\s*'), '^');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*!'), (m) => 'factorial(${m[1]})');

    return _implicitMul(s, keepRel: keepRel, keepPrime: keepPrime);
  }

  /// Convert "2x sin(x)(x+1)" → "2*x*sin(x)*(x+1)" using a small tokenizer.
  String _implicitMul(String s, {bool keepRel = false, bool keepPrime = false}) {
    final toks = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n') {
        i++;
        continue;
      }
      if (_isDigit(c) || (c == '.' && i + 1 < s.length && _isDigit(s[i + 1]))) {
        var j = i;
        while (j < s.length && (_isDigit(s[j]) || s[j] == '.')) {
          j++;
        }
        toks.add(_Tok(_K.num, s.substring(i, j)));
        i = j;
        continue;
      }
      if (_isLetter(c)) {
        var j = i;
        while (j < s.length && (_isLetter(s[j]) || s[j] == '_')) {
          j++;
        }
        for (final piece in _splitRun(s.substring(i, j))) {
          if (_funcs.contains(piece)) {
            toks.add(_Tok(_K.fn, piece));
          } else {
            toks.add(_Tok(_K.id, piece));
          }
        }
        i = j;
        continue;
      }
      if (c == '(' || c == '[') {
        toks.add(_Tok(_K.open, c));
        i++;
        continue;
      }
      if (c == ')' || c == ']') {
        toks.add(_Tok(_K.close, c));
        i++;
        continue;
      }
      if ((c == '<' || c == '>' || c == '!') && i + 1 < s.length && s[i + 1] == '=') {
        toks.add(_Tok(_K.op, '$c='));
        i += 2;
        continue;
      }
      if (c == '-' && i + 1 < s.length && s[i + 1] == '>') {
        toks.add(_Tok(_K.op, '->'));
        i += 2;
        continue;
      }
      if (c == "'" && !keepPrime) {
        i++;
        continue;
      }
      toks.add(_Tok(_K.op, c));
      i++;
    }

    final out = StringBuffer();
    for (var k = 0; k < toks.length; k++) {
      final cur = toks[k];
      final prev = k > 0 ? toks[k - 1] : null;
      if (prev != null && _needsStar(prev, cur)) out.write('*');
      // function written without parentheses: "sinx", "cos2x"
      if (cur.kind == _K.fn &&
          k + 1 < toks.length &&
          toks[k + 1].kind != _K.open &&
          (toks[k + 1].kind == _K.id || toks[k + 1].kind == _K.num)) {
        var end = k + 1;
        final arg = StringBuffer(toks[end].text);
        if (end + 1 < toks.length && toks[end + 1].text == '^' && end + 2 < toks.length) {
          arg.write('^${toks[end + 2].text}');
          end += 2;
        }
        out.write('${cur.text}($arg)');
        k = end;
        continue;
      }
      out.write(cur.text);
    }
    var res = out.toString();
    if (!keepRel) {
      res = res.replaceAll(RegExp(r'^[=:,]+|[=:,]+$'), '');
    }
    return res;
  }

  bool _needsStar(_Tok a, _Tok b) {
    final left = a.kind == _K.num || a.kind == _K.id || a.kind == _K.close;
    if (!left) return false;
    switch (b.kind) {
      case _K.fn:
        return true;
      case _K.id:
        // Keep textbook shorthand the step-by-step solver is built around:
        // "3x", "2t", "4i", "30deg".  (SolverEngine adds the explicit '*'
        // before handing anything to Giac.)
        if (a.kind == _K.num && (b.text == 'deg' || (b.text.length == 1 && b.text != 'e'))) {
          return false;
        }
        return true;
      case _K.num:
        return a.kind == _K.close;
      case _K.open:
        if (a.kind == _K.id && const {'f', 'g', 'h', 'y'}.contains(a.text)) {
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool _isLetter(String c) {
    final u = c.codeUnitAt(0);
    return u >= 97 && u <= 122;
  }

  /// "xsin" → [x, sin];  "pix" → [pi, x];  "theta" stays whole.
  List<String> _splitRun(String run) {
    final out = <String>[];
    var i = 0;
    var knownPiece = false;
    while (i < run.length) {
      String? hit;
      for (final w in _pieces) {
        if (run.startsWith(w, i)) {
          hit = w;
          break;
        }
      }
      if (hit != null) {
        out.add(hit);
        i += hit.length;
        knownPiece = true;
      } else {
        out.add(run[i]);
        i++;
      }
    }
    if (!knownPiece && run.length > 3) return [run];
    return out;
  }

  Set<String> _varsOf(String expr) {
    final vars = <String>{};
    for (final m in RegExp(r'[a-z_]+').allMatches(expr)) {
      for (final p in _splitRun(m[0]!)) {
        if (p.length == 1 && p != 'e' && p != 'i') vars.add(p);
      }
    }
    return vars;
  }

  String _renameVar(String expr, String from, String to) =>
      expr.replaceAll(RegExp('(?<![a-z])$from(?![a-z])'), to);

  bool _hasUnknownWords(String cleaned) {
    for (final m in RegExp(r'[a-z]{4,}').allMatches(cleaned)) {
      final w = m[0]!;
      if (_funcs.contains(w) || _consts.contains(w)) continue;
      if (const {'theta', 'lambda', 'omega', 'alpha', 'beta', 'gamma', 'delta', 'factorial', 'sigma', 'epsilon'}
          .contains(w)) {
        continue;
      }
      // pieces made only of functions/constants/letters glued together are fine
      if (_splitRun(w).length > 1) continue;
      return true;
    }
    return false;
  }

  String _cleanBound(String s) {
    var b = _cleanExpr(s.replaceAll(RegExp(r'\binfinity\b'), 'inf'));
    b = b.replaceFirst(RegExp(r'^[a-z]=(?=[^=])'), '');
    b = b.replaceFirst(RegExp(r'^\+(?=inf)'), '');
    return b;
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ═══ PRIVATE VALUE TYPES ═════════════════════════════════════════════════════

class _Intent {
  final String name;
  final RegExp re;
  const _Intent(this.name, this.re);
}

class _Hit {
  final String name;
  final Match match;
  const _Hit(this.name, this.match);
}

class _Payload {
  final String body;
  const _Payload(this.body);
}

class _Wrt {
  final String variable;
  final String rest;
  const _Wrt(this.variable, this.rest);
}

enum _K { num, id, fn, open, close, op }

class _Tok {
  final _K kind;
  final String text;
  const _Tok(this.kind, this.text);
}
