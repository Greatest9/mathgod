// lib/models/history_item.dart
import 'solution.dart';

class HistoryItem {
  final String id;
  final String input;
  final MathDomain domain;
  final String operation;
  final String resultLatex;
  final String resultReadable;
  final DateTime timestamp;
  final bool isFavorite;

  const HistoryItem({
    required this.id,
    required this.input,
    required this.domain,
    required this.operation,
    required this.resultLatex,
    required this.resultReadable,
    required this.timestamp,
    this.isFavorite = false,
  });

  HistoryItem copyWith({bool? isFavorite}) {
    return HistoryItem(
      id: id,
      input: input,
      domain: domain,
      operation: operation,
      resultLatex: resultLatex,
      resultReadable: resultReadable,
      timestamp: timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'input': input,
    'domain': domain.index,
    'operation': operation,
    'resultLatex': resultLatex,
    'resultReadable': resultReadable,
    'timestamp': timestamp.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      input: json['input'] as String,
      domain: MathDomain.values[json['domain'] as int? ?? 10],
      operation: json['operation'] as String? ?? '',
      resultLatex: json['resultLatex'] as String? ?? '',
      resultReadable: json['resultReadable'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  factory HistoryItem.fromSolution(Solution solution) {
    return HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      input: solution.input,
      domain: solution.domain,
      operation: solution.operation,
      resultLatex: solution.resultLatex,
      resultReadable: solution.resultReadable,
      timestamp: DateTime.now(),
    );
  }
}
