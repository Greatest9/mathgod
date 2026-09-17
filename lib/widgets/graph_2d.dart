// lib/widgets/graph_2d.dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/graph_evaluator.dart';

/// Interactive 2D function plot (y = f(x)) rendered on a CustomPainter.
///
/// Adaptive sampling with curvature refinement, gap detection at
/// discontinuities, pinch-to-zoom / pan, double-tap auto-fit, and nice
/// 1-2-5 grid ticks with axis labels.
class Graph2DView extends StatefulWidget {
  const Graph2DView({
    super.key,
    required this.expression,
    this.minX = -10.0,
    this.maxX = 10.0,
  });

  final String expression;
  final double minX;
  final double maxX;

  @override
  State<Graph2DView> createState() => _Graph2DViewState();
}

class _Graph2DViewState extends State<Graph2DView> {
  List<List<double>> _segments = const [];
  double _xMin = 0;
  double _xMax = 0;
  double _yMin = 0;
  double _yMax = 0;
  bool _loading = true;
  String? _error;
  Size _size = Size.zero;
  double _gXMin = 0;
  double _gXMax = 0;
  double _gYMin = 0;
  double _gYMax = 0;
  Offset _gFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant Graph2DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression ||
        oldWidget.minX != widget.minX ||
        oldWidget.maxX != widget.maxX) {
      _compute();
    }
  }

  Future<void> _compute() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final xMin = widget.minX;
    final xMax = widget.maxX;
    final segments = await _sample(widget.expression, xMin, xMax);
    if (!mounted) return;
    if (segments.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No points to display';
      });
      return;
    }
    final values = <double>[];
    for (final seg in segments) {
      for (var i = 1; i < seg.length; i += 2) {
        if (seg[i].isFinite) values.add(seg[i]);
      }
    }
    values.sort();
    final n = values.length;
    final lo = values[n ~/ 50];
    final hi = values[n - 1 - n ~/ 50];
    var pad = (hi - lo) * 0.12;
    if (!pad.isFinite || pad == 0) pad = 1;
    setState(() {
      _segments = segments;
      _xMin = xMin;
      _xMax = xMax;
      _yMin = lo - pad;
      _yMax = hi + pad;
      _loading = false;
    });
  }

  Future<void> _resample() async {
    final xMin = _xMin;
    final xMax = _xMax;
    final segments = await _sample(widget.expression, xMin, xMax);
    if (!mounted) return;
    if (segments.isEmpty) {
      setState(() => _error = 'No points to display');
      return;
    }
    setState(() {
      _segments = segments;
      _error = null;
    });
  }

  Future<List<List<double>>> _sample(String expr, double xMin, double xMax) async {
    try {
      return await compute(
        _sample2DEntry,
        _Sample2DRequest(expr, xMin, xMax),
      );
    } catch (_) {
      return _sample2DSegments(expr, xMin, xMax);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gXMin = _xMin;
    _gXMax = _xMax;
    _gYMin = _yMin;
    _gYMax = _yMax;
    _gFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_size.width <= 0 || _size.height <= 0) return;
    final w = _size.width;
    final h = _size.height;
    final worldW = _gXMax - _gXMin;
    final worldH = _gYMax - _gYMin;
    final scale = details.scale.clamp(0.2, 8.0);
    final nW = worldW / scale;
    final nH = worldH / scale;
    final wx0 = _gXMin + _gFocal.dx / w * worldW;
    final wy0 = _gYMax - _gFocal.dy / h * worldH;
    final xMin2 = wx0 - _gFocal.dx / w * nW;
    final yMax2 = wy0 + _gFocal.dy / h * nH;
    setState(() {
      _xMin = xMin2;
      _xMax = xMin2 + nW;
      _yMax = yMax2;
      _yMin = yMax2 - nH;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = Size(constraints.maxWidth, constraints.maxHeight);
      return ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: (_) => _resample(),
          onDoubleTap: _compute,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _Graph2DPainter(
                  segments: _segments,
                  xMin: _xMin,
                  xMax: _xMax,
                  yMin: _yMin,
                  yMax: _yMax,
                ),
              ),
              if (_loading && _segments.isEmpty)
                const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00E5AA),
                    ),
                  ),
                ),
              if (_error != null)
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF6B8A), fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _Graph2DPainter extends CustomPainter {
  _Graph2DPainter({
    required this.segments,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  final List<List<double>> segments;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  static const Color _gridColor = Color(0xFF1C1C2E);
  static const Color _axisColor = Color(0xFF6B5DFF);
  static const Color _labelColor = Color(0xFF7A7AA0);
  static const Color _curveColor = Color(0xFF00E5AA);
  static const Color _glowColor = Color(0x2600E5AA);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (segments.isEmpty || size.width <= 0 || size.height <= 0) return;

    final grid = _Grid(xMin, xMax, yMin, yMax);
    final w = size.width;
    final h = size.height;
    double px(double x) => (x - xMin) / (xMax - xMin) * w;
    double py(double y) => h - (y - yMin) / (yMax - yMin) * h;

    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = _axisColor
      ..strokeWidth = 1.3;

    for (final t in grid.xTicks) {
      if (t == 0) continue;
      canvas.drawLine(Offset(px(t), 0), Offset(px(t), h), gridPaint);
    }
    for (final t in grid.yTicks) {
      if (t == 0) continue;
      canvas.drawLine(Offset(0, py(t)), Offset(w, py(t)), gridPaint);
    }
    if (xMin <= 0 && xMax >= 0) {
      canvas.drawLine(Offset(px(0), 0), Offset(px(0), h), axisPaint);
    }
    if (yMin <= 0 && yMax >= 0) {
      canvas.drawLine(Offset(0, py(0)), Offset(w, py(0)), axisPaint);
    }

    _drawLabels(canvas, grid, px, py, w, h);

    final glow = Paint()
      ..color = _glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;
    final curve = Paint()
      ..color = _curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final seg in segments) {
      if (seg.length < 4) continue;
      final path = Path();
      var started = false;
      for (var i = 0; i + 1 < seg.length; i += 2) {
        final p = Offset(px(seg[i]), py(seg[i + 1]));
        if (!p.dx.isFinite || !p.dy.isFinite) continue;
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      if (!started) continue;
      canvas.drawPath(path, glow);
      canvas.drawPath(path, curve);
    }
  }

  void _drawLabels(
    Canvas canvas,
    _Grid grid,
    double Function(double) px,
    double Function(double) py,
    double w,
    double h,
  ) {
    void label(String text, Offset at, {bool rightOf = true, bool below = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: _labelColor,
            fontSize: 8.5,
            fontFamily: 'IBMPlexMono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = rightOf ? at.dx + 4 : at.dx - painter.width - 4;
      final dy = below ? at.dy - painter.height - 3 : at.dy + 3;
      painter.paint(canvas, Offset(dx, dy));
    }

    String fmt(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

    for (final t in grid.xTicks) {
      if (t == 0 || px(t) < 0 || px(t) > w) continue;
      label(fmt(t), Offset(px(t), h), rightOf: true, below: true);
    }
    for (final t in grid.yTicks) {
      if (t == 0 || py(t) < 0 || py(t) > h) continue;
      label(fmt(t), Offset(0, py(t)), rightOf: true);
    }
  }

  @override
  bool shouldRepaint(covariant _Graph2DPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.xMin != xMin ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax;
  }
}

class _Grid {
  _Grid(this.x0, this.x1, this.y0, this.y1) {
    _xStep = _niceStep((x1 - x0) / 8);
    _yStep = _niceStep((y1 - y0) / 6);
  }

  final double x0;
  final double x1;
  final double y0;
  final double y1;
  late final double _xStep;
  late final double _yStep;

  List<double> get xTicks => _ticks(x0, x1, _xStep);
  List<double> get yTicks => _ticks(y0, y1, _yStep);

  static List<double> _ticks(double lo, double hi, double step) {
    final out = <double>[];
    if (step <= 0 || !step.isFinite) return out;
    final start = (lo / step).ceil() * step;
    for (var v = start; v <= hi; v += step) {
      out.add(v);
      if (out.length > 64) break;
    }
    return out;
  }

  static double _niceStep(double raw) {
    if (!raw.isFinite || raw <= 0) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 5.0, 10.0]) {
      final s = mag * m;
      if (s >= raw) return s;
    }
    return mag * 10;
  }
}

class _Sample2DRequest {
  const _Sample2DRequest(this.expr, this.xMin, this.xMax);

  final String expr;
  final double xMin;
  final double xMax;
}

List<List<double>> _sample2DEntry(_Sample2DRequest request) =>
    _sample2DSegments(request.expr, request.xMin, request.xMax);

List<List<double>> _sample2DSegments(String expr, double xMin, double xMax) {
  const int base = 220;
  final step = (xMax - xMin) / base;
  final ev = GraphEvaluator.instance;
  final xs = List<double>.filled(base + 1, 0);
  final ys = List<double>.filled(base + 1, double.nan);
  var yLo = double.infinity;
  var yHi = -double.infinity;

  for (var i = 0; i <= base; i++) {
    final x = xMin + i * step;
    xs[i] = x;
    final y = ev.eval2D(expr, x);
    if (y != null && y.isFinite) {
      ys[i] = y;
      if (y < yLo) yLo = y;
      if (y > yHi) yHi = y;
    }
  }

  final eps = math.max(1e-6, (yHi - yLo).abs() * 0.005);
  final samples = <double>[xs[0], ys[0]];
  for (var i = 1; i <= base; i++) {
    final xa = xs[i - 1];
    final ya = ys[i - 1];
    final xb = xs[i];
    final yb = ys[i];
    if (ya.isNaN || yb.isNaN) {
      samples.addAll([xb, yb]);
      continue;
    }
    _refineCell(expr, ev, xa, ya, xb, yb, 4, eps, samples);
    samples.addAll([xb, yb]);
  }

  final segments = <List<double>>[];
  var seg = <double>[];
  for (var i = 0; i + 1 < samples.length; i += 2) {
    final x = samples[i];
    final y = samples[i + 1];
    if (y.isNaN) {
      if (seg.isNotEmpty) segments.add(seg);
      seg = <double>[];
      continue;
    }
    seg.addAll([x, y]);
  }
  if (seg.isNotEmpty) segments.add(seg);
  return segments;
}

void _refineCell(
  String expr,
  GraphEvaluator ev,
  double xa,
  double ya,
  double xb,
  double yb,
  int depth,
  double eps,
  List<double> out,
) {
  final xm = (xa + xb) / 2;
  final ym = ev.eval2D(expr, xm);
  final valid = ym != null &&
      ym.isFinite &&
      (ym - (ya + yb) / 2).abs() > eps;
  if (depth > 0 && valid) {
    _refineCell(expr, ev, xa, ya, xm, ym, depth - 1, eps, out);
  }
  out.addAll([xm, ym ?? double.nan]);
  if (depth > 0 && valid) {
    _refineCell(expr, ev, xm, ym, xb, yb, depth - 1, eps, out);
  }
}