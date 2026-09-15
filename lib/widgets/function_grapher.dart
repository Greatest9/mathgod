// lib/widgets/function_grapher.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:math_expressions/math_expressions.dart';

class FunctionGrapher extends StatefulWidget {
  final String initialExpression;
  final bool isDialog;

  const FunctionGrapher({
    super.key,
    this.initialExpression = 'sin(x)',
    this.isDialog = false,
  });

  static Future<void> show(BuildContext context, {String initialExpression = 'sin(x)'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FunctionGrapher(
        initialExpression: initialExpression,
        isDialog: true,
      ),
    );
  }

  @override
  State<FunctionGrapher> createState() => _FunctionGrapherState();
}

class _FunctionGrapherState extends State<FunctionGrapher> {
  late final TextEditingController _ctrl;
  double _minX = -10.0;
  double _maxX = 10.0;
  double _minY = -10.0;
  double _maxY = 10.0;
  List<FlSpot> _spots = [];
  String? _error;

  final List<String> _presets = [
    'sin(x)',
    'cos(x)',
    'x^2',
    'x^3 - 3*x',
    '1/x',
    'e^x',
    'ln(x)',
    'sqrt(x)',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _cleanExpression(widget.initialExpression));
    _plot();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _cleanExpression(String raw) {
    var s = raw.trim();
    if (s.startsWith('y=') || s.startsWith('y =') || s.startsWith('f(x)=')) {
      s = s.substring(s.indexOf('=') + 1).trim();
    }
    return s.isEmpty ? 'sin(x)' : s;
  }

  void _plot() {
    final exprStr = _ctrl.text.trim();
    if (exprStr.isEmpty) return;

    try {
      // Normalize common math shorthands for math_expressions
      final normalized = exprStr
          .replaceAll('pi', '${math.pi}')
          .replaceAll('e^', 'exp')
          .replaceAllMapped(RegExp(r'(\d)([a-zA-Z])'), (m) => '${m[1]}*${m[2]}');

      final parser = Parser();
      final expression = parser.parse(normalized);
      final cm = ContextModel();

      final points = <FlSpot>[];
      const int steps = 200;
      final stepSize = (_maxX - _minX) / steps;

      double calculatedMinY = double.infinity;
      double calculatedMaxY = -double.infinity;

      for (int i = 0; i <= steps; i++) {
        final x = _minX + i * stepSize;
        cm.bindVariable(Variable('x'), Number(x));
        try {
          final eval = expression.evaluate(EvaluationType.REAL, cm);
          if (eval is num && !eval.isNaN && !eval.isInfinite) {
            final y = eval.toDouble();
            // Clamp extreme asymptotic values (e.g. 1/x at 0)
            if (y >= -100 && y <= 100) {
              points.add(FlSpot(x, y));
              if (y < calculatedMinY) calculatedMinY = y;
              if (y > calculatedMaxY) calculatedMaxY = y;
            }
          }
        } catch (_) {
          // Skip undefined evaluation points (e.g. sqrt(-1), ln(0))
        }
      }

      setState(() {
        _spots = points;
        _error = null;
        if (calculatedMinY != double.infinity && calculatedMaxY != -double.infinity) {
          final margin = (calculatedMaxY - calculatedMinY).abs() * 0.15;
          _minY = (calculatedMinY - margin).clamp(-50.0, 50.0);
          _maxY = (calculatedMaxY + margin).clamp(-50.0, 50.0);
          if ((_maxY - _minY).abs() < 1) {
            _minY -= 2;
            _maxY += 2;
          }
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Could not plot function';
        _spots = [];
      });
    }
  }

  void _setDomain(double min, double max) {
    setState(() {
      _minX = min;
      _maxX = max;
    });
    _plot();
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF10101C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildInputField(),
          const SizedBox(height: 8),
          _buildPresets(),
          const SizedBox(height: 14),
          _buildDomainControls(),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF6B8A), fontSize: 13),
                    ),
                  )
                : _buildChart(),
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF10101C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xFF232336), width: 1.5)),
        ),
        child: SafeArea(child: SingleChildScrollView(child: content)),
      );
    }
    return content;
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.show_chart_rounded, color: Color(0xFF00E5AA), size: 22),
        const SizedBox(width: 8),
        const Text(
          "2D Function Plotter",
          style: TextStyle(
            color: Color(0xFFF0F0FF),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (widget.isDialog)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF7777AA)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161624),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF232336)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "y = ",
              style: TextStyle(
                color: Color(0xFF7C6FFF),
                fontFamily: 'IBMPlexMono',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(
                fontFamily: 'IBMPlexMono',
                color: Color(0xFFF0F0FF),
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: "sin(x), x^2 - 4, e^x",
                hintStyle: TextStyle(color: Color(0xFF555577), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _plot(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF00E5AA)),
            onPressed: _plot,
            tooltip: 'Plot curve',
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _presets.map((p) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                _ctrl.text = p;
                _plot();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161624),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF232336)),
                ),
                child: Text(
                  p,
                  style: const TextStyle(
                    color: Color(0xFF9090BB),
                    fontFamily: 'IBMPlexMono',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDomainControls() {
    return Row(
      children: [
        const Text(
          "Domain: ",
          style: TextStyle(color: Color(0xFF7777AA), fontSize: 11),
        ),
        _domainChip("[-5, 5]", _minX == -5, () => _setDomain(-5, 5)),
        const SizedBox(width: 6),
        _domainChip("[-10, 10]", _minX == -10, () => _setDomain(-10, 10)),
        const SizedBox(width: 6),
        _domainChip("[-2π, 2π]", _minX == -2 * math.pi, () => _setDomain(-2 * math.pi, 2 * math.pi)),
        const SizedBox(width: 6),
        _domainChip("[0, 20]", _minX == 0, () => _setDomain(0, 20)),
      ],
    );
  }

  Widget _domainChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C6FFF).withOpacity(0.2) : const Color(0xFF161624),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFF7C6FFF) : const Color(0xFF232336),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF7C6FFF) : const Color(0xFF7777AA),
            fontSize: 10,
            fontFamily: 'IBMPlexMono',
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_spots.isEmpty) {
      return const Center(
        child: Text("No points to display", style: TextStyle(color: Color(0xFF7777AA))),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: value == 0 ? const Color(0xFF7C6FFF).withOpacity(0.5) : const Color(0xFF1C1C2E),
              strokeWidth: value == 0 ? 1.5 : 0.8,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: value == 0 ? const Color(0xFF7C6FFF).withOpacity(0.5) : const Color(0xFF1C1C2E),
              strokeWidth: value == 0 ? 1.5 : 0.8,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (_maxX - _minX) / 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1).replaceAll('.0', ''),
                  style: const TextStyle(color: Color(0xFF666688), fontSize: 9, fontFamily: 'IBMPlexMono'),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (_maxY - _minY) / 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1).replaceAll('.0', ''),
                  style: const TextStyle(color: Color(0xFF666688), fontSize: 9, fontFamily: 'IBMPlexMono'),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xFF232336)),
        ),
        minX: _minX,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'x: ${spot.x.toStringAsFixed(2)}\ny: ${spot.y.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Color(0xFF00E5AA),
                    fontSize: 11,
                    fontFamily: 'IBMPlexMono',
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: true,
            color: const Color(0xFF00E5AA),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00E5AA).withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }
}
