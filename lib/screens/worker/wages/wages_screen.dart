import 'package:flutter/material.dart';

class WorkerWagesScreen extends StatelessWidget {
  final int workerId;

  const WorkerWagesScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wages')),
      body: Center(
        child: Text('Wages for worker ID: $workerId'),
      ),
    );
  }
}
