// lib/widgets/math_keypad.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum KeypadCategory {
  basic,
  calculus,
  functions,
  matrices,
}

class MathKeypad extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSolve;
  final VoidCallback? onClose;

  const MathKeypad({
    super.key,
    required this.controller,
    required this.onSolve,
    this.onClose,
  });

  @override
  State<MathKeypad> createState() => _MathKeypadState();
}

class _MathKeypadState extends State<MathKeypad> {
  KeypadCategory _category = KeypadCategory.basic;

  void _insert(String text, {int cursorOffset = 0}) {
    HapticFeedback.lightImpact();
    final ctrl = widget.controller;
    final value = ctrl.value;
    final start = value.selection.start;
    final end = value.selection.end;

    if (start == -1) {
      // No cursor position, append to end
      ctrl.text = ctrl.text + text;
      ctrl.selection = TextSelection.collapsed(
        offset: ctrl.text.length + cursorOffset,
      );
      return;
    }

    final newText = value.text.replaceRange(start, end, text);
    final newOffset = start + text.length + cursorOffset;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _backspace() {
    HapticFeedback.lightImpact();
    final ctrl = widget.controller;
    final value = ctrl.value;
    final start = value.selection.start;
    final end = value.selection.end;

    if (start == -1 || ctrl.text.isEmpty) return;

    if (start != end) {
      // Selection range deleted
      final newText = value.text.replaceRange(start, end, '');
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      // Single char before cursor deleted
      final newText = value.text.replaceRange(start - 1, start, '');
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 1),
      );
    }
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D18),
        border: Border(top: BorderSide(color: Color(0xFF232336), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
              child: _buildKeyGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF131322),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E30))),
      ),
      child: Row(
        children: [
          _tabButton("123", KeypadCategory.basic),
          const SizedBox(width: 4),
          _tabButton("∫ Calculus", KeypadCategory.calculus),
          const SizedBox(width: 4),
          _tabButton("sin/f(x)", KeypadCategory.functions),
          const SizedBox(width: 4),
          _tabButton("[M] Matrix", KeypadCategory.matrices),
          const Spacer(),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.keyboard_hide_rounded, size: 18, color: Color(0xFF7777AA)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, KeypadCategory cat) {
    final active = _category == cat;
    return GestureDetector(
      onTap: () => setState(() => _category = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C6FFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF8888AA),
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontFamily: 'IBMPlexMono',
          ),
        ),
      ),
    );
  }

  Widget _buildKeyGrid() {
    switch (_category) {
      case KeypadCategory.basic:
        return _grid([
          [_key("x"), _key("y"), _key("("), _key(")"), _key("^", insert: "^"), _actionKey("DEL", _backspace, isRed: true)],
          [_key("7"), _key("8"), _key("9"), _key("+"), _key("√", insert: "sqrt()", cursorOffset: -1), _actionKey("AC", _clear)],
          [_key("4"), _key("5"), _key("6"), _key("-"), _key("²", insert: "^2"), _key("=")],
          [_key("1"), _key("2"), _key("3"), _key("*", label: "×"), _key("/"), _key("π", insert: "pi")],
          [_key("0"), _key("."), _key("t"), _key(","), _key("e"), _evalKey()],
        ]);
      case KeypadCategory.calculus:
        return _grid([
          [_key("d/dx", insert: "d/dx[]", cursorOffset: -1), _key("d/dt", insert: "d/dt[]", cursorOffset: -1), _key("∂/∂x", insert: "diff(,x)", cursorOffset: -3), _key("∞", insert: "inf"), _key("x"), _actionKey("DEL", _backspace, isRed: true)],
          [_key("∫ dx", insert: "int(x)", cursorOffset: -1), _key("∫ₐᵇ", insert: "int(,,)", cursorOffset: -3), _key("lim", insert: "lim(,,)", cursorOffset: -3), _key("x→0", insert: "lim(,x,0)", cursorOffset: -5), _key("y"), _actionKey("AC", _clear)],
          [_key("eˣ", insert: "e^"), _key("ln", insert: "ln()", cursorOffset: -1), _key("1/x", insert: "1/()", cursorOffset: -1), _key("∑", insert: "sum(,,)", cursorOffset: -3), _key("t"), _key("=")],
          [_key("Laplace", insert: "laplace()", cursorOffset: -1), _key("InvLap", insert: "invlaplace()", cursorOffset: -1), _key("Taylor", insert: "taylor(,,)", cursorOffset: -3), _key("ODE", insert: "ode()", cursorOffset: -1), _key("+"), _key("-")],
          [_key("sin", insert: "sin()", cursorOffset: -1), _key("cos", insert: "cos()", cursorOffset: -1), _key("("), _key(")"), _key("*", label: "×"), _evalKey()],
        ]);
      case KeypadCategory.functions:
        return _grid([
          [_key("sin", insert: "sin()", cursorOffset: -1), _key("cos", insert: "cos()", cursorOffset: -1), _key("tan", insert: "tan()", cursorOffset: -1), _key("log", insert: "log()", cursorOffset: -1), _key("!", insert: "!"), _actionKey("DEL", _backspace, isRed: true)],
          [_key("asin", insert: "arcsin()", cursorOffset: -1), _key("acos", insert: "arccos()", cursorOffset: -1), _key("atan", insert: "arctan()", cursorOffset: -1), _key("ln", insert: "ln()", cursorOffset: -1), _key("e", insert: "e"), _actionKey("AC", _clear)],
          [_key("sinh", insert: "sinh()", cursorOffset: -1), _key("cosh", insert: "cosh()", cursorOffset: -1), _key("tanh", insert: "tanh()", cursorOffset: -1), _key("|x|", insert: "abs()", cursorOffset: -1), _key("π", insert: "pi"), _key("^")],
          [_key("factor", insert: "factorize()", cursorOffset: -1), _key("gcd", insert: "gcd(,)", cursorOffset: -2), _key("lcm", insert: "lcm(,)", cursorOffset: -2), _key("isprime", insert: "isprime()", cursorOffset: -1), _key("mod", insert: "mod(,)", cursorOffset: -2), _key("=")],
          [_key("mean", insert: "mean([])", cursorOffset: -2), _key("var", insert: "variance([])", cursorOffset: -2), _key("("), _key(")"), _key(","), _evalKey()],
        ]);
      case KeypadCategory.matrices:
        return _grid([
          [_key("det", insert: "det([[],[]])", cursorOffset: -4), _key("inv", insert: "inv([[],[]])", cursorOffset: -4), _key("eigen", insert: "eigen([[],[]])", cursorOffset: -4), _key("[", insert: "["), _key("]", insert: "]"), _actionKey("DEL", _backspace, isRed: true)],
          [_key("2x2", insert: "[[a,b],[c,d]]"), _key("3x3", insert: "[[1,0,0],[0,1,0],[0,0,1]]"), _key("solve", insert: "solve()", cursorOffset: -1), _key(","), _key("="), _actionKey("AC", _clear)],
          [_key("grad", insert: "gradient()", cursorOffset: -1), _key("curl", insert: "curl()", cursorOffset: -1), _key("div", insert: "div()", cursorOffset: -1), _key("dot", insert: "dot(,)", cursorOffset: -2), _key("cross", insert: "cross(,)", cursorOffset: -2), _key("+")],
          [_key("1"), _key("2"), _key("3"), _key("4"), _key("5"), _key("-")],
          [_key("6"), _key("7"), _key("8"), _key("9"), _key("0"), _evalKey()],
        ]);
    }
  }

  Widget _grid(List<List<Widget>> rows) {
    return Column(
      children: rows.map((r) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: r.map((cell) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: cell,
            ))).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _key(String text, {String? label, String? insert, int cursorOffset = 0}) {
    final toInsert = insert ?? text;
    final display = label ?? text;
    final isNum = RegExp(r'^[0-9]$').hasMatch(text);
    return _KeyButton(
      label: display,
      bgColor: isNum ? const Color(0xFF1A1A2E) : const Color(0xFF141424),
      textColor: isNum ? Colors.white : const Color(0xFF7C6FFF),
      fontSize: display.length > 3 ? 10 : 13,
      onTap: () => _insert(toInsert, cursorOffset: cursorOffset),
    );
  }

  Widget _actionKey(String label, VoidCallback onTap, {bool isRed = false}) {
    return _KeyButton(
      label: label,
      bgColor: isRed ? const Color(0xFF2C1420) : const Color(0xFF1F1F35),
      textColor: isRed ? const Color(0xFFFF6B8A) : const Color(0xFF9090BB),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      onTap: onTap,
    );
  }

  Widget _evalKey() {
    return _KeyButton(
      label: "GO ↵",
      bgColor: const Color(0xFF7C6FFF),
      textColor: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      onTap: () {
        HapticFeedback.heavyImpact();
        widget.onSolve();
      },
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: fontWeight,
                fontFamily: 'IBMPlexMono',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
