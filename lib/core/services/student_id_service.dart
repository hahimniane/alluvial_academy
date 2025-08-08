import 'dart:math';

class StudentIdService {
  // Domain used for alias emails for students without a real email address
  static const String _aliasEmailDomain = 'students.alluwaleducationhub.org';

  // Generate a human-friendly, non-sequential student code, e.g. A7Q4-MZ2N
  static String generateStudentCode({int groups = 2, int groupLength = 4}) {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random.secure();
    String generateGroup() => List.generate(
          groupLength,
          (_) => alphabet[random.nextInt(alphabet.length)],
        ).join();

    return List.generate(groups, (_) => generateGroup()).join('-');
  }

  // Map a student code to an alias email usable with Firebase Auth
  static String aliasEmailFromStudentCode(String studentCode) {
    final normalized = studentCode.trim().toUpperCase();
    return '$normalized@$_aliasEmailDomain';
  }
}

