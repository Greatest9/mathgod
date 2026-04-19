// lib/models/solution.dart

enum MathDomain {
  calculus,
  linearAlgebra,
  differentialEquations,
  realAnalysis,
  numberTheory,
  abstractAlgebra,
  statistics,
  trigonometry,
  complexAnalysis,
  topology,
  general,
}

extension MathDomainX on MathDomain {
  String get label {
    switch (this) {
      case MathDomain.calculus:
        return "Calculus";
      case MathDomain.linearAlgebra:
        return "Linear Algebra";
      case MathDomain.differentialEquations:
        return "Differential Equations";
      case MathDomain.realAnalysis:
        return "Real Analysis";
      case MathDomain.numberTheory:
        return "Number Theory";
      case MathDomain.abstractAlgebra:
        return "Abstract Algebra";
      case MathDomain.statistics:
        return "Statistics & Probability";
      case MathDomain.trigonometry:
        return "Trigonometry";
      case MathDomain.complexAnalysis:
        return "Complex Analysis";
      case MathDomain.topology:
        return "Topology";
      case MathDomain.general:
        return "General Math";
    }
  }

  String get symbol {
    switch (this) {
      case MathDomain.calculus:
        return "∫";
      case MathDomain.linearAlgebra:
        return "⊞";
      case MathDomain.differentialEquations:
        return "∂";
      case MathDomain.realAnalysis:
        return "ε";
      case MathDomain.numberTheory:
        return "ℕ";
      case MathDomain.abstractAlgebra:
        return "⊕";
      case MathDomain.statistics:
        return "σ";
      case MathDomain.trigonometry:
        return "θ";
      case MathDomain.complexAnalysis:
        return "ℂ";
      case MathDomain.topology:
        return "∞";
      case MathDomain.general:
        return "∑";
    }
  }
}

class SolutionStep {
  final String title;
  final String latex;
  final String explanation;
  final String? rule;

  const SolutionStep({
    required this.title,
    required this.latex,
    required this.explanation,
    this.rule,
  });
}

class Solution {
  final String input;
  final MathDomain domain;
  final String operation;
  final String resultLatex;
  final String resultReadable;
  final List<SolutionStep> steps;
  final bool isUnsolvable;
  final String? tip;

  const Solution({
    required this.input,
    required this.domain,
    required this.operation,
    required this.resultLatex,
    this.resultReadable = '',
    required this.steps,
    this.isUnsolvable = false,
    this.tip,
  });

  factory Solution.unknown(String input) => Solution(
    input: input,
    domain: MathDomain.general,
    operation: "Unknown",
    resultLatex: "\\text{?}",
    steps: [
      SolutionStep(
        title: "Input Format Not Recognized",
        latex: "\\text{Try the examples below}",
        explanation:
            "Math God supports:\n"
            "• Derivatives: d/dx[x^3]  or  diff(sin(x))\n"
            "• Integrals: int(x^2)  or  int(e^x, 0, 1)\n"
            "• Limits: lim(sin(x)/x, x, 0)\n"
            "• Matrices: det([[1,2],[3,4]])  inv([[2,1],[1,1]])\n"
            "• Eigenvalues: eigen([[4,1],[2,3]])\n"
            "• ODEs: ode(y' = x*y)  or  ode(y'' + 4y = 0)\n"
            "• Series: series(1/n^2)  sum(1/2^n)\n"
            "• Trig: sin(pi/6)  cos(45deg)  tan(x)\n"
            "• Complex: complex(3+4i)  modulus(2-3i)\n"
            "• Stats: mean([1,2,3,4,5])  variance([2,4,6])\n"
            "• Primes: isprime(97)  factorize(360)",
      ),
    ],
  );
}
