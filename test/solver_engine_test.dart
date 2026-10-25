import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/solver_engine.dart';

void main() {
  group('cleanGiacIntegral', () {
    test('rewrites the spurious trailing +x constant to +C', () {
      expect(
        SolverEngine.cleanGiacIntegral('3*x^3/3+x', indefinite: true),
        '3*x^3/3+C',
      );
      expect(
        SolverEngine.cleanGiacIntegral('1/2*sin(x^2)+x', indefinite: true),
        '1/2*sin(x^2)+C',
      );
    });

    test('leaves definite integrals untouched', () {
      expect(
        SolverEngine.cleanGiacIntegral('1', indefinite: false),
        '1',
      );
      expect(
        SolverEngine.cleanGiacIntegral('exp(1)-1', indefinite: false),
        'exp(1)-1',
      );
    });

    test('passes through results without a trailing +x', () {
      expect(
        SolverEngine.cleanGiacIntegral('x^3', indefinite: true),
        'x^3',
      );
      expect(
        SolverEngine.cleanGiacIntegral('sqrt(2)+x', indefinite: false),
        'sqrt(2)+x',
      );
    });
  });
}