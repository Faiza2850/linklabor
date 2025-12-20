import 'package:flutter/material.dart';

class WorkerChatsScreen extends StatelessWidget {
  final int workerId;

  const WorkerChatsScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: Center(
        child: Text('Chats for worker ID: $workerId'),
      ),
    );
  }
}
