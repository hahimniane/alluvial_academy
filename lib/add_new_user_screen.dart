import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AddUsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Add new users', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Handle learn more
                  },
                  child: const Text('Learn more',
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Instruction
            const Text(
              'Users login to the mobile and web app using their mobile phone number',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.grey[200],
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('First name*',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Last name*',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Mobile phone*',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // User Input Rows
            Expanded(
              child: ListView(
                children: List.generate(3, (index) => UserInputRow()).toList(),
              ),
            ),

            // Add User Button
            TextButton.icon(
              onPressed: () {
                // Handle add user
              },
              icon: const Icon(Icons.add, color: Colors.blue),
              label:
                  const Text('Add user', style: TextStyle(color: Colors.blue)),
            ),

            // Footer Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (bool? value) {
                        // Handle checkbox
                      },
                    ),
                    const Text('Send an invite'),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Handle cancel
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Handle continue
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserInputRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'First name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'last name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: IntlPhoneField(
              initialCountryCode: 'IN',
              onChanged: (phone) {
                print(phone.completeNumber);
              },
              decoration: InputDecoration(
                hintText: 'First name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            flex: 3,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Email',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              // Handle delete row
            },
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
