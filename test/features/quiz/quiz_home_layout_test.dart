import 'package:alluwalacademyadmin/features/quiz/screens/quiz_home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses compact, responsive category tiles', () {
    expect(quizCategoryGridDelegate.maxCrossAxisExtent, 164);
    expect(quizCategoryGridDelegate.mainAxisExtent, 128);
    expect(quizCategoryGridDelegate.mainAxisSpacing, 12);
    expect(quizCategoryGridDelegate.crossAxisSpacing, 12);
  });
}
