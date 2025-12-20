import 'package:flutter/material.dart';

class WorkerJobsScreen extends StatelessWidget {
  final int workerId;

  const WorkerJobsScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: Center(
        child: Text('Jobs for worker ID: $workerId'),
      ),
    );
  }
}
