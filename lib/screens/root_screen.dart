// lib/screens/root_screen.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'solver_screen.dart';
import 'library_screen.dart';
import 'unsolved_screen.dart';
import 'about_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _idx = 0;

  static const _tabs = [
    (
      icon: Icons.auto_awesome_outlined,
      active: Icons.auto_awesome,
      label: "Home",
    ),
    (icon: Icons.functions_outlined, active: Icons.functions, label: "Solver"),
    (icon: Icons.menu_book_outlined, active: Icons.menu_book, label: "Library"),
    (
      icon: Icons.psychology_outlined,
      active: Icons.psychology,
      label: "Unsolved",
    ),
  ];

  final _screens = [
    const HomeScreen(),
    const SolverScreen(),
    const LibraryScreen(),
    const UnsolvedScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Math God"),
        backgroundColor: const Color(0xFF10101C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF7777AA)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10101C),
        border: const Border(top: BorderSide(color: Color(0xFF232336))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final sel = _idx == i;
              return GestureDetector(
                onTap: () => setState(() => _idx = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF7C6FFF).withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sel ? _tabs[i].active : _tabs[i].icon,
                        color: sel
                            ? const Color(0xFF7C6FFF)
                            : const Color(0xFF555577),
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabs[i].label,
                        style: TextStyle(
                          fontFamily: 'IBMPlexSans',
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel
                              ? const Color(0xFF7C6FFF)
                              : const Color(0xFF555577),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
