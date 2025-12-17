import 'package:flutter/material.dart';
import 'worker_registration_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. GRADIENT BACKGROUND
      // Unlike Web (CSS), we often wrap the Scaffold body in a Container to do gradients
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD), // Light Blue
              Color(0xFFFCE4EC), // Light Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2. TITLE
              const Text(
                "Welcome to Amal-e-Rozi",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 50),

              // 3. ROLE CARDS
              // Worker Button
              RoleCard(
                label: "I am a Worker",
                icon: "👷",
                textColor: Colors.blue[700]!, // Or Colors.green if you want to match the next screen
                onTap: () {
                  // Navigate to the Worker Registration Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkerRegistrationScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Customer Button
              RoleCard(
                label: "I Need a Worker",
                icon: "🙋‍♀️",
                textColor: Colors.green[700]!,
                onTap: () {
                  print("Selected: Customer");
                  // Navigate to Customer Login/Signup later
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 4. CUSTOM REUSABLE WIDGET
// Instead of writing the same Container code twice, we create a template.
// Equivalent to a React Component: const RoleCard = ({ label, icon, ... }) => { ... }
class RoleCard extends StatelessWidget {
  final String label;
  final String icon;
  final Color textColor;
  final VoidCallback onTap; // 'VoidCallback' is the type for a function with no arguments

  const RoleCard({
    super.key,
    required this.label,
    required this.icon,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280, // Fixed width for consistency
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8), // Slightly transparent white
          borderRadius: BorderRadius.circular(20), // Rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}