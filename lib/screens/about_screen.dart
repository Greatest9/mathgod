import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Math God"),
        backgroundColor: const Color(0xFF10101C),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF080810), Color(0xFF10101C)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Logo/Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C6FFF), Color(0xFF00E5AA)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          "∑",
                          style: TextStyle(fontSize: 40, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Math God",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0F0FF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Version 1.0.0",
                      style: TextStyle(color: Color(0xFF7777AA)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Divider
              const Divider(color: Color(0xFF232336)),

              // Giac Credit
              const SizedBox(height: 16),
              const Text(
                "🧮 Computer Algebra System",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C6FFF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This app uses the Giac computer algebra system, "
                "developed by Bernard Parisse and others.",
                style: TextStyle(color: Color(0xFF9090BB), height: 1.5),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    "https://www-fourier.ujf-grenoble.fr/~parisse/giac.html",
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: const Text(
                  "https://www-fourier.ujf-grenoble.fr/~parisse/giac.html",
                  style: TextStyle(
                    color: Color(0xFF00E5AA),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GPL v3 License
              const Text(
                "📜 License",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C6FFF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Giac is free software distributed under the "
                "GNU General Public License version 3 (GPL v3).",
                style: TextStyle(color: Color(0xFF9090BB), height: 1.5),
              ),
              const SizedBox(height: 16),

              // GPL Notice Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161624),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF232336)),
                ),
                child: const Text(
                  "This program is free software: you can redistribute it and/or modify "
                  "it under the terms of the GNU General Public License as published by "
                  "the Free Software Foundation, either version 3 of the License, or "
                  "(at your option) any later version.\n\n"
                  "This program is distributed in the hope that it will be useful, "
                  "but WITHOUT ANY WARRANTY; without even the implied warranty of "
                  "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the "
                  "GNU General Public License for more details.",
                  style: TextStyle(
                    color: Color(0xFF9090BB),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Full License Link
              Center(
                child: TextButton(
                  onPressed: () async {
                    final uri = Uri.parse(
                      "https://www.gnu.org/licenses/gpl-3.0.en.html",
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5AA),
                  ),
                  child: const Text("View Full GPL v3 License →"),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFF232336)),

              // Source Code Offer
              const SizedBox(height: 16),
              const Text(
                "📦 Source Code",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C6FFF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "The source code for Giac is available at:",
                style: TextStyle(color: Color(0xFF9090BB)),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse("https://github.com/geogebra/giac");
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: const Text(
                  "https://github.com/geogebra/giac",
                  style: TextStyle(
                    color: Color(0xFF00E5AA),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Credits
              const Divider(color: Color(0xFF232336)),
              const SizedBox(height: 16),
              const Text(
                "👨‍💻 Developer",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C6FFF),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Math God was built with Flutter and Giac.\n\n"
                "Special thanks to the open-source community.\n"
                "Made with ❤️ for students in Nigeria and around the world.",
                style: TextStyle(color: Color(0xFF9090BB), height: 1.5),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
