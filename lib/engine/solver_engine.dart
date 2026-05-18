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
import 'word_problem_parser.dart';

part 'pattern_solver.dart';

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

  Solution solve(String raw, {bool approximate = false}) {
    final input = parseWordProblem(raw.trim());
    if (input.isEmpty) return Solution.unknown(input);

    Solution? giacSolution;
    if (_useGiac) {
      giacSolution = _solveViaGiac(input, approximate: approximate);
    }

    final patternSolution = _solveViaPatterns(input);

    if (giacSolution != null) {
      if (patternSolution.operation == "Unknown" || patternSolution.isUnsolvable) {
        return giacSolution;
      }

      final combinedSteps = List<SolutionStep>.from(patternSolution.steps);
      combinedSteps.add(SolutionStep(
        title: 'CAS Final Verification',
        latex: giacSolution.resultLatex,
        explanation: 'Exact final result computed by the offline Giac CAS engine.',
        rule: 'Giac CAS',
      ));

      return Solution(
        input: input,
        domain: patternSolution.domain,
        operation: patternSolution.operation,
        resultLatex: giacSolution.resultLatex,
        resultReadable: giacSolution.resultReadable,
        steps: combinedSteps,
        tip: patternSolution.tip ?? giacSolution.tip,
      );
    }

    return patternSolution;
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

  Solution? _solveViaGiac(String input, {bool approximate = false}) {
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
      } else if (_isTrig(lower)) {
        // Dedicated trig branch — avoids normal() crash on e.g. sin(pi/8)
        giacCmd = 'simplify($input)';
        operation = 'Trigonometry';
        domain = MathDomain.trigonometry;
      } else {
        // Generic: try to evaluate / simplify
        giacCmd = 'normal($input)';
        operation = 'Evaluate';
        domain = MathDomain.general;
      }

      // Wrap in evalf() when user requests decimal approximation
      if (approximate) {
        giacCmd = 'evalf($giacCmd)';
      }

      // ── Call the CAS ──────────────────────────────────────────────────────
      final rawResult = GiacFFI.instance.solve(giacCmd);

      if (rawResult.startsWith('Error:')) {
        // CAS failed — fallback handled in solve()
        return null;
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
      return null;
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
