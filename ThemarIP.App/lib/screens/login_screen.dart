import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty && _errorMessage == null) {
      _errorMessage = args;
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First check if Admin has flagged this account for a mandatory password reset.
      // This allows the user to set their new password even if they forgot their old password!
      final status = await _apiService.getUserStatus(email: email);
      if (status['requirePasswordReset'] == true) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showMandatoryPasswordResetModal(email);
        return;
      }

      if (_passwordController.text.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter both your email and password.';
        });
        return;
      }

      final user = await _apiService.login(
        email,
        _passwordController.text,
      );
      if (!mounted) return;

      if (user.requirePasswordReset) {
        await AuthService.clearSession(keepBackgroundSms: true);
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showMandatoryPasswordResetModal(email);
        return;
      }

      Navigator.of(context).pushReplacementNamed('/categories');
    } catch (e) {
      String msg = 'Invalid email or password. Please check your credentials.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          msg = 'Unable to connect to the server. Please check your connection.';
        } else if (e.response?.data != null && e.response?.data is Map) {
          final data = e.response!.data as Map;
          if (data['message'] != null) {
            msg = data['message'].toString();
          }
        }
      }
      setState(() {
        _errorMessage = msg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Shown when an Administrator has triggered "Reset Password" for this user from the Admin Portal.
  /// Prompts the user to enter their new password and re-enter it as confirmation, then redirects to Login.
  void _showMandatoryPasswordResetModal(String email) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? modalError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141A29),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: AppTheme.neonPink, width: 1.2),
            ),
            title: Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: AppTheme.neonPink, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LanguageService.tr('admin_reset_required_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.tr('admin_reset_required_sub'),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded, size: 16, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (modalError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modalError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    LanguageService.tr('enter_new_password'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                      hintText: '••••••••••••',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LanguageService.tr('confirm_new_password'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.verified_user_outlined, color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                      hintText: '••••••••••••',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: Text(
                  LanguageService.tr('cancel'),
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newPass = newPassCtrl.text;
                        final confirmPass = confirmPassCtrl.text;
                        if (newPass.length < 6) {
                          setModalState(() {
                            modalError = LanguageService.tr('password_min_error');
                          });
                          return;
                        }
                        if (newPass != confirmPass) {
                          setModalState(() {
                            modalError = LanguageService.tr('passwords_do_not_match');
                          });
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() {
                          isSubmitting = true;
                          modalError = null;
                        });

                        try {
                          await _apiService.completePasswordReset(
                            email: email,
                            newPassword: newPass,
                            confirmPassword: confirmPass,
                          );
                          await AuthService.clearSession(keepBackgroundSms: true);
                          if (!mounted) return;
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          setState(() {
                            _passwordController.clear();
                            _errorMessage = null;
                          });
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(LanguageService.tr('password_reset_success')),
                              backgroundColor: AppTheme.emeraldGreen,
                            ),
                          );
                        } catch (e) {
                          String msg = 'Failed to update password.';
                          if (e is DioException && e.response?.data is Map) {
                            msg = e.response!.data['message']?.toString() ?? msg;
                          }
                          setModalState(() {
                            modalError = msg;
                            isSubmitting = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        LanguageService.tr('update_password'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailController.text.trim());
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isOtpSent = false;
    bool isResetting = false;
    bool obscureNewPass = true;
    bool obscureConfirmPass = true;
    bool emailWasDelivered = false;
    String? dialogError;
    String? previewOtp;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141A29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF28364F)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_reset_rounded, color: AppTheme.neonPink, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            LanguageService.tr('reset_password'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOtpSent
                        ? 'Enter the 6-digit verification code sent to your email and confirm your new password.'
                        : 'Enter your registered email address to receive a password reset verification code.',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 18),

                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (emailWasDelivered) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.mark_email_read_rounded, color: AppTheme.emeraldGreen, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verification email sent! Please check your Inbox and Spam folder.',
                              style: TextStyle(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (previewOtp != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined, color: Color(0xFF00E5FF), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verification Code: $previewOtp (valid for 15 min)',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              otpCtrl.text = previewOtp!;
                            },
                            child: const Text('Auto-fill', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (!isOtpSent) ...[
                    Text(
                      LanguageService.tr('email_address'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: resetEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline_rounded, color: AppTheme.textMuted),
                        hintText: 'user@themar.ip',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isResetting
                            ? null
                            : () async {
                                final email = resetEmailCtrl.text.trim();
                                if (email.isEmpty) {
                                  setModalState(() => dialogError = 'Please enter your email address.');
                                  return;
                                }
                                setModalState(() {
                                  isResetting = true;
                                  dialogError = null;
                                });
                                try {
                                  // Check if admin already enabled direct password reset for this user
                                  final status = await _apiService.getUserStatus(email: email);
                                  if (status['requirePasswordReset'] == true) {
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    _showMandatoryPasswordResetModal(email);
                                    return;
                                  }

                                  final res = await _apiService.forgotPassword(email);
                                  setModalState(() {
                                    isOtpSent = true;
                                    emailWasDelivered = res['emailSent'] == true;
                                    previewOtp = res['previewOtp']?.toString();
                                    isResetting = false;
                                  });
                                } catch (e) {
                                  String msg = 'Failed to request reset code.';
                                  if (e is DioException && e.response?.data is Map) {
                                    msg = e.response!.data['message']?.toString() ?? msg;
                                  }
                                  setModalState(() {
                                    dialogError = msg;
                                    isResetting = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isResetting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '6-DIGIT VERIFICATION CODE (OTP)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(letterSpacing: 6, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_outlined, color: AppTheme.textMuted),
                        hintText: '123456',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LanguageService.tr('enter_new_password'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscureNewPass,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setModalState(() => obscureNewPass = !obscureNewPass);
                          },
                        ),
                        hintText: '••••••••••••',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LanguageService.tr('confirm_new_password'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: obscureConfirmPass,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.verified_user_outlined, color: AppTheme.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setModalState(() => obscureConfirmPass = !obscureConfirmPass);
                          },
                        ),
                        hintText: '••••••••••••',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isResetting
                            ? null
                            : () async {
                                final otp = otpCtrl.text.trim();
                                final newPass = newPassCtrl.text;
                                final confirmPass = confirmPassCtrl.text;
                                if (otp.length < 6) {
                                  setModalState(() => dialogError = 'Please enter the 6-digit code.');
                                  return;
                                }
                                if (newPass.length < 6) {
                                  setModalState(() => dialogError = LanguageService.tr('password_min_error'));
                                  return;
                                }
                                if (newPass != confirmPass) {
                                  setModalState(() => dialogError = LanguageService.tr('passwords_do_not_match'));
                                  return;
                                }
                                final messenger = ScaffoldMessenger.of(context);
                                setModalState(() {
                                  isResetting = true;
                                  dialogError = null;
                                });
                                try {
                                  await _apiService.resetPassword(
                                    resetEmailCtrl.text.trim(),
                                    otp,
                                    newPass,
                                  );
                                  if (!mounted) return;
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                  _passwordController.clear();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(LanguageService.tr('password_reset_success')),
                                      backgroundColor: AppTheme.emeraldGreen,
                                    ),
                                  );
                                } catch (e) {
                                  String msg = 'Failed to reset password.';
                                  if (e is DioException && e.response?.data is Map) {
                                    msg = e.response!.data['message']?.toString() ?? msg;
                                  }
                                  setModalState(() {
                                    dialogError = msg;
                                    isResetting = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isResetting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                LanguageService.tr('update_password'),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.notifier,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderGlow),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Language Selector at Top of Login Card (Default: English)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.language_rounded,
                              size: 16,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              LanguageService.tr('select_language'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        LanguageSelectorPill(
                          compact: true,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: Image.asset(
                          'assets/themarip_logo_transparent.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.auto_awesome_rounded,
                            size: 72,
                            color: Color(0xFFA855F7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        LanguageService.tr('welcome_back'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      LanguageService.tr('email_address'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          color: AppTheme.textMuted,
                        ),
                        hintText: 'user@themar.ip',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService.tr('password'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showForgotPasswordDialog,
                          child: Text(
                            LanguageService.tr('forgot_password'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.neonPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.textMuted,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        hintText: '••••••••••••',
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        LanguageService.tr('sign_in'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          LanguageService.tr('no_account'),
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/register');
                          },
                          child: Text(
                            LanguageService.tr('create_account'),
                            style: const TextStyle(
                              color: AppTheme.neonPink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
