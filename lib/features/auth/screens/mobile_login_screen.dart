import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';

/// Beautiful mobile-optimized login screen
class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _useStudentIdLogin = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      String emailOrId = _emailController.text.trim();
      final password = _passwordController.text;

      // If using Student ID, convert to email alias
      if (_useStudentIdLogin) {
        final normalized = emailOrId.toLowerCase();
        emailOrId = '$normalized@alluwaleducationhub.org';
      }

      User? user = await authService.signInWithEmailAndPassword(
        emailOrId,
        password,
      );

      if (user != null) {
        AppLogger.info('AuthService login succeeded for uid=${user.uid}');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        String errorMessage;
        switch (e.code) {
          case 'user-deactivated':
            errorMessage = l10n.loginAccountArchived;
            break;
          case 'user-not-found':
            errorMessage = _useStudentIdLogin ? l10n.loginNoAccountStudentId : l10n.loginNoAccountEmail;
            break;
          case 'wrong-password':
            errorMessage = l10n.loginIncorrectPassword;
            break;
          case 'invalid-email':
            errorMessage = l10n.loginInvalidEmailFormat;
            break;
          case 'user-disabled':
            errorMessage = l10n.loginAccountDisabled;
            break;
          case 'too-many-requests':
            errorMessage = l10n.loginTooManyAttempts;
            break;
          default:
            errorMessage = l10n.loginFailed;
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showErrorSnackBar(l10n.loginUnexpectedError);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              child: Container(
                height: size.height - MediaQuery.of(context).padding.top,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section (minimal height so form fits without scrolling)
                    if (!keyboardVisible) ...[
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff0386FF).withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/Alluwal_Education_Hub_Logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.loginWelcomeBack,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff111827),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          l10n.loginSignInContinue,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff6B7280),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 6),
                    ],

                    // Login Form Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Login Mode Toggle
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xffF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildLoginModeButton(
                                      l10n.loginEmail,
                                      !_useStudentIdLogin,
                                      () {
                                        setState(() {
                                          _useStudentIdLogin = false;
                                          _emailController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildLoginModeButton(
                                      l10n.loginStudentId,
                                      _useStudentIdLogin,
                                      () {
                                        setState(() {
                                          _useStudentIdLogin = true;
                                          _emailController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Email/Student ID Field
                            Text(
                              _useStudentIdLogin ? l10n.loginStudentId : l10n.loginEmail,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff374151),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: _useStudentIdLogin
                                  ? TextInputType.text
                                  : TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xff111827),
                              ),
                              decoration: InputDecoration(
                                hintText: _useStudentIdLogin
                                    ? l10n.loginEnterStudentId
                                    : l10n.loginEnterEmail,
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xff9CA3AF),
                                ),
                                filled: true,
                                fillColor: const Color(0xffF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xffE5E7EB),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xff0386FF),
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xffEF4444),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: Icon(
                                  _useStudentIdLogin ? Icons.badge : Icons.email,
                                  color: const Color(0xff6B7280),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l10n.loginFieldRequired;
                                }
                                if (!_useStudentIdLogin &&
                                    !value.contains('@')) {
                                  return l10n.loginInvalidEmail;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            // Password Field
                            Text(
                              l10n.loginPassword,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff374151),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleSignIn(),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: const Color(0xff111827),
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.loginEnterPassword,
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xff9CA3AF),
                                ),
                                filled: true,
                                fillColor: const Color(0xffF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xffE5E7EB),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xff0386FF),
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xffEF4444),
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xff6B7280),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xff6B7280),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.loginPasswordRequired;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Sign In Button
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff0386FF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor:
                                      const Color(0xff0386FF).withOpacity(0.6),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        l10n.loginSignIn,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!keyboardVisible) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n.loginAlluvialHub,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginModeButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xff111827) : const Color(0xff6B7280),
          ),
        ),
      ),
    );
  }
}
