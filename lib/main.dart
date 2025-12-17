import 'package:flutter/material.dart';
import 'welcome_screen.dart'; // Import the file we just created

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Removes the 'Debug' banner
      home: const WelcomeScreen(), // Set our new screen as the starting point
    );
  }
}