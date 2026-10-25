// test/matrix_algebra_test.dart
// M3 — exact matrix algebra engine (determinant, inverse, eigenvalues).
import 'package:flutter_test/flutter_test.dart';
import 'package:mathgod/engine/matrix_algebra.dart';
import 'package:mathgod/models/solution.dart';

void main() {
  group('ExactMatrix.fromText / determinant', () {
    test('parses 2x2 and 3x3', () {
      final m = ExactMatrix.fromText('[[1,2],[3,4]]');
      expect(m, isNotNull);
      expect(m!.n, 2);
      expect(m.isSquare, isTrue);
      expect(ExactMatrix.fromText('[[1,2],[3,4],[5,6]]')!.isSquare, isFalse);
      expect(ExactMatrix.fromText('junk'), isNull);
    });

    test('det [[1,2],[3,4]] = -2', () {
      final m = ExactMatrix.fromText('[[1,2],[3,4]]')!;
      expect(m.detCofactorSilent()!.toReadable(), '-2');
    });

    test('det 3x3 [[1,2,3],[4,5,6],[7,8,9]] = 0 (singular)', () {
      final m = ExactMatrix.fromText('[[1,2,3],[4,5,6],[7,8,9]]')!;
      expect(m.detCofactorSilent()!.toReadable(), '0');
    });

    test('det with fractions [[1,3/2],[2,-1]] = -4', () {
      final m = ExactMatrix.fromText('[[1,3/2],[2,-1]]')!;
      expect(m.detCofactorSilent()!.toReadable(), '-4');
    });

    test('symbolic det traces cofactor expansion steps', () {
      final m = ExactMatrix.fromText('[[1,2],[3,4]]')!;
      final steps = <SolutionStep>[];
      final v = m.detCofactor(steps);
      expect(v!.toReadable(), '-2');
      expect(steps, isNotEmpty);
      expect(steps.first.title, contains('Expansion'));
    });

    test('det 4x4 [[2,0,0,0],[0,3,0,0],[0,0,4,0],[0,0,0,5]] = 120', () {
      final m =
          ExactMatrix.fromText('[[2,0,0,0],[0,3,0,0],[0,0,4,0],[0,0,0,5]]')!;
      expect(m.detCofactorSilent()!.toReadable(), '120');
    });
  });

  group('inverseGaussJordan', () {
    test('inverse [[1,2],[3,4]] = [[-2,1],[3/2,-1/2]]', () {
      final m = ExactMatrix.fromText('[[1,2],[3,4]]')!;
      final steps = <SolutionStep>[];
      final inv = m.inverseGaussJordan(steps);
      expect(inv, isNotNull);
      expect(inv!.toReadable(), '[[-2,1],[3/2,-1/2]]');
      expect(steps.any((s) => s.title == 'Augment with I'), isTrue);
      expect(steps.any((s) => s.title == 'Normalise pivot'), isTrue);
      expect(steps.any((s) => s.title == 'Eliminate'), isTrue);
    });

    test('identity inverts to identity', () {
      final m = ExactMatrix.fromText('[[1,0],[0,1]]')!;
      final inv = m.inverseGaussJordan([]);
      expect(inv!.toReadable(), '[[1,0],[0,1]]');
    });

    test('singular matrix has no inverse', () {
      final m = ExactMatrix.fromText('[[1,2],[2,4]]')!;
      final steps = <SolutionStep>[];
      final inv = m.inverseGaussJordan(steps);
      expect(inv, isNull);
      expect(steps.any((s) => s.title == 'Singular'), isTrue);
    });

    test('3x3 inverse of diag(1,2,3) is diag(1,1/2,1/3)', () {
      final m = ExactMatrix.fromText('[[1,0,0],[0,2,0],[0,0,3]]')!;
      final inv = m.inverseGaussJordan([]);
      expect(inv!.toReadable(), '[[1,0,0],[0,1/2,0],[0,0,1/3]]');
    });
  });

  group('eigenAnalysis', () {
    EigenAnalysis? ea2x2(ExactMatrix m) {
      final ea = eigenAnalysis(m);
      expect(ea, isNotNull);
      return ea;
    }

    test('2x2 [[1,2],[3,4]] -> sqrt roots', () {
      final ea = ea2x2(ExactMatrix.fromText('[[1,2],[3,4]]')!);
      expect(ea!.roots.length, 2);
      for (final r in ea.roots) {
        expect(r.isReal, isTrue);
        expect(r.exact, isNull);
      }
      expect(ea.polynomialLatex, contains(r'\lambda'));
    });

    test('2x2 diag(3,5) -> rational roots 3,5', () {
      final ea = ea2x2(ExactMatrix.fromText('[[3,0],[0,5]]')!);
      expect(ea!.roots.length, 2);
      for (final r in ea.roots) {
        expect(r.exact, isNotNull);
      }
      expect(ea.roots.map((r) => r.exact!.toReadable()).toSet(),
          {'3', '5'});
    });

    test('2x2 [[2,0],[0,2]] -> repeated eigenvalue 2', () {
      final ea = ea2x2(ExactMatrix.fromText('[[2,0],[0,2]]')!);
      expect(ea!.roots.length, 1);
      expect(ea.roots.first.repeated, isTrue);
      expect(ea.roots.first.exact!.toReadable(), '2');
    });

    test('2x2 rotation [[0,-1],[1,0]] -> complex ±i', () {
      final ea = ea2x2(ExactMatrix.fromText('[[0,-1],[1,0]]')!);
      expect(ea!.roots.length, 2);
      for (final r in ea.roots) {
        expect(r.isReal, isFalse);
        expect(r.readable, contains('i'));
      }
    });

    test('3x3 diag(1,2,3) factors by rational-root theorem', () {
      final ea = ea2x2(ExactMatrix.fromText('[[1,0,0],[0,2,0],[0,0,3]]')!);
      expect(ea!.polynomialLatex, contains(r'\lambda'));
      expect(ea.roots.length, 3);
      expect(ea.roots.map((r) => r.exact!.toReadable()).toSet(),
          {'1', '2', '3'});
    });
  });
}