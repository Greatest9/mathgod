import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/math_interpreter.dart';

void main() {
  final interp = MathInterpreter.instance;

  // input → expected canonical command
  const cases = <String, String>{
    // calculus
    'differentiate x squared times sin x': 'd/dx[x^2*sin(x)]',
    'what is the derivative of x^2 sin(x)?': 'd/dx[x^2*sin(x)]',
    'derivitive of x^3': 'd/dx[x^3]',
    'derivative of t^3 with respect to t': 'd/dt[t^3]',
    'second derivative of x^4': 'diff(x^4,x,2)',
    'derivative of x^2 at x=3': 'subst(diff(x^2,x),x=3)',
    'partial derivative of x^2*y with respect to y': 'd/dy[x^2*y]',
    'integral of 2x from 0 to pi': 'int(2x,0,pi)',
    'integrate x^2 dx from 0 to 1': 'int(x^2,0,1)',
    '∫ sin x dx': 'int(sin(x))',
    'integral of 1/x from 1 to e': 'int(1/x,1,e)',
    'limit as x approaches 0 of sin x / x': 'lim(sin(x)/x,x,0)',
    'limit of 1/x as x approaches infinity': 'lim(1/x,x,inf)',
    'taylor series of e^x around 0 up to order 4': 'maclaurin(e^x,4)',
    'laplace transform of sin(3t)': 'laplace(sin(3t))',
    'inverse laplace of 1/(s^2+1)': 'ilaplace(1/(s^2+1))',
    'sum of k^2 for k from 1 to 10': 'sum(k^2,k,1,10)',
    // algebra
    'solve 2x + 3 = 7': 'solve(2x+3=7)',
    'x^2 - 4 = 0': 'solve(x^2-4=0)',
    'x+y=3 and x-y=1': 'solve([x+y=3,x-y=1],[x,y])',
    'solve for y: 2y + 4 = 10': 'solve(2y+4=10,y)',
    'factor x^2 - 1': 'factor(x^2-1)',
    'prime factors of 360': 'factorize(360)',
    'expand (x+1)^3': 'expand((x+1)^3)',
    // linear algebra
    'determinant of 1 2; 3 4': 'det([[1,2],[3,4]])',
    'eigenvalues of 2x2 matrix 4 1 2 3': 'eigen([[4,1],[2,3]])',
    'tell me the inverse of [[2,1],[1,1]]': 'inv([[2,1],[1,1]])',
    // number theory / stats
    'gcd of 12 and 18': 'gcd(12,18)',
    'is 97 prime?': 'isprime(97)',
    '5 choose 2': 'comb(5,2)',
    '5 factorial': 'factorial(5)',
    '17 mod 5': 'irem(17,5)',
    'mean of 1, 2, 3, 4, 5': 'mean([1,2,3,4,5])',
    // misc
    '20% of 50': '(20/100)*50',
    'sin of 30 degrees': 'sin(30deg)',
    'cos of pi over 3': 'cos(pi/3)',
    'square root of 16 plus 3': 'sqrt(16)+3',
    "solve y' + y = 0": "ode(y'+y=0)",
  };

  group('MathInterpreter', () {
    cases.forEach((input, expected) {
      test(input, () {
        expect(interp.interpret(input).command, expected);
      });
    });

    test('canonical input passes through untouched', () {
      for (final s in ['d/dx[x^3]', 'int(x^2, 0, 1)', 'lim(sin(x)/x, x, 0)']) {
        final r = interp.interpret(s);
        expect(r.command, s);
        expect(r.intent, 'passthrough');
      }
    });

    test('decimal requests set the approximate flag', () {
      expect(interp.interpret('ln of 5 as a decimal').approximate, isTrue);
    });

    test('gibberish is reported as not understood', () {
      expect(interp.interpret('blah blah banana').understood, isFalse);
    });

    for (final s in ['asdf', 'hello how are you', 'how are you', 'hello']) {
      test('plain words are not math: $s', () {
        final r = interp.interpret(s);
        expect(r.understood, isFalse,
            reason: 'DIAG "$s" -> intent=${r.intent} cmd=${r.command} '
                'conf=${r.confidence} summary=${r.summary}');
      });
    }
  });
}
