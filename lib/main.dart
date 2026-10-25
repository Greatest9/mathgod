
import 'package:flutter/material.dart';
import 'screens/root_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MathGodApp());
}

class MathGodApp extends StatelessWidget {
  const MathGodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math God',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6FFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}
