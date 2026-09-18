// lib/services/history_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/history_item.dart';
import '../models/solution.dart';

class HistoryService {
  static final HistoryService instance = HistoryService._();
  HistoryService._();

  static const String _kHistoryKey = 'mg_history_items';
  static const int _maxItems = 100;

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  List<HistoryItem>? _cachedHistory;

  Future<List<HistoryItem>> getHistory() async {
    if (_cachedHistory != null) return _cachedHistory!;
    try {
      final raw = await _storage.read(key: _kHistoryKey);
      if (raw == null || raw.isEmpty) {
        _cachedHistory = [];
        return [];
      }
      final List<dynamic> decoded = jsonDecode(raw);
      _cachedHistory = decoded
          .map((item) => HistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
      return _cachedHistory!;
    } catch (_) {
      _cachedHistory = [];
      return [];
    }
  }

  Future<void> addEntry(Solution solution) async {
    if (solution.operation == "Unknown" || solution.isUnsolvable) return;
    final items = await getHistory();

    // Avoid duplicate adjacent entries of the exact same input
    if (items.isNotEmpty && items.first.input.trim() == solution.input.trim()) {
      return;
    }

    final newEntry = HistoryItem.fromSolution(solution);
    items.insert(0, newEntry);

    if (items.length > _maxItems) {
      items.removeLast();
    }

    await _save(items);
  }

  Future<void> toggleFavorite(String id) async {
    final items = await getHistory();
    final index = items.indexWhere((i) => i.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(isFavorite: !items[index].isFavorite);
      await _save(items);
    }
  }

  Future<void> deleteEntry(String id) async {
    final items = await getHistory();
    items.removeWhere((i) => i.id == id);
    await _save(items);
  }

  Future<void> clearHistory() async {
    final items = await getHistory();
    // Keep favorites if any, or clear all
    items.removeWhere((i) => !i.isFavorite);
    await _save(items);
  }

  Future<void> _save(List<HistoryItem> items) async {
    _cachedHistory = items;
    final raw = jsonEncode(items.map((i) => i.toJson()).toList());
    await _storage.write(key: _kHistoryKey, value: raw);
  }
}
