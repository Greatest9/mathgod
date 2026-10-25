// lib/widgets/history_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/history_item.dart';
import '../models/solution.dart';
import '../services/history_service.dart';

class HistoryBottomSheet extends StatefulWidget {
  final Function(String) onSelectInput;

  const HistoryBottomSheet({
    super.key,
    required this.onSelectInput,
  });

  static Future<void> show(BuildContext context, {required Function(String) onSelectInput}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HistoryBottomSheet(onSelectInput: onSelectInput),
    );
  }

  @override
  State<HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends State<HistoryBottomSheet> {
  final _searchCtrl = TextEditingController();
  List<HistoryItem> _items = [];
  bool _loading = true;
  bool _onlyStarred = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.instance.getHistory();
    if (mounted) {
      setState(() {
        _items = history;
        _loading = false;
      });
    }
  }

  List<HistoryItem> get _filteredItems {
    return _items.where((item) {
      if (_onlyStarred && !item.isFavorite) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item.input.toLowerCase().contains(q) ||
          item.operation.toLowerCase().contains(q) ||
          item.domain.label.toLowerCase().contains(q);
    }).toList();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF10101C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF232336), width: 1.5)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildSearchBar(),
          _buildTabs(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C6FFF)))
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF33334D),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF7C6FFF), size: 22),
          const SizedBox(width: 8),
          const Text(
            "Calculation History",
            style: TextStyle(
              color: Color(0xFFF0F0FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_items.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFF7777AA)),
              label: const Text(
                "Clear",
                style: TextStyle(color: Color(0xFF7777AA), fontSize: 12),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF161624),
                    title: const Text("Clear History?", style: TextStyle(color: Colors.white, fontSize: 16)),
                    content: const Text(
                      "This will remove non-starred history items.",
                      style: TextStyle(color: Color(0xFF9090BB), fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel", style: TextStyle(color: Color(0xFF7777AA))),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B8A)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Clear"),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await HistoryService.instance.clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161624),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF232336)),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Color(0xFFF0F0FF), fontSize: 13),
          decoration: InputDecoration(
            hintText: "Search previous calculations...",
            hintStyle: const TextStyle(color: Color(0xFF555577), fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF555577)),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Color(0xFF555577)),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (val) => setState(() => _query = val),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          _filterChip("All (${_items.length})", !_onlyStarred, () {
            setState(() => _onlyStarred = false);
          }),
          const SizedBox(width: 8),
          _filterChip(
            "★ Starred (${_items.where((i) => i.isFavorite).length})",
            _onlyStarred,
            () {
              setState(() => _onlyStarred = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C6FFF) : const Color(0xFF161624),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? const Color(0xFF7C6FFF) : const Color(0xFF232336)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF7777AA),
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final list = _filteredItems;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _onlyStarred ? Icons.star_border_rounded : Icons.history_toggle_off_rounded,
              color: const Color(0xFF444466),
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              _onlyStarred ? "No starred calculations yet" : "No calculation history",
              style: const TextStyle(color: Color(0xFF7777AA), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        return _buildHistoryCard(item);
      },
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B8A).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFFF6B8A)),
      ),
      onDismissed: (_) {
        HistoryService.instance.deleteEntry(item.id);
        setState(() {
          _items.removeWhere((i) => i.id == item.id);
        });
      },
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          widget.onSelectInput(item.input);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161624),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isFavorite
                  ? const Color(0xFFFFB347).withValues(alpha: 0.3)
                  : const Color(0xFF232336),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6FFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.domain.label.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF7C6FFF),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.operation,
                    style: const TextStyle(color: Color(0xFF8888AA), fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(item.timestamp),
                    style: const TextStyle(color: Color(0xFF555577), fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await HistoryService.instance.toggleFavorite(item.id);
                      _loadHistory();
                    },
                    child: Icon(
                      item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: item.isFavorite ? const Color(0xFFFFB347) : const Color(0xFF555577),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.input,
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  color: Color(0xFF00E5AA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.resultLatex.isNotEmpty) ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    item.resultLatex,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFF0F0FF),
                    ),
                    onErrorFallback: (_) => Text(
                      item.resultReadable.isNotEmpty ? item.resultReadable : item.resultLatex,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMono',
                        color: Color(0xFF9090BB),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
