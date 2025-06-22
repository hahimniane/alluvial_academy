import 'package:flutter/material.dart';
import '../../../shared/widgets/top_nav_bar.dart';

class AddUserScreen extends StatelessWidget {
  const AddUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopNavBar(title: 'Add New User'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New User',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  // Role dropdown and other fields will be added later
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Add user functionality will be implemented later
                    },
                    child: const Text('Add User'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
