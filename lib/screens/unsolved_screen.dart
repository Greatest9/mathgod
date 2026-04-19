// lib/screens/unsolved_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../data/theorem_database.dart';
import '../models/theorem.dart';

class UnsolvedScreen extends StatelessWidget {
  const UnsolvedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final problems = TheoremDatabase.instance.unsolved;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          SliverToBoxAdapter(child: _intro(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ProblemCard(
                  p: problems[i],
                ).animate(delay: (60 * i).ms).fadeIn().slideY(begin: 0.07),
                childCount: problems.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "∞",
              style: TextStyle(color: Color(0xFFFF6B8A), fontSize: 22),
            ),
            const SizedBox(width: 10),
            Text(
              "Unsolved Mysteries",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "The hardest open problems in mathematics",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms),
  );

  Widget _intro(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFFFF6B8A).withOpacity(0.07),
          const Color(0xFFFFB347).withOpacity(0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFF6B8A).withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFFB347),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              "Millennium Prize Problems",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Clay Mathematics Institute: \$1,000,000 for each of 7 problems. Only 1 solved — Poincaré Conjecture (2003) by Grigori Perelman, who refused the prize.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ],
    ),
  ).animate().fadeIn(delay: 200.ms);
}

class _ProblemCard extends StatefulWidget {
  final Theorem p;
  const _ProblemCard({required this.p});
  @override
  State<_ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<_ProblemCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161624),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B8A).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge("UNSOLVED", const Color(0xFFFF6B8A)),
                      const SizedBox(width: 8),
                      _badge(p.domain.toUpperCase(), const Color(0xFF555577)),
                      const Spacer(),
                      if (p.prizeInfo != null)
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFB347),
                          size: 16,
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF555577),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    p.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080810),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Math.tex(
                        p.statementLatex,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFF0F0FF),
                        ),
                        onErrorFallback: (_) => SelectableText(
                          p.statementLatex,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMono',
                            color: Color(0xFF00E5AA),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: Color(0xFF232336)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detSec(context, "What is it?", p.explanation),
                  const SizedBox(height: 14),
                  _detSec(context, "Current Status", p.proof, red: true),
                  if (p.unsolvedNote != null) ...[
                    const SizedBox(height: 14),
                    _detSec(context, "Why It Matters", p.unsolvedNote!),
                  ],
                  if (p.applications.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      "Applications",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.applications
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF7C6FFF,
                                ).withOpacity(0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF7C6FFF,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  color: Color(0xFF9090CC),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (p.prizeInfo != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB347).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFB347).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Color(0xFFFFB347),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.prizeInfo!,
                              style: const TextStyle(
                                color: Color(0xFFFFD080),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _detSec(
    BuildContext context,
    String title,
    String content, {
    bool red = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
      ),
      const SizedBox(height: 6),
      Text(
        content,
        style: TextStyle(
          color: red ? const Color(0xFFFF9999) : const Color(0xFF9090BB),
          fontSize: 13,
          height: 1.6,
        ),
      ),
    ],
  );
}
