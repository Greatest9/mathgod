// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'solver_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _domains = [
    (
      sym: "∫",
      name: "Calculus",
      sub: "Derivatives · Integrals · Limits",
      col: Color(0xFF7C6FFF),
    ),
    (
      sym: "⊞",
      name: "Linear Algebra",
      sub: "Matrices · Eigenvalues · SVD",
      col: Color(0xFF00E5AA),
    ),
    (
      sym: "∂",
      name: "Diff. Equations",
      sub: "ODEs · Separable · 2nd Order",
      col: Color(0xFFFF6B8A),
    ),
    (
      sym: "ε",
      name: "Real Analysis",
      sub: "Series · Convergence · Epsilon-Delta",
      col: Color(0xFFFFB347),
    ),
    (
      sym: "ℕ",
      name: "Number Theory",
      sub: "Primes · Modular · Cryptography",
      col: Color(0xFF4ECDC4),
    ),
    (
      sym: "⊕",
      name: "Abstract Algebra",
      sub: "Groups · Rings · Fields",
      col: Color(0xFFB47AEA),
    ),
    (
      sym: "σ",
      name: "Statistics",
      sub: "Probability · Distributions · Bayes",
      col: Color(0xFFFF8C00),
    ),
    (
      sym: "θ",
      name: "Trigonometry",
      sub: "Identities · Unit Circle · Inverse",
      col: Color(0xFF00BFFF),
    ),
    (
      sym: "ℂ",
      name: "Complex Analysis",
      sub: "Euler · Modulus · De Moivre",
      col: Color(0xFFFF69B4),
    ),
    (
      sym: "∞",
      name: "Topology",
      sub: "Compactness · Continuity · Homeomorphism",
      col: Color(0xFF98FB98),
    ),
    (
      sym: "∇",
      name: "Vector Calculus",
      sub: "Grad · Curl · Div · Stokes",
      col: Color(0xFFDDA0DD),
    ),
  ];

  static const _quickExamples = [
    "d/dx[x^5]",
    "int(x^3)",
    "lim(sin(x)/x, x, 0)",
    "det([[1,2],[3,4]])",
    "eigen([[4,1],[2,3]])",
    "ode(y'' + 4y = 0)",
    "series(1/n^2)",
    "isprime(97)",
    "sin(pi/6)",
    "complex(3+4i)",
    "mean([1,2,3,4,5])",
    "factorize(360)",
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildOfflineBadge(context)),
          SliverToBoxAdapter(child: _buildExamples(context)),
          SliverToBoxAdapter(child: _buildDomainHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _DomainCard(d: _domains[i])
                    .animate(delay: (40 * i).ms)
                    .fadeIn()
                    .scale(begin: const Offset(0.95, 0.95)),
                childCount: _domains.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C6FFF), Color(0xFF00E5AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    "∑",
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Math God",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    "Fields Medalist in your pocket",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
    );
  }

  Widget _buildOfflineBadge(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5AA).withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00E5AA).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFF00E5AA),
              size: 16,
            ),
            const SizedBox(width: 10),
            Text(
              "No . Internet . Needed",
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  Widget _buildExamples(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Try These:", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickExamples
                .map(
                  (e) => _ExampleChip(
                    label: e,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SolverScreen(initialInput: e),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        "All Domains",
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final ({String sym, String name, String sub, Color col}) d;
  const _DomainCard({required this.d});

  // One representative example per domain, pre-fills the solver
  static const _domainExamples = {
    'Calculus': 'd/dx[x^5]',
    'Linear Algebra': 'eigen([[4,1],[2,3]])',
    'Diff. Equations': "ode(y'' + 4y = 0)",
    'Real Analysis': 'series(1/n^2)',
    'Number Theory': 'factorize(360)',
    'Abstract Algebra': 'group(Z_n)',
    'Statistics': 'mean([1,2,3,4,5])',
    'Trigonometry': 'sin(pi/6)',
    'Complex Analysis': 'complex(3+4i)',
    'Topology': 'topology(compact)',
    'Vector Calculus': 'curl(F)',
  };

  @override
  Widget build(BuildContext context) {
    final example = _domainExamples[d.name];
    return GestureDetector(
      onTap: () {
        if (example != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SolverScreen(initialInput: example),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161624),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: d.col.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(d.sym, style: TextStyle(fontSize: 22, color: d.col)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  d.sub,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExampleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF161624),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF232336)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'IBMPlexMono',
            color: Color(0xFF00E5AA),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
