import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class _CountryCode {
  final String flag;
  final String name;
  final String dialCode;

  const _CountryCode(this.flag, this.name, this.dialCode);
}

const _countryCodes = <_CountryCode>[
  _CountryCode('🇺🇸', 'United States', '+1'),
  _CountryCode('🇨🇦', 'Canada', '+1'),
  _CountryCode('🇬🇧', 'United Kingdom', '+44'),
  _CountryCode('🇫🇷', 'France', '+33'),
  _CountryCode('🇸🇳', 'Senegal', '+221'),
  _CountryCode('🇬🇳', 'Guinea', '+224'),
  _CountryCode('🇲🇱', 'Mali', '+223'),
  _CountryCode('🇨🇮', "Côte d'Ivoire", '+225'),
  _CountryCode('🇬🇲', 'Gambia', '+220'),
  _CountryCode('🇲🇷', 'Mauritania', '+222'),
  _CountryCode('🇧🇫', 'Burkina Faso', '+226'),
  _CountryCode('🇳🇪', 'Niger', '+227'),
  _CountryCode('🇳🇬', 'Nigeria', '+234'),
  _CountryCode('🇬🇭', 'Ghana', '+233'),
  _CountryCode('🇨🇲', 'Cameroon', '+237'),
  _CountryCode('🇹🇩', 'Chad', '+235'),
  _CountryCode('🇲🇦', 'Morocco', '+212'),
  _CountryCode('🇩🇿', 'Algeria', '+213'),
  _CountryCode('🇹🇳', 'Tunisia', '+216'),
  _CountryCode('🇪🇬', 'Egypt', '+20'),
  _CountryCode('🇸🇦', 'Saudi Arabia', '+966'),
  _CountryCode('🇦🇪', 'UAE', '+971'),
  _CountryCode('🇶🇦', 'Qatar', '+974'),
  _CountryCode('🇰🇼', 'Kuwait', '+965'),
  _CountryCode('🇹🇷', 'Turkey', '+90'),
  _CountryCode('🇩🇪', 'Germany', '+49'),
  _CountryCode('🇮🇹', 'Italy', '+39'),
  _CountryCode('🇪🇸', 'Spain', '+34'),
  _CountryCode('🇧🇪', 'Belgium', '+32'),
  _CountryCode('🇳🇱', 'Netherlands', '+31'),
  _CountryCode('🇨🇭', 'Switzerland', '+41'),
];

class MobilePhoneLoginScreen extends StatefulWidget {
  const MobilePhoneLoginScreen({super.key});

  @override
  State<MobilePhoneLoginScreen> createState() => _MobilePhoneLoginScreenState();
}

class _MobilePhoneLoginScreenState extends State<MobilePhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;
  _CountryCode _selectedCountry = _countryCodes.first; // US default

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = query.isEmpty
                ? _countryCodes
                : _countryCodes
                    .where((c) =>
                        c.name.toLowerCase().contains(query.toLowerCase()) ||
                        c.dialCode.contains(query))
                    .toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search country...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        final isSelected = c.dialCode == _selectedCountry.dialCode &&
                            c.name == _selectedCountry.name;
                        return ListTile(
                          leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                          title: Text(
                            c.name,
                            style: GoogleFonts.inter(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          trailing: Text(
                            c.dialCode,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onTap: () {
                            setState(() => _selectedCountry = c);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String get _fullPhoneNumber {
    var digits = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '${_selectedCountry.dialCode}$digits';
  }

  Future<void> _sendCode() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showErrorSnackBar('Please enter a phone number');
      return;
    }

    final digits = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 6) {
      _showErrorSnackBar('Please enter a valid phone number');
      return;
    }

    final phone = _fullPhoneNumber;
    AppLogger.info('Phone auth: sending code to $phone');

    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        _webConfirmationResult =
            await FirebaseAuth.instance.signInWithPhoneNumber(phone);
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              final authService = AuthService();
              final result =
                  await FirebaseAuth.instance.signInWithCredential(credential);
              if (result.user != null) {
                await authService.handleSuccessfulLogin(result.user!);
                AppLogger.info('Phone auth auto-retrieval succeeded');
                if (mounted) Navigator.of(context).pop();
              }
            } catch (e) {
              AppLogger.error('Auto-retrieval login failed: $e');
              if (mounted) _showErrorSnackBar('Failed to login automatically');
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            AppLogger.error('Verification failed: ${e.code} — ${e.message}');
            if (mounted) {
              setState(() => _isLoading = false);
              String msg;
              switch (e.code) {
                case 'invalid-phone-number':
                  msg = 'The phone number format is invalid. Please check and try again.';
                  break;
                case 'too-many-requests':
                  msg = 'Too many attempts. Please wait a few minutes and try again.';
                  break;
                case 'quota-exceeded':
                  msg = 'SMS quota exceeded. Please try again later.';
                  break;
                default:
                  msg = e.message ?? 'Verification failed. Please try again.';
              }
              _showErrorSnackBar(msg);
            }
          },
          codeSent: (String verificationId, int? resendToken) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
                _isLoading = false;
              });
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      AppLogger.error('Error sending code: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to send verification code. Please try again.');
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showErrorSnackBar('Please enter the SMS code');
      return;
    }
    if (code.length < 6) {
      _showErrorSnackBar('Please enter the full 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential result;
      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          throw Exception('No web confirmation result');
        }
        result = await _webConfirmationResult!.confirm(code);
      } else {
        if (_verificationId == null) throw Exception('No verification ID');
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        result = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (result.user != null) {
        final authService = AuthService();
        await authService.handleSuccessfulLogin(result.user!);
        AppLogger.info('Phone auth succeeded for uid=${result.user!.uid}');
        if (mounted) Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Phone verification failed: ${e.message}');
      if (mounted) {
        setState(() => _isLoading = false);
        String msg;
        switch (e.code) {
          case 'invalid-verification-code':
            msg = 'The code you entered is incorrect. Please try again.';
            break;
          case 'session-expired':
            msg = 'The code has expired. Please request a new one.';
            break;
          default:
            msg = e.message ?? 'Verification failed. Please try again.';
        }
        _showErrorSnackBar(msg);
      }
    } catch (e) {
      AppLogger.error('Phone verification failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Verification failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xff111827)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xffE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    size: 32,
                    color: Color(0xff0284C7),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _codeSent ? 'Enter SMS Code' : 'Sign in with Phone',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'We sent a verification code to $_fullPhoneNumber'
                    : 'Enter your phone number to receive a verification code',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 32),
              if (!_codeSent) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _showCountryPicker,
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffE5E7EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCountry.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCountry.dialCode,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff111827),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xff9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
                        ],
                        style: GoogleFonts.inter(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '234 567 8900',
                          hintStyle: GoogleFonts.inter(color: const Color(0xFFBBBBBB)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xff0386FF)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0386FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Send Code',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: GoogleFonts.inter(fontSize: 28, letterSpacing: 12),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFFBBBBBB),
                      fontSize: 28,
                      letterSpacing: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff0386FF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0386FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Verify & Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _codeSent = false;
                            _codeController.clear();
                          });
                        },
                  child: Text(
                    'Change Phone Number',
                    style: GoogleFonts.inter(
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
