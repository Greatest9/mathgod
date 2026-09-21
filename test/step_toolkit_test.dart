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
}
