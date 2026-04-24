// lib/screens/license_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/license_manager.dart';
import 'root_screen.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});
  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final AnimationController _pulseCtrl;
  bool _loading = false;
  String _error = '';

  static const _bg = Color(0xFF080810);
  static const _card = Color(0xFF161624);
  static const _border = Color(0xFF232336);
  static const _accent = Color(0xFF7C6FFF);
  static const _green = Color(0xFF00E5AA);
  static const _textMain = Color(0xFFF0F0FF);
  static const _textSub = Color(0xFF7777AA);
  static const _red = Color(0xFFFF6B8A);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await LicenseManager.instance.activate(_ctrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RootScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              _buildLogo(),
              const SizedBox(height: 28),
              _buildHeading(),
              const SizedBox(height: 48),
              _buildInput(),
              const SizedBox(height: 14),
              if (_error.isNotEmpty) _buildError(),
              const SizedBox(height: 20),
              _buildButton(),
              const SizedBox(height: 32),
              _buildBuyLink(),
              const SizedBox(height: 16),
              _buildFeatureList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(
                const Color(0xFF7C6FFF),
                const Color(0xFF9D93FF),
                _pulseCtrl.value,
              )!,
              const Color(0xFF00E5AA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF7C6FFF,
              ).withOpacity(0.3 + 0.15 * _pulseCtrl.value),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            "∑",
            style: GoogleFonts.playfairDisplay(
              fontSize: 42,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeading() => Column(
    children: [
      Text(
        "Math God",
        style: GoogleFonts.playfairDisplay(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: _textMain,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        "Activate your license to unlock\neverything.",
        textAlign: TextAlign.center,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 14,
          color: _textSub,
          height: 1.55,
        ),
      ),
    ],
  );

  Widget _buildInput() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "License Key",
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          color: _textSub,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _error.isNotEmpty ? _red.withOpacity(0.5) : _border,
          ),
        ),
        child: TextField(
          controller: _ctrl,
          style: GoogleFonts.ibmPlexMono(
            color: _green,
            fontSize: 15,
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) {
            if (_error.isNotEmpty) setState(() => _error = '');
          },
          onSubmitted: (_) => _activate(),
          decoration: InputDecoration(
            hintText: "MATH-ABCD-1234-EFGH",
            hintStyle: GoogleFonts.ibmPlexMono(
              color: _textSub,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildError() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _red.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: _red, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error,
            style: GoogleFonts.ibmPlexSans(
              color: const Color(0xFFFF9999),
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildButton() => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: _loading ? null : _activate,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              "ACTIVATE",
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
    ),
  );

  // ─── FIXED BUY LINK with clipboard fallback ──────────────────────────────
  Widget _buildBuyLink() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        "Don't have a key? ",
        style: GoogleFonts.ibmPlexSans(color: _textSub, fontSize: 13),
      ),
      GestureDetector(
        onTap: () async {
          const url = 'https://selar.com/mathgod';
          final uri = Uri.parse(url);
          try {
            if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              // Success, link opened
              return;
            }
            // Fallback: launch failed → copy to clipboard
            await Clipboard.setData(ClipboardData(text: url));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Link copied to clipboard! Open your browser and paste.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          } catch (e) {
            // Any exception → copy to clipboard
            await Clipboard.setData(ClipboardData(text: url));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open link. Link copied to clipboard.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        child: Text(
          "Buy on Selar →",
          style: GoogleFonts.ibmPlexSans(
            color: _green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: _green,
          ),
        ),
      ),
    ],
  );

  Widget _buildFeatureList() {
    final items = [
      ("Fully offline after activation", Icons.wifi_off_rounded),
      ("Works on up to 3 devices", Icons.devices_rounded),
      ("Step-by-step university math", Icons.school_rounded),
      ("Calculus, Algebra, Stats & more", Icons.functions_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(item.$2, color: _green, size: 16),
                    const SizedBox(width: 12),
                    Text(
                      item.$1,
                      style: GoogleFonts.ibmPlexSans(
                        color: _textSub,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
