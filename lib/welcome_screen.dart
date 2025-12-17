import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Selected language state
  String selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  // Load saved language from SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLanguage = prefs.getString('language') ?? 'English';
    });
  }

  // Save selected language to SharedPreferences
  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // IMAGE
              Image.asset(
                'assets/images/onboarding_illustration.jpg',
                height: 250,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 30),

              // TITLE
              const Text(
                "Welcome to Rozgaar",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // SUBTITLE
              const Text(
                "Connect with skilled workers for your daily needs. Find the right person for the job, quickly and easily.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // LANGUAGE LABEL
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Select Language",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // LANGUAGE TOGGLE
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLanguage = 'English';
                          });
                          _saveLanguage('English');
                        },
                        child: _buildLanguageButton('English'),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedLanguage = 'Urdu';
                          });
                          _saveLanguage('Urdu');
                        },
                        child: _buildLanguageButton('Urdu'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // GET STARTED BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // NAVIGATION LOGIC
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RoleSelectionScreen(),
                      ),
                    );
                    debugPrint("Language saved: $selectedLanguage");

                    // TODO: Navigate to next screen
                    // Navigator.push(...)
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable language button widget
  Widget _buildLanguageButton(String language) {
    final bool isSelected = selectedLanguage == language;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
          const BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
          )
        ]
            : [],
      ),
      child: Center(
        child: Text(
          language,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
