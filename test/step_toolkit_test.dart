import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/solver_engine.dart';
import 'package:mathgod/engine/step_toolkit.dart';

void main() {
  group('step vocabulary', () {
    test('every solve closes with a Verification step', () {
      final solution = SolverEngine.instance.solve('d/dx[x^3]');

      expect(solution.steps, isNotEmpty);
      expect(solution.steps.last.title, 'Verification');
      expect(solution.resultReadable, isNotEmpty);
    });

    test('the old CAS boilerplate cards are gone', () {
      final solution = SolverEngine.instance.solve('d/dx[x^3]');
      final titles = solution.steps.map((s) => s.title).toList();

      expect(titles, isNot(contains('CAS Engine')));
      expect(titles, isNot(contains('Command Sent')));
      expect(titles, isNot(contains('CAS Final Verification')));
    });

    test('verification is honest when there is no CAS on the platform', () {
      final solution = SolverEngine.instance.solve('d/dx[x^3]');
      final verification = solution.steps.last;

      // On a platform without the Giac .so the check cannot run, and the card
      // must say so instead of implying the answer was verified.
      expect(verification.latex, contains('no independent check'));
      expect(verification.rule, isNull);
    });
  });

  group('determinant verification', () {
    test('independent expansion of [[1,2],[3,4]] is -2', () {
      expect(
        SolutionVerifier.expansionDeterminant('[[1,2],[3,4]]'),
        closeTo(-2, 1e-12),
      );
    });

    test('negative reported value no longer forces a false mismatch', () {
      // The on-device bug: det([[1,2],[3,4]]) = -2 was wrapped in abs() before
      // comparing, so the residual was |(-2)-2|/3 = 4/3 and the card wrongly
      // read "Check failed" instead of "Verified".
      expect(
        SolutionVerifier.relativeError(-2.0, -2.0),
        closeTo(0, 1e-12),
      );
      expect(
        SolutionVerifier.relativeError(-2.0, 2.0),
        greaterThan(1.0),
      );
    });
  });

  group('list parsing', () {
    test('Giac list[...] roots are split into entries', () {
      // The on-device bug: solve(x^2-5x+6=0) reports "list[2,3]" and the
      // verifier treated the whole string as one non-numeric "root".
      expect(SolutionVerifier.parseList('list[2,3]'), ['2', '3']);
      expect(SolutionVerifier.parseList('list[2]'), ['2']);
    });

    test('brace and bracket lists still parse', () {
      expect(SolutionVerifier.parseList('{2,3}'), ['2', '3']);
      expect(SolutionVerifier.parseList('[2,3]'), ['2', '3']);
    });
  });

  group('vector parsing', () {
    test('bracketed vectors split into components', () {
      expect(
        SolutionVerifier.parseVector('[2*x,2*y,0]'),
        ['2*x', '2*y', '0'],
      );
      expect(SolutionVerifier.parseVector('[1,2,3]'), ['1', '2', '3']);
    });
  });

  group('readable-latex conversion', () {
    test('frac{...}{...} becomes division Giac can evaluate', () {
      expect(SolutionVerifier.toEvaluable('frac{sqrt{2}}{2}'), '(sqrt(2))/(2)');
      expect(SolutionVerifier.toEvaluable('frac{1}{sqrt{3}}'), '(1)/(sqrt(3))');
    });

    test('plain expressions and predicates pass through untouched', () {
      expect(SolutionVerifier.toEvaluable('sin(pi/4)'), 'sin(pi/4)');
      expect(SolutionVerifier.toEvaluable('mean([1,2,3])'), 'mean([1,2,3])');
      expect(SolutionVerifier.toEvaluable('factor(x)'), 'factor(x)');
    });
  });

  group('abstract algebra check', () {
    test('group(Z_12) verifies order and generator count', () {
      final solution = SolverEngine.instance.solve('group(Z_12)');
      expect(solution.resultReadable, contains('order 12'));
      expect(solution.resultReadable, contains('φ(12)=4'));
      expect(solution.steps.last.title, 'Verification');
      expect(solution.steps.last.rule, 'Verified');
    });

    test('brutePhi counts coprime residues', () {
      expect(SolutionVerifier.brutePhi(12), 4);
      expect(SolutionVerifier.brutePhi(7), 6);
    });
  });

  group('topology check', () {
    test('compact([0,1]) verifies as compact', () {
      final solution = SolverEngine.instance.solve('compact([0,1])');
      expect(solution.steps.last.rule, 'Verified');
    });

    test('compact(R) reports not compact and verifies', () {
      final solution = SolverEngine.instance.solve('compact(R)');
      expect(solution.resultReadable, contains('not compact'));
      expect(solution.steps.last.rule, 'Verified');
    });

    test('connected(Q) reports not connected and verifies', () {
      final solution = SolverEngine.instance.solve('connected(Q)');
      expect(solution.resultReadable, contains('not connected'));
      expect(solution.steps.last.rule, 'Verified');
    });

    group('exact-trig crash guard', () {
    test('detects constant-argument trig', () {
      expect(SolutionVerifier.hasExactTrig('sin(pi/4)'), isTrue);
      expect(SolutionVerifier.hasExactTrig('2*cos(pi/8)^2'), isTrue);
      expect(SolutionVerifier.hasExactTrig('1+sin(pi/4)'), isTrue);
      expect(SolutionVerifier.hasExactTrig('Sin(pi/4)'), isTrue);
      expect(SolutionVerifier.hasExactTrig('tan(pi/12)*x'), isTrue);
      expect(SolutionVerifier.hasExactTrig('sqrt(2)/2'), isFalse);
    });

    test('leaves variable-argument trig alone', () {
      expect(SolutionVerifier.hasExactTrig('sin(x)'), isFalse);
      expect(SolutionVerifier.hasExactTrig('diff(sin(x^2),x)'), isFalse);
      expect(SolutionVerifier.hasExactTrig('solve(sin(x)=1)'), isFalse);
      expect(SolutionVerifier.hasExactTrig('cos(2*x)+sin(x)'), isFalse);
    });

    test('trig-exact generic input solves without crashing', () {
      final solution = SolverEngine.instance.solve('1+sin(pi/4)');
      expect(solution.input, '1+sin(pi/4)');
    });
  });
  });
}
