// lib/engine/word_problem_parser.dart

/// Parses simple English word problems into math syntax that Math God understands.
String parseWordProblem(String raw) {
  var s = raw.toLowerCase().trim();
  
  // Clean up question marks and filler words
  s = s.replaceAll('?', '');
  s = s.replaceAll('what is the ', '');
  s = s.replaceAll('find the ', '');
  s = s.replaceAll('evaluate the ', '');
  s = s.replaceAll('compute the ', '');
  s = s.replaceAll('calculate the ', '');

  // Derivative
  if (s.startsWith('derivative of ') || s.startsWith('differentiate ')) {
    var expr = s.replaceAll('derivative of ', '').replaceAll('differentiate ', '').trim();
    return 'd/dx[$expr]';
  }

  // Integral
  if (s.startsWith('integral of ') || s.startsWith('integrate ')) {
    var expr = s.replaceAll('integral of ', '').replaceAll('integrate ', '').trim();
    if (expr.contains(' from ') && expr.contains(' to ')) {
      // Definite integral
      var parts = expr.split(' from ');
      var bounds = parts[1].split(' to ');
      return 'int(${parts[0].trim()}, ${bounds[0].trim()}, ${bounds[1].trim()})';
    }
    return 'int($expr)';
  }

  // Limit
  if (s.startsWith('limit of ') && s.contains(' as ')) {
    var parts = s.split(' as ');
    var expr = parts[0].replaceAll('limit of ', '').trim();
    var varParts = parts[1].split(' approaches ');
    if (varParts.length == 2) {
      return 'lim($expr, ${varParts[0].trim()}, ${varParts[1].trim()})';
    }
    var varParts2 = parts[1].split(' goes to ');
    if (varParts2.length == 2) {
      return 'lim($expr, ${varParts2[0].trim()}, ${varParts2[1].trim()})';
    }
  }

  // Solve equation
  if (s.startsWith('roots of ') || s.startsWith('solutions to ')) {
    var expr = s.replaceAll('roots of ', '').replaceAll('solutions to ', '').trim();
    if (!expr.contains('=')) {
      expr = '$expr = 0';
    }
    return 'solve($expr)';
  }

  // Factors
  if (s.startsWith('prime factors of ') || s.startsWith('factors of ')) {
    var expr = s.replaceAll('prime factors of ', '').replaceAll('factors of ', '').trim();
    return 'factorize($expr)';
  }

  // Matrix operations
  if (s.startsWith('determinant of ')) {
    var expr = s.replaceAll('determinant of ', '').trim();
    return 'det($expr)';
  }
  if (s.startsWith('inverse of ')) {
    var expr = s.replaceAll('inverse of ', '').trim();
    return 'inv($expr)';
  }
  if (s.startsWith('eigenvalues of ')) {
    var expr = s.replaceAll('eigenvalues of ', '').trim();
    return 'eigen($expr)';
  }

  return raw; // Return unmodified if no pattern matched
}
