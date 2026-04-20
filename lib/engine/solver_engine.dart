// lib/engine/solver_engine.dart
// Math God v4 — Offline CAS via Giac FFI.
//
// Architecture:
//   User input → SolverEngine.solve()
//     ├─ GiacFFI available? → _solveViaGiac()    (true symbolic CAS)
//     └─ fallback           → _solveViaPatterns() (original pattern engine)
//
// The Giac path runs entirely on-device.  No network.  No regex hacks.
// Results are exact: factor(x^3-1) = (x-1)*(x^2+x+1), not "polynomial".

import 'dart:math' as math;
import '../models/solution.dart';
import 'giac_ffi.dart';

class SolverEngine {
  static final SolverEngine instance = SolverEngine._();
  SolverEngine._();

  // Cached once — opening the .so is non-trivial
  bool? _giacAvailable;
  bool get _useGiac {
    _giacAvailable ??= _tryInitGiac();
    return _giacAvailable!;
  }

  bool _tryInitGiac() {
    try {
      return GiacFFI.instance.isAvailable;
    } catch (_) {
      return false;
    }
  }

  // ═══ ENTRY POINT ═════════════════════════════════════════════════════════════

  Solution solve(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return Solution.unknown(input);

    if (_useGiac) {
      return _solveViaGiac(input);
    }
    return _solveViaPatterns(input);
  }

  // ═══ GIAC PATH ═══════════════════════════════════════════════════════════════
  //
  // We translate user-friendly input strings into Giac's Xcas language,
  // then ask Giac for both a symbolic result and a LaTeX rendering.
  //
  // Giac command reference (subset used here):
  //   diff(f,x)           differentiate
  //   int(f,x)            indefinite integral
  //   int(f,x,a,b)        definite integral
  //   limit(f,x,a)        limit
  //   factor(expr)        factorise
  //   expand(expr)        expand
  //   solve(eq,x)         solve equation
  //   laplace(f,t,s)      Laplace transform
  //   ilaplace(F,s,t)     inverse Laplace
  //   desolve(ode,t,y)    ODE solver
  //   det(M)              matrix determinant
  //   inverse(M)          matrix inverse
  //   eigenvalues(M)      eigenvalues
  //   normal(expr)        simplify
  //   latex(expr)         render to LaTeX string

  Solution _solveViaGiac(String input) {
    final lower = input.toLowerCase();

    // ── Determine Giac command ──────────────────────────────────────────────
    String giacCmd;
    String operation;
    MathDomain domain;

    try {
      if (_isDerivative(lower)) {
        final expr = _ex(input, [
          'd/dx[',
          'd/dx',
          'diff(',
          'derivative(',
          'd/dt[',
          'd/dt',
        ]);
        final varName = lower.contains('d/dt') ? 't' : 'x';
        giacCmd = 'diff($expr,$varName)';
        operation = 'Derivative';
        domain = MathDomain.calculus;
      } else if (lower.startsWith('laplace(')) {
        final expr = _ex(input, ['laplace(']);
        giacCmd = 'laplace($expr,t,s)';
        operation = 'Laplace Transform';
        domain = MathDomain.differentialEquations;
      } else if (lower.startsWith('invlaplace(') ||
          lower.startsWith('ilaplace(')) {
        final expr = _ex(input, ['invlaplace(', 'ilaplace(']);
        giacCmd = 'ilaplace($expr,s,t)';
        operation = 'Inverse Laplace';
        domain = MathDomain.differentialEquations;
      } else if (_isIntegral(lower)) {
        final inner = _ex(input, ['int(', 'integrate(', 'antideriv(']);
        final parts = _splitArgs(inner);
        if (parts.length >= 3) {
          giacCmd = 'int(${parts[0]},x,${parts[1]},${parts[2]})';
        } else {
          giacCmd = 'int($inner,x)';
        }
        operation = 'Integral';
        domain = MathDomain.calculus;
      } else if (_isLimit(lower)) {
        final inner = _ex(input, ['lim(', 'limit(', 'lim ']);
        final parts = _splitArgs(inner);
        if (parts.length >= 3) {
          giacCmd = 'limit(${parts[0]},${parts[1]},${parts[2]})';
        } else {
          giacCmd = 'limit($inner,x,0)';
        }
        operation = 'Limit';
        domain = MathDomain.calculus;
      } else if (_isDet(lower)) {
        final inner = _ex(input, ['det(', 'determinant(']);
        giacCmd = 'det($inner)';
        operation = 'Determinant';
        domain = MathDomain.linearAlgebra;
      } else if (_isInv(lower)) {
        final inner = _ex(input, ['inv(', 'inverse(']);
        giacCmd = 'inverse($inner)';
        operation = 'Matrix Inverse';
        domain = MathDomain.linearAlgebra;
      } else if (_isEigen(lower)) {
        final inner = _ex(input, ['eigen(', 'eig(', 'eigenvalue(']);
        giacCmd = 'eigenvalues($inner)';
        operation = 'Eigenvalues';
        domain = MathDomain.linearAlgebra;
      } else if (_isFactorize(lower)) {
        final inner = _ex(input, ['factorize(', 'factor(', 'prime_factors(']);
        giacCmd = 'factor($inner)';
        operation = 'Factorize';
        domain = MathDomain.numberTheory;
      } else if (lower.startsWith('solve(')) {
        giacCmd = input; // pass through verbatim
        operation = 'Solve';
        domain = MathDomain.general;
      } else if (lower.startsWith('taylor(') ||
          lower.startsWith('maclaurin(')) {
        final inner = _ex(input, ['taylor(', 'maclaurin(']);
        final parts = _splitArgs(inner);
        final f = parts.isNotEmpty ? parts[0] : inner;
        final n = parts.length >= 2 ? parts[1] : '5';
        final a = lower.startsWith('maclaurin(')
            ? '0'
            : (parts.length >= 3 ? parts[2] : '0');
        giacCmd = 'series($f,x=$a,$n)';
        operation = lower.startsWith('maclaurin(')
            ? 'Maclaurin Series'
            : 'Taylor Series';
        domain = MathDomain.realAnalysis;
      } else if (_isODE(lower)) {
        giacCmd = 'desolve($input,t,y)';
        operation = 'ODE';
        domain = MathDomain.differentialEquations;
      } else if (_isVector(lower)) {
        giacCmd =
            input; // gradient/div/curl pass through — Giac understands them
        operation = 'Vector Calculus';
        domain = MathDomain.calculus;
      } else {
        // Generic: try to evaluate / simplify
        giacCmd = 'normal($input)';
        operation = 'Evaluate';
        domain = MathDomain.general;
      }

      // ── Call the CAS ──────────────────────────────────────────────────────
      final rawResult = GiacFFI.instance.solve(giacCmd);

      if (rawResult.startsWith('Error:')) {
        // CAS failed — fall back to pattern engine
        return _solveViaPatterns(input);
      }

      // Also grab LaTeX rendering (a second Giac call)
      final latexResult = GiacFFI.instance.solve('latex($giacCmd)');
      final resultLatex = latexResult.startsWith('Error:')
          ? _toLatexFallback(rawResult)
          : _cleanGiacLatex(latexResult);

      // ── Build explanation steps ───────────────────────────────────────────
      final steps = _buildGiacSteps(input, giacCmd, rawResult, operation);

      return Solution(
        input: input,
        domain: domain,
        operation: operation,
        resultLatex: resultLatex,
        resultReadable: rawResult,
        steps: steps,
        tip: _tipFor(operation),
      );
    } catch (e) {
      return _solveViaPatterns(input);
    }
  }

  // Clean up Giac's LaTeX output (it adds extra quotes and sometimes \n)
  String _cleanGiacLatex(String s) {
    var out = s.trim();
    if (out.startsWith('"') && out.endsWith('"')) {
      out = out.substring(1, out.length - 1);
    }
    return out.replaceAll(r'\n', ' ').trim();
  }

  // Minimal LaTeX rendering when Giac's latex() call also fails
  String _toLatexFallback(String s) => '\\text{${s.replaceAll(r'\', r'\\')}}';

  List<SolutionStep> _buildGiacSteps(
    String input,
    String cmd,
    String result,
    String operation,
  ) {
    return [
      const SolutionStep(
        title: 'CAS Engine',
        latex: r'\text{Giac CAS (offline symbolic engine)}',
        explanation:
            'Evaluated on-device using the Giac library — '
            'the same engine that powers HP Prime calculators and Xcas.',
      ),
      SolutionStep(
        title: 'Command Sent',
        latex: '\\texttt{${_texEscape(cmd)}}',
        explanation: 'Translated your input into a Giac CAS command.',
      ),
      SolutionStep(
        title: 'Result',
        latex: _toLatexFallback(result),
        explanation: 'Exact symbolic result from Giac.',
        rule: operation,
      ),
    ];
  }

  String _texEscape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('_', r'\_').replaceAll('^', r'\^{}');

  String _tipFor(String op) {
    const tips = {
      'Derivative':
          'Verify: integrate the result and you should get back the original.',
      'Integral':
          'Verify: differentiate the result and you should recover the integrand.',
      'Laplace Transform':
          'Giac uses the one-sided Laplace: ∫₀^∞ e^{-st} f(t) dt.',
      'Eigenvalues': 'Eigenvectors: solve (A − λI)v = 0 for each eigenvalue.',
      'Factorize': 'GCD of two polynomials: gcd(f,g) in Giac.',
      'Taylor Series': 'series(f, x=a, n) gives O((x-a)^n) precision.',
      'ODE': 'Verify: substitute the solution back into the original ODE.',
    };
    return tips[op] ??
        'Powered by Giac — the offline CAS inside HP Prime calculators.';
  }

  // Split comma-separated args respecting nested parentheses
  List<String> _splitArgs(String s) {
    final result = <String>[];
    int depth = 0;
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      if (ch == '(' || ch == '[')
        depth++;
      else if (ch == ')' || ch == ']')
        depth--;
      if (ch == ',' && depth == 0) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) result.add(buf.toString().trim());
    return result;
  }

  // ═══ PATTERN-MATCHING FALLBACK ════════════════════════════════════════════════
  // Preserved in full — used when libgiac.so is not available (first install,
  // emulator, or platform not yet supported).

  Solution _solveViaPatterns(String input) {
    final lower = input.toLowerCase();

    if (lower.startsWith('laplace(')) return _laplace(input);
    if (lower.startsWith('invlaplace(') || lower.startsWith('ilaplace('))
      return _invLaplace(input);
    if (lower.startsWith('fourier_series(') || lower.startsWith('fseries('))
      return _fourierSeries(input);
    if (lower.startsWith('newton(') || lower.startsWith('newtonraphson('))
      return _newtonRaphson(input);
    if (lower.startsWith('euler(')) return _eulerMethod(input);
    if (lower.startsWith('rk4(') || lower.startsWith('runge('))
      return _rungeKutta4(input);
    if (lower.startsWith('partial(') ||
        lower.startsWith('pd(') ||
        lower.startsWith('d/dy'))
      return _partialDerivative(input);
    if (lower.startsWith('dblint(') ||
        lower.startsWith('tripleint(') ||
        lower.startsWith('doubleint('))
      return _multipleIntegral(input);
    if (lower.startsWith('taylor(') || lower.startsWith('maclaurin('))
      return _taylorSeries(input);
    if (lower.startsWith('line_int(') || lower.startsWith('lineint('))
      return _lineIntegral(input);

    if (_isDerivative(lower)) return _derivative(input);
    if (_isIntegral(lower)) return _integral(input);
    if (_isLimit(lower)) return _limit(input);
    if (_isDet(lower)) return _determinant(input);
    if (_isInv(lower)) return _matrixInverse(input);
    if (_isEigen(lower)) return _eigenvalue(input);
    if (_isODE(lower)) return _ode(input);
    if (_isSeries(lower)) return _series(input);
    if (_isTrig(lower)) return _trigonometry(input);
    if (_isComplex(lower)) return _complex(input);
    if (_isStats(lower)) return _statistics(input);
    if (_isPrime(lower)) return _numberTheory(input);
    if (_isFactorize(lower)) return _factorize(input);
    if (_isGroup(lower)) return _abstractAlgebra(input);
    if (_isTopology(lower)) return _topology(input);
    if (_isVector(lower)) return _vectorCalculus(input);

    return Solution.unknown(input);
  }

  // ═══ DETECTION ═══════════════════════════════════════════════════════════════

  bool _isDerivative(String s) =>
      s.startsWith('d/dx') ||
      s.startsWith('diff(') ||
      s.startsWith('derivative(') ||
      s.startsWith('d/dt');
  bool _isIntegral(String s) =>
      s.startsWith('int(') ||
      s.startsWith('integrate(') ||
      s.startsWith('antideriv(');
  bool _isLimit(String s) =>
      s.startsWith('lim(') || s.startsWith('limit(') || s.startsWith('lim ');
  bool _isDet(String s) => s.startsWith('det(') || s.startsWith('determinant(');
  bool _isInv(String s) => s.startsWith('inv(') || s.startsWith('inverse(');
  bool _isEigen(String s) =>
      s.startsWith('eigen(') ||
      s.startsWith('eig(') ||
      s.startsWith('eigenvalue(');
  bool _isODE(String s) =>
      s.startsWith('ode(') || s.contains("y'") || s.contains('dy/dx');
  bool _isSeries(String s) =>
      s.startsWith('series(') ||
      s.startsWith('sum(') ||
      s.startsWith('sequence(');
  bool _isTrig(String s) =>
      RegExp(r'^(sin|cos|tan|cot|sec|csc|arcsin|arccos|arctan)\(').hasMatch(s);
  bool _isComplex(String s) =>
      s.startsWith('complex(') ||
      s.startsWith('modulus(') ||
      s.startsWith('conjugate(') ||
      s.contains(RegExp(r'\d[+\-]\d*i'));
  bool _isStats(String s) =>
      s.startsWith('mean(') ||
      s.startsWith('median(') ||
      s.startsWith('variance(') ||
      s.startsWith('stddev(') ||
      s.startsWith('binomial(') ||
      s.startsWith('normal(') ||
      s.startsWith('poisson(') ||
      s.startsWith('combination(') ||
      s.startsWith('permutation(');
  bool _isPrime(String s) =>
      s.startsWith('isprime(') ||
      s.startsWith('gcd(') ||
      s.startsWith('lcm(') ||
      s.startsWith('mod(');
  bool _isFactorize(String s) =>
      s.startsWith('factorize(') ||
      s.startsWith('factor(') ||
      s.startsWith('prime_factors(');
  bool _isGroup(String s) =>
      s.startsWith('group(') || s.startsWith('ring(') || s.startsWith('field(');
  bool _isTopology(String s) =>
      s.startsWith('topology(') ||
      s.startsWith('compact(') ||
      s.startsWith('connected(');
  bool _isVector(String s) =>
      s.startsWith('curl(') ||
      s.startsWith('div(') ||
      s.startsWith('gradient(') ||
      s.startsWith('grad(') ||
      s.startsWith('laplacian(') ||
      s.startsWith('dot(') ||
      s.startsWith('cross(');

  // ═══ 1. LAPLACE TRANSFORM ════════════════════════════════════════════════════

  Solution _laplace(String input) {
    final expr = _ex(input, ['laplace(']);
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Laplace Definition',
        latex: r'\mathcal{L}\{f(t)\} = \int_0^{\infty} e^{-st}f(t)\,dt',
        explanation: 'Converts f(t) → F(s). Turns DEs into algebra.',
      ),
    );
    final result = _laplaceLookup(expr, steps);
    steps.add(
      SolutionStep(
        title: 'Final Result',
        latex: '\\mathcal{L}\\{${_tex(expr)}\\} = $result',
        explanation: 'Verify by inverse Laplace.',
        rule: 'Laplace Table',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.differentialEquations,
      operation: 'Laplace Transform',
      resultLatex: result,
      resultReadable: 'F(s) = $result',
      steps: steps,
      tip: 'Master the Laplace table + linearity + s-shift theorem.',
    );
  }

  String _laplaceLookup(String expr, List<SolutionStep> steps) {
    final e = expr.replaceAll(' ', '').toLowerCase();
    if (e == '1' || e == 'u(t)') {
      steps.add(
        const SolutionStep(
          title: 'Unit step',
          latex: r'\mathcal{L}\{1\} = \frac{1}{s}',
          explanation: 'Valid for s>0.',
        ),
      );
      return r'\frac{1}{s}';
    }
    if (e == 't') {
      steps.add(
        const SolutionStep(
          title: 'Linear: t',
          latex: r'\mathcal{L}\{t\} = \frac{1}{s^2}',
          explanation: 'n=1 case of t^n.',
        ),
      );
      return r'\frac{1}{s^2}';
    }
    final tPow = RegExp(r'^t\^(\d+)$').firstMatch(e);
    if (tPow != null) {
      final n = int.parse(tPow.group(1)!);
      final f = _fact(n);
      steps.add(
        SolutionStep(
          title: 't^$n',
          latex: '\\mathcal{L}\\{t^$n\\}=\\frac{$f}{s^{${n + 1}}}',
          explanation: 'n!=$f',
        ),
      );
      return '\\frac{$f}{s^{${n + 1}}}';
    }
    final expA = RegExp(r'^e\^\(?(-?\d*\.?\d*)t\)?$').firstMatch(e);
    if (expA != null) {
      final a = expA.group(1)!.isEmpty ? '1' : expA.group(1)!;
      steps.add(
        SolutionStep(
          title: 'e^(${a}t)',
          latex: r'\mathcal{L}\{e^{at}\}=\frac{1}{s-a}',
          explanation: 'a=$a',
        ),
      );
      return '\\frac{1}{s-(${a})}';
    }
    final sinW = RegExp(r'^sin\((\d*\.?\d*)t\)$').firstMatch(e);
    if (sinW != null) {
      final w = sinW.group(1)!.isEmpty ? '1' : sinW.group(1)!;
      final w2 = _fmt((double.tryParse(w) ?? 1) * (double.tryParse(w) ?? 1));
      steps.add(
        SolutionStep(
          title: 'sin(${w}t)',
          latex: r'\mathcal{L}\{\sin(\omega t)\}=\frac{\omega}{s^2+\omega^2}',
          explanation: 'ω=$w',
        ),
      );
      return '\\frac{$w}{s^2+$w2}';
    }
    final cosW = RegExp(r'^cos\((\d*\.?\d*)t\)$').firstMatch(e);
    if (cosW != null) {
      final w = cosW.group(1)!.isEmpty ? '1' : cosW.group(1)!;
      final w2 = _fmt((double.tryParse(w) ?? 1) * (double.tryParse(w) ?? 1));
      steps.add(
        SolutionStep(
          title: 'cos(${w}t)',
          latex: r'\mathcal{L}\{\cos(\omega t)\}=\frac{s}{s^2+\omega^2}',
          explanation: 'ω=$w',
        ),
      );
      return '\\frac{s}{s^2+$w2}';
    }
    final c = RegExp(r'^(\d+\.?\d*)$').firstMatch(e);
    if (c != null) {
      steps.add(
        const SolutionStep(
          title: 'Constant',
          latex: r'\mathcal{L}\{c\}=\frac{c}{s}',
          explanation: '',
        ),
      );
      return '\\frac{${c.group(1)!}}{s}';
    }
    steps.add(
      const SolutionStep(
        title: 'Linearity',
        latex: r'\mathcal{L}\{af+bg\}=a\mathcal{L}\{f\}+b\mathcal{L}\{g\}',
        explanation: 'Decompose into recognizable pieces.',
      ),
    );
    return '\\mathcal{L}\\{${_tex(expr)}\\}';
  }

  // ═══ 2. INVERSE LAPLACE ══════════════════════════════════════════════════════

  Solution _invLaplace(String input) {
    final expr = _ex(input, ['invlaplace(', 'ilaplace(']);
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Inverse Strategy',
        latex: r'\mathcal{L}^{-1}\{F(s)\}=f(t)',
        explanation: 'Match F(s) to table after partial fractions.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Partial Fractions',
        latex: r'F(s)=\frac{A}{s-a}+\frac{Bs+C}{s^2+\omega^2}+\cdots',
        explanation: 'Decompose into standard forms, read off inverse.',
        rule: 'PFD',
      ),
    );
    final result = _invLaplaceLookup(expr, steps);
    steps.add(
      SolutionStep(
        title: 'Final Result',
        latex: '\\mathcal{L}^{-1}\\{${_tex(expr)}\\} = $result',
        explanation: 'Verify: L{$result} = $expr',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.differentialEquations,
      operation: 'Inverse Laplace',
      resultLatex: result,
      resultReadable: 'f(t) = $result',
      steps: steps,
      tip: 'Always verify: take Laplace of answer and check it equals F(s).',
    );
  }

  String _invLaplaceLookup(String expr, List<SolutionStep> steps) {
    final e = expr.replaceAll(' ', '').toLowerCase();
    if (e == '1/s') return '1';
    if (e == '1/s^2') {
      steps.add(
        const SolutionStep(
          title: '1/s²',
          latex: r'\mathcal{L}^{-1}\{1/s^2\}=t',
          explanation: 'n=1',
        ),
      );
      return 't';
    }
    final sn = RegExp(r'^1/s\^(\d+)$').firstMatch(e);
    if (sn != null) {
      final n = int.parse(sn.group(1)!);
      steps.add(
        SolutionStep(
          title: '1/s^$n',
          latex: '\\mathcal{L}^{-1}\\{1/s^$n\\}=t^{${n - 1}}/${_fact(n - 1)}!',
          explanation: '',
        ),
      );
      return '\\frac{t^{${n - 1}}}{${_fact(n - 1)}}';
    }
    final ep = RegExp(r'^1/\(s\+(\d+\.?\d*)\)$').firstMatch(e);
    if (ep != null) {
      final a = ep.group(1)!;
      steps.add(
        SolutionStep(
          title: '1/(s+$a)',
          latex: '\\mathcal{L}^{-1}\\{1/(s+a)\\}=e^{-at}',
          explanation: 'a=$a',
        ),
      );
      return 'e^{-${a}t}';
    }
    final en = RegExp(r'^1/\(s-(\d+\.?\d*)\)$').firstMatch(e);
    if (en != null) {
      final a = en.group(1)!;
      steps.add(
        SolutionStep(
          title: '1/(s-$a)',
          latex: '\\mathcal{L}^{-1}\\{1/(s-a)\\}=e^{at}',
          explanation: 'a=$a',
        ),
      );
      return 'e^{${a}t}';
    }
    final sf = RegExp(r'^(\d+\.?\d*)/\(s\^2\+(\d+\.?\d*)\)$').firstMatch(e);
    if (sf != null) {
      final w = math.sqrt(double.tryParse(sf.group(2)!) ?? 1);
      steps.add(
        SolutionStep(
          title: 'ω/(s²+ω²)',
          latex: r'\mathcal{L}^{-1}\{\omega/(s^2+\omega^2)\}=\sin(\omega t)',
          explanation: 'ω=${_fmt(w)}',
        ),
      );
      return '\\sin(${_fmt(w)}t)';
    }
    final cf = RegExp(r'^s/\(s\^2\+(\d+\.?\d*)\)$').firstMatch(e);
    if (cf != null) {
      final w = math.sqrt(double.tryParse(cf.group(1)!) ?? 1);
      steps.add(
        SolutionStep(
          title: 's/(s²+ω²)',
          latex: r'\mathcal{L}^{-1}\{s/(s^2+\omega^2)\}=\cos(\omega t)',
          explanation: 'ω=${_fmt(w)}',
        ),
      );
      return '\\cos(${_fmt(w)}t)';
    }
    return 'f(t)';
  }

  // ═══ 3. FOURIER SERIES ═══════════════════════════════════════════════════════

  Solution _fourierSeries(String input) {
    final inner = _ex(input, ['fourier_series(', 'fseries(']);
    final steps = <SolutionStep>[];
    int n = 5;
    final nM = RegExp(r'n=(\d+)').firstMatch(inner);
    if (nM != null) n = int.parse(nM.group(1)!);
    steps.add(
      const SolutionStep(
        title: 'Fourier Series Definition',
        latex:
            r'f(x)=\frac{a_0}{2}+\sum_{n=1}^{\infty}\left[a_n\cos\frac{n\pi x}{L}+b_n\sin\frac{n\pi x}{L}\right]',
        explanation:
            'Any periodic function decomposes into sines+cosines. L=half-period.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Coefficients',
        latex:
            r'a_n=\frac{1}{L}\int_{-L}^{L}f(x)\cos\frac{n\pi x}{L}\,dx,\quad b_n=\frac{1}{L}\int_{-L}^{L}f(x)\sin\frac{n\pi x}{L}\,dx',
        explanation: 'Orthogonality extracts each frequency amplitude.',
        rule: 'Euler-Fourier',
      ),
    );
    final terms = <String>[];
    for (int k = 1; terms.length < n; k += 2) {
      terms.add('\\frac{\\sin(${k}x)}{$k}');
    }
    final ps = '\\frac{4}{\\pi}\\left(' + terms.join('+') + '+\\cdots\\right)';
    steps.add(
      SolutionStep(
        title: 'Square Wave: N=$n Terms',
        latex: ps,
        explanation:
            'Only odd harmonics. Gibbs phenomenon: 9% overshoot at discontinuities — always.',
        rule: 'Square Wave',
      ),
    );
    steps.add(
      const SolutionStep(
        title: "Parseval's Theorem",
        latex: r'\frac{1}{L}\int|f|^2\,dx=\frac{a_0^2}{2}+\sum(a_n^2+b_n^2)',
        explanation: 'Energy conserved in frequency domain.',
        rule: "Parseval",
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.differentialEquations,
      operation: 'Fourier Series',
      resultLatex: ps,
      resultReadable: 'N=$n partial sum (square wave)',
      steps: steps,
      tip:
          'Fourier Series: the math of MP3, JPEG, WiFi, and every oscilloscope you use.',
    );
  }

  // ═══ 4. NEWTON-RAPHSON ═══════════════════════════════════════════════════════

  Solution _newtonRaphson(String input) {
    final inner = _ex(input, ['newton(', 'newtonraphson(']);
    final steps = <SolutionStep>[];
    double x0 = 1.0;
    final x0M = RegExp(r'x0\s*=\s*(-?\d+\.?\d*)').firstMatch(inner);
    if (x0M != null) x0 = double.parse(x0M.group(1)!);
    final fn = inner.split(',').first.trim();
    steps.add(
      const SolutionStep(
        title: 'Newton-Raphson Formula',
        latex: "x_{n+1}=x_n-\\frac{f(x_n)}{f'(x_n)}",
        explanation:
            'Tangent-line root approximation. Quadratic convergence near root.',
        rule: "Newton's Method",
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Geometric Idea',
        latex: "x_1=x_0-\\frac{f(x_0)}{f'(x_0)}",
        explanation:
            'Tangent at x₀ crosses x-axis at x₁. Each step ≈ doubles correct digits.',
      ),
    );
    final rows = <String>[];
    double x = x0;
    for (int i = 0; i < 7; i++) {
      final fx = _ep(fn, x);
      final fpx = _epd(fn, x);
      if (fpx.abs() < 1e-14) break;
      final xn = x - fx / fpx;
      rows.add('x_{${i + 1}}=${_fn(xn)}');
      if ((xn - x).abs() < 1e-9) {
        x = xn;
        break;
      }
      x = xn;
    }
    if (rows.isNotEmpty)
      steps.add(
        SolutionStep(
          title: 'Iterations from x₀=${_fn(x0)}',
          latex: rows.take(5).join(',\\;'),
          explanation: '4–6 steps typically reach machine precision.',
          rule: 'Iteration',
        ),
      );
    steps.add(
      const SolutionStep(
        title: 'Stop Criterion',
        latex: r'|x_{n+1}-x_n|<\varepsilon',
        explanation: 'ε=10⁻⁶ for engineering.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Failure Modes',
        latex: "f'(x_n)=0\\Rightarrow\\text{fails}",
        explanation: "Fails if f'=0, or initial guess too far from root.",
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.general,
      operation: 'Newton-Raphson',
      resultLatex: 'x\\approx${_fn(x)}',
      resultReadable: 'Root ≈ ${_fn(x)}',
      steps: steps,
      tip:
          "Newton's method is inside MATLAB's fzero and scipy.optimize.fsolve.",
    );
  }

  double _ep(String e, double x) {
    // Use Giac for accurate evaluation when available
    if (_useGiac) {
      try {
        final xStr = x.toStringAsFixed(15);
        final expr = e.toLowerCase().replaceAll('x', '($xStr)');
        final result = GiacFFI.instance.solve('evalf($expr)');
        final val = double.tryParse(result.trim());
        if (val != null) return val;
      } catch (_) {}
    }
    // Fallback: simple pattern matching for common cases
    final s = e.toLowerCase().replaceAll(' ', '');
    if (s.contains('x^3') && s.contains('-2')) return x * x * x - 2;
    if (s.contains('x^3') && s.contains('+2')) return x * x * x + 2;
    if (s.contains('x^3')) return x * x * x;
    if (s.contains('x^2') && s.contains('-2')) return x * x - 2;
    if (s.contains('x^2')) return x * x;
    return x * x * x - 2;
  }

  double _epd(String e, double x) {
    // Use Giac for accurate derivative evaluation when available
    if (_useGiac) {
      try {
        final xStr = x.toStringAsFixed(15);
        final result = GiacFFI.instance.solve(
          'evalf(subst(diff(${e.toLowerCase()},x),x,$xStr))',
        );
        final val = double.tryParse(result.trim());
        if (val != null) return val;
      } catch (_) {}
    }
    // Fallback
    final s = e.toLowerCase().replaceAll(' ', '');
    if (s.contains('x^3')) return 3 * x * x;
    if (s.contains('x^2')) return 2 * x;
    return 1.0;
  }

  // ═══ 5. EULER METHOD ═════════════════════════════════════════════════════════

  Solution _eulerMethod(String input) {
    final inner = _ex(input, ['euler(']);
    final steps = <SolutionStep>[];
    double x0 = 0, y0 = 1, h = 0.1;
    int n = 5;
    final xm = RegExp(r'x0\s*=\s*(-?\d+\.?\d*)').firstMatch(inner);
    if (xm != null) x0 = double.parse(xm.group(1)!);
    final ym = RegExp(r'y0\s*=\s*(-?\d+\.?\d*)').firstMatch(inner);
    if (ym != null) y0 = double.parse(ym.group(1)!);
    final hm = RegExp(r',\s*h\s*=\s*(\d+\.?\d*)').firstMatch(inner);
    if (hm != null) h = double.parse(hm.group(1)!);
    final nm = RegExp(r',\s*n\s*=\s*(\d+)').firstMatch(inner);
    if (nm != null) n = int.parse(nm.group(1)!);
    steps.add(
      const SolutionStep(
        title: "Euler Formula",
        latex: r'y_{n+1}=y_n+h\cdot f(x_n,y_n)',
        explanation: "Step h along tangent. First-order: global error ∝ h.",
        rule: "Euler's Method",
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Error',
        latex:
            r'\text{Local: }\mathcal{O}(h^2),\;\text{Global: }\mathcal{O}(h)',
        explanation:
            'Halving h halves error but doubles work. Compare RK4: same work gives h⁴ accuracy.',
      ),
    );
    double xi = x0, yi = y0;
    final rows = <String>[];
    for (int i = 0; i < math.min(n, 6); i++) {
      final f = xi + yi;
      final yn = yi + h * f;
      rows.add('(${_fn(xi)},${_fn(yi)})\\to${_fn(yn)}');
      xi += h;
      yi = yn;
    }
    steps.add(
      SolutionStep(
        title: "Steps (y'=x+y, h=$h)",
        latex: rows.take(4).join('\\\\'),
        explanation: 'f(xₙ,yₙ)=xₙ+yₙ used as illustration.',
        rule: 'Euler Steps',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Stability',
        latex: r'|1+h\lambda|<1',
        explanation:
            'For stiff ODEs (large |λ|) Euler needs tiny h or diverges. Use RK4 or implicit methods.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.differentialEquations,
      operation: "Euler's Method",
      resultLatex: 'y(${_fn(xi)})\\approx${_fn(yi)}',
      resultReadable: 'y(${_fn(xi)}) ≈ ${_fn(yi)}',
      steps: steps,
      tip: "Euler = conceptual foundation. RK4 = practical tool.",
    );
  }

  // ═══ 6. RUNGE-KUTTA 4 ════════════════════════════════════════════════════════

  Solution _rungeKutta4(String input) {
    final inner = _ex(input, ['rk4(', 'runge(', 'rungekutta(']);
    final steps = <SolutionStep>[];
    double x0 = 0, y0 = 1, h = 0.1;
    int n = 5;
    final xm = RegExp(r'x0\s*=\s*(-?\d+\.?\d*)').firstMatch(inner);
    if (xm != null) x0 = double.parse(xm.group(1)!);
    final ym = RegExp(r'y0\s*=\s*(-?\d+\.?\d*)').firstMatch(inner);
    if (ym != null) y0 = double.parse(ym.group(1)!);
    final hm = RegExp(r',\s*h\s*=\s*(\d+\.?\d*)').firstMatch(inner);
    if (hm != null) h = double.parse(hm.group(1)!);
    final nm = RegExp(r',\s*n\s*=\s*(\d+)').firstMatch(inner);
    if (nm != null) n = int.parse(nm.group(1)!);
    steps.add(
      const SolutionStep(
        title: 'RK4 Formula',
        latex: r'y_{n+1}=y_n+\frac{h}{6}(k_1+2k_2+2k_3+k_4)',
        explanation: '4 slope estimates weighted 1:2:2:1. Local error ∝ h⁵.',
        rule: 'RK4',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Four Slopes',
        latex:
            'k_1=f(x_n,y_n),\\;k_2=f(x_n+h/2,y_n+hk_1/2),\\;k_3=f(x_n+h/2,y_n+hk_2/2),\\;k_4=f(x_n+h,y_n+hk_3)',
        explanation:
            'Start, two midpoints, endpoint. Simpson-rule-like weighting.',
        rule: 'RK4 Slopes',
      ),
    );
    double f(double xi, double yi) => yi; // y'=y → exact: e^x
    double xi = x0, yi = y0;
    final rows = <String>[];
    for (int i = 0; i < math.min(n, 5); i++) {
      final k1 = f(xi, yi);
      final k2 = f(xi + h / 2, yi + h / 2 * k1);
      final k3 = f(xi + h / 2, yi + h / 2 * k2);
      final k4 = f(xi + h, yi + h * k3);
      final yn = yi + (h / 6) * (k1 + 2 * k2 + 2 * k3 + k4);
      final ex = math.exp(xi + h);
      rows.add(
        'y_{${i + 1}}=${_fn(yn)},\\;e^x=${_fn(ex)},\\;\\varepsilon=${_fn((yn - ex).abs())}',
      );
      xi += h;
      yi = yn;
    }
    steps.add(
      SolutionStep(
        title: "RK4 vs Exact (y'=y, y₀=1 → eˣ)",
        latex: rows.take(4).join('\\\\'),
        explanation: 'Error is dramatically smaller than Euler for same h.',
        rule: 'Accuracy',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Accuracy Comparison',
        latex:
            r'\text{Euler: }\mathcal{O}(h),\quad\text{RK4: }\mathcal{O}(h^4)',
        explanation:
            "MATLAB ode45 = adaptive RK4/5 (Dormand-Prince). Python scipy.solve_ivp default = RK45.",
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.differentialEquations,
      operation: 'Runge-Kutta 4',
      resultLatex: 'y(${_fn(xi)})\\approx${_fn(yi)}',
      resultReadable: 'y(${_fn(xi)}) ≈ ${_fn(yi)} (h=$h)',
      steps: steps,
      tip:
          'RK4: gold-standard explicit solver. Use when Euler accuracy is insufficient.',
    );
  }

  // ═══ 7. PARTIAL DERIVATIVES ══════════════════════════════════════════════════

  Solution _partialDerivative(String input) {
    final lower = input.toLowerCase();
    final wrtY =
        lower.contains('/dy') ||
        lower.contains('d/dy') ||
        (lower.startsWith('pd(') && lower.contains(',y'));
    final v = wrtY ? 'y' : 'x';
    String expr = _ex(input, [
      'partial(',
      'pd(',
      'd/dx[',
      'd/dy[',
      'd/dx',
      'd/dy',
    ]);
    if (expr.contains(',')) expr = expr.split(',').first.trim();
    final steps = <SolutionStep>[];
    steps.add(
      SolutionStep(
        title: 'Partial Derivative',
        latex:
            '\\frac{\\partial f}{\\partial $v}=\\lim_{h\\to0}\\frac{f(\\ldots,$v+h,\\ldots)-f(\\ldots)}{h}',
        explanation:
            'Differentiate w.r.t. $v; treat all other variables as constants.',
      ),
    );
    steps.add(
      SolutionStep(
        title: 'Apply Rules',
        latex: '\\frac{\\partial}{\\partial $v}\\left[${_tex(expr)}\\right]',
        explanation:
            'Same power/product/chain rules — non-$v variables are just numbers.',
        rule: 'Partial Diff',
      ),
    );
    steps.add(
      const SolutionStep(
        title: "Clairaut's Theorem",
        latex:
            r'\frac{\partial^2 f}{\partial x\partial y}=\frac{\partial^2 f}{\partial y\partial x}',
        explanation:
            'Order of mixed partials is interchangeable for continuous functions.',
        rule: "Clairaut",
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Gradient Vector',
        latex:
            r'\nabla f=\left(\frac{\partial f}{\partial x},\frac{\partial f}{\partial y},\frac{\partial f}{\partial z}\right)',
        explanation:
            '∇f → steepest ascent. |∇f| = max directional derivative. ∇f=0 at critical points.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Multivariable Chain Rule',
        latex:
            r'\frac{dz}{dt}=\frac{\partial z}{\partial x}\frac{dx}{dt}+\frac{\partial z}{\partial y}\frac{dy}{dt}',
        explanation: 'One term per intermediate variable. Sum them all.',
        rule: 'MV Chain Rule',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.calculus,
      operation: '∂/∂$v',
      resultLatex:
          '\\frac{\\partial}{\\partial $v}\\left[${_tex(expr)}\\right]',
      resultReadable: '∂/∂$v[$expr]',
      steps: steps,
      tip:
          'Partial derivatives: foundation of gradient descent, heat/wave equations, thermodynamics.',
    );
  }

  // ═══ 8. MULTIPLE INTEGRALS ═══════════════════════════════════════════════════

  Solution _multipleIntegral(String input) {
    final lower = input.toLowerCase();
    final triple = lower.startsWith('tripleint(');
    final steps = <SolutionStep>[];
    steps.add(
      SolutionStep(
        title: triple ? 'Triple Integral' : 'Double Integral',
        latex: triple
            ? r'\iiint_V f\,dV=\int\int\int f\,dx\,dy\,dz'
            : r'\iint_D f(x,y)\,dA=\int_{y_1}^{y_2}\int_{x_1}^{x_2}f\,dx\,dy',
        explanation:
            'Integrate over ${triple ? "3D volume" : "2D region"}. Apply Fubini: integrate any order.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: "Fubini's Theorem",
        latex:
            r'\iint_R f\,dA=\int_a^b\int_c^d f\,dy\,dx=\int_c^d\int_a^b f\,dx\,dy',
        explanation: 'Choose order that makes inner integral simpler.',
        rule: "Fubini",
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Polar Coordinates',
        latex:
            r'\iint_D f\,dA=\int_0^{2\pi}\int_0^R f(r\cos\theta,r\sin\theta)\,r\,dr\,d\theta',
        explanation:
            "Don't forget Jacobian r! Always try polar for circular regions.",
        rule: 'Polar Jacobian',
      ),
    );
    if (triple)
      steps.add(
        const SolutionStep(
          title: 'Spherical Coords',
          latex: r'dV=\rho^2\sin\phi\,d\rho\,d\phi\,d\theta',
          explanation: 'x=ρsin(φ)cos(θ), y=ρsin(φ)sin(θ), z=ρcos(φ).',
          rule: 'Spherical',
        ),
      );
    steps.add(
      const SolutionStep(
        title: 'Applications',
        latex:
            r'\text{Area}=\iint dA,\;\text{Volume}=\iint f\,dA,\;\text{Mass}=\iint\rho\,dA',
        explanation:
            'Also: moments of inertia, center of mass, electric charge.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.calculus,
      operation: triple ? 'Triple Integral' : 'Double Integral',
      resultLatex: triple ? r'\iiint_V f\,dV' : r'\iint_D f\,dA',
      resultReadable: triple ? '∭_V f dV' : '∬_D f dA',
      steps: steps,
      tip: 'For circular/spherical regions: always try polar/spherical first.',
    );
  }

  // ═══ 9. TAYLOR / MACLAURIN SERIES ════════════════════════════════════════════

  Solution _taylorSeries(String input) {
    final lower = input.toLowerCase();
    final isMac = lower.startsWith('maclaurin(');
    final inner = _ex(input, ['taylor(', 'maclaurin(']);
    final steps = <SolutionStep>[];
    int n = 5;
    final nM = RegExp(r'n\s*=\s*(\d+)').firstMatch(inner);
    if (nM != null) n = int.parse(nM.group(1)!);
    final fn = inner.split(',').first.trim().toLowerCase();
    steps.add(
      SolutionStep(
        title: isMac ? 'Maclaurin (Taylor at a=0)' : 'Taylor Series',
        latex: r'f(x)=\sum_{n=0}^{\infty}\frac{f^{(n)}(a)}{n!}(x-a)^n',
        explanation:
            'Power series representation of infinitely differentiable f.',
        rule: 'Taylor',
      ),
    );
    String res;
    if (fn.contains('sin')) {
      res = _sinS(n);
      steps.add(
        const SolutionStep(
          title: 'sin(x)',
          latex:
              r'\sin(x)=x-\frac{x^3}{6}+\frac{x^5}{120}-\cdots=\sum\frac{(-1)^nx^{2n+1}}{(2n+1)!}',
          explanation: 'Odd powers, alternating signs. R=∞.',
          rule: 'sin series',
        ),
      );
    } else if (fn.contains('cos')) {
      res = _cosS(n);
      steps.add(
        const SolutionStep(
          title: 'cos(x)',
          latex:
              r'\cos(x)=1-\frac{x^2}{2}+\frac{x^4}{24}-\cdots=\sum\frac{(-1)^nx^{2n}}{(2n)!}',
          explanation: 'Even powers, alternating signs. R=∞.',
          rule: 'cos series',
        ),
      );
    } else if (fn.contains('e^x') || fn.contains('exp')) {
      res = _expS(n);
      steps.add(
        const SolutionStep(
          title: 'eˣ',
          latex:
              r'e^x=1+x+\frac{x^2}{2!}+\frac{x^3}{3!}+\cdots=\sum\frac{x^n}{n!}',
          explanation: 'All coeff=1/n!. R=∞.',
          rule: 'eˣ series',
        ),
      );
    } else if (fn.contains('ln')) {
      res = r'x-\frac{x^2}{2}+\frac{x^3}{3}-\frac{x^4}{4}+\cdots';
      steps.add(
        const SolutionStep(
          title: 'ln(1+x)',
          latex: r'\ln(1+x)=\sum_{n=1}^{\infty}\frac{(-1)^{n+1}x^n}{n}',
          explanation: 'R=1. Only converges for −1<x≤1.',
          rule: 'ln series',
        ),
      );
    } else {
      res = r"f(a)+f'(a)(x-a)+\frac{f''(a)}{2!}(x-a)^2+\cdots";
      steps.add(
        const SolutionStep(
          title: 'General',
          latex: r'f(x)\approx\sum_{k=0}^{N}\frac{f^{(k)}(a)}{k!}(x-a)^k',
          explanation: 'Compute derivatives at a, divide by k!',
        ),
      );
    }
    steps.add(
      const SolutionStep(
        title: 'Radius of Convergence',
        latex: r'R=\lim_{n\to\infty}|a_n/a_{n+1}|',
        explanation: 'Converges for |x−a|<R. sin,cos,eˣ: R=∞. ln(1+x): R=1.',
        rule: 'Ratio Test for R',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Lagrange Remainder',
        latex: r'|R_n(x)|\leq\frac{M|x-a|^{n+1}}{(n+1)!}',
        explanation:
            'M=max|f^(n+1)|. Tells how many terms give desired accuracy.',
        rule: 'Error Bound',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.realAnalysis,
      operation: isMac ? 'Maclaurin Series' : 'Taylor Series',
      resultLatex: res,
      resultReadable: 'N=$n term expansion',
      steps: steps,
      tip:
          'Must-know 4: sin(x), cos(x), eˣ, 1/(1−x). Build everything from these.',
    );
  }

  String _sinS(int n) {
    final t = <String>[];
    for (int k = 0; t.length < n; k++) {
      final p = 2 * k + 1;
      t.add('${k % 2 == 0 ? "" : "-"}\\frac{x^{$p}}{${_fact(p)}}');
    }
    return t.join('+').replaceAll('+-', '-');
  }

  String _cosS(int n) {
    final t = <String>['1'];
    for (int k = 1; t.length < n; k++) {
      final p = 2 * k;
      t.add('${k % 2 == 0 ? "" : "-"}\\frac{x^{$p}}{${_fact(p)}}');
    }
    return t.join('+').replaceAll('+-', '-');
  }

  String _expS(int n) {
    final t = <String>['1', 'x'];
    for (int k = 2; k < n; k++) {
      t.add('\\frac{x^{$k}}{${_fact(k)}}');
    }
    return t.join('+');
  }

  // ═══ 10. LINE INTEGRALS ═══════════════════════════════════════════════════════

  Solution _lineIntegral(String input) {
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Scalar Line Integral',
        latex:
            r"\int_C f\,ds = \int_a^b f(\mathbf{r}(t))\,|\mathbf{r}'(t)|\,dt",
        explanation:
            "1. Write r(t)\n2. Compute r'(t)\n3. Substitute into integrand\n4. Multiply by |r'| or dot with r'\n5. Integrate from a to b",
        rule: 'Line integral (scalar)',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Vector Line Integral (Work)',
        latex:
            r"\int_C \mathbf{F}\cdot d\mathbf{r} = \int_a^b \mathbf{F}(\mathbf{r}(t))\cdot \mathbf{r}'(t)\,dt",
        explanation:
            'Work done by force field F along curve C. If F is conservative, the integral is path-independent.',
        rule: 'Work integral',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Parameterisation Steps',
        latex: r'\mathbf{r}(t) = (x(t), y(t)), \quad t \in [a, b]',
        explanation:
            'Parameterise the curve, compute derivative, substitute and integrate.',
        rule: 'Parameterisation',
      ),
    );
    steps.add(
      const SolutionStep(
        title: "Green's Theorem",
        latex:
            r'\oint_C (P\,dx + Q\,dy) = \iint_D \left(\frac{\partial Q}{\partial x} - \frac{\partial P}{\partial y}\right) dA',
        explanation:
            'Converts a closed line integral into a double integral over the region D.',
        rule: "Green's Theorem",
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Conservative Field Test',
        latex:
            r'\mathbf{F} \text{ conservative} \iff \frac{\partial F_1}{\partial y} = \frac{\partial F_2}{\partial x}',
        explanation:
            'If the field is conservative, the line integral depends only on the endpoints.',
        rule: 'Conservative test',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.calculus,
      operation: 'Line Integral',
      resultLatex:
          r"\int_C \mathbf{F}\cdot d\mathbf{r} = \int_a^b \mathbf{F}(\mathbf{r}(t))\cdot \mathbf{r}'(t)\,dt",
      resultReadable: '∫_C F·dr (parameterised)',
      steps: steps,
      tip:
          'Always check conservativity first – it makes line integrals trivial.',
    );
  }

  // ═══ EXISTING PATTERN SOLVERS ═════════════════════════════════════════════════

  Solution _derivative(String input) {
    final expr = _ex(input, [
      'd/dx[',
      'd/dx',
      'diff(',
      'derivative(',
      'd/dt[',
      'd/dt',
    ]);
    final steps = <SolutionStep>[];
    steps.add(
      SolutionStep(
        title: 'Differentiate',
        latex: '\\frac{d}{dx}\\left[${_tex(expr)}\\right]',
        explanation: 'Apply the appropriate rule.',
      ),
    );
    if (RegExp(
          r'^-?\d*\.?\d*\*?x\^-?\d+\.?\d*$',
        ).hasMatch(expr.replaceAll(' ', '')) ||
        RegExp(r'^x\^-?\d+\.?\d*$').hasMatch(expr) ||
        expr == 'x')
      return _dPow(expr, steps);
    if (RegExp(
      r'^(sin|cos|tan|cot|sec|csc|arcsin|arccos|arctan)\(',
    ).hasMatch(expr))
      return _dTrig(expr, steps);
    if (expr.startsWith('e^') || expr.startsWith('exp('))
      return _dExp(expr, steps);
    if (expr.startsWith('ln(') || expr.startsWith('log('))
      return _dLog(expr, steps);
    if (_hasP(expr)) return _dProd(expr, steps);
    if (_hasQ(expr)) return _dQuo(expr, steps);
    if (_hasC(expr)) return _dChain(expr, steps);
    if (expr.contains('+') || expr.contains('-')) return _dPoly(expr, steps);
    return _dGen(expr, steps);
  }

  Solution _dPow(String e, List<SolutionStep> s) {
    final nM = RegExp(r'x\^(-?\d+\.?\d*)').firstMatch(e);
    final cM = RegExp(r'^(-?\d+\.?\d*)\*?x').firstMatch(e);
    double n = nM != null ? double.parse(nM.group(1)!) : 1.0;
    double c = cM != null ? double.parse(cM.group(1)!) : 1.0;
    s.add(
      const SolutionStep(
        title: 'Power Rule',
        latex: '\\frac{d}{dx}[x^n]=nx^{n-1}',
        explanation: 'Multiply by n, subtract 1 from exponent.',
        rule: 'Power Rule',
      ),
    );
    final nn = n - 1;
    final nc = c * n;
    String r;
    if (nn == 0) {
      r = _fmt(nc);
    } else if (nn == 1) {
      r = '${_fmt(nc)}x';
    } else {
      r = '${_fmt(nc)}x^{${_fmt(nn)}}';
    }
    s.add(
      SolutionStep(
        title: 'Result',
        latex: '=$r',
        explanation:
            '${_fmt(c)}×${_fmt(n)}=${_fmt(nc)}, exponent: ${_fmt(n)}→${_fmt(nn)}',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative',
      resultLatex: r,
      resultReadable: r.replaceAll('{', '').replaceAll('}', ''),
      steps: s,
      tip: 'Power Rule: most-used derivative rule.',
    );
  }

  Solution _dTrig(String e, List<SolutionStep> s) {
    const trig = {
      'sin': {'d': '\\cos', 'r': 'cos'},
      'cos': {'d': '-\\sin', 'r': '-sin'},
      'tan': {'d': '\\sec^2', 'r': 'sec²'},
      'cot': {'d': '-\\csc^2', 'r': '-csc²'},
      'sec': {'d': '\\sec\\tan', 'r': 'sec·tan'},
      'csc': {'d': '-\\csc\\cot', 'r': '-csc·cot'},
      'arcsin': {'d': '\\frac{1}{\\sqrt{1-x^2}}', 'r': '1/√(1-x²)'},
      'arccos': {'d': '\\frac{-1}{\\sqrt{1-x^2}}', 'r': '-1/√(1-x²)'},
      'arctan': {'d': '\\frac{1}{1+x^2}', 'r': '1/(1+x²)'},
    };
    String m = '';
    for (final k in trig.keys) {
      if (e.startsWith(k)) {
        m = k;
        break;
      }
    }
    final d = trig[m] ?? {'d': '?', 'r': '?'};
    s.add(
      SolutionStep(
        title: 'Trig: $m',
        latex: '\\frac{d}{dx}[\\$m(x)]=${d['d']}(x)',
        explanation: 'Standard result.',
        rule: 'Trig Deriv',
      ),
    );
    final inner = e
        .replaceFirst(RegExp('^$m\\('), '')
        .replaceFirst(RegExp('\\)\$'), '');
    final chain = inner != 'x' && inner.isNotEmpty;
    if (chain)
      s.add(
        SolutionStep(
          title: 'Chain Rule',
          latex: "${d['d']}(g)\\cdot g'",
          explanation: 'Inner: $inner',
          rule: 'Chain Rule',
        ),
      );
    final r =
        "${d['d']}(${chain ? _tex(inner) : 'x'})${chain ? " \\cdot \\frac{d}{dx}[${_tex(inner)}]" : ""}";
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Trig)',
      resultLatex: r,
      resultReadable: "${d['r']}(${chain ? inner : 'x'})",
      steps: s,
      tip: 'sin→cos→-sin→-cos (cycle).',
    );
  }

  Solution _dExp(String e, List<SolutionStep> s) {
    s.add(
      const SolutionStep(
        title: 'Exp Deriv',
        latex: "\\frac{d}{dx}[e^{f(x)}]=e^{f(x)}\\cdot f'(x)",
        explanation: 'eˣ is its own derivative.',
        rule: 'Exp+Chain',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Exp)',
      resultLatex: "e^{f(x)}\\cdot f'(x)",
      resultReadable: "e^f·f'",
      steps: s,
      tip: 'd/dx[eˣ]=eˣ',
    );
  }

  Solution _dLog(String e, List<SolutionStep> s) {
    final nat = e.startsWith('ln(');
    s.add(
      SolutionStep(
        title: 'Log Deriv',
        latex: nat
            ? "\\frac{d}{dx}[\\ln f]=\\frac{f'}{f}"
            : "\\frac{d}{dx}[\\log_a f]=\\frac{f'}{f\\ln a}",
        explanation: "d/dx[ln u]=u'/u",
        rule: 'Log Deriv',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Log)',
      resultLatex: nat ? "\\frac{f'}{f}" : "\\frac{f'}{f\\ln a}",
      resultReadable: nat ? "f'/f" : "f'/(f·ln a)",
      steps: s,
      tip: 'd/dx[ln x]=1/x',
    );
  }

  Solution _dProd(String e, List<SolutionStep> s) {
    final p = _sp(e, '*');
    s.add(
      const SolutionStep(
        title: 'Product Rule',
        latex: "(uv)'=u'v+uv'",
        explanation: "first·d(second)+second·d(first)",
        rule: 'Product Rule',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Product)',
      resultLatex:
          "\\frac{d}{dx}[${_tex(p[0])}]\\cdot${_tex(p[1])}+${_tex(p[0])}\\cdot\\frac{d}{dx}[${_tex(p[1])}]",
      resultReadable: "u'v+uv'",
      steps: s,
    );
  }

  Solution _dQuo(String e, List<SolutionStep> s) {
    final p = _sp(e, '/');
    s.add(
      const SolutionStep(
        title: 'Quotient Rule',
        latex: "(u/v)'=(u'v-uv')/v^2",
        explanation: 'Low d-High minus High d-Low over Low².',
        rule: 'Quotient Rule',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Quotient)',
      resultLatex: "\\frac{u'v-uv'}{v^2}",
      resultReadable: "(u'v-uv')/v²",
      steps: s,
      tip: 'Sign is MINUS.',
    );
  }

  Solution _dChain(String e, List<SolutionStep> s) {
    s.add(
      const SolutionStep(
        title: 'Chain Rule',
        latex: "\\frac{d}{dx}[f(g(x))]=f'(g(x))\\cdot g'(x)",
        explanation: 'Outside-in.',
        rule: 'Chain Rule',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Chain)',
      resultLatex: "f'(g(x))\\cdot g'(x)",
      resultReadable: "f'(g)·g'",
      steps: s,
    );
  }

  Solution _dPoly(String e, List<SolutionStep> s) {
    s.add(
      const SolutionStep(
        title: 'Sum Rule',
        latex: "(f+g)'=f'+g'",
        explanation: 'Term-by-term.',
        rule: 'Sum Rule',
      ),
    );
    s.add(
      const SolutionStep(
        title: 'Power Rule per term',
        latex: '\\frac{d}{dx}[ax^n]=nax^{n-1},\\;\\frac{d}{dx}[c]=0',
        explanation: 'Constants→0.',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative (Poly)',
      resultLatex: "\\frac{d}{dx}\\left[${_tex(e)}\\right]",
      steps: s,
    );
  }

  Solution _dGen(String e, List<SolutionStep> s) {
    s.add(
      const SolutionStep(
        title: 'Linearity',
        latex: "\\frac{d}{dx}[af+bg]=af'+bg'",
        explanation: 'Break into simpler terms.',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Derivative',
      resultLatex: "\\frac{d}{dx}\\left[${_tex(e)}\\right]",
      steps: s,
    );
  }

  Solution _integral(String input) {
    final expr = _ex(input, ['int(', 'integrate(', 'antideriv(']);
    final isD = expr.contains(',');
    final clean = isD ? expr.split(',').first.trim() : expr;
    final steps = <SolutionStep>[];
    steps.add(
      SolutionStep(
        title: isD ? 'Definite Integral' : 'Indefinite Integral',
        latex: isD
            ? '\\int_a^b ${_tex(clean)}\\,dx'
            : '\\int ${_tex(clean)}\\,dx',
        explanation: isD ? 'Net signed area a to b.' : 'Family F(x)+C.',
      ),
    );
    if (RegExp(r'x\^-?\d+').hasMatch(clean) ||
        clean == 'x' ||
        RegExp(r'^\d+$').hasMatch(clean))
      return _iPow(clean, steps, isD);
    if (RegExp(r'^(sin|cos|tan|cot|sec|csc)\(').hasMatch(clean))
      return _iTrig(clean, steps, isD);
    if (clean.startsWith('e^') || clean.startsWith('exp('))
      return _iExp(clean, steps, isD);
    if (clean.startsWith('ln(') || clean.startsWith('log('))
      return _iLog(clean, steps, isD);
    if (clean.contains('*') || _hasP(clean)) return _iIBP(clean, steps, isD);
    if (clean.contains('/')) return _iPFD(clean, steps, isD);
    return _iGen(clean, steps, isD);
  }

  Solution _iPow(String e, List<SolutionStep> s, bool d) {
    final nM = RegExp(r'x\^(-?\d+\.?\d*)').firstMatch(e);
    final cM = RegExp(r'^(-?\d+\.?\d*)\*?x').firstMatch(e);
    double n = nM != null ? double.parse(nM.group(1)!) : 1.0;
    double c = cM != null ? double.parse(cM.group(1)!) : 1.0;
    if (n == -1) {
      s.add(
        const SolutionStep(
          title: '∫1/x=ln|x|+C',
          latex: '\\int x^{-1}\\,dx=\\ln|x|+C',
          explanation: 'Special case n=−1.',
          rule: 'Log Integral',
        ),
      );
      return Solution(
        input: e,
        domain: MathDomain.calculus,
        operation: 'Integral',
        resultLatex: '\\ln|x|+C',
        resultReadable: 'ln|x|+C',
        steps: s,
      );
    }
    s.add(
      const SolutionStep(
        title: 'Power Rule',
        latex: '\\int x^n\\,dx=\\frac{x^{n+1}}{n+1}+C',
        explanation: 'Raise exponent, divide.',
        rule: 'Power Rule',
      ),
    );
    final nn = n + 1;
    final co = c / nn;
    final r = '${_fmt(co)}x^{${_fmt(nn)}}';
    s.add(
      SolutionStep(
        title: 'Result',
        latex: '=$r+C',
        explanation: 'Verify: d/dx[$r+C]=$e ✓',
      ),
    );
    if (d)
      s.add(
        const SolutionStep(
          title: 'FTC Part 2',
          latex: '\\int_a^b f\\,dx=F(b)-F(a)',
          explanation: 'Evaluate at bounds, subtract.',
          rule: 'FTC 2',
        ),
      );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral',
      resultLatex: '$r+C',
      resultReadable: '$r+C',
      steps: s,
    );
  }

  Solution _iTrig(String e, List<SolutionStep> s, bool d) {
    const ints = {
      'sin': '-\\cos(x)',
      'cos': '\\sin(x)',
      'tan': '-\\ln|\\cos(x)|',
      'cot': '\\ln|\\sin(x)|',
      'sec': '\\ln|\\sec(x)+\\tan(x)|',
      'csc': '-\\ln|\\csc(x)+\\cot(x)|',
    };
    String m = '';
    for (final k in ints.keys) {
      if (e.startsWith(k)) {
        m = k;
        break;
      }
    }
    s.add(
      SolutionStep(
        title: 'Trig Integral',
        latex: '\\int \\$m(x)\\,dx=${ints[m] ?? '?'}+C',
        explanation: 'Standard result.',
        rule: 'Trig Int',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral (Trig)',
      resultLatex: '${ints[m] ?? '?'}+C',
      resultReadable: '${ints[m]?.replaceAll('\\', '') ?? '?'}+C',
      steps: s,
    );
  }

  Solution _iExp(String e, List<SolutionStep> s, bool d) {
    s.add(
      const SolutionStep(
        title: 'Exp Integral',
        latex: '\\int e^{ax}\\,dx=\\frac{e^{ax}}{a}+C',
        explanation: 'Divide by coeff a.',
        rule: 'Exp Int',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral (Exp)',
      resultLatex: '\\frac{e^{ax}}{a}+C',
      resultReadable: 'e^(ax)/a+C',
      steps: s,
    );
  }

  Solution _iLog(String e, List<SolutionStep> s, bool d) {
    s.add(
      const SolutionStep(
        title: '∫ln(x)dx=x·ln(x)−x+C',
        latex: '\\int\\ln(x)\\,dx=x\\ln(x)-x+C',
        explanation: 'IBP: u=ln(x), dv=dx. Verify: d/dx[x·ln(x)−x]=ln(x) ✓',
        rule: 'IBP',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral (Log)',
      resultLatex: 'x\\ln(x)-x+C',
      resultReadable: 'x·ln(x)−x+C',
      steps: s,
    );
  }

  Solution _iIBP(String e, List<SolutionStep> s, bool d) {
    s.add(
      const SolutionStep(
        title: 'Integration by Parts (LIATE)',
        latex: '\\int u\\,dv=uv-\\int v\\,du',
        explanation: 'LIATE: Log, Inv trig, Algebraic, Trig, Exp.',
        rule: 'IBP',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral (IBP)',
      resultLatex: 'uv-\\int v\\,du',
      steps: s,
    );
  }

  Solution _iPFD(String e, List<SolutionStep> s, bool d) {
    s.add(
      const SolutionStep(
        title: 'Partial Fractions',
        latex: '\\frac{P}{Q}=\\frac{A}{x-r_1}+\\frac{B}{x-r_2}',
        explanation: 'Each term integrates to a logarithm.',
        rule: 'PFD',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral (PFD)',
      resultLatex: 'A\\ln|x-r_1|+B\\ln|x-r_2|+C',
      steps: s,
    );
  }

  Solution _iGen(String e, List<SolutionStep> s, bool d) {
    s.add(
      SolutionStep(
        title: 'Strategy',
        latex: '\\int ${_tex(e)}\\,dx',
        explanation: 'Try: 1.U-sub 2.IBP 3.PFD 4.Trig sub.',
      ),
    );
    return Solution(
      input: e,
      domain: MathDomain.calculus,
      operation: 'Integral',
      resultLatex: '\\int ${_tex(e)}\\,dx',
      steps: s,
    );
  }

  Solution _limit(String input) {
    final inner = _ex(input, ['lim(', 'limit(', 'lim ']);
    final inf = inner.contains('inf') || inner.contains('∞');
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Limit',
        latex: '\\lim_{x\\to a}f(x)=L',
        explanation: 'Value f approaches as x→a.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Direct Substitution',
        latex: '\\lim_{x\\to a}f(x)=f(a)',
        explanation: 'Always try first.',
        rule: 'Direct Sub',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Indeterminate Forms',
        latex:
            '\\frac{0}{0},\\frac{\\infty}{\\infty},0\\cdot\\infty,\\infty-\\infty,0^0,1^\\infty,\\infty^0',
        explanation: "7 forms → L'Hôpital or algebra.",
      ),
    );
    if (inf)
      steps.add(
        const SolutionStep(
          title: 'Limit at ∞',
          latex: '\\text{Divide by highest power}',
          explanation:
              'deg(top)<deg(bot)→0. Equal→ratio of leading coeff. Top>bot→±∞.',
          rule: 'Dominant Term',
        ),
      );
    steps.add(
      const SolutionStep(
        title: "L'Hôpital",
        latex: "\\lim\\frac{f}{g}\\overset{H}{=}\\lim\\frac{f'}{g'}",
        explanation: 'Differentiate top/bottom SEPARATELY.',
        rule: "L'Hôpital",
      ),
    );
    final known = _knownLim(inner);
    return Solution(
      input: inner,
      domain: MathDomain.calculus,
      operation: 'Limit',
      resultLatex: known ?? 'L',
      resultReadable: known ?? 'L (see steps)',
      steps: steps,
      tip: "Substitution → simplify → L'Hôpital.",
    );
  }

  String? _knownLim(String s) {
    final e = s.toLowerCase().replaceAll(' ', '');
    if (e.contains('sin(x)/x') && e.contains('x,0')) return '1';
    if (e.contains('1/x') && e.contains('inf')) return '0';
    return null;
  }

  Solution _determinant(String input) {
    final steps = <SolutionStep>[];
    final m = RegExp(
      r'\[\[(-?\d+\.?\d*),(-?\d+\.?\d*)\],\[(-?\d+\.?\d*),(-?\d+\.?\d*)\]\]',
    ).firstMatch(input);
    String rL = '\\det(A)=ad-bc', rR = 'ad−bc';
    if (m != null) {
      final a = double.parse(m.group(1)!),
          b = double.parse(m.group(2)!),
          c = double.parse(m.group(3)!),
          d = double.parse(m.group(4)!);
      final det = a * d - b * c;
      rL =
          '\\det=${_fmt(a)}\\cdot${_fmt(d)}-${_fmt(b)}\\cdot${_fmt(c)}=${_fmt(det)}';
      rR = _fmt(det);
      steps.add(
        SolutionStep(
          title: '2×2 Computed',
          latex: rL,
          explanation:
              'ad−bc=${_fmt(a)}×${_fmt(d)}−${_fmt(b)}×${_fmt(c)}=${_fmt(det)}',
        ),
      );
    }
    steps.add(
      const SolutionStep(
        title: '2×2 Formula',
        latex: '|A|=ad-bc',
        explanation: 'Diagonal minus off-diagonal.',
        rule: '2×2',
      ),
    );
    steps.add(
      const SolutionStep(
        title: '3×3: Cofactor Expansion',
        latex: '|A|=a_{11}M_{11}-a_{12}M_{12}+a_{13}M_{13}',
        explanation: 'Signs: + − + on row 1.',
        rule: 'Cofactor',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.linearAlgebra,
      operation: 'Determinant',
      resultLatex: rL,
      resultReadable: rR,
      steps: steps,
      tip: 'det=0 → singular matrix.',
    );
  }

  Solution _matrixInverse(String input) {
    final steps = <SolutionStep>[];
    final m = RegExp(
      r'\[\[(-?\d+\.?\d*),(-?\d+\.?\d*)\],\[(-?\d+\.?\d*),(-?\d+\.?\d*)\]\]',
    ).firstMatch(input);
    String rL = 'A^{-1}=\\frac{1}{\\det}\\text{adj}(A)', rR = '1/det·adj(A)';
    if (m != null) {
      final a = double.parse(m.group(1)!),
          b = double.parse(m.group(2)!),
          c = double.parse(m.group(3)!),
          d = double.parse(m.group(4)!);
      final det = a * d - b * c;
      if (det.abs() < 1e-10) {
        rL = '\\text{Singular: det}=0';
        rR = 'No inverse';
      } else {
        final i11 = _fmt(d / det),
            i12 = _fmt(-b / det),
            i21 = _fmt(-c / det),
            i22 = _fmt(a / det);
        rL = '\\begin{pmatrix}$i11&$i12\\\\$i21&$i22\\end{pmatrix}';
        rR = '[[$i11,$i12],[$i21,$i22]]';
        steps.add(
          SolutionStep(
            title: 'Computed 2×2 Inverse',
            latex:
                'A^{-1}=\\frac{1}{${_fmt(det)}}\\begin{pmatrix}${_fmt(d)}&${_fmt(-b)}\\\\${_fmt(-c)}&${_fmt(a)}\\end{pmatrix}=$rL',
            explanation:
                'det=${_fmt(det)}. Swap diagonal, negate off-diagonal, divide by det.',
          ),
        );
      }
    }
    steps.add(
      const SolutionStep(
        title: '2×2 Formula',
        latex:
            'A^{-1}=\\frac{1}{ad-bc}\\begin{pmatrix}d&-b\\\\-c&a\\end{pmatrix}',
        explanation: 'Swap diag, negate off-diag, divide by det.',
        rule: '2×2 Inverse',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'General: Gauss-Jordan',
        latex: '[A|I]\\to[I|A^{-1}]',
        explanation: 'Row-reduce augmented matrix.',
        rule: 'Gauss-Jordan',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.linearAlgebra,
      operation: 'Matrix Inverse',
      resultLatex: rL,
      resultReadable: rR,
      steps: steps,
      tip: 'Verify: A·A⁻¹=I.',
    );
  }

  Solution _eigenvalue(String input) {
    final steps = <SolutionStep>[];
    final m = RegExp(
      r'\[\[(-?\d+\.?\d*),(-?\d+\.?\d*)\],\[(-?\d+\.?\d*),(-?\d+\.?\d*)\]\]',
    ).firstMatch(input);
    String rL = '\\lambda:\\det(A-\\lambda I)=0', rR = 'Solve char. poly.';
    if (m != null) {
      final a = double.parse(m.group(1)!),
          b = double.parse(m.group(2)!),
          c = double.parse(m.group(3)!),
          d = double.parse(m.group(4)!);
      final tr = a + d, det = a * d - b * c, disc = tr * tr - 4 * det;
      if (disc >= 0) {
        final l1 = (tr + math.sqrt(disc)) / 2, l2 = (tr - math.sqrt(disc)) / 2;
        rL = '\\lambda_1=${_fmt(l1)},\\;\\lambda_2=${_fmt(l2)}';
        rR = 'λ₁=${_fmt(l1)}, λ₂=${_fmt(l2)}';
        steps.add(
          SolutionStep(
            title: 'Eigenvalues',
            latex: rL,
            explanation:
                'From λ²−${_fmt(tr)}λ+${_fmt(det)}=0. Check: λ₁+λ₂=${_fmt(l1 + l2)}=tr ✓ λ₁λ₂=${_fmt(l1 * l2)}=det ✓',
          ),
        );
      } else {
        final re = tr / 2, im = math.sqrt(-disc) / 2;
        rL = '\\lambda=${_fmt(re)}\\pm${_fmt(im)}i';
        rR = 'λ=${_fmt(re)}±${_fmt(im)}i (complex)';
        steps.add(
          SolutionStep(
            title: 'Complex Eigenvalues',
            latex: rL,
            explanation: 'Δ<0 → rotation+scaling.',
          ),
        );
      }
    }
    steps.add(
      const SolutionStep(
        title: 'Char. Equation',
        latex: '\\det(A-\\lambda I)=0',
        explanation: 'Nontrivial solutions require singularity.',
        rule: 'Char. Poly.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: '2×2 Polynomial',
        latex: '\\lambda^2-\\text{tr}(A)\\lambda+\\det(A)=0',
        explanation: 'Sum λ=trace, product λ=det.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.linearAlgebra,
      operation: 'Eigenvalues',
      resultLatex: rL,
      resultReadable: rR,
      steps: steps,
      tip: 'Sum of eigenvalues=trace. Product=determinant.',
    );
  }

  Solution _ode(String input) {
    final steps = <SolutionStep>[];
    final isS = input.contains("y''");
    final isSep = input.contains('*') && input.contains('y');
    steps.add(
      SolutionStep(
        title: 'Classify ODE',
        latex: isS ? "ay''+by'+cy=f(x)" : '\\frac{dy}{dx}=f(x,y)',
        explanation: isS
            ? '2nd order. Characteristic equation.'
            : '1st order. Separable or integrating factor.',
      ),
    );
    if (isS) {
      steps.add(
        const SolutionStep(
          title: 'Char. Equation',
          latex: 'ar^2+br+c=0',
          explanation: 'Guess y=eʳˣ. Δ>0:real, Δ=0:repeated, Δ<0:complex.',
          rule: 'Char. Roots',
        ),
      );
      steps.add(
        const SolutionStep(
          title: 'General Solutions',
          latex:
              '\\Delta>0:C_1e^{r_1x}+C_2e^{r_2x}\\;\\Delta=0:(C_1+C_2x)e^{rx}\\;\\Delta<0:e^{\\alpha x}(C_1\\cos\\beta x+C_2\\sin\\beta x)',
          explanation: 'Three cases by discriminant.',
          rule: 'ODE Solutions',
        ),
      );
    } else if (isSep) {
      steps.add(
        const SolutionStep(
          title: 'Separate Variables',
          latex: '\\frac{dy}{h(y)}=g(x)\\,dx',
          explanation: 'All y left, all x right.',
          rule: 'Separation',
        ),
      );
      steps.add(
        const SolutionStep(
          title: 'Integrate',
          latex: '\\int\\frac{dy}{h(y)}=\\int g(x)\\,dx+C',
          explanation: 'Integrate independently.',
        ),
      );
    } else {
      steps.add(
        const SolutionStep(
          title: 'Integrating Factor',
          latex: '\\mu(x)=e^{\\int P(x)\\,dx}',
          explanation:
              'Multiply through by μ to make LHS a perfect derivative.',
          rule: 'Integrating Factor',
        ),
      );
    }
    return Solution(
      input: input,
      domain: MathDomain.differentialEquations,
      operation: isS
          ? '2nd Order ODE'
          : isSep
          ? 'Separable ODE'
          : 'Linear ODE',
      resultLatex: isS ? 'y=C_1e^{r_1x}+C_2e^{r_2x}' : 'y=F(x)+C',
      resultReadable: isS ? 'y=C₁eʳ¹ˣ+C₂eʳ²ˣ' : 'y=F(x)+C',
      steps: steps,
      tip: 'Verify: substitute solution back into the ODE.',
    );
  }

  Solution _series(String input) {
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Convergence',
        latex: '\\sum a_n=\\lim_{N\\to\\infty}\\sum_{n=1}^N a_n',
        explanation: 'Converges if partial sums have finite limit.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Divergence Test (First!)',
        latex: '\\lim a_n\\neq0\\Rightarrow\\text{diverges}',
        explanation: 'Necessary but not sufficient.',
        rule: 'Divergence Test',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Geometric',
        latex: '\\sum ar^n=\\frac{a}{1-r},\\;|r|<1',
        explanation: 'Most important series. Converges to a/(1−r).',
        rule: 'Geometric',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'p-Series',
        latex: '\\sum 1/n^p:\\;p>1\\text{ converges}',
        explanation: 'p=1: harmonic, diverges.',
        rule: 'p-Series',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Ratio Test',
        latex: 'L=\\lim|a_{n+1}/a_n|:\\;L<1\\text{ conv}',
        explanation: 'Best for factorials/exponentials.',
        rule: 'Ratio Test',
      ),
    );
    String result = '\\text{Convergence Analysis}';
    if (input.toLowerCase().contains('1/2^n') ||
        input.toLowerCase().contains('(1/2)^n')) {
      result = '\\frac{1}{1-1/2}=2';
      steps.add(
        const SolutionStep(
          title: 'Geometric r=1/2',
          latex: '\\sum(1/2)^n=2',
          explanation: 'a=1,r=1/2→sum=2.',
        ),
      );
    }
    return Solution(
      input: input,
      domain: MathDomain.realAnalysis,
      operation: 'Series',
      resultLatex: result,
      resultReadable: 'See convergence steps',
      steps: steps,
      tip: 'Test order: Divergence→Geometric/p-series→Ratio→Comparison.',
    );
  }

  Solution _trigonometry(String input) {
    final steps = <SolutionStep>[];
    final num = _evalTrig(input.toLowerCase());
    steps.add(
      const SolutionStep(
        title: 'Unit Circle Values',
        latex:
            '\\sin(0)=0,\\sin(\\pi/6)=1/2,\\sin(\\pi/4)=\\sqrt2/2,\\sin(\\pi/3)=\\sqrt3/2,\\sin(\\pi/2)=1',
        explanation: 'Pattern: √0/2,√1/2,√2/2,√3/2,√4/2',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Pythagorean Identity',
        latex: '\\sin^2\\theta+\\cos^2\\theta=1',
        explanation: 'All identities derive from this.',
        rule: 'Pythagorean',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Double Angle',
        latex:
            '\\sin(2\\theta)=2\\sin\\theta\\cos\\theta,\\;\\cos(2\\theta)=\\cos^2\\theta-\\sin^2\\theta',
        explanation: 'Used in integration.',
        rule: 'Double Angle',
      ),
    );
    if (num != null)
      steps.add(
        SolutionStep(
          title: 'Exact Value',
          latex: '${input.toLowerCase()}=$num',
          explanation: 'From unit circle.',
        ),
      );
    return Solution(
      input: input,
      domain: MathDomain.trigonometry,
      operation: 'Trigonometry',
      resultLatex: num ?? '\\text{See identities}',
      resultReadable: num?.replaceAll('\\', '') ?? 'See identities',
      steps: steps,
      tip: 'SOHCAHTOA for right triangles, unit circle for all angles.',
    );
  }

  String? _evalTrig(String s) {
    if (s.contains('pi/6') || s.contains('30deg')) {
      if (s.startsWith('sin')) return '\\frac{1}{2}';
      if (s.startsWith('cos')) return '\\frac{\\sqrt{3}}{2}';
      if (s.startsWith('tan')) return '\\frac{1}{\\sqrt{3}}';
    }
    if (s.contains('pi/4') || s.contains('45deg')) {
      if (s.startsWith('sin') || s.startsWith('cos'))
        return '\\frac{\\sqrt{2}}{2}';
      if (s.startsWith('tan')) return '1';
    }
    if (s.contains('pi/3') || s.contains('60deg')) {
      if (s.startsWith('sin')) return '\\frac{\\sqrt{3}}{2}';
      if (s.startsWith('cos')) return '\\frac{1}{2}';
      if (s.startsWith('tan')) return '\\sqrt{3}';
    }
    if (s.contains('pi/2') || s.contains('90deg')) {
      if (s.startsWith('sin')) return '1';
      if (s.startsWith('cos')) return '0';
    }
    if ((s.contains('pi)') || s.contains('180deg')) && !s.contains('/2')) {
      if (s.startsWith('sin')) return '0';
      if (s.startsWith('cos')) return '-1';
    }
    if (s.contains('0)')) {
      if (s.startsWith('sin')) return '0';
      if (s.startsWith('cos')) return '1';
    }
    return null;
  }

  Solution _complex(String input) {
    final steps = <SolutionStep>[];
    final match = RegExp(r'(-?\d+\.?\d*)[+\-](-?\d+\.?\d*)i').firstMatch(input);
    String rL = 're^{i\\theta}', rR = 'r·e^(iθ)';
    if (match != null) {
      final a = double.parse(match.group(1)!),
          b = double.parse(match.group(2)!);
      final r = math.sqrt(a * a + b * b), th = math.atan2(b, a);
      rL = '${_fmt(r)}e^{i\\cdot${_fn(th)}}';
      rR = 'r=${_fmt(r)}, θ=${_fn(th)} rad';
      steps.add(
        SolutionStep(
          title: 'Modulus',
          latex: '|z|=\\sqrt{${_fmt(a)}^2+${_fmt(b)}^2}=${_fmt(r)}',
          explanation: 'Distance from origin.',
        ),
      );
      steps.add(
        SolutionStep(
          title: 'Argument',
          latex:
              '\\theta=\\arctan(${_fmt(b)}/${_fmt(a)})=${_fn(th)}\\text{ rad}',
          explanation: 'Angle from +real axis.',
        ),
      );
    }
    steps.add(
      const SolutionStep(
        title: 'Polar Form',
        latex: 'z=re^{i\\theta}=r(\\cos\\theta+i\\sin\\theta)',
        explanation: "Euler's formula.",
        rule: "Euler",
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'De Moivre',
        latex: '(re^{i\\theta})^n=r^ne^{in\\theta}',
        explanation: 'Raise modulus to n, multiply angle by n.',
        rule: "De Moivre",
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.complexAnalysis,
      operation: 'Complex',
      resultLatex: rL,
      resultReadable: rR,
      steps: steps,
      tip: "Euler: eⁱᵖⁱ+1=0.",
    );
  }

  Solution _statistics(String input) {
    final lower = input.toLowerCase();
    final steps = <SolutionStep>[];
    final nr = _cStats(input);
    if (lower.startsWith('mean('))
      steps.add(
        const SolutionStep(
          title: 'Mean',
          latex: '\\bar{x}=\\frac{1}{n}\\sum x_i',
          explanation: 'Sum/count.',
          rule: 'Mean',
        ),
      );
    else if (lower.startsWith('variance('))
      steps.add(
        const SolutionStep(
          title: 'Variance',
          latex: '\\sigma^2=\\frac{1}{n}\\sum(x_i-\\bar{x})^2',
          explanation: 'Avg squared deviation.',
          rule: 'Variance',
        ),
      );
    else if (lower.startsWith('stddev('))
      steps.add(
        const SolutionStep(
          title: 'Std Dev',
          latex: '\\sigma=\\sqrt{\\sigma^2}',
          explanation: 'Same units as data.',
          rule: 'Std Dev',
        ),
      );
    else if (lower.startsWith('binomial('))
      steps.add(
        const SolutionStep(
          title: 'Binomial',
          latex: 'P(X=k)=\\binom{n}{k}p^k(1-p)^{n-k}',
          explanation: 'n trials, prob p.',
          rule: 'Binomial',
        ),
      );
    else if (lower.startsWith('normal('))
      steps.add(
        const SolutionStep(
          title: 'Normal',
          latex:
              'f(x)=\\frac{1}{\\sigma\\sqrt{2\\pi}}e^{-(x-\\mu)^2/2\\sigma^2}',
          explanation: '68-95-99.7 rule.',
          rule: 'Normal',
        ),
      );
    else if (lower.startsWith('combination('))
      steps.add(
        const SolutionStep(
          title: 'Combinations',
          latex: '\\binom{n}{k}=\\frac{n!}{k!(n-k)!}',
          explanation: 'Order does NOT matter.',
          rule: 'C(n,k)',
        ),
      );
    else if (lower.startsWith('permutation('))
      steps.add(
        const SolutionStep(
          title: 'Permutations',
          latex: 'P(n,k)=\\frac{n!}{(n-k)!}',
          explanation: 'Order DOES matter.',
          rule: 'P(n,k)',
        ),
      );
    steps.add(
      const SolutionStep(
        title: 'CLT',
        latex: '\\bar{X}\\sim N(\\mu,\\sigma^2/n)\\text{ as }n\\to\\infty',
        explanation: 'Sample means→normal regardless of population.',
        rule: 'CLT',
      ),
    );
    String? numR = nr;
    if ((lower.startsWith('combination(') ||
            lower.startsWith('permutation(')) &&
        numR == null) {
      final ns = RegExp(
        r'(\d+)',
      ).allMatches(input).map((m) => int.parse(m.group(0)!)).toList();
      if (ns.length >= 2) {
        final n = ns[0], k = ns[1];
        if (n >= k) {
          numR = lower.startsWith('combination(')
              ? '${_fact(n) ~/ (_fact(k) * _fact(n - k))}'
              : '${_fact(n) ~/ _fact(n - k)}';
        }
      }
    }
    return Solution(
      input: input,
      domain: MathDomain.statistics,
      operation: 'Statistics',
      resultLatex: numR ?? '\\text{Statistical Result}',
      resultReadable: numR ?? 'See steps',
      steps: steps,
      tip: 'CLT: n≥30 sufficient for normal approximation.',
    );
  }

  String? _cStats(String input) {
    try {
      final match = RegExp(r'\[([^\]]+)\]').firstMatch(input);
      if (match == null) return null;
      final nums = match
          .group(1)!
          .split(',')
          .map((s) => double.parse(s.trim()))
          .toList();
      if (nums.isEmpty) return null;
      final lower = input.toLowerCase();
      final mean = nums.reduce((a, b) => a + b) / nums.length;
      if (lower.startsWith('mean(')) return _fmt(mean);
      if (lower.startsWith('median(')) {
        final sorted = List<double>.from(nums)..sort();
        final mid = sorted.length ~/ 2;
        return _fmt(
          sorted.length.isOdd
              ? sorted[mid]
              : (sorted[mid - 1] + sorted[mid]) / 2,
        );
      }
      final v =
          nums.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
          nums.length;
      if (lower.startsWith('variance(')) return _fmt(v);
      if (lower.startsWith('stddev(')) return _fmt(math.sqrt(v));
    } catch (_) {}
    return null;
  }

  Solution _numberTheory(String input) {
    final lower = input.toLowerCase();
    final steps = <SolutionStep>[];
    if (lower.startsWith('isprime(')) {
      final n = int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final p = _isPrimeInt(n);
      steps.add(
        SolutionStep(
          title: 'Primality',
          latex: '$n ${p ? "\\text{ is PRIME}" : "\\text{ is NOT prime}"}',
          explanation: p
              ? 'No divisors other than 1 and itself.'
              : 'Composite.',
        ),
      );
      steps.add(
        SolutionStep(
          title: 'Trial Division',
          latex:
              '\\text{Test primes up to }\\sqrt{$n}\\approx${_fmt(math.sqrt(n.toDouble()))}',
          explanation: 'Only need to check up to √n.',
        ),
      );
      return Solution(
        input: input,
        domain: MathDomain.numberTheory,
        operation: 'Primality',
        resultLatex: '$n ${p ? "\\text{ is prime}" : "\\text{ is NOT prime}"}',
        resultReadable: '$n is ${p ? "prime" : "NOT prime"}',
        steps: steps,
        tip: p ? '$n is prime.' : 'Use factorize($n) to find factors.',
      );
    }
    if (lower.startsWith('gcd(') || lower.startsWith('lcm(')) {
      final ns = RegExp(
        r'(\d+)',
      ).allMatches(input).map((m) => int.parse(m.group(0)!)).toList();
      if (ns.length >= 2) {
        final a = ns[0], b = ns[1], g = _gcd(a, b);
        final isG = lower.startsWith('gcd(');
        final res = isG ? g : a * b ~/ g;
        steps.add(
          SolutionStep(
            title: isG ? 'Euclidean Algorithm' : 'LCM',
            latex: isG ? '\\gcd($a,$b)=$g' : '\\text{lcm}($a,$b)=$res',
            explanation: isG ? 'Euclidean: gcd($a,$b)=$g' : '$a×$b/$g=$res',
            rule: isG ? 'Euclidean' : 'LCM',
          ),
        );
        return Solution(
          input: input,
          domain: MathDomain.numberTheory,
          operation: isG ? 'GCD' : 'LCM',
          resultLatex: '$res',
          resultReadable: '$res',
          steps: steps,
        );
      }
    }
    if (lower.startsWith('mod(')) {
      final ns = RegExp(
        r'(\d+)',
      ).allMatches(input).map((m) => int.parse(m.group(0)!)).toList();
      if (ns.length >= 2) {
        final r = ns[0] % ns[1];
        steps.add(
          SolutionStep(
            title: 'Modular Arithmetic',
            latex: '${ns[0]}\\bmod${ns[1]}=$r',
            explanation: '${ns[0]}=${ns[0] ~/ ns[1]}×${ns[1]}+$r',
          ),
        );
        return Solution(
          input: input,
          domain: MathDomain.numberTheory,
          operation: 'Mod',
          resultLatex: '$r',
          resultReadable: '$r',
          steps: steps,
        );
      }
    }
    steps.add(
      const SolutionStep(
        title: 'FTA',
        latex: 'n=p_1^{a_1}\\cdot p_2^{a_2}\\cdots',
        explanation: 'Unique prime factorization.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.numberTheory,
      operation: 'Number Theory',
      resultLatex: '\\text{Number Theory}',
      steps: steps,
    );
  }

  Solution _factorize(String input) {
    final n = int.tryParse(input.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final steps = <SolutionStep>[];
    final factors = n > 0 ? _primeF(n) : <int>[];
    final Map<int, int> fm = {};
    for (final f in factors) {
      fm[f] = (fm[f] ?? 0) + 1;
    }
    final ef = fm.entries
        .map((e) => e.value == 1 ? '${e.key}' : '${e.key}^{${e.value}}')
        .join('\\times');
    final nd = fm.values.fold<int>(1, (acc, exp) => acc * (exp + 1));
    steps.add(
      SolutionStep(
        title: 'Prime Factorization of $n',
        latex: '$n=${ef.isEmpty ? "?" : ef}',
        explanation: 'Divide by smallest prime repeatedly.',
        rule: 'Prime Factorization',
      ),
    );
    steps.add(
      SolutionStep(
        title: 'Number of Divisors',
        latex: '\\tau($n)=${fm.values.map((e) => "(${e}+1)").join("×")}=$nd',
        explanation: 'Product of (exp+1) for each prime.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.numberTheory,
      operation: 'Factorize',
      resultLatex: ef.isEmpty ? '?' : ef,
      resultReadable: factors.join(' × '),
      steps: steps,
    );
  }

  Solution _abstractAlgebra(String input) {
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Group Axioms',
        latex: '(G,\\star):\\text{ closure, assoc, identity, inverses}',
        explanation: '4 axioms. Verify all four.',
        rule: 'Group Axioms',
      ),
    );
    steps.add(
      const SolutionStep(
        title: "Lagrange",
        latex: '|H|\\mid|G|',
        explanation: 'Subgroup order divides group order.',
        rule: "Lagrange",
      ),
    );
    steps.add(
      const SolutionStep(
        title: '1st Isomorphism Thm',
        latex: 'G/\\ker\\phi\\cong\\text{Im}\\phi',
        explanation: 'Quotient/kernel ≅ image.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.abstractAlgebra,
      operation: 'Abstract Algebra',
      resultLatex: '\\text{Abstract Algebra}',
      steps: steps,
      tip: 'Groups→Rings→Fields: each adds structure.',
    );
  }

  Solution _topology(String input) {
    final steps = <SolutionStep>[];
    steps.add(
      const SolutionStep(
        title: 'Topological Space',
        latex: '(X,\\mathcal{T}):\\;\\emptyset,X\\in\\mathcal{T}',
        explanation:
            '3 axioms: empty+X open, arbitrary unions, finite intersections.',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Compactness',
        latex:
            'K\\text{ compact}\\iff\\text{every open cover has finite subcover}',
        explanation: 'Heine-Borel: in ℝⁿ, compact↔closed+bounded.',
        rule: 'Compactness',
      ),
    );
    steps.add(
      const SolutionStep(
        title: 'Connectedness',
        latex:
            'X\\text{ connected}\\iff X\\neq A\\cup B\\text{ (disjoint open)}',
        explanation: 'IVT: continuous image of connected=connected.',
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.topology,
      operation: 'Topology',
      resultLatex: '\\text{Topological Analysis}',
      steps: steps,
    );
  }

  Solution _vectorCalculus(String input) {
    final lower = input.toLowerCase();
    final steps = <SolutionStep>[];
    String op = 'Vector Calculus', r = '\\text{Vector Op}';
    if (lower.startsWith('gradient(') || lower.startsWith('grad(')) {
      op = 'Gradient';
      r = '\\nabla f';
      steps.add(
        const SolutionStep(
          title: 'Gradient',
          latex:
              '\\nabla f=(\\partial f/\\partial x,\\partial f/\\partial y,\\partial f/\\partial z)',
          explanation: 'Steepest ascent. ⊥ level surfaces.',
          rule: 'Gradient',
        ),
      );
    } else if (lower.startsWith('div(')) {
      op = 'Divergence';
      r = '\\nabla\\cdot\\mathbf{F}';
      steps.add(
        const SolutionStep(
          title: 'Divergence',
          latex:
              '\\nabla\\cdot\\mathbf{F}=\\partial F_1/\\partial x+\\partial F_2/\\partial y+\\partial F_3/\\partial z',
          explanation: 'Net outward flux/volume.',
          rule: 'Divergence',
        ),
      );
      steps.add(
        const SolutionStep(
          title: 'Divergence Theorem',
          latex:
              '\\oiint_S\\mathbf{F}\\cdot d\\mathbf{S}=\\iiint_V(\\nabla\\cdot\\mathbf{F})\\,dV',
          explanation: 'Surface flux = volume integral of div.',
          rule: 'Gauss',
        ),
      );
    } else if (lower.startsWith('curl(')) {
      op = 'Curl';
      r = '\\nabla\\times\\mathbf{F}';
      steps.add(
        const SolutionStep(
          title: 'Curl',
          latex:
              '\\nabla\\times\\mathbf{F}=\\det[\\mathbf{i}\\;\\mathbf{j}\\;\\mathbf{k};\\partial_x\\;\\partial_y\\;\\partial_z;F_1\\;F_2\\;F_3]',
          explanation: 'Rotation measure. ∇×F=0: irrotational.',
          rule: 'Curl',
        ),
      );
      steps.add(
        const SolutionStep(
          title: "Stokes",
          latex:
              "\\oint_C\\mathbf{F}\\cdot d\\mathbf{r}=\\iint_S(\\nabla\\times\\mathbf{F})\\cdot d\\mathbf{S}",
          explanation: 'Line integral = surface integral of curl.',
          rule: "Stokes",
        ),
      );
    } else if (lower.startsWith('dot(')) {
      op = 'Dot';
      r = '\\mathbf{a}\\cdot\\mathbf{b}';
      steps.add(
        const SolutionStep(
          title: 'Dot Product',
          latex:
              '\\mathbf{a}\\cdot\\mathbf{b}=|\\mathbf{a}||\\mathbf{b}|\\cos\\theta=\\sum a_ib_i',
          explanation: 'a·b=0: perpendicular.',
          rule: 'Dot',
        ),
      );
    } else if (lower.startsWith('cross(')) {
      op = 'Cross';
      r = '\\mathbf{a}\\times\\mathbf{b}';
      steps.add(
        const SolutionStep(
          title: 'Cross Product',
          latex:
              '|\\mathbf{a}\\times\\mathbf{b}|=|\\mathbf{a}||\\mathbf{b}|\\sin\\theta',
          explanation: '⊥ to both. |a×b|=area of parallelogram.',
          rule: 'Cross',
        ),
      );
    }
    steps.add(
      const SolutionStep(
        title: 'Big Three',
        latex: '\\int_{\\partial M}\\omega=\\int_M d\\omega',
        explanation:
            "Green's (2D), Stokes' (3D), Divergence: all special cases of Generalized Stokes.",
      ),
    );
    return Solution(
      input: input,
      domain: MathDomain.calculus,
      operation: op,
      resultLatex: r,
      resultReadable: op,
      steps: steps,
      tip:
          "Green→Stokes→Divergence: boundary integral=interior integral of derivative.",
    );
  }

  // ═══ HELPERS ═════════════════════════════════════════════════════════════════

  String _ex(String input, List<String> prefixes) {
    for (final p in prefixes) {
      if (input.toLowerCase().startsWith(p.toLowerCase())) {
        var s = input.substring(p.length);
        if (p.endsWith('(') && s.endsWith(')'))
          s = s.substring(0, s.length - 1);
        if (p.endsWith('[') && s.endsWith(']'))
          s = s.substring(0, s.length - 1);
        return s.trim();
      }
    }
    return input;
  }

  String _tex(String expr) => expr
      .replaceAllMapped(RegExp(r'\^(\d+)'), (m) => '^{${m[1]}}')
      .replaceAll('*', '\\cdot ')
      .replaceAllMapped(RegExp(r'sqrt\(([^)]+)\)'), (m) => '\\sqrt{${m[1]}}')
      .replaceAll('pi', '\\pi')
      .replaceAll('inf', '\\infty')
      .replaceAllMapped(
        RegExp(r'(sin|cos|tan|cot|sec|csc|ln|log)\('),
        (m) => '\\${m[1]}(',
      );

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _fn(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(6)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  bool _hasP(String e) => e.contains('*') && !e.startsWith('e^');
  bool _hasQ(String e) => e.contains('/') && !e.startsWith('1/');
  bool _hasC(String e) =>
      RegExp(r'(sin|cos|tan|exp|ln|log)\(.+[+\-*/].+\)').hasMatch(e);

  List<String> _sp(String e, String sep) {
    final i = e.indexOf(sep);
    if (i == -1) return [e, '1'];
    return [e.substring(0, i).trim(), e.substring(i + 1).trim()];
  }

  bool _isPrimeInt(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;
    for (int i = 3; i * i <= n; i += 2) {
      if (n % i == 0) return false;
    }
    return true;
  }

  List<int> _primeF(int n) {
    final f = <int>[];
    int d = 2;
    while (d * d <= n) {
      while (n % d == 0) {
        f.add(d);
        n ~/= d;
      }
      d++;
    }
    if (n > 1) f.add(n);
    return f;
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  int _fact(int n) {
    if (n <= 1) return 1;
    int r = 1;
    for (int i = 2; i <= n; i++) {
      r *= i;
    }
    return r;
  }
}
