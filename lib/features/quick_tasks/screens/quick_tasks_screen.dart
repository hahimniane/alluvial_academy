import 'package:flutter/material.dart';
import '../../../core/models/user.dart';
import '../models/quick_task.dart';
import '../services/quick_task_service.dart';
import '../widgets/quick_task_form.dart';

class QuickTasksScreen extends StatelessWidget {
  final AppUser currentUser;
  const QuickTasksScreen({super.key, required this.currentUser});

  bool get isAdmin => currentUser.role.toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    final service = QuickTaskService();
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Tasks')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => QuickTaskForm(currentUser: currentUser)),
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<QuickTask>>(
        stream: isAdmin
            ? service.streamCreatedTasks(currentUser.id)
            : service.streamTasksForUser(currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading tasks'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    task.priority == TaskPriority.high
                        ? Icons.priority_high
                        : task.priority == TaskPriority.medium
                            ? Icons.flag
                            : Icons.low_priority,
                    color: task.priority == TaskPriority.high
                        ? Colors.red
                        : task.priority == TaskPriority.medium
                            ? Colors.orange
                            : Colors.green,
                  ),
                  title: Text(task.title),
                  subtitle: Text(
                      'Due: ${task.dueDate.toLocal().toString().split(' ').first} • Repeat: ${task.repeat.name.toUpperCase()}'),
                  trailing: isAdmin
                      ? Checkbox(
                          value: task.isCompleted,
                          onChanged: (v) => QuickTaskService()
                              .markCompleted(task.id, v ?? false),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
