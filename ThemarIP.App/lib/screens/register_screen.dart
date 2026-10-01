import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegister() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill out all required fields.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.register(
        _emailController.text.trim(),
        _passwordController.text,
        _fullNameController.text.trim(),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please sign in.'),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );

      // Redirect user to login page
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      String msg = 'Registration failed. Please try again.';
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
        } else if (e.response?.statusCode == 409 || e.response?.statusCode == 400) {
          msg = 'Registration failed. User with this email may already exist.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/terms');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: AppTheme.neonPink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderGlow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Join ThemarIP 🚀',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create an account to start processing financial card statements.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 28),
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
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'FULL NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppTheme.textMuted,
                    ),
                    hintText: 'Ahmed Al-Mamari',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'EMAIL ADDRESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                    hintText: 'ahmed@themar.ip',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.textMuted,
                    ),
                    hintText: '••••••••••••',
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              )
                            : const Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
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
  }
}
