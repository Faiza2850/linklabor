import 'package:flutter/material.dart';
// CORRECT: Import the actual customer profile screen
import 'package:linklabor/screens/customer/profile/profile_screen.dart';
// You will create these screens next. For now, they are placeholders.
 import 'package:linklabor/screens/customer/jobs/post_job_screen.dart';
// import 'package:linklabor/screens/customer/chats/customer_chats_screen.dart';
import 'package:linklabor/screens/customer/jobs/my_jobs_screen.dart'; // Import the new file
class CustomerDashboard extends StatefulWidget {
  final int customerId;
  const CustomerDashboard({super.key, required this.customerId});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // Screen 0: CORRECTLY uses CustomerProfileScreen
      CustomerProfileScreen(customerId: widget.customerId),

      // Screen 1: Placeholder for "My Job Postings"
      CustomerMyJobsScreen(customerId: widget.customerId),
      const Center(child: Text("My Job Postings Screen")),

      // Screen 2: Placeholder for "Chats"
      const Center(child: Text("Customer Chats Screen")),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // CORRECT: Use a dedicated CustomerBottomNavBar
      bottomNavigationBar: CustomerBottomNavBar(
        currentIndex: _currentIndex,
        onTabChange: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// --- NEW WIDGET: CustomerBottomNavBar ---
// A dedicated navigation bar for the customer.
class CustomerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabChange;

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTabChange,
      selectedItemColor: const Color(0xFF1E8449), // Theme color for selected
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: "Profile",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article_outlined),
          activeIcon: Icon(Icons.article),
          label: "My Posts",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: "Chats",
        ),
      ],
    );
  }
}
