import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/onboarding');
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Terms & Privacy',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Terms Box
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderGlow),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ThemarIP Financial Intelligence Platform Terms',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Last updated: September 2026',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const Divider(height: 28, color: Colors.white10),

                          _buildSectionTitle('1. Bank Statement Processing & Data Security'),
                          _buildSectionBody(
                            'ThemarIP processes uploaded Bank Muscat card statements strictly to parse transactional records, determine merchant insights, and construct personal financial management (PFM) categorizations. All data ingestion is executed in secured database environments with tokenized identity.',
                          ),

                          _buildSectionTitle('2. User Privacy & Ownership'),
                          _buildSectionBody(
                            'You retain 100% ownership over your financial statement records. ThemarIP does not sell or distribute personal spending habits to unapproved 3rd parties. Extracted metrics are exclusively utilized to render financial hierarchies and analytics for your account.',
                          ),

                          _buildSectionTitle('3. Accuracy & PFM Advisory'),
                          _buildSectionBody(
                            'Transaction categorization models and merchant detection algorithms provide advisory intelligence for budgeting and tracking. Users may review, update, or edit category mappings at any time.',
                          ),

                          _buildSectionTitle('4. Account Credentials & Access'),
                          _buildSectionBody(
                            'You are responsible for safeguarding your login credentials. By continuing, you agree to report any unauthorized access immediately.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Agreement Checkbox
                InkWell(
                  onTap: () {
                    setState(() => _agreed = !_agreed);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _agreed
                          ? AppTheme.primaryPurple.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _agreed
                            ? AppTheme.primaryPurple
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          activeColor: AppTheme.primaryPurple,
                          onChanged: (val) {
                            setState(() => _agreed = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I have read and agree to the Terms of Service & Privacy Policy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Agree & Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _agreed
                        ? () {
                            Navigator.of(context).pushReplacementNamed('/register');
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _agreed ? AppTheme.primaryGradient : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Agree & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _agreed ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: _agreed ? Colors.white : AppTheme.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.neonPink,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppTheme.textMuted,
        height: 1.5,
      ),
    );
  }
}
