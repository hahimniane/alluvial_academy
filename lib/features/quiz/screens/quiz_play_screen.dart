import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/quiz_category.dart';
import '../models/quiz_question.dart';
import '../models/quiz_result.dart';
import '../services/quiz_service.dart';
import '../services/quiz_audio_service.dart';

/// Active quiz gameplay screen
class QuizPlayScreen extends StatefulWidget {
  final QuizCategory category;

  const QuizPlayScreen({
    super.key,
    required this.category,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen>
    with SingleTickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final QuizAudioService _audioService = QuizAudioService();
  
  List<QuizQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;
  bool _isLoading = true;
  String? _error;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  final Stopwatch _quizStopwatch = Stopwatch();
  final List<QuestionResult> _questionResults = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _audioService.initialize();
    _loadQuestions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _quizStopwatch.stop();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final questions = await _quizService.getQuestionsForCategory(
        widget.category.id,
      );
      
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        _quizStopwatch.start();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load questions: $e';
          _isLoading = false;
        });
      }
    }
  }

  QuizQuestion get _currentQuestion => _questions[_currentQuestionIndex];
  
  bool get _isLastQuestion => _currentQuestionIndex >= _questions.length - 1;

  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    HapticFeedback.lightImpact();
    
    setState(() {
      _selectedAnswerIndex = index;
      _hasAnswered = true;
    });

    final isCorrect = _currentQuestion.isCorrect(index);
    
    if (isCorrect) {
      _correctAnswers++;
      _audioService.playCorrectSound(); // Play correct sound
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    } else {
      _audioService.playWrongSound(); // Play wrong sound
    }

    // Record question result
    _questionResults.add(QuestionResult(
      questionId: _currentQuestion.id,
      selectedAnswerIndex: index,
      correctAnswerIndex: _currentQuestion.correctAnswerIndex,
      isCorrect: isCorrect,
      timeTaken: Duration.zero, // Could track per-question time
    ));
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _showResults();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _hasAnswered = false;
      });
    }
  }

  void _showResults() {
    _quizStopwatch.stop();
    
    // Play celebration sound
    _audioService.playCelebrationSound();
    
    final result = QuizResult(
      categoryId: widget.category.id,
      totalQuestions: _questions.length,
      correctAnswers: _correctAnswers,
      wrongAnswers: _questions.length - _correctAnswers,
      timeTaken: _quizStopwatch.elapsed,
      completedAt: DateTime.now(),
      questionResults: _questionResults,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _QuizResultScreen(
          result: result,
          category: widget.category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: widget.category.color.withOpacity(0.1),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: widget.category.color),
              const SizedBox(height: 16),
              Text(
                'Loading questions...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: widget.category.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: Text(widget.category.name),
          backgroundColor: widget.category.color,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error ?? 'No questions available yet',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.category.color,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Progress Bar
            _buildProgressBar(),
            
            // Question Card
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildQuestionCard(),
              ),
            ),
            
            // Next Button
            if (_hasAnswered)
              _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitConfirmation(),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Score Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: widget.category.color, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_correctAnswers',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: widget.category.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(widget.category.color),
          minHeight: 8,
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Number Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Question ${_currentQuestionIndex + 1}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.category.color,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Question Text
            Text(
              _currentQuestion.question,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            
            // Answer Options
            ...List.generate(
              _currentQuestion.options.length,
              (index) => _buildAnswerOption(index),
            ),
            
            // Explanation (shown after answering)
            if (_hasAnswered && _currentQuestion.explanation != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFF0EA5E9), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentQuestion.explanation!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF0369A1),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption(int index) {
    final option = _currentQuestion.options[index];
    final isSelected = _selectedAnswerIndex == index;
    final isCorrect = index == _currentQuestion.correctAnswerIndex;
    
    Color bgColor = Colors.grey[50]!;
    Color borderColor = Colors.grey[200]!;
    Color textColor = const Color(0xFF374151);
    IconData? icon;
    
    if (_hasAnswered) {
      if (isCorrect) {
        bgColor = const Color(0xFFD1FAE5);
        borderColor = const Color(0xFF10B981);
        textColor = const Color(0xFF065F46);
        icon = Icons.check_circle_rounded;
      } else if (isSelected && !isCorrect) {
        bgColor = const Color(0xFFFEE2E2);
        borderColor = const Color(0xFFEF4444);
        textColor = const Color(0xFF991B1B);
        icon = Icons.cancel_rounded;
      }
    } else if (isSelected) {
      bgColor = widget.category.color.withOpacity(0.1);
      borderColor = widget.category.color;
      textColor = widget.category.color;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _selectAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (icon != null)
                Icon(icon, color: borderColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.category.color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            _isLastQuestion ? 'See Results' : 'Next Question',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quit Quiz?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your progress will be lost. Are you sure?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: Text('Quit', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
}

/// Results screen shown after completing a quiz
class _QuizResultScreen extends StatelessWidget {
  final QuizResult result;
  final QuizCategory category;

  const _QuizResultScreen({
    required this.result,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // Trophy/Stars
              _buildStarsDisplay(),
              const SizedBox(height: 24),
              
              // Encouragement
              Text(
                result.encouragement,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Score Card
              _buildScoreCard(),
              
              const Spacer(),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Home'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: category.color),
                        foregroundColor: category.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizPlayScreen(category: category),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Play Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: category.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarsDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isEarned = index < result.starsEarned;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            isEarned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: index == 1 ? 72 : 56,
            color: isEarned ? const Color(0xFFFBBF24) : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'Score',
                '${result.correctAnswers}/${result.totalQuestions}',
                Icons.check_circle_outline_rounded,
                const Color(0xFF10B981),
              ),
              Container(height: 50, width: 1, color: Colors.grey[200]),
              _buildStatItem(
                'Percentage',
                '${result.scorePercentage.toStringAsFixed(0)}%',
                Icons.percent_rounded,
                category.color,
              ),
              Container(height: 50, width: 1, color: Colors.grey[200]),
              _buildStatItem(
                'Grade',
                result.grade,
                Icons.grade_rounded,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
