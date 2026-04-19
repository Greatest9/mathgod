// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/license_screen.dart';
import 'screens/root_screen.dart';
import 'services/license_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MathGodApp());
}

class MathGodApp extends StatelessWidget {
  const MathGodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math God',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: const LicenseGate(),
    );
  }

  ThemeData _theme() {
    const bg = Color(0xFF080810);
    const surface = Color(0xFF10101C);
    const card = Color(0xFF161624);
    const accent = Color(0xFF7C6FFF);
    const green = Color(0xFF00E5AA);
    const textPrimary = Color(0xFFF0F0FF);
    const textSub = Color(0xFF7777AA);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        background: bg,
        surface: surface,
        primary: accent,
        secondary: green,
        onBackground: textPrimary,
        onSurface: textPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          color: textPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.ibmPlexSans(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.ibmPlexSans(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.ibmPlexSans(
          color: textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.ibmPlexSans(
          color: textSub,
          fontSize: 13,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.ibmPlexMono(
          color: green,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF232336), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF232336)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF232336)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.ibmPlexMono(color: textSub, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

/// License gate: checks local storage first, shows license screen if not activated.
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key});
  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  bool _checking = true;
  bool _licensed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await LicenseManager.instance.isActivated();
    if (mounted)
      setState(() {
        _licensed = ok;
        _checking = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C6FFF)),
        ),
      );
    }
    return _licensed ? const RootScreen() : const LicenseScreen();
  }
}
