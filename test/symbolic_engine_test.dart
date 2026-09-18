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
}