// lib/models/theorem.dart

class Theorem {
  final String id;
  final String name;
  final String domain;
  final String statement;
  final String statementLatex;
  final String explanation;
  final String proof;
  final List<String> applications;
  final bool isUnsolved;
  final String? unsolvedNote;
  final String? prizeInfo;
  final String? year;
  final String? author;

  const Theorem({
    required this.id,
    required this.name,
    required this.domain,
    required this.statement,
    required this.statementLatex,
    required this.explanation,
    required this.proof,
    required this.applications,
    this.isUnsolved = false,
    this.unsolvedNote,
    this.prizeInfo,
    this.year,
    this.author,
  });
}
