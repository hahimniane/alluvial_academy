import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/circle_dashboard_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/create_admin_circle_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminCirclesScreen extends StatelessWidget {
  const AdminCirclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Admin Circle Management',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          PopupMenuButton<CircleType>(
            onSelected: (CircleType type) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateAdminCircleScreen(circleType: type),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create Admin Circle',
            itemBuilder: (BuildContext context) => <PopupMenuEntry<CircleType>>[
              const PopupMenuItem<CircleType>(
                value: CircleType.teacher,
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, color: Color(0xFF0F766E), size: 20),
                    SizedBox(width: 12),
                    Text('Teacher Circle'),
                  ],
                ),
              ),
              const PopupMenuItem<CircleType>(
                value: CircleType.parent,
                child: Row(
                  children: [
                    Icon(Icons.family_restroom_rounded, color: Color(0xFF0E7490), size: 20),
                    SizedBox(width: 12),
                    Text('Parent Circle'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('circles').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No circles found.'));
          }

          final circles = snapshot.data!.docs.map((doc) => Circle.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: circles.length,
            itemBuilder: (context, index) {
              final circle = circles[index];
              return Card(
                child: ListTile(
                  title: Text(circle.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Type: ${circle.type.name} | Status: ${circle.status.name}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CircleDashboardScreen(circleId: circle.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
