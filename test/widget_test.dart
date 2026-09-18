// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/main.dart';
import 'package:mathgod/engine/solver_engine.dart';
import 'package:mathgod/engine/word_problem_parser.dart';
import 'package:mathgod/models/history_item.dart';

void main() {
  testWidgets('MathGodApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MathGodApp());
    expect(find.byType(MathGodApp), findsOneWidget);
  });

  group('Word Problem Parser Tests', () {
    test('Derivative parsing', () {
      expect(parseWordProblem('derivative of sin(x)'), 'd/dx[sin(x)]');
      expect(parseWordProblem('differentiate x^3'), 'd/dx[x^3]');
    });

    test('Integral parsing', () {
      expect(parseWordProblem('integral of x^2'), 'int(x^2)');
      expect(parseWordProblem('integrate e^x from 0 to 1'), 'int(e^x, 0, 1)');
    });
  });

  group('Solver Engine Fallback Tests', () {
    test('Derivative pattern solve', () {
      final sol = SolverEngine.instance.solve('d/dx[x^5]');
      expect(sol.operation, 'Derivative');
      expect(sol.steps.isNotEmpty, true);
    });
  });

  group('History Item Tests', () {
    test('HistoryItem fromSolution and JSON conversion', () {
      final sol = SolverEngine.instance.solve('d/dx[x^3]');
      final item = HistoryItem.fromSolution(sol);
      expect(item.input, sol.input);
      final json = item.toJson();
      final fromJson = HistoryItem.fromJson(json);
      expect(fromJson.input, item.input);
      expect(fromJson.operation, item.operation);
      expect(fromJson.domain, item.domain);
    });
  });
}
