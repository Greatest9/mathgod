// lib/data/theorem_database.dart

import '../models/theorem.dart';

class TheoremDatabase {
  static final TheoremDatabase instance = TheoremDatabase._();
  TheoremDatabase._();

  final List<Theorem> _all = [
    // ───── CALCULUS ─────
    Theorem(
      id: "ftc",
      name: "Fundamental Theorem of Calculus",
      domain: "Calculus",
      author: "Newton & Leibniz",
      year: "1668",
      statement: "∫ₐᵇ f(x)dx = F(b) − F(a) where F'(x) = f(x)",
      statementLatex: "\\int_a^b f(x)\\,dx = F(b) - F(a)",
      explanation:
          "The FTC bridges differentiation and integration — they are inverse operations. "
          "Part 1: derivative of ∫ₐˣ f(t)dt = f(x). "
          "Part 2: definite integral computed via antiderivatives. "
          "This single theorem makes calculus practically computable.",
      proof:
          "Define G(x) = ∫ₐˣ f(t)dt. By FTC Part 1, G'(x) = f(x). "
          "G and F have same derivative so G = F + C. "
          "Then: ∫ₐᵇ f = G(b) - G(a) = (F(b)+C) - (F(a)+C) = F(b) - F(a). ∎",
      applications: [
        "Computing areas, volumes",
        "Physics: work, displacement from velocity",
        "Probability: CDF from PDF",
        "Signal processing",
      ],
    ),
    Theorem(
      id: "mvt",
      name: "Mean Value Theorem",
      domain: "Calculus",
      author: "Lagrange",
      year: "1797",
      statement:
          "If f is continuous on [a,b] and differentiable on (a,b), then ∃c: f'(c) = (f(b)−f(a))/(b−a)",
      statementLatex: "\\exists c \\in (a,b): f'(c) = \\frac{f(b)-f(a)}{b-a}",
      explanation:
          "At some interior point, the instantaneous rate of change equals the average rate of change. "
          "Geometrically: a tangent line parallel to the secant line always exists.",
      proof:
          "Apply Rolle's theorem to g(x) = f(x) - f(a) - [(f(b)-f(a))/(b-a)](x-a). g(a)=g(b)=0, so g'(c)=0 for some c. ∎",
      applications: [
        "Proving f'=0 implies f constant",
        "Error bounds in numerics",
        "Physics: average velocity",
        "Inequalities",
      ],
    ),
    Theorem(
      id: "taylor",
      name: "Taylor's Theorem",
      domain: "Calculus",
      author: "Brook Taylor",
      year: "1715",
      statement: "f(x) = Σ f⁽ⁿ⁾(a)/n! · (x−a)ⁿ + Rₙ(x)",
      statementLatex:
          "f(x) = \\sum_{n=0}^{N}\\frac{f^{(n)}(a)}{n!}(x-a)^n + R_N(x)",
      explanation:
          "Any smooth function can be approximated by a polynomial using its derivatives at a point. "
          "As N → ∞, Rₙ → 0 for analytic functions. Maclaurin series: special case a=0.",
      proof:
          "By repeated integration by parts from f(x) = f(a) + ∫ₐˣ f'(t)dt. Each IBP step adds the next term. Remainder: Rₙ = f^(n+1)(c)/(n+1)! · (x-a)^(n+1). ∎",
      applications: [
        "Small angle approximation sin(θ)≈θ",
        "Numerical root finding (Newton's method)",
        "Physics: linearization",
        "ML: optimization landscape",
      ],
    ),
    Theorem(
      id: "lhopital",
      name: "L'Hôpital's Rule",
      domain: "Calculus",
      author: "Johann Bernoulli / Guillaume l'Hôpital",
      year: "1696",
      statement:
          "If lim f(x)/g(x) is 0/0 or ∞/∞, then it equals lim f'(x)/g'(x)",
      statementLatex:
          "\\lim_{x\\to a}\\frac{f(x)}{g(x)} \\overset{H}{=} \\lim_{x\\to a}\\frac{f'(x)}{g'(x)}",
      explanation:
          "Resolves indeterminate forms (0/0, ∞/∞) by differentiating numerator and denominator separately. "
          "NOT the quotient rule — differentiate top and bottom independently.",
      proof:
          "Follows from Cauchy's generalization of MVT. Full proof via Cauchy MVT applied to f and g simultaneously.",
      applications: [
        "Evaluating indeterminate limits",
        "Proving classic limits: sin(x)/x → 1",
        "Asymptotic analysis",
        "Series convergence",
      ],
    ),

    // ───── LINEAR ALGEBRA ─────
    Theorem(
      id: "spectral",
      name: "Spectral Theorem",
      domain: "Linear Algebra",
      statement:
          "Every real symmetric matrix is orthogonally diagonalizable with real eigenvalues",
      statementLatex: "A = A^T \\Rightarrow A = Q\\Lambda Q^T,\\; QQ^T = I",
      explanation:
          "For symmetric matrices: all eigenvalues are real, eigenvectors for distinct eigenvalues are orthogonal. "
          "This is the mathematical foundation of PCA, quantum mechanics observables, and structural vibration analysis.",
      proof:
          "Induction on n. A has a real eigenvalue (Complex roots of real polynomials come in conjugate pairs; symmetric matrices have real eigenvalues by Ax·x = x·Ax). Restrict to eigenspace complement, apply induction. ∎",
      applications: [
        "PCA / dimensionality reduction",
        "Quantum mechanics observables",
        "Google PageRank",
        "Structural engineering vibrations",
      ],
    ),
    Theorem(
      id: "rank_nullity",
      name: "Rank-Nullity Theorem",
      domain: "Linear Algebra",
      statement: "For linear map T: V→W, dim(V) = rank(T) + nullity(T)",
      statementLatex: "\\dim(V) = \\text{rank}(T) + \\text{nullity}(T)",
      explanation:
          "The input dimension splits into: image dimension + kernel dimension. "
          "A big kernel means a small image — the transformation loses information.",
      proof:
          "Extend kernel basis to full basis of V. Show images of non-kernel basis vectors are linearly independent and span Im(T). Count = dim(V) - nullity(T). ∎",
      applications: [
        "Linear systems: existence and uniqueness",
        "Over/underdetermined systems",
        "Coding theory",
        "Computer graphics",
      ],
    ),
    Theorem(
      id: "svd",
      name: "Singular Value Decomposition",
      domain: "Linear Algebra",
      statement:
          "Any m×n matrix A = UΣVᵀ where U, V orthogonal and Σ diagonal non-negative",
      statementLatex: "A = U\\Sigma V^T",
      explanation:
          "Generalizes eigendecomposition to non-square matrices. Singular values σᵢ = stretching amounts. "
          "Truncated SVD gives best low-rank approximation (Eckart-Young theorem).",
      proof:
          "AᵀA positive semidefinite → orthogonally diagonalizable. V = eigenvectors of AᵀA, σᵢ = √λᵢ, uᵢ = Avᵢ/σᵢ. Then AV = UΣ → A = UΣVᵀ. ∎",
      applications: [
        "Image compression",
        "Netflix/Spotify recommendations",
        "NLP (LSA)",
        "Pseudoinverse",
        "Noise reduction",
      ],
    ),
    Theorem(
      id: "cayley_hamilton",
      name: "Cayley-Hamilton Theorem",
      domain: "Linear Algebra",
      statement:
          "Every square matrix satisfies its own characteristic polynomial: p(A) = 0",
      statementLatex:
          "p(\\lambda) = \\det(A-\\lambda I) = 0 \\Rightarrow p(A) = 0",
      explanation:
          "Plug the matrix itself into its characteristic polynomial — you always get the zero matrix. "
          "This allows computing A⁻¹ and high matrix powers without repeated multiplication.",
      proof:
          "Factor over algebraically closed field. Schur decomposition reduces to triangular case. For triangular matrices, verify directly by nilpotent argument. ∎",
      applications: [
        "Computing matrix inverse via polynomial",
        "Control theory: minimal polynomial",
        "Matrix exponential",
      ],
    ),

    // ───── REAL ANALYSIS ─────
    Theorem(
      id: "bolzano_weierstrass",
      name: "Bolzano-Weierstrass Theorem",
      domain: "Real Analysis",
      author: "Bolzano & Weierstrass",
      year: "1817",
      statement: "Every bounded sequence in ℝⁿ has a convergent subsequence",
      statementLatex:
          "\\{x_n\\}\\text{ bounded} \\Rightarrow \\exists\\{x_{n_k}\\}\\text{ convergent}",
      explanation:
          "Bounded sequences can't escape to infinity — some subsequence must converge. "
          "This is the compactness argument in disguise.",
      proof:
          "n=1: [a,b] contains infinite sequence. Bisect repeatedly choosing the half with infinitely many terms. Selected terms form Cauchy sequence → converges. ∎",
      applications: [
        "Proving extreme value theorem",
        "Existence of minimizers in optimization",
        "Functional analysis",
        "Dynamical systems",
      ],
    ),
    Theorem(
      id: "heine_borel",
      name: "Heine-Borel Theorem",
      domain: "Real Analysis",
      statement: "A subset of ℝⁿ is compact iff it is closed and bounded",
      statementLatex:
          "K \\subset \\mathbb{R}^n\\text{ compact} \\iff K\\text{ closed and bounded}",
      explanation:
          "Compactness = closed + bounded in Euclidean space. Compact sets are where analysis is nice: "
          "continuous functions attain extrema, sequences have convergent subsequences.",
      proof:
          "⇒: Compact → closed (limits in set) and bounded (finitely many unit ball cover). ⇐: Closed bounded → Bolzano-Weierstrass → sequentially compact → compact. ∎",
      applications: [
        "Extreme value theorem",
        "Optimization existence",
        "Functional analysis",
        "Machine learning convergence",
      ],
    ),
    Theorem(
      id: "monotone_convergence",
      name: "Monotone Convergence Theorem",
      domain: "Real Analysis",
      statement: "Every bounded monotone sequence in ℝ converges",
      statementLatex:
          "\\{a_n\\}\\text{ monotone and bounded} \\Rightarrow \\lim a_n\\text{ exists}",
      explanation:
          "Increasing + bounded above → converges to supremum. Decreasing + bounded below → converges to infimum. "
          "This is essentially the completeness of ℝ in action.",
      proof:
          "Let L = sup{aₙ}. For any ε>0, ∃N: aₙ > L-ε. Since monotone increasing, aₙ ≥ aₙ for n≥N. So |aₙ-L| < ε for all n≥N. ∎",
      applications: [
        "Defining e = lim(1+1/n)ⁿ",
        "Convergence of Newton's method",
        "Proving series converge",
        "Fixed point theorems",
      ],
    ),

    // ───── DIFFERENTIAL EQUATIONS ─────
    Theorem(
      id: "existence_uniqueness",
      name: "Picard-Lindelöf Theorem",
      domain: "Differential Equations",
      author: "Picard & Lindelöf",
      year: "1890",
      statement:
          "If f is Lipschitz continuous, then y' = f(x,y), y(x₀) = y₀ has a unique local solution",
      statementLatex:
          "y' = f(x,y),\\;y(x_0)=y_0 \\Rightarrow \\exists! \\text{ solution locally}",
      explanation:
          "Guarantees ODEs have unique solutions under mild conditions. "
          "Proved via Picard iteration: yₙ₊₁(x) = y₀ + ∫f(t, yₙ(t))dt converges to unique solution.",
      proof:
          "Define Picard operator T[y](x) = y₀ + ∫f(t,y(t))dt. Show T is contraction on complete metric space. Banach fixed point theorem gives unique fixed point = solution. ∎",
      applications: [
        "Confirms ODE solutions exist before computing them",
        "Foundation of numerical ODE solvers",
        "Dynamical systems theory",
      ],
    ),

    // ───── NUMBER THEORY ─────
    Theorem(
      id: "prime_number",
      name: "Prime Number Theorem",
      domain: "Number Theory",
      author: "Hadamard & de la Vallée Poussin",
      year: "1896",
      statement: "The number of primes ≤ x satisfies π(x) ~ x/ln(x) as x → ∞",
      statementLatex: "\\pi(x) \\sim \\frac{x}{\\ln x} \\quad (x \\to \\infty)",
      explanation:
          "Primes thin out but in a predictable way. The probability that a random number near n is prime ≈ 1/ln(n). "
          "Proved using complex analysis on the Riemann zeta function.",
      proof:
          "Follows from showing ζ(s) has no zeros on Re(s)=1. Hadamard and de la Vallée Poussin proved this independently in 1896. ∎",
      applications: [
        "Cryptographic key generation",
        "RSA security analysis",
        "Random prime generation",
        "Distribution of twin primes",
      ],
    ),
    Theorem(
      id: "fermat_little",
      name: "Fermat's Little Theorem",
      domain: "Number Theory",
      author: "Fermat",
      year: "1640",
      statement: "If p is prime and gcd(a,p)=1, then aᵖ⁻¹ ≡ 1 (mod p)",
      statementLatex:
          "a^{p-1} \\equiv 1 \\pmod{p} \\quad (p\\text{ prime}, \\gcd(a,p)=1)",
      explanation:
          "The multiplicative group mod p has order p-1. "
          "Consequence: aᵖ ≡ a (mod p) for ALL a (including multiples of p). "
          "Foundation of RSA encryption and Miller-Rabin primality test.",
      proof:
          "The set {a, 2a, 3a, ..., (p-1)a} is a permutation of {1, 2, ..., p-1} mod p. Multiply both sides: a^(p-1)·(p-1)! ≡ (p-1)! (mod p). Cancel (p-1)!. ∎",
      applications: [
        "RSA decryption",
        "Miller-Rabin primality test",
        "Computing modular inverses",
        "Euler's theorem generalization",
      ],
    ),
    Theorem(
      id: "euclid_infinitely_primes",
      name: "Euclid's Theorem",
      domain: "Number Theory",
      author: "Euclid",
      year: "300 BC",
      statement: "There are infinitely many prime numbers",
      statementLatex: "\\{p : p \\text{ prime}\\}\\text{ is infinite}",
      explanation:
          "One of the oldest and most elegant proofs in mathematics. "
          "The proof by contradiction is a template for mathematical reasoning.",
      proof:
          "Assume finitely many primes p₁,...,pₙ. Let N = p₁·p₂·...·pₙ + 1. N is divisible by some prime p. But p cannot be any of p₁,...,pₙ (remainder 1). Contradiction. ∎",
      applications: [
        "Foundation of number theory",
        "Cryptographic security (key space is infinite)",
        "Mathematical proof technique template",
      ],
    ),
    Theorem(
      id: "fermat_last",
      name: "Fermat's Last Theorem",
      domain: "Number Theory",
      author: "Andrew Wiles",
      year: "1995",
      statement: "No positive integers a, b, c satisfy aⁿ + bⁿ = cⁿ for n > 2",
      statementLatex:
          "a^n + b^n = c^n\\text{ has no positive integer solutions for }n > 2",
      explanation:
          "Fermat wrote in 1637 that he had a 'truly marvelous proof' but the margin was too small. "
          "358 years later, Andrew Wiles proved it in a 130-page proof connecting elliptic curves and modular forms — "
          "using mathematics that didn't exist in Fermat's time.",
      proof:
          "Wiles proved the Modularity Theorem for semistable elliptic curves (1995). "
          "Ribet (1986) showed this implies FLT via the Frey curve: if aⁿ+bⁿ=cⁿ, the Frey curve y²=x(x-aⁿ)(x+bⁿ) would be non-modular — contradiction. ∎",
      applications: [
        "Developed algebraic number theory",
        "Modular forms in cryptography",
        "Inspired entire new math subfields",
      ],
    ),

    // ───── ABSTRACT ALGEBRA ─────
    Theorem(
      id: "fundamental_algebra",
      name: "Fundamental Theorem of Algebra",
      domain: "Abstract Algebra",
      author: "Gauss",
      year: "1799",
      statement:
          "Every non-constant polynomial over ℂ has at least one complex root",
      statementLatex:
          "p(z) = a_nz^n + \\cdots + a_0,\\;a_n\\neq 0 \\Rightarrow \\exists z_0\\in\\mathbb{C}: p(z_0)=0",
      explanation:
          "Every degree-n polynomial has exactly n complex roots (counting multiplicity). "
          "ℂ is algebraically closed — unlike ℝ where x²+1=0 has no solution.",
      proof:
          "Suppose p has no roots. Then 1/p(z) is entire. As |z|→∞, |p(z)|→∞ so 1/p is bounded. By Liouville's theorem, 1/p is constant. Contradiction. ∎",
      applications: [
        "Eigenvalues always exist in ℂ",
        "Control theory: pole placement",
        "Signal processing: Z-transform",
        "Root finding algorithms",
      ],
    ),
    Theorem(
      id: "lagrange_group",
      name: "Lagrange's Theorem",
      domain: "Abstract Algebra",
      author: "Lagrange",
      year: "1771",
      statement: "For finite group G and subgroup H, |H| divides |G|",
      statementLatex: "|H| \\mid |G| \\text{ for subgroup } H \\leq G",
      explanation:
          "The order of any subgroup must divide the order of the group. "
          "Consequence: groups of prime order p are always cyclic (isomorphic to ℤ/pℤ).",
      proof:
          "Left cosets {gH} partition G into equal-sized pieces, each with |H| elements. So |G| = [G:H]·|H|. ∎",
      applications: [
        "Group classification",
        "Cryptography: discrete log security",
        "Counting orbits",
        "Galois theory",
      ],
    ),

    // ───── STATISTICS ─────
    Theorem(
      id: "clt",
      name: "Central Limit Theorem",
      domain: "Statistics",
      statement:
          "Sample means approach normal distribution as n → ∞ regardless of underlying distribution",
      statementLatex:
          "\\bar{X} \\xrightarrow{d} N\\!\\left(\\mu, \\frac{\\sigma^2}{n}\\right)",
      explanation:
          "Perhaps the most practically important theorem in statistics. "
          "No matter how weird the population distribution, averages of large samples are approximately normal. "
          "This is why normal distribution appears everywhere.",
      proof:
          "Via characteristic functions: moment generating function of normalized sum converges to MGF of standard normal. Or via Fourier analysis on the MGF. ∎",
      applications: [
        "Statistical inference",
        "Confidence intervals",
        "Hypothesis testing",
        "Quality control",
        "Machine learning generalization bounds",
      ],
    ),
    Theorem(
      id: "bayes",
      name: "Bayes' Theorem",
      domain: "Statistics",
      author: "Thomas Bayes & Laplace",
      year: "1763",
      statement: "P(A|B) = P(B|A)·P(A) / P(B)",
      statementLatex: "P(A|B) = \\frac{P(B|A) \\cdot P(A)}{P(B)}",
      explanation:
          "Updates probability (prior) given new evidence to get posterior probability. "
          "Foundation of Bayesian inference — a complete framework for learning from data.",
      proof:
          "Follows directly from the definition of conditional probability P(A|B) = P(A∩B)/P(B) and symmetry P(A∩B) = P(B|A)P(A). ∎",
      applications: [
        "Medical diagnosis",
        "Spam filtering",
        "Bayesian ML models",
        "Search algorithms",
        "Scientific hypothesis testing",
      ],
    ),

    // ───── UNSOLVED PROBLEMS ─────
    Theorem(
      id: "riemann",
      name: "Riemann Hypothesis",
      domain: "Number Theory",
      author: "Bernhard Riemann",
      year: "1859",
      statement:
          "All non-trivial zeros of ζ(s) lie on the critical line Re(s) = 1/2",
      statementLatex: "\\zeta(s) = 0 \\Rightarrow \\text{Re}(s) = \\frac{1}{2}",
      explanation:
          "The Riemann zeta function ζ(s) = Σ1/nˢ encodes all information about prime distribution. "
          "Its zeros control the error in the Prime Number Theorem. "
          "Over 10¹³ zeros verified computationally — all on the critical line. No proof.",
      proof:
          "UNSOLVED. Riemann proposed in 1859. Hardy proved infinitely many zeros are on the critical line. "
          "Hadamard proved no zeros on Re(s)=1. The strip 0 < Re(s) < 1 remains mysterious.",
      applications: [
        "Prime distribution precision",
        "RSA cryptography",
        "Quantum chaos",
        "Random matrix theory",
      ],
      isUnsolved: true,
      prizeInfo: "Clay Millennium Prize: \$1,000,000",
      unsolvedNote:
          "If proved, it would give the tightest known bounds on prime distribution. "
          "If disproved (one zero found off the line), it would shake number theory to its foundations.",
    ),
    Theorem(
      id: "p_vs_np",
      name: "P vs NP Problem",
      domain: "Computer Science",
      year: "1971",
      statement:
          "Does P = NP? Can every efficiently verifiable problem be efficiently solved?",
      statementLatex: "P \\stackrel{?}{=} NP",
      explanation:
          "P = problems solvable in polynomial time. NP = problems where solutions are verifiable in polynomial time. "
          "If P=NP: all encryption breaks. All creative problems (art, science) become mechanical. "
          "~83% of researchers believe P≠NP but no proof exists.",
      proof:
          "UNSOLVED. The defining open problem of computer science. Cook-Levin theorem (1971) showed NP-completeness. Hundreds of failed proofs. No progress on lower bounds.",
      applications: [
        "RSA/AES security",
        "Optimization",
        "AI and ML complexity",
        "Drug discovery",
      ],
      isUnsolved: true,
      prizeInfo: "Clay Millennium Prize: \$1,000,000",
      unsolvedNote:
          "P=NP would break all public-key cryptography instantly. Your bank, WhatsApp, everything.",
    ),
    Theorem(
      id: "goldbach",
      name: "Goldbach's Conjecture",
      domain: "Number Theory",
      author: "Christian Goldbach",
      year: "1742",
      statement: "Every even integer > 2 is the sum of two prime numbers",
      statementLatex:
          "\\forall n > 2,\\; n\\text{ even} \\Rightarrow \\exists p,q\\text{ prime}: n = p + q",
      explanation:
          "4=2+2, 6=3+3, 8=3+5, 100=3+97=11+89=... Verified up to 4×10¹⁸. "
          "Chen's theorem (1973): every large even n = prime + semiprime. One step away. "
          "281 years and no proof.",
      proof:
          "UNSOLVED. Oldest open problem in number theory. Proposed to Euler in 1742.",
      applications: [
        "Sieve theory development",
        "Computational number theory benchmarks",
      ],
      isUnsolved: true,
      unsolvedNote:
          "Simple to state, impossible to prove. The gap between computational verification and mathematical proof.",
    ),
    Theorem(
      id: "navier_stokes",
      name: "Navier-Stokes Existence & Smoothness",
      domain: "Differential Equations",
      statement:
          "Do smooth solutions to 3D Navier-Stokes always exist, or can they blow up in finite time?",
      statementLatex:
          "\\frac{\\partial\\mathbf{u}}{\\partial t} + (\\mathbf{u}\\cdot\\nabla)\\mathbf{u} = -\\nabla p + \\nu\\nabla^2\\mathbf{u}",
      explanation:
          "These equations govern fluid flow — from aircraft wings to blood. "
          "In 2D: smooth solutions always exist. In 3D: unknown. "
          "Can turbulence create infinite velocities (blow-up) in finite time? Nobody knows.",
      proof:
          "UNSOLVED. 2D solved. 3D regularity or blow-up open. One of the hardest PDE problems.",
      applications: [
        "Aircraft design",
        "Weather modeling",
        "Cardiovascular flow",
        "Ocean circulation",
      ],
      isUnsolved: true,
      prizeInfo: "Clay Millennium Prize: \$1,000,000",
      unsolvedNote:
          "Turbulence — Feynman called it 'the most important unsolved problem of classical physics.'",
    ),
    Theorem(
      id: "twin_prime",
      name: "Twin Prime Conjecture",
      domain: "Number Theory",
      statement: "There are infinitely many pairs of primes (p, p+2)",
      statementLatex:
          "\\exists\\text{ infinitely many }p:\\; p,\\, p+2\\text{ both prime}",
      explanation:
          "Twin primes: (3,5), (5,7), (11,13), (17,19)... "
          "Zhang (2013) proved infinitely many prime pairs with gap ≤ 70,000,000. "
          "Polymath project: gap ≤ 246. From 246 to 2 is the entire remaining problem.",
      proof:
          "UNSOLVED. Zhang's 2013 breakthrough was the first finite bound — a watershed in analytic number theory.",
      applications: [
        "Analytic number theory",
        "Sieve methods",
        "Distribution of prime gaps",
      ],
      isUnsolved: true,
      unsolvedNote:
          "Zhang proved the result after years working in isolation. From gap 70M to 246 in one year. From 246 to 2: open.",
    ),
    Theorem(
      id: "abc_conjecture",
      name: "ABC Conjecture",
      domain: "Number Theory",
      author: "Oesterlé & Masser",
      year: "1985",
      statement:
          "For a+b=c (coprime), c is rarely much larger than the product of distinct prime factors of abc",
      statementLatex:
          "c < \\text{rad}(abc)^{1+\\varepsilon}\\text{ for all but finitely many coprime triples}",
      explanation:
          "rad(n) = product of distinct prime factors of n. "
          "If proved, it immediately implies Fermat's Last Theorem for large n. "
          "Mochizuki claimed a proof in 2012 using Inter-Universal Teichmüller Theory — "
          "experts still debating its validity in 2024.",
      proof:
          "DISPUTED. Mochizuki (2012) ~500-page proof. Most experts unable to verify. Status unclear.",
      applications: [
        "Implies many results in Diophantine equations",
        "Fermat's Last Theorem as corollary",
        "Elliptic curves",
      ],
      isUnsolved: true,
      unsolvedNote:
          "Most controversial claim in recent mathematics. A proof exists on paper that almost nobody understands.",
    ),
  ];

  List<Theorem> get all => List.unmodifiable(_all);
  List<Theorem> get unsolved => _all.where((t) => t.isUnsolved).toList();

  List<Theorem> search(String query) {
    if (query.isEmpty) return _all;
    final q = query.toLowerCase();
    return _all
        .where(
          (t) =>
              t.name.toLowerCase().contains(q) ||
              t.domain.toLowerCase().contains(q) ||
              t.statement.toLowerCase().contains(q) ||
              t.explanation.toLowerCase().contains(q),
        )
        .toList();
  }

  List<Theorem> byDomain(String domain) => _all
      .where((t) => t.domain.toLowerCase() == domain.toLowerCase())
      .toList();

  Theorem? byId(String id) {
    try {
      return _all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
