import 'package:flutter/material.dart';

class CustomerChatsScreen extends StatelessWidget {
  final int  customerId;

  const CustomerChatsScreen({super.key, required this. customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: Center(
        child: Text('Chats for worker ID: $customerId'),
      ),
    );
  }
}
