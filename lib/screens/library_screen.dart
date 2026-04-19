// lib/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../data/theorem_database.dart';
import '../models/theorem.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _domain;

  final _domains = [
    "All",
    "Calculus",
    "Linear Algebra",
    "Real Analysis",
    "Number Theory",
    "Abstract Algebra",
    "Statistics",
    "Differential Equations",
  ];

  List<Theorem> get _filtered {
    var r = TheoremDatabase.instance.search(_q);
    if (_domain != null && _domain != "All")
      r = r.where((t) => t.domain == _domain).toList();
    return r;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _header(),
          _filterRow(),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF232336))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "⊞",
                style: TextStyle(color: Color(0xFF7C6FFF), fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                "Theorem Library",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                "${TheoremDatabase.instance.all.length} theorems",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            style: const TextStyle(color: Color(0xFFF0F0FF), fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search theorems, proofs, topics...",
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF555577),
                size: 18,
              ),
              suffixIcon: _q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _search.clear();
                        setState(() => _q = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _domains.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = _domains[i];
          final sel = (_domain == null && d == "All") || _domain == d;
          return GestureDetector(
            onTap: () => setState(() => _domain = d == "All" ? null : d),
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF7C6FFF) : const Color(0xFF161624),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? const Color(0xFF7C6FFF)
                      : const Color(0xFF232336),
                ),
              ),
              child: Text(
                d,
                style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF7777AA),
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _list() {
    final items = _filtered;
    if (items.isEmpty)
      return Center(
        child: Text(
          "No theorems found",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TheoremCard(
        t: items[i],
        onTap: () => _showDetail(items[i]),
      ).animate(delay: (30 * i).ms).fadeIn().slideY(begin: 0.05),
    );
  }

  void _showDetail(Theorem t) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _TheoremDetail(t: t)),
  );
}

class _TheoremCard extends StatelessWidget {
  final Theorem t;
  final VoidCallback onTap;
  const _TheoremCard({required this.t, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161624),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: t.isUnsolved
                ? const Color(0xFFFF6B8A).withOpacity(0.3)
                : const Color(0xFF232336),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (t.isUnsolved)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B8A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFFF6B8A).withOpacity(0.4),
                            ),
                          ),
                          child: const Text(
                            "UNSOLVED",
                            style: TextStyle(
                              color: Color(0xFFFF6B8A),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          t.name,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.domain,
                    style: const TextStyle(
                      color: Color(0xFF7C6FFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.statement,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF555577), size: 20),
          ],
        ),
      ),
    );
  }
}

class _TheoremDetail extends StatelessWidget {
  final Theorem t;
  const _TheoremDetail({required this.t});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF10101C),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: t.isUnsolved
                          ? [
                              const Color(0xFFFF6B8A).withOpacity(0.15),
                              const Color(0xFF080810),
                            ]
                          : [
                              const Color(0xFF7C6FFF).withOpacity(0.15),
                              const Color(0xFF080810),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (t.isUnsolved)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B8A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "UNSOLVED PROBLEM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text(
                        t.name,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      Row(
                        children: [
                          Text(
                            t.domain,
                            style: const TextStyle(
                              color: Color(0xFF7C6FFF),
                              fontSize: 13,
                            ),
                          ),
                          if (t.author != null) ...[
                            const Text(
                              "  ·  ",
                              style: TextStyle(color: Color(0xFF555577)),
                            ),
                            Text(
                              t.author!,
                              style: const TextStyle(
                                color: Color(0xFF555577),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (t.year != null) ...[
                            const Text(
                              "  ·  ",
                              style: TextStyle(color: Color(0xFF555577)),
                            ),
                            Text(
                              t.year!,
                              style: const TextStyle(
                                color: Color(0xFF555577),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _sec(context, "Statement", _latex(t.statementLatex)),
                  _sec(context, "Explanation", _txt(context, t.explanation)),
                  _sec(
                    context,
                    t.isUnsolved ? "Current Status" : "Proof Sketch",
                    _proof(context, t),
                  ),
                  _sec(context, "Applications", _apps(context, t.applications)),
                  if (t.unsolvedNote != null)
                    _sec(
                      context,
                      "Why It Matters",
                      _txt(context, t.unsolvedNote!),
                    ),
                  if (t.prizeInfo != null) _prize(context, t.prizeInfo!),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sec(BuildContext context, String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF7C6FFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _latex(String latex) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF080810),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF232336)),
    ),
    child: Center(
      child: Math.tex(
        latex,
        textStyle: const TextStyle(fontSize: 17, color: Color(0xFFF0F0FF)),
        onErrorFallback: (_) => SelectableText(
          latex,
          style: const TextStyle(
            fontFamily: 'IBMPlexMono',
            color: Color(0xFF00E5AA),
            fontSize: 14,
          ),
        ),
      ),
    ),
  );

  Widget _txt(BuildContext context, String text) => Text(
    text,
    style: const TextStyle(color: Color(0xFF9090BB), fontSize: 13, height: 1.7),
  );

  Widget _proof(BuildContext context, Theorem t) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: t.isUnsolved
          ? const Color(0xFFFF6B8A).withOpacity(0.04)
          : const Color(0xFF161624),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: t.isUnsolved
            ? const Color(0xFFFF6B8A).withOpacity(0.2)
            : const Color(0xFF232336),
      ),
    ),
    child: Text(
      t.proof,
      style: TextStyle(
        color: t.isUnsolved ? const Color(0xFFFF9999) : const Color(0xFF9090BB),
        fontSize: 13,
        height: 1.7,
        fontFamily: t.isUnsolved ? null : 'IBMPlexMono',
      ),
    ),
  );

  Widget _apps(BuildContext context, List<String> apps) => Column(
    children: apps
        .map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.arrow_right,
                    color: Color(0xFF00E5AA),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a,
                    style: const TextStyle(
                      color: Color(0xFF9090BB),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  Widget _prize(BuildContext context, String prize) => Container(
    margin: const EdgeInsets.only(bottom: 24),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFB347).withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFFB347).withOpacity(0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.emoji_events, color: Color(0xFFFFB347), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            prize,
            style: const TextStyle(
              color: Color(0xFFFFD080),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
