import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/features/chat/models/chat_user.dart';

void main() {
  test('a leader with a real job title shows it under their name', () {
    final leader = ChatUser(
      id: 'a1',
      name: 'Aisha Diallo',
      email: 'a@example.com',
      role: 'admin',
      jobTitle: '  Head of Admissions ',
    );
    expect(leader.leaderTitle, 'Head of Admissions');
    expect(
      ChatUser.leaderTitleFor(role: 'super_admin', title: 'Director'),
      'Director',
    );
  });

  test('a generic or missing title keeps the role label', () {
    expect(ChatUser.leaderTitleFor(role: 'admin', title: 'Admin'), isNull);
    expect(
        ChatUser.leaderTitleFor(role: 'admin', title: 'ADMINISTRATOR'), isNull);
    expect(ChatUser.leaderTitleFor(role: 'admin', title: ' '), isNull);
    expect(ChatUser.leaderTitleFor(role: 'admin', title: null), isNull);
  });

  test('non-leaders never show a title', () {
    expect(
        ChatUser.leaderTitleFor(role: 'teacher', title: 'Head Teacher'), isNull);
    expect(ChatUser.leaderTitleFor(role: 'parent', title: 'Admin'), isNull);
    expect(ChatUser.leaderTitleFor(role: null, title: 'Director'), isNull);
  });

  test('fromMap reads the job title from the user doc title field', () {
    final user = ChatUser.fromMap({
      'id': 'a2',
      'first_name': 'Musa',
      'last_name': 'Bah',
      'user_type': 'admin',
      'title': 'Finance Lead',
    });
    expect(user.jobTitle, 'Finance Lead');
    expect(user.leaderTitle, 'Finance Lead');
  });
}
