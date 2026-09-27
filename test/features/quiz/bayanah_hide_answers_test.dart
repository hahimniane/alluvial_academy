import 'package:alluwalacademyadmin/features/quiz/screens/bayanah_admin_screen.dart';
import 'package:alluwalacademyadmin/features/quiz/services/bayanah_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A service that never touches Firebase — it just replays the streams the host
/// screen watches, so the answer-masking can be tested on the real widget.
class _FakeService extends BayanahService {
  _FakeService(this.status);
  final String status;

  final _event = BayanahEvent(
    id: 'evt', title: 'Test', status: '', joinCode: '838517',
    eventDate: null, playerCount: 1, questionCount: 2, currentIndex: -1,
    currentQuestion: null, questionStartedAt: null, reveal: null,
  );

  @override
  Stream<BayanahEvent> watchEvent(String eventId) => Stream.value(
        BayanahEvent(
          id: _event.id, title: _event.title, status: status,
          joinCode: _event.joinCode, eventDate: null, playerCount: 1,
          questionCount: 2, currentIndex: -1, currentQuestion: null,
          questionStartedAt: null, reveal: null,
        ),
      );

  @override
  Stream<List<BayanahQuestion>> watchQuestions(String eventId) => Stream.value(const [
        BayanahQuestion(
          id: 'q1', order: 0, question: "What was the name of the Prophet Muhammad's mother?",
          options: ['Amina', 'Khadija', 'Aisha', 'Fatima'],
          correctIndex: 0, durationMs: 20000, points: 1000,
        ),
      ]);

  @override
  Stream<List<BayanahPlayer>> watchLeaderboard(String eventId) =>
      const Stream.empty();
}

Future<void> _pump(WidgetTester tester, String status) async {
  await tester.pumpWidget(MaterialApp(
    home: BayanahEventScreen(eventId: 'evt', service: _FakeService(status)),
  ));
  await tester.pump(); // resolve the event + question streams
  await tester.pump(const Duration(milliseconds: 50)); // let the auto-hide postframe run
}

void main() {
  testWidgets('while drafting, the host can see the correct answer', (tester) async {
    await _pump(tester, 'draft');
    expect(find.text('✓ Amina  ·  20s  ·  1000 pts'), findsOneWidget);
    expect(find.textContaining('answer hidden'), findsNothing);
  });

  testWidgets('in the lobby (screen shared) the answer hides itself', (tester) async {
    await _pump(tester, 'lobby');
    expect(find.text('✓ Amina  ·  20s  ·  1000 pts'), findsNothing);
    expect(find.textContaining('answer hidden'), findsOneWidget);
  });

  testWidgets('once the game is live the answer stays hidden', (tester) async {
    await _pump(tester, 'live');
    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('answer hidden'), findsOneWidget);
  });

  testWidgets('the eye button flips the answers back and forth', (tester) async {
    await _pump(tester, 'draft');
    expect(find.textContaining('answer hidden'), findsNothing);
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump();
    expect(find.textContaining('answer hidden'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_rounded));
    await tester.pump();
    expect(find.text('✓ Amina  ·  20s  ·  1000 pts'), findsOneWidget);
  });
}
