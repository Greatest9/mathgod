// lib/screens/solver_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../engine/solver_engine.dart';
import '../models/solution.dart';

class SolverScreen extends StatefulWidget {
  final String? initialInput;
  const SolverScreen({super.key, this.initialInput});

  @override
  State<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends State<SolverScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _screenshotCtrl = ScreenshotController();
  Solution? _solution;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialInput != null) {
      _ctrl.text = widget.initialInput!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _solve());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _solve() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    _focus.unfocus();
    setState(() => _loading = true);
    // Run solver off the main thread so complex Giac calls don't jank the UI
    final solution = await Future.microtask(
      () => SolverEngine.instance.solve(input),
    );
    if (!mounted) return;
    setState(() {
      _solution = solution;
      _loading = false;
    });
  }

  Future<void> _shareResult() async {
    if (_solution == null) return;
    try {
      // Capture the result card as PNG
      final Uint8List? imageBytes = await _screenshotCtrl.capture(
        pixelRatio: 2.5,
      );
      if (imageBytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mathgod_result.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Solved with Math God 🧠\n'
            'Input: ${_solution!.input}\n'
            'Result: ${_solution!.resultReadable}',
        subject: 'Math God — ${_solution!.operation}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C6FFF),
                      ),
                    )
                  : _solution == null
                  ? _buildEmpty()
                  : _buildResult(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
                "∫",
                style: TextStyle(color: Color(0xFF7C6FFF), fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text("Solver", style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (_solution != null) ...[
                // Share button
                IconButton(
                  icon: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFF7C6FFF),
                    size: 20,
                  ),
                  onPressed: _shareResult,
                  tooltip: 'Share result',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _solution = null;
                    _ctrl.clear();
                  }),
                  child: const Text(
                    "Clear",
                    style: TextStyle(color: Color(0xFF7777AA), fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMono',
                    color: Color(0xFFF0F0FF),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        "d/dx[x^3]  or  int(sin(x))  or  eigen([[4,1],[2,3]])",
                    prefixIcon: const Icon(
                      Icons.functions,
                      color: Color(0xFF7C6FFF),
                      size: 18,
                    ),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: Color(0xFF555577),
                            ),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _solve(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loading ? null : _solve,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Input Guide", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          ..._guideItems().map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      g.$1,
                      style: const TextStyle(
                        color: Color(0xFF7777AA),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      g.$2,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMono',
                        color: Color(0xFF00E5AA),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _guideItems() => [
    ("Derivative", "d/dx[x^5]  or  diff(sin(x))"),
    ("Integral", "int(x^2)  or  int(e^x, 0, 1)"),
    ("Limit", "lim(sin(x)/x, x, 0)"),
    ("Limit at ∞", "lim(1/x, x, inf)"),
    ("Determinant", "det([[1,2],[3,4]])"),
    ("Matrix Inverse", "inv([[2,1],[1,1]])"),
    ("Eigenvalues", "eigen([[4,1],[2,3]])"),
    ("ODE 1st order", "ode(dy/dx = x*y)"),
    ("ODE 2nd order", "ode(y'' + 4y = 0)"),
    ("Series", "series(1/n^2)"),
    ("Trig values", "sin(pi/6)  or  tan(45deg)"),
    ("Complex", "complex(3+4i)  or  modulus(2-3i)"),
    ("Statistics", "mean([1,2,3,4,5])"),
    ("Variance", "variance([2,4,6,8])"),
    ("Primality", "isprime(97)"),
    ("GCD/LCM", "gcd(48,18)  or  lcm(4,6)"),
    ("Factorize", "factorize(360)"),
    ("Mod arithmetic", "mod(17,5)"),
    ("Gradient", "gradient(f)"),
    ("Divergence", "div(F)"),
    ("Curl", "curl(F)"),
    ("Dot product", "dot(a,b)"),
    ("Cross product", "cross(a,b)"),
    ("Group theory", "group(Z_n)"),
    ("Topology", "topology(compact)"),
  ];

  Widget _buildResult() {
    final s = _solution!;
    // Wrap the result card in Screenshot so we can capture it for sharing
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Screenshot(
            controller: _screenshotCtrl,
            child: _ShareableResultCard(solution: s),
          ),
          const SizedBox(height: 20),
          if (s.tip != null) _TipCard(tip: s.tip!),
          if (s.tip != null) const SizedBox(height: 16),
          _StepsSection(solution: s),
        ],
      ),
    );
  }
}

// ─── Shareable result card (wrapped in Screenshot) ────────────────────────────
class _ShareableResultCard extends StatelessWidget {
  final Solution solution;
  const _ShareableResultCard({required this.solution});

  @override
  Widget build(BuildContext context) {
    final s = solution;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10101C), // solid bg so PNG looks clean
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C6FFF).withOpacity(0.1),
            const Color(0xFF00E5AA).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C6FFF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6FFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.domain.label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(s.operation, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: s.resultLatex));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("LaTeX copied"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Color(0xFF555577),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Math.tex(
              s.resultLatex,
              textStyle: const TextStyle(
                fontSize: 28,
                color: Color(0xFFF0F0FF),
              ),
              onErrorFallback: (_) => Text(
                s.resultLatex,
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  color: Color(0xFF00E5AA),
                  fontSize: 18,
                ),
              ),
            ),
          ),
          if (s.resultReadable.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                s.resultReadable,
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  color: Color(0xFF7777AA),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Watermark so shared images are attributed
          Center(
            child: Text(
              'Math God  ·  math.god',
              style: TextStyle(
                color: const Color(0xFF7C6FFF).withOpacity(0.5),
                fontSize: 10,
                letterSpacing: 1.0,
                fontFamily: 'IBMPlexMono',
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }
}

class _TipCard extends StatelessWidget {
  final String tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5AA).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5AA).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: Color(0xFF00E5AA),
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: Color(0xFF99CCBB),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  final Solution solution;
  const _StepsSection({required this.solution});

  @override
  Widget build(BuildContext context) {
    final steps = solution.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.list_alt_rounded,
              color: Color(0xFF7C6FFF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              "Step-by-Step",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              "${steps.length} steps",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...steps.asMap().entries.map(
          (e) => _StepCard(
            num: e.key + 1,
            step: e.value,
          ).animate(delay: (70 * e.key).ms).fadeIn().slideX(begin: 0.04),
        ),
      ],
    );
  }
}

class _StepCard extends StatefulWidget {
  final int num;
  final SolutionStep step; // ← was `dynamic`, now properly typed
  const _StepCard({required this.num, required this.step});

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161624),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232336)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6FFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        "${widget.num}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 14),
                        ),
                        if (s.rule != null) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5AA).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.rule!,
                              style: const TextStyle(
                                color: Color(0xFF00E5AA),
                                fontSize: 10,
                                fontFamily: 'IBMPlexMono',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF555577),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: Color(0xFF232336)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080810),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Math.tex(
                        s.latex,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFF0F0FF),
                        ),
                        onErrorFallback: (_) => SelectableText(
                          s.latex,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMono',
                            color: Color(0xFF00E5AA),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.explanation,
                    style: const TextStyle(
                      color: Color(0xFF9090BB),
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
