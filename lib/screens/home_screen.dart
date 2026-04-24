// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'solver_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Secondary School domains ────────────────────────────────────────────────
  static const _secondaryDomains = [
    (
      sym: "θ",
      name: "Trigonometry",
      sub: "SOHCAHTOA · Identities · Unit Circle",
      col: Color(0xFF00BFFF),
    ),
    (
      sym: "x²",
      name: "Algebra",
      sub: "Quadratics · Factoring · Equations",
      col: Color(0xFF7C6FFF),
    ),
    (
      sym: "σ",
      name: "Statistics",
      sub: "Mean · Median · Probability",
      col: Color(0xFFFF8C00),
    ),
    (
      sym: "ℕ",
      name: "Number Theory",
      sub: "Primes · GCD · LCM · Factorize",
      col: Color(0xFF4ECDC4),
    ),
    (
      sym: "∠",
      name: "Geometry",
      sub: "Area · Volume · Angles · Pythagoras",
      col: Color(0xFFFFB347),
    ),
    (
      sym: "ƒ",
      name: "Functions",
      sub: "Graphs · Domain · Range · Inverse",
      col: Color(0xFF98FB98),
    ),
  ];

  // ── A-Level / University domains ────────────────────────────────────────────
  static const _alevelDomains = [
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
      sub: "Series · Convergence · Taylor",
      col: Color(0xFFFFB347),
    ),
    (
      sym: "⊕",
      name: "Abstract Algebra",
      sub: "Groups · Rings · Fields",
      col: Color(0xFFB47AEA),
    ),
    (
      sym: "ℂ",
      name: "Complex Analysis",
      sub: "Euler · Modulus · De Moivre",
      col: Color(0xFFFF69B4),
    ),
    (
      sym: "∇",
      name: "Vector Calculus",
      sub: "Grad · Curl · Div · Stokes",
      col: Color(0xFFDDA0DD),
    ),
    (
      sym: "∞",
      name: "Topology",
      sub: "Compactness · Continuity · Homeomorphism",
      col: Color(0xFF98FB98),
    ),
    (
      sym: "ℒ",
      name: "Laplace / Fourier",
      sub: "Transforms · Engineering · Signals",
      col: Color(0xFF00CED1),
    ),
  ];

  // ── Quick examples per level ────────────────────────────────────────────────
  static const _secondaryExamples = [
    "sin(pi/6)",
    "factorize(360)",
    "gcd(48,18)",
    "mean([1,2,3,4,5])",
    "isprime(97)",
    "lcm(4,6)",
  ];

  static const _alevelExamples = [
    "d/dx[x^5]",
    "int(x^3)",
    "lim(sin(x)/x, x, 0)",
    "det([[1,2],[3,4]])",
    "eigen([[4,1],[2,3]])",
    "ode(y'' + 4y = 0)",
    "series(1/n^2)",
    "laplace(e^(-2t))",
    "taylor(sin(x), 6)",
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildOfflineBadge(context)),
          SliverToBoxAdapter(child: _buildTabBar(context)),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildLevel(
              context,
              domains: _secondaryDomains,
              examples: _secondaryExamples,
              label: "📚 Core Topics",
            ),
            _buildLevel(
              context,
              domains: _alevelDomains,
              examples: _alevelExamples,
              label: "🎓 Advanced Topics",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161624),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF232336)),
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: const Color(0xFF7C6FFF),
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF7777AA),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: "Secondary School"),
            Tab(text: "A-Level / Uni"),
          ],
        ),
      ),
    );
  }

  Widget _buildLevel(
    BuildContext context, {
    required List<({String sym, String name, String sub, Color col})> domains,
    required List<String> examples,
    required String label,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Try These:",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: examples
                      .map(
                        (e) => _ExampleChip(
                          label: e,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SolverScreen(initialInput: e),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _DomainCard(d: domains[i])
                  .animate(delay: (40 * i).ms)
                  .fadeIn()
                  .scale(begin: const Offset(0.95, 0.95)),
              childCount: domains.length,
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
          border:
              Border.all(color: const Color(0xFF00E5AA).withOpacity(0.2)),
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
    'Algebra': 'solve(x^2-5x+6=0)',
    'Geometry': 'sin(pi/4)',
    'Functions': 'd/dx[x^2]',
    'Laplace / Fourier': 'laplace(e^(-2t))',
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
