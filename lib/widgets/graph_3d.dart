// lib/widgets/graph_3d.dart
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/graph_evaluator.dart';

/// Interactive 3D surface plot (z = f(x, y)) rendered on a CustomPainter.
///
/// Samples a regular mesh over the visible region, then projects each node
/// with an orthographic camera (drag to rotate, pinch to zoom). Undefined
/// cells are skipped; quads are depth-sorted and shaded from an ambient
/// light combined with a height-based color ramp.
class Graph3DView extends StatefulWidget {
  const Graph3DView({
    super.key,
    required this.expression,
    this.min = -6.0,
    this.max = 6.0,
    this.cells = 42,
  });

  final String expression;
  final double min;
  final double max;
  final int cells;

  @override
  State<Graph3DView> createState() => _Graph3DViewState();
}

class _Graph3DViewState extends State<Graph3DView> {
  List<double> _values = const [];
  double _zMin = 0;
  double _zMax = 1;
  double _azimuth = -2.2;
  double _elevation = 0.5;
  double _zoom = 1;
  bool _loading = true;
  String? _error;
  double _gAzimuth = 0;
  double _gElevation = 0;
  double _gZoom = 1;
  Offset _gFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant Graph3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.cells != widget.cells) {
      _compute();
    }
  }

  Future<void> _compute() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final min = widget.min;
    final max = widget.max;
    final cells = widget.cells;
    final values = await _sampleMesh(widget.expression, min, max, cells);
    if (!mounted) return;
    var zMin = double.infinity;
    var zMax = -double.infinity;
    for (final v in values) {
      if (v.isNaN) continue;
      if (v < zMin) zMin = v;
      if (v > zMax) zMax = v;
    }
    if (!zMin.isFinite) {
      setState(() {
        _loading = false;
        _error = 'No points to display';
      });
      return;
    }
    if (zMin == zMax) {
      zMin -= 1;
      zMax += 1;
    }
    setState(() {
      _values = values;
      _zMin = zMin;
      _zMax = zMax;
      _loading = false;
    });
  }

  Future<List<double>> _sampleMesh(
      String expr, double min, double max, int cells) async {
    try {
      return await Isolate.run(() => _sample3DMesh(expr, min, max, cells));
    } catch (_) {
      return _sample3DMesh(expr, min, max, cells);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gAzimuth = _azimuth;
    _gElevation = _elevation;
    _gZoom = _zoom;
    _gFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final dx = details.localFocalPoint.dx - _gFocal.dx;
    final dy = details.localFocalPoint.dy - _gFocal.dy;
    setState(() {
      _azimuth = _gAzimuth - dx * 0.008;
      _elevation = (_gElevation + dy * 0.008).clamp(-1.35, 1.35);
      _zoom = (_gZoom * details.scale).clamp(0.3, 5.0);
    });
  }

  void _reset() {
    setState(() {
      _azimuth = -2.2;
      _elevation = 0.5;
      _zoom = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onDoubleTap: _reset,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _Graph3DPainter(
                values: _values,
                cells: widget.cells,
                min: widget.min,
                max: widget.max,
                zMin: _zMin,
                zMax: _zMax,
                azimuth: _azimuth,
                elevation: _elevation,
                zoom: _zoom,
              ),
            ),
            if (!_loading)
              const Positioned(
                left: 10,
                top: 6,
                child: Text(
                  'drag to rotate · pinch to zoom',
                  style: TextStyle(color: Color(0xFF666688), fontSize: 10),
                ),
              ),
            if (_loading && _values.isEmpty)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E5AA),
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
  }
}

class _Graph3DPainter extends CustomPainter {
  _Graph3DPainter({
    required this.values,
    required this.cells,
    required this.min,
    required this.max,
    required this.zMin,
    required this.zMax,
    required this.azimuth,
    required this.elevation,
    required this.zoom,
  });

  final List<double> values;
  final int cells;
  final double min;
  final double max;
  final double zMin;
  final double zMax;
  final double azimuth;
  final double elevation;
  final double zoom;

  static const Color _lowColor = Color(0xFF4D4DA6);
  static const Color _highColor = Color(0xFF00E5AA);
  static const Color _axisColor = Color(0xFF55557F);
  static const Color _labelColor = Color(0xFF9090BB);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (cells < 2 || values.length < cells * cells) return;

    final cx = size.width * 0.52;
    final cy = size.height * 0.52;
    final s = math.min(size.width, size.height) * 0.42 / 6.0 * zoom;
    final ca = math.cos(azimuth);
    final sa = math.sin(azimuth);
    final ce = math.cos(elevation);
    final se = math.sin(elevation);
    final dx = (max - min) / (cells - 1);

    final px = List<double>.filled(cells * cells, double.nan);
    final py = List<double>.filled(cells * cells, double.nan);
    final pd = List<double>.filled(cells * cells, double.nan);
    for (var i = 0; i < cells; i++) {
      for (var j = 0; j < cells; j++) {
        final idx = i * cells + j;
        final v = values[idx];
        if (v.isNaN) continue;
        final wx = min + i * dx;
        final wy = min + j * dx;
        final xr = ca * wx + sa * v;
        final zr = -sa * wx + ca * v;
        final y2 = ce * wy - se * zr;
        final depth = se * wy + ce * zr;
        px[idx] = cx + s * xr;
        py[idx] = cy - s * y2;
        pd[idx] = depth;
      }
    }

    const lx = 0.4, ly = -0.5, lz = 0.77;
    final quads = <_Quad3D>[];
    for (var i = 0; i < cells - 1; i++) {
      for (var j = 0; j < cells - 1; j++) {
        final i00 = i * cells + j;
        final i10 = (i + 1) * cells + j;
        final i11 = (i + 1) * cells + j + 1;
        final i01 = i * cells + j + 1;
        if (px[i00].isNaN ||
            px[i10].isNaN ||
            px[i11].isNaN ||
            px[i01].isNaN) {
          continue;
        }
        final z00 = values[i00];
        final z10 = values[i10];
        final z01 = values[i01];
        final ax = dx;
        final az = z10 - z00;
        final by = dx;
        final bz = z01 - z00;
        final nx = -az * by;
        final ny = -ax * bz;
        final nz = ax * by;
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        final dot = len > 0 ? (nx * lx + ny * ly + nz * lz) / len : 0.0;
        final shade = 0.58 + 0.42 * (dot < 0 ? 0.0 : dot);

        final zAvg = (z00 + z10 + z01 + values[i11]) / 4;
        final t = ((zAvg - zMin) / (zMax - zMin)).clamp(0.0, 1.0);
        final base = Color.lerp(_lowColor, _highColor, t)!;
        final color = base.withValues(
          red: (base.r * shade).clamp(0.0, 1.0),
          green: (base.g * shade).clamp(0.0, 1.0),
          blue: (base.b * shade).clamp(0.0, 1.0),
        );

        final depth = (pd[i00] + pd[i10] + pd[i11] + pd[i01]) / 4;
        quads.add(
          _Quad3D(
            [
              Offset(px[i00], py[i00]),
              Offset(px[i10], py[i10]),
              Offset(px[i11], py[i11]),
              Offset(px[i01], py[i01]),
            ],
            depth,
            color,
          ),
        );
      }
    }

    quads.sort((a, b) => b.depth.compareTo(a.depth));
    final fill = Paint()..isAntiAlias = true;
    for (final q in quads) {
      final path = Path()
        ..moveTo(q.points[0].dx, q.points[0].dy)
        ..lineTo(q.points[1].dx, q.points[1].dy)
        ..lineTo(q.points[2].dx, q.points[2].dy)
        ..lineTo(q.points[3].dx, q.points[3].dy)
        ..close();
      fill.color = q.color;
      canvas.drawPath(path, fill);
    }

    _drawAxes(canvas, size, cx, cy, s, ca, sa, ce, se);
    _drawLegend(canvas, size);
  }

  Offset _project(
    double wx,
    double wy,
    double z,
    double cx,
    double cy,
    double s,
    double ca,
    double sa,
    double ce,
    double se,
  ) {
    final xr = ca * wx + sa * z;
    final zr = -sa * wx + ca * z;
    final y2 = ce * wy - se * zr;
    return Offset(cx + s * xr, cy - s * y2);
  }

  void _drawAxes(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double s,
    double ca,
    double sa,
    double ce,
    double se,
  ) {
    final axisPaint = Paint()
      ..color = _axisColor
      ..strokeWidth = 1.2
      ..isAntiAlias = true;
    final origin = _project(0, 0, 0, cx, cy, s, ca, sa, ce, se);
    final xEnd = _project(max, 0, 0, cx, cy, s, ca, sa, ce, se);
    final yEnd = _project(0, max, 0, cx, cy, s, ca, sa, ce, se);
    final zEnd = _project(0, 0, max, cx, cy, s, ca, sa, ce, se);
    canvas.drawLine(origin, xEnd, axisPaint);
    canvas.drawLine(origin, yEnd, axisPaint);
    canvas.drawLine(origin, zEnd, axisPaint);

    void axisLabel(String text, Offset at) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: _labelColor,
            fontSize: 10,
            fontFamily: 'IBMPlexMono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at - Offset(painter.width / 2, painter.height));
    }

    axisLabel('x', xEnd);
    axisLabel('y', yEnd);
    axisLabel('z', zEnd);
  }

  void _drawLegend(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width - 30, 20, 12, size.height - 46);
    if (rect.height <= 0) return;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_highColor, _lowColor],
      ).createShader(rect)
      ..isAntiAlias = true;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = _axisColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    void tickLabel(String text, Offset at) {
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
      painter.paint(canvas, Offset(rect.right + 6, at.dy - painter.height / 2));
    }

    tickLabel(zMax.toStringAsFixed(1), Offset(0, rect.top));
    tickLabel(zMin.toStringAsFixed(1), Offset(0, rect.bottom));
  }

  @override
  bool shouldRepaint(covariant _Graph3DPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.cells != cells ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.zMin != zMin ||
        oldDelegate.zMax != zMax ||
        oldDelegate.azimuth != azimuth ||
        oldDelegate.elevation != elevation ||
        oldDelegate.zoom != zoom;
  }
}

class _Quad3D {
  _Quad3D(this.points, this.depth, this.color);

  final List<Offset> points;
  final double depth;
  final Color color;
}

List<double> _sample3DMesh(String expr, double min, double max, int cells) {
  final ev = GraphEvaluator.instance;
  final dx = (max - min) / (cells - 1);
  final values = List<double>.filled(cells * cells, double.nan);
  for (var i = 0; i < cells; i++) {
    for (var j = 0; j < cells; j++) {
      final v = ev.eval3D(expr, min + i * dx, min + j * dx);
      values[i * cells + j] = (v != null && v.isFinite) ? v : double.nan;
    }
  }
  return values;
}