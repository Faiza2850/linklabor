// File: lib/screens/worker/dashboard.dart

import 'package:flutter/material.dart';
import 'package:linklabor/screens/worker/profile/profile_screen.dart';
import 'package:linklabor/screens/worker/jobs/jobs_screen.dart';
import 'package:linklabor/screens/worker/wages/wages_screen.dart';
import 'package:linklabor/screens/worker/chats/chats_screen.dart';
import 'package:linklabor/screens/widgets/bottom_nav_bar.dart';

class WorkerDashboard extends StatefulWidget {
  final int workerId;

  const WorkerDashboard({super.key, required this.workerId});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  int _currentIndex = 0;

  // List to hold the screens
  // We initialize this in initState so we can access 'widget.workerId'
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      WorkerProfile(workerId: widget.workerId), // Screen 0
      WorkerJobsScreen(workerId: widget.workerId), // Screen 1
      WorkerWagesScreen(workerId: widget.workerId), // Screen 2
      WorkerChatsScreen(workerId: widget.workerId), // Screen 3
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack preserves the state of each screen (so they don't reload when switching)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: WorkerBottomNavBar(
        currentIndex: _currentIndex,
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
