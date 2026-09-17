import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/solver_engine.dart';

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
}
