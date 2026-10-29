// lib/engine/word_problem_parser.dart
//
// Kept for backward compatibility. All interpretation now lives in
// MathInterpreter (lib/engine/math_interpreter.dart).

import 'math_interpreter.dart';

/// Converts plain-language input into Math God syntax (offline).
String parseWordProblem(String raw) =>
    MathInterpreter.instance.interpret(raw).command;
