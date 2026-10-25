// lib/widgets/function_grapher.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'graph_2d.dart';
import 'graph_3d.dart';

class FunctionGrapher extends StatefulWidget {
  final String initialExpression;
  final bool isDialog;

  const FunctionGrapher({
    super.key,
    this.initialExpression = 'sin(x)',
    this.isDialog = false,
  });

  static Future<void> show(BuildContext context,
      {String initialExpression = 'sin(x)'}) {
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
  bool _is3d = false;
  double _minX = -10.0;
  double _maxX = 10.0;

  final List<String> _presets2d = [
    'sin(x)',
    'cos(x)',
    'x^2',
    'x^3 - 3*x',
    '1/x',
    'e^x',
    'ln(x)',
    'sqrt(x)',
  ];

  final List<String> _presets3d = [
    'sin(x)*cos(y)',
    'x*x - y*y',
    'sqrt(x*x + y*y)',
    'sin(x*x + y*y)',
    'x*y',
    'e^(-(x*x + y*y)/4)',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialExpression);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _expr {
    var s = _ctrl.text.trim();
    if (s.startsWith('y=') || s.startsWith('y =') || s.startsWith('f(x)=')) {
      s = s.substring(s.indexOf('=') + 1).trim();
    }
    return s;
  }

  void _setDomain(double min, double max) {
    setState(() {
      _minX = min;
      _maxX = max;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expr = _expr;
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
          _buildModeToggle(),
          const SizedBox(height: 10),
          _buildInputField(),
          const SizedBox(height: 8),
          _buildPresets(),
          if (!_is3d) ...[
            const SizedBox(height: 14),
            _buildDomainControls(),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: _is3d ? 300 : 240,
            child: expr.isEmpty
                ? const Center(
                    child: Text(
                      'Enter a function to plot',
                      style: TextStyle(color: Color(0xFF7777AA), fontSize: 13),
                    ),
                  )
                : _is3d
                    ? Graph3DView(
                        key: ValueKey('3d|$expr'),
                        expression: expr,
                      )
                    : Graph2DView(
                        key: ValueKey('2d|$expr|$_minX|$_maxX'),
                        expression: expr,
                        minX: _minX,
                        maxX: _maxX,
                      ),
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
          'Function Plotter',
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

  Widget _buildModeToggle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF161624),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF232336)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeChip('2D', !_is3d, () => setState(() => _is3d = false)),
              const SizedBox(width: 3),
              _modeChip('3D', _is3d, () => setState(() => _is3d = true)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _is3d ? 'z = f(x, y)' : 'y = f(x)',
          style: const TextStyle(
            color: Color(0xFF7777AA),
            fontSize: 11,
            fontFamily: 'IBMPlexMono',
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C6FFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFF0F0FF) : const Color(0xFF7777AA),
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'y = ',
              style: const TextStyle(
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
              decoration: InputDecoration(
                hintText: _is3d ? 'sin(x)*cos(y), x^2 - y^2' : 'sin(x), x^2 - 4, e^x',
                hintStyle: const TextStyle(color: Color(0xFF555577), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF00E5AA)),
            onPressed: () => setState(() {}),
            tooltip: 'Plot',
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final presets = _is3d ? _presets3d : _presets2d;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((p) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                _ctrl.text = p;
                setState(() {});
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
          'Domain: ',
          style: TextStyle(color: Color(0xFF7777AA), fontSize: 11),
        ),
        _domainChip('[-5, 5]', _minX == -5, () => _setDomain(-5, 5)),
        const SizedBox(width: 6),
        _domainChip('[-10, 10]', _minX == -10, () => _setDomain(-10, 10)),
        const SizedBox(width: 6),
        _domainChip('[-2pi, 2pi]', _minX == -2 * math.pi,
            () => _setDomain(-2 * math.pi, 2 * math.pi)),
        const SizedBox(width: 6),
        _domainChip('[0, 20]', _minX == 0, () => _setDomain(0, 20)),
      ],
    );
  }

  Widget _domainChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C6FFF).withValues(alpha: 0.2) : const Color(0xFF161624),
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
}