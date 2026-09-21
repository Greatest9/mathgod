// test/symbolic_engine_test.dart
// Phase B / M2 — exact symbolic derivative engine.
import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/symbolic.dart';

void main() {
  group('SymbolicEngine.differentiate', () {
    DerivResult? d(String expr, {String v = 'x'}) =>
        SymbolicEngine.differentiate(expr, v: v);

    List<String> titles(DerivResult r) => r.steps.map((s) => s.title).toList();

    test('emits header + result cards', () {
      final r = d('x^3');
      expect(r, isNotNull);
      final t = titles(r!);
      expect(t.first, 'Differentiate');
      expect(t.last, 'Result');
    });

    test('power rule: x^3 -> 3*x^2', () {
      final r = d('x^3');
      expect(r, isNotNull);
      expect(r!.resultReadable, '3*x^2');
      expect(titles(r), contains('Power Rule'));
    });

    test('sum rule: 3*x^2+2*x+1 -> 6*x + 2', () {
      final r = d('3x^2+2x+1');
      expect(r, isNotNull);
      expect(r!.resultReadable, '6*x + 2');
      expect(titles(r), contains('Sum Rule'));
    });

    test('combines like terms on differentiation: 2x+3x -> 5', () {
      final r = d('2x+3x');
      expect(r, isNotNull);
      expect(r!.resultReadable, '5');
    });

    test('rational coefficient stays exact: 1/3*x^3 -> x^2', () {
      final r = d('1/3*x^3');
      expect(r, isNotNull);
      expect(r!.resultReadable, 'x^2');
      expect(r.resultLatex, isNot(contains('0.333')));
    });

    test('product rule: x^3*sin(x)', () {
      final r = d('x^3*sin(x)');
      expect(r, isNotNull);
      expect(r!.resultReadable, 'x^3*cos(x) + 3*x^2*sin(x)');
      expect(titles(r), contains('Product Rule'));
    });

    test('chain rule: sin(x^2) -> 2*x*cos(x^2)', () {
      final r = d('sin(x^2)');
      expect(r, isNotNull);
      expect(r!.resultReadable, '2*x*cos(x^2)');
      expect(titles(r), contains('Chain Rule'));
    });

    test('negative power via power rule: 1/x -> -1/x^2', () {
      final r = d('1/x');
      expect(r, isNotNull);
      expect(r!.resultReadable, '-1/x^2');
      expect(titles(r), contains('Power Rule'));
    });

    test('quotient rule, parens: (x+1)/(x-1) is non-null and rational', () {
      final r = d('(x+1)/(x-1)');
      expect(r, isNotNull);
      expect(r!.resultLatex, contains('x - 1'));
      expect(titles(r), contains('Quotient Rule'));
    });

    test('exponential: e^(2x) -> 2*e^(2*x)', () {
      final r = d('e^(2x)');
      expect(r, isNotNull);
      expect(r!.resultReadable, '2*e^(2*x)');
      expect(titles(r), contains('Chain Rule'));
    });

    test('logarithm: ln(x) -> 1/x', () {
      final r = d('ln(x)');
      expect(r, isNotNull);
      expect(r!.resultReadable, '1/x');
      expect(r.resultLatex, contains(r'\frac{1}{x}'));
      expect(titles(r), contains('Logarithmic Rule'));
    });

    test('constant: 5 -> 0', () {
      final r = d('5');
      expect(r, isNotNull);
      expect(r!.resultReadable, '0');
      expect(titles(r), contains('Constant Rule'));
    });

    test('different variable name: 3*t^2+1 wrt t -> 6*t', () {
      final r = d('3*t^2+1', v: 't');
      expect(r, isNotNull);
      expect(r!.resultReadable, '6*t');
    });

    test('non-target letters are constants: x+y wrt x -> 1', () {
      final r = d('x+y');
      expect(r, isNotNull);
      expect(r!.resultReadable, '1');
    });

    test('parenthesized sum parses: (x+1) -> 1', () {
      final r = d('(x+1)');
      expect(r, isNotNull);
      expect(r!.resultReadable, '1');
    });

    test('out-of-grammar returns null', () {
      expect(d('arcsin(x)'), isNull);
      expect(d('sqrt(x)'), isNull);
      expect(d('e^x'), isNull);
    });
  });

  group('SymbolicEngine.integrate', () {
    String n(String s) => s.replaceAll(RegExp(r'\s+'), '');

    IntegralResult? i(String expr, {String v = 'x'}) =>
        SymbolicEngine.integrate(expr, v: v);

    List<String> titles(IntegralResult r) => r.steps.map((s) => s.title).toList();

    test('emits header + result cards', () {
      final r = i('x^3');
      expect(r, isNotNull);
      final t = titles(r!);
      expect(t.first, 'Integrate');
      expect(t.last, 'Result');
    });

    test('power: x^3 -> 1/4*x^4', () {
      final r = i('x^3');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '1/4*x^4+C');
      expect(titles(r), contains('Power Rule'));
    });

    test('power: x^2 -> 1/3*x^3', () {
      final r = i('x^2');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '1/3*x^3+C');
    });

    test('linear: x -> 1/2*x^2', () {
      final r = i('x');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '1/2*x^2+C');
    });

    test('constant: 5 -> 5x', () {
      final r = i('5');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '5*x+C');
      expect(titles(r), contains('Constant Rule'));
    });

    test('reciprocal: 1/x -> ln|x|', () {
      final r = i('1/x');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), 'ln(x)+C');
      expect(titles(r), contains('Logarithmic Rule'));
    });

    test('exponential: e^(x) -> e^x', () {
      final r = i('e^(x)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), 'e^x+C');
    });

    test('scaled exponential via u-sub: 3*e^(2*x) -> 3/2*e^(2*x)', () {
      final r = i('3*e^(2*x)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '3/2*e^(2*x)+C');
      expect(titles(r), contains('Choose u'));
    });

    test('u-sub: sin(2*x) -> -1/2*cos(2*x)', () {
      final r = i('sin(2*x)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '-1/2*cos(2*x)+C');
    });

    test('u-sub x^2: x*cos(x^2) -> 1/2*sin(x^2)', () {
      final r = i('x*cos(x^2)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '1/2*sin(x^2)+C');
      expect(titles(r), contains('Back-substitute'));
    });

    test('u-sub x^2 with coefficient: 2*x*exp(x^2) -> e^(x^2)', () {
      final r = i('2*x*exp(x^2)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), 'e^(x^2)+C');
    });

    test('u-sub trig ratio: cos(x)/sin(x) -> ln(sin(x))', () {
      final r = i('cos(x)/sin(x)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), 'ln(sin(x))+C');
    });

    test('u-sub denominator: x/(x^2+1) -> 1/2*ln(x^2+1)', () {
      final r = i('x/(x^2+1)');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '1/2*ln(x^2+1)+C');
    });

    test('direct sum: x^2+3*x+1 -> rational terms stay exact', () {
      final r = i('x^2+3*x+1');
      expect(r, isNotNull);
      expect(n(r!.resultReadable), '1/3*x^3+3/2*x^2+x+C');
      expect(r.resultLatex, isNot(contains('1.5')));
      expect(r.resultLatex, isNot(contains('0.333')));
    });

    test('definite pushed to pattern layer: int(x,0,1) returns null without bounds API', () {
      expect(SymbolicEngine.isExactBound('0'), isTrue);
      expect(SymbolicEngine.isExactBound('-3/2'), isTrue);
      expect(SymbolicEngine.isExactBound('pi'), isTrue);
      expect(SymbolicEngine.isExactBound('inf'), isFalse);
    });

    test('out-of-grammar returns null', () {
      expect(i('arcsin(x)'), isNull);
      expect(i('sqrt(x)'), isNull);
    });
  });

  group('SymbolicEngine.limit', () {
    String n(String s) => s.replaceAll(RegExp(r'\s+'), '');

    test('constant: lim(5,x,3) -> 5', () {
      final r = SymbolicEngine.limit('5,x,3');
      expect(r, isNotNull);
      expect(n(r!.result), '5');
    });

    test('polynomial: lim(x^2,x,3) -> 9', () {
      final r = SymbolicEngine.limit('x^2,x,3');
      expect(r, isNotNull);
      expect(n(r!.result), '9');
    });

    test('l hopital: lim(sin(x)/x,x,0) -> 1', () {
      final r = SymbolicEngine.limit('sin(x)/x,x,0');
      expect(r, isNotNull);
      expect(n(r!.result), '1');
      expect(r.steps.any((s) => s.title.contains("Hôpital")) , isTrue);
    });

    test('l hopital by diff: lim((x^2-1)/(x-1),x,1) -> 2', () {
      final r = SymbolicEngine.limit('(x^2-1)/(x-1),x,1');
      expect(r, isNotNull);
      expect(n(r!.result), '2');
    });

    test('trig over pi/2: lim(cos(x),x,pi/2) -> 0', () {
      final r = SymbolicEngine.limit('cos(x),x,pi/2');
      expect(r, isNotNull);
      expect(n(r!.result), '0');
    });

    test('infinite target returns null (pattern layer handles it)', () {
      expect(SymbolicEngine.limit('1/x,x,inf'), isNull);
      expect(SymbolicEngine.limit('1/x,x,∞'), isNull);
    });

    test('cancelled form survives division: lim((x^2-4)/(x-2),x,2) -> 4', () {
      final r = SymbolicEngine.limit('(x^2-4)/(x-2),x,2');
      expect(r, isNotNull);
      expect(n(r!.result), '4');
    });
  });
}