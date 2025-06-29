import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class FirestoreDebugScreen extends StatefulWidget {
  const FirestoreDebugScreen({super.key});

  @override
  State<FirestoreDebugScreen> createState() => _FirestoreDebugScreenState();
}

class _FirestoreDebugScreenState extends State<FirestoreDebugScreen> {
  List<Map<String, dynamic>> userDocuments = [];
  List<Map<String, dynamic>> capitalUserDocuments = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _checkFirestoreData();
  }

  Future<void> _checkFirestoreData() async {
    try {
      // Check lowercase 'users' collection
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      userDocuments = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();

      // Check uppercase 'Users' collection
      try {
        final capitalUsersSnapshot =
            await FirebaseFirestore.instance.collection('Users').get();

        capitalUserDocuments = capitalUsersSnapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        print('No Users collection found: $e');
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Firestore Debug',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xff0386FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
                userDocuments.clear();
                capitalUserDocuments.clear();
              });
              _checkFirestoreData();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error: $error'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCollectionSection(
                        'users (lowercase)',
                        userDocuments,
                        Colors.blue,
                      ),
                      const SizedBox(height: 32),
                      _buildCollectionSection(
                        'Users (uppercase)',
                        capitalUserDocuments,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCollectionSection(
      String title, List<Map<String, dynamic>> documents, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${documents.length} documents',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (documents.isEmpty)
              Text(
                'No documents found in this collection',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              )
            else
              Column(
                children: documents.take(5).map((doc) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${doc['docId']}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (doc['email'] != null)
                          Text('Email: ${doc['email']}'),
                        if (doc['first_name'] != null)
                          Text(
                              'Name: ${doc['first_name']} ${doc['lastName'] ?? ''}'),
                        if (doc['user_type'] != null)
                          Text('Type: ${doc['user_type']}'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (documents.length > 5)
              Text(
                '... and ${documents.length - 5} more documents',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
