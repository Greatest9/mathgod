// M4 coverage: Laplace/inverse-Laplace table, literal F(x,y,z) parsing,
// and solve() pattern fallback — all driven through the public solve() entry
// point so they exercise the same path a user hits without Giac.

import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/solver_engine.dart';

void main() {
  final engine = SolverEngine.instance;

  group('M4: equation solving', () {
    test('linear equation isolates', () {
      final s = engine.solve('solve(2*x+4=0)');
      expect(s.operation, 'Solve');
      expect(s.resultReadable, 'x = -2');
      expect(s.steps.any((st) => st.rule == 'Isolate'), isTrue);
      expect(s.steps.last.title, 'Verification');
    });

    test('monic quadratic factors via discriminant when square', () {
      final s = engine.solve('solve(x^2-5*x+6=0)');
      expect(s.operation, 'Solve');
      expect(s.resultReadable, 'x = 2, x = 3');
      expect(s.steps.any((st) => st.rule == 'Discriminant'), isTrue);
      expect(s.steps.any((st) => st.rule == 'Factor'), isTrue);
    });

    test('non-monic quadratic returns exact fractions', () {
      final s = engine.solve('solve(3*x^2-2*x-1=0)');
      expect(s.resultReadable, contains('x = -1/3'));
      expect(s.resultReadable, contains('x = 1'));
      expect(s.resultLatex, contains(r'\frac{-1}{3}'));
    });

    test('negative discriminant yields complex roots', () {
      final s = engine.solve('solve(x^2+1=0)');
      expect(s.operation, 'Solve');
      expect(s.resultLatex, contains(r'\pm i'));
    });

    test('solutions to 2x=8 maps through word parser', () {
      final s = engine.solve('solutions to 2x = 8');
      expect(s.operation, 'Solve');
      expect(s.resultReadable, 'x = 4');
    });

    test('factored formula read directly via zero-product', () {
      final s = engine.solve('solve((x-2)*(x+3)=0)');
      expect(s.resultReadable, contains('x = 2'));
      expect(s.resultReadable, contains('x = -3'));
      expect(s.steps.any((st) => st.rule == 'Zero-Product'), isTrue);
    });

    test('contradiction has no solution', () {
      final s = engine.solve('solve(5=0)');
      expect(s.operation, 'Solve');
      expect(s.resultReadable, 'No solution');
    });
  });

  group('M4: Laplace table', () {
    test('e^{-2t} → 1/(s+2)', () {
      final s = engine.solve('laplace(e^(-2*t))');
      expect(s.operation, 'Laplace Transform');
      expect(s.resultLatex, contains(r'\frac{1}{s+2}'));
    });

    test('sin(3t) → 3/(s^2+9)', () {
      final s = engine.solve('laplace(sin(3*t))');
      expect(s.resultLatex, contains(r'\frac{3}{s^2+9}'));
    });

    test('constant scales: 5 → 5/s', () {
      final s = engine.solve('laplace(5)');
      expect(s.resultLatex, contains(r'\frac{5}{s}'));
    });

    test('linearity splits cos(2t)+1', () {
      final s = engine.solve('laplace(cos(2*t)+1)');
      expect(s.resultLatex, contains(r'\frac{s}{s^2+4}'));
      expect(s.resultLatex, contains(r'\frac{1}{s}'));
    });

    test('hypberbolic rows', () {
      final sinh = engine.solve('laplace(sinh(2*t))');
      expect(sinh.resultLatex, contains(r'\frac{2}{s^2-4}'));
      final cosh = engine.solve('laplace(cosh(2*t))');
      expect(cosh.resultLatex, contains(r'\frac{s}{s^2-4}'));
    });

    test('t·e^{-2t} → 1/(s+2)^2', () {
      final s = engine.solve('laplace(t*e^(-2*t))');
      expect(s.resultLatex, contains(r'\frac{1}{(s+2)^{2}}'));
    });

    test('e^{-2t}sin(3t) s-shift sine', () {
      final s = engine.solve('laplace(e^(-2*t)*sin(3*t))');
      expect(s.resultLatex, contains(r'\frac{3}{(s+2)^2+9}'));
    });
  });

  group('M4: inverse Laplace table', () {
    test('1/s^2 → t', () {
      final s = engine.solve('invlaplace(1/s^2)');
      expect(s.operation, 'Inverse Laplace');
      expect(s.resultLatex, 't');
    });

    test('1/(s+3) → e^{-3t}', () {
      final s = engine.solve('invlaplace(1/(s+3))');
      expect(s.resultLatex, 'e^{-3t}');
    });

    test('k/(s^2+ω^2) includes the k/ω factor', () {
      final s = engine.solve('invlaplace(1/(s^2+9))');
      expect(s.resultLatex, contains(r'\frac{1}{3}\sin(3t)'));
    });

    test('s/(s^2+9) → cos(3t)', () {
      final s = engine.solve('invlaplace(s/(s^2+9))');
      expect(s.resultLatex, contains(r'\cos(3t)'));
    });

    test('constant 5/s → 5', () {
      final s = engine.solve('invlaplace(5/s)');
      expect(s.resultLatex, startsWith('5'));
    });

    test('k/s^n scaling', () {
      final s = engine.solve('invlaplace(3/s^2)');
      expect(s.resultLatex, contains('t'));
      expect(s.resultLatex, contains('3'));
    });

    test('s-shifted sine: 1/((s+1)^2+4)', () {
      final s = engine.solve('invlaplace(1/((s+1)^2+4))');
      expect(s.resultLatex, contains(r'e^{-1t}'));
      expect(s.resultLatex, contains(r'\sin(2t)'));
    });

    test('s-shifted cosine: (s+1)/((s+1)^2+4)', () {
      final s = engine.solve('invlaplace((s+1)/((s+1)^2+4))');
      expect(s.resultLatex, 'e^{-1t}\\cos(2t)');
    });

    test('partial fractions → exponential sum', () {
      final s = engine.solve('invlaplace(3/((s+1)*(s+2)))');
      expect(s.resultLatex, contains(r'3e^{-1t}'));
      expect(s.resultLatex, contains(r'- 3e^{-2t}'));
      expect(s.steps.any((st) => st.rule == 'PFD'), isTrue);
    });

    test('hyperbolic inverse rows', () {
      final sh = engine.solve('invlaplace(1/(s^2-4))');
      expect(sh.resultLatex, contains(r'\frac{1}{2}\sinh(2t)'));
      final ch = engine.solve('invlaplace(s/(s^2-4))');
      expect(ch.resultLatex, contains(r'\cosh(2t)'));
    });
  });

  group('M4: literal F(x,y,z) parsing', () {
    test('partial(F(x,y,z), x) keeps the function name', () {
      final s = engine.solve('partial(F(x,y,z), x)');
      expect(s.operation, '∂/∂x');
      expect(s.resultReadable, '∂/∂x[F(x,y,z)]');
      expect(s.resultLatex, contains(r'\frac{\partial F}{\partial x}'));
    });

    test('double integral echoes the integrand', () {
      final s = engine.solve('dblint(F(x,y))');
      expect(s.operation, 'Double Integral');
      expect(s.resultLatex, contains(r'F(x,y)'));
    });

    test('triple integral echoes F(x,y,z)', () {
      final s = engine.solve('tripleint(F(x,y,z))');
      expect(s.operation, 'Triple Integral');
      expect(s.resultReadable, '∭_V F(x,y,z) dV');
    });

    test('gradient(F(x,y,z)) substitutes the literal field', () {
      final s = engine.solve('gradient(F(x,y,z))');
      expect(s.operation, 'Gradient');
      expect(s.resultLatex, contains(r'\nabla F(x,y,z)'));
      expect(s.steps.any((st) => st.title == 'Literal Field'), isTrue);
    });

    test('div(F(x,y,z)) stays a divergence', () {
      final s = engine.solve('div(F(x,y,z))');
      expect(s.operation, 'Divergence');
      expect(s.resultLatex, contains(r'\nabla\cdot'));
    });
  });
}