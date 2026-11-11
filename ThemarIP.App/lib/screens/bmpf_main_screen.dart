import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../config/app_theme.dart';
import '../models/bmpf_models.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/bank_setup_service.dart';
import '../services/language_service.dart';
import '../services/sms_service.dart';
import '../budgeting/main.dart';
import '../budgeting/models/budget_models.dart';
import '../budgeting/state/budget_controller.dart';
import '../budgeting/theme/app_theme.dart' show AppColors;

class LocalBank {
  final String code;
  final String nameEn;
  final String nameAr;
  final String shortName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String formatDescription;
  final String badgeText;
  final bool isSupported;
  final IconData defaultIcon;
  final String logoAsset;

  const LocalBank({
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.shortName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.formatDescription,
    required this.badgeText,
    this.isSupported = true,
    required this.defaultIcon,
    required this.logoAsset,
  });
}

enum ExtractorFlowStep {
  selectBank,
  connectBank,
  uploadStatement,
  inspectData,
}

const List<LocalBank> _localBanks = [
  LocalBank(
    code: 'BANK_MUSCAT',
    nameEn: 'Bank Muscat',
    nameAr: 'بنك مسقط',
    shortName: 'BM',
    primaryColor: Color(0xFFC41230),
    secondaryColor: Color(0xFF8B0000),
    accentColor: Color(0xFFFFD700),
    formatDescription: 'Official Multi-page Account & Card Statements (.pdf)',
    badgeText: 'Active Parser',
    defaultIcon: Icons.account_balance,
    logoAsset: 'assets/banks/bank_muscat.png',
  ),
  LocalBank(
    code: 'NBO',
    nameEn: 'National Bank of Oman',
    nameAr: 'البنك الوطني العماني',
    shortName: 'NBO',
    primaryColor: Color(0xFF002B49),
    secondaryColor: Color(0xFF0A3D62),
    accentColor: Color(0xFFD4AF37),
    formatDescription: 'Retail & Corporate Account Statements (.pdf)',
    badgeText: 'Active Parser',
    defaultIcon: Icons.sailing,
    logoAsset: 'assets/banks/nbo.png',
  ),
  LocalBank(
    code: 'BANK_DHOFAR',
    nameEn: 'Bank Dhofar',
    nameAr: 'بنك ظفار',
    shortName: 'BD',
    primaryColor: Color(0xFF007A3D),
    secondaryColor: Color(0xFF004D26),
    accentColor: Color(0xFFE5A823),
    formatDescription: 'Dhofar e-Statement Multi-page PDF Format',
    badgeText: 'Format Ready',
    defaultIcon: Icons.waves,
    logoAsset: 'assets/banks/bank_dhofar.png',
  ),
  LocalBank(
    code: 'OAB',
    nameEn: 'Oman Arab Bank',
    nameAr: 'بنك عمان العربي',
    shortName: 'OAB',
    primaryColor: Color(0xFF004B87),
    secondaryColor: Color(0xFF002D62),
    accentColor: Color(0xFFEF4444),
    formatDescription: 'OAB Digital Statement & Summary Tables (.pdf)',
    badgeText: 'Format Ready',
    defaultIcon: Icons.shield,
    logoAsset: 'assets/banks/oab.png',
  ),
  LocalBank(
    code: 'SOHAR_INTL',
    nameEn: 'Sohar International',
    nameAr: 'صحار الدولي',
    shortName: 'SI',
    primaryColor: Color(0xFFE11D48),
    secondaryColor: Color(0xFF9F1239),
    accentColor: Color(0xFFF97316),
    formatDescription: 'Sohar International e-Statement Format (.pdf)',
    badgeText: 'Format Ready',
    defaultIcon: Icons.diamond_outlined,
    logoAsset: 'assets/banks/sohar_intl.png',
  ),
  LocalBank(
    code: 'AHLI_BANK',
    nameEn: 'Ahli Bank Oman',
    nameAr: 'البنك الأهلي',
    shortName: 'AB',
    primaryColor: Color(0xFF70001E),
    secondaryColor: Color(0xFF4A0014),
    accentColor: Color(0xFF38BDF8),
    formatDescription: 'Ahli Bank Standard e-Statement (.pdf)',
    badgeText: 'Format Ready',
    defaultIcon: Icons.security,
    logoAsset: 'assets/banks/ahli_bank.png',
  ),
  LocalBank(
    code: 'BANK_NIZWA',
    nameEn: 'Bank Nizwa',
    nameAr: 'بنك نزوى',
    shortName: 'BN',
    primaryColor: Color(0xFF006633),
    secondaryColor: Color(0xFF00381C),
    accentColor: Color(0xFF10B981),
    formatDescription: 'Nizwa Islamic Account Statement (.pdf)',
    badgeText: 'Islamic Banking',
    defaultIcon: Icons.auto_awesome,
    logoAsset: 'assets/banks/bank_nizwa.png',
  ),
  LocalBank(
    code: 'ALIZZ_ISLAMIC',
    nameEn: 'Alizz Islamic Bank',
    nameAr: 'بنك العز الإسلامي',
    shortName: 'AIB',
    primaryColor: Color(0xFF0284C7),
    secondaryColor: Color(0xFF0369A1),
    accentColor: Color(0xFFF59E0B),
    formatDescription: 'Alizz Islamic Finance & Card Statement (.pdf)',
    badgeText: 'Islamic Banking',
    defaultIcon: Icons.stars_rounded,
    logoAsset: 'assets/banks/alizz_islamic.png',
  ),
  LocalBank(
    code: 'AMWAL_PAY',
    nameEn: 'AmwalPay',
    nameAr: 'أموال باي',
    shortName: 'Amwal',
    primaryColor: Color(0xFF0D9488),
    secondaryColor: Color(0xFF0F766E),
    accentColor: Color(0xFF2DD4BF),
    formatDescription: 'AmwalPay Digital Wallet & Gateway Statements',
    badgeText: 'Digital Wallet',
    defaultIcon: Icons.account_balance_wallet_rounded,
    logoAsset: 'assets/banks/amwal_pay.png',
  ),
  LocalBank(
    code: 'OMPAY',
    nameEn: 'OMPay',
    nameAr: 'أو إم باي',
    shortName: 'OMPay',
    primaryColor: Color(0xFF7C3AED),
    secondaryColor: Color(0xFF5B21B6),
    accentColor: Color(0xFFA855F7),
    formatDescription: 'OMPay Smart Mobile Wallet & QR Payments',
    badgeText: 'Digital Wallet',
    defaultIcon: Icons.qr_code_2_rounded,
    logoAsset: 'assets/banks/ompay.png',
  ),
  LocalBank(
    code: 'THAWANI',
    nameEn: 'Thawani',
    nameAr: 'ثواني',
    shortName: 'Thawani',
    primaryColor: Color(0xFF0284C7),
    secondaryColor: Color(0xFF0369A1),
    accentColor: Color(0xFF38BDF8),
    formatDescription: 'Thawani Technologies Digital Wallet & App',
    badgeText: 'Fintech Wallet',
    defaultIcon: Icons.flash_on_rounded,
    logoAsset: 'assets/banks/thawani.png',
  ),
  LocalBank(
    code: 'WALITII',
    nameEn: 'Walitii',
    nameAr: 'محفظة ولتي',
    shortName: 'Walitii',
    primaryColor: Color(0xFF1E3A8A),
    secondaryColor: Color(0xFF172554),
    accentColor: Color(0xFF60A5FA),
    formatDescription: 'Walitii Digital Mobile Wallet & Statements',
    badgeText: 'Digital Wallet',
    defaultIcon: Icons.account_balance_wallet_outlined,
    logoAsset: 'assets/banks/walitii.png',
  ),
  LocalBank(
    code: 'PAYMOB',
    nameEn: 'Paymob',
    nameAr: 'باي موب',
    shortName: 'Paymob',
    primaryColor: Color(0xFFEA580C),
    secondaryColor: Color(0xFF9A3412),
    accentColor: Color(0xFFFB923C),
    formatDescription: 'Paymob Payments & Gateway Statement Summaries',
    badgeText: 'Payment Gateway',
    defaultIcon: Icons.point_of_sale_rounded,
    logoAsset: 'assets/banks/paymob.png',
  ),
];

/// Public access to the supported Omani bank catalog (used by the bank setup screen).
const List<LocalBank> kLocalBanks = _localBanks;

Widget buildBankLogoWidget(LocalBank bank, {double size = 42, bool circular = false}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: circular ? BorderRadius.circular(size / 2) : BorderRadius.circular(size * 0.28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: circular ? BorderRadius.circular(size / 2) : BorderRadius.circular(size * 0.24),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: Image.asset(
          bank.logoAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => buildBankEmblemIconWidget(bank, size),
        ),
      ),
    ),
  );
}

Widget buildBankEmblemIconWidget(LocalBank bank, double size) {
  switch (bank.code) {
    case 'BANK_MUSCAT':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, color: bank.accentColor, size: size * 0.42),
          Text(
            'BM',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.22,
              letterSpacing: -0.3,
              height: 1.0,
            ),
          ),
        ],
      );
    case 'NBO':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sailing_rounded, color: bank.primaryColor, size: size * 0.42),
          Text(
            'NBO',
            style: TextStyle(
              color: bank.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.22,
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
        ],
      );
    case 'AMWAL_PAY':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_rounded, color: bank.primaryColor, size: size * 0.42),
          Text(
            'AMWAL',
            style: TextStyle(
              color: bank.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.17,
              letterSpacing: 0.1,
              height: 1.0,
            ),
          ),
        ],
      );
    case 'OMPAY':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, color: bank.primaryColor, size: size * 0.42),
          Text(
            'OMPAY',
            style: TextStyle(
              color: bank.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.17,
              letterSpacing: 0.1,
              height: 1.0,
            ),
          ),
        ],
      );
    case 'THAWANI':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flash_on_rounded, color: bank.primaryColor, size: size * 0.42),
          Text(
            'THAWANI',
            style: TextStyle(
              color: bank.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.15,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ],
      );
    case 'WALITII':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: bank.primaryColor, size: size * 0.42),
          Text(
            'WALITII',
            style: TextStyle(
              color: bank.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.16,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ],
      );
    case 'PAYMOB':
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.point_of_sale_rounded, color: bank.primaryColor, size: size * 0.42),
          Text(
            'PAYMOB',
            style: TextStyle(
              color: bank.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.16,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ],
      );
    default:
      return Icon(bank.defaultIcon, color: bank.primaryColor, size: size * 0.45);
  }
}

class BmpfMainScreen extends StatefulWidget {
  final int initialPageIndex;

  const BmpfMainScreen({
    super.key,
    this.initialPageIndex = 0,
  });

  @override
  State<BmpfMainScreen> createState() => _BmpfMainScreenState();
}

class _BmpfMainScreenState extends State<BmpfMainScreen> {
  final ApiService _apiService = ApiService();
  final BudgetController _budgetController = BudgetController();

  // Page switcher: 0 = Category Hierarchy (/hierarchy or /categories), 1 = Profile, 2 = Extractor, 3 = Budgeting
  int _selectedPageIndex = 0;

  // Selected Local Bank for statement parsing format
  LocalBank _selectedBank = _localBanks[0];
  ExtractorFlowStep _extractorFlow = ExtractorFlowStep.selectBank;
  final TextEditingController _bankSearchController = TextEditingController();
  String _bankSearchText = '';

  UserModel? _currentUser;
  int _dbTxCount = 0;
  bool _isLoading = false;
  String _loadingMessage = '';
  bool _smsPaused = false;

  // 1. PDF State
  PlatformFile? _selectedPdfFile;
  BmpfParseResult? _pdfParseResult;

  // Category Hierarchy State
  List<BmpfCategoryNode> _categories = [];
  List<BmpfCategoryNode> _rawCategories = [];
  String _selectedHierarchyBankCode = 'ALL';
  bool _showPaidSpentHeatmap = false;
  String _selectedTimePeriod = 'MONTH'; // 'DAY', 'WEEK', 'MONTH'
  List<Map<String, dynamic>> _userUploadedBanks = [];
  // Banks the user chose to connect in the bank setup step (drives which cards are shown)
  List<String> _selectedBankCodes = [];
  bool _isLoadingCategories = false;
  final Set<String> _expandedCategoryIds = {};
  int? _selectedCategoryIndex;

  bool get _hasUploadedStatement {
    if (_userUploadedBanks.isNotEmpty) return true;
    if (_rawCategories.any((c) => c.transactions.isNotEmpty)) return true;
    if (_dbTxCount > 0) return true;
    return false;
  }

  List<LocalBank> get _filteredBanks {
    if (_bankSearchText.trim().isEmpty) return _localBanks;
    final q = _bankSearchText.toLowerCase();
    return _localBanks.where((b) {
      return b.nameEn.toLowerCase().contains(q) ||
          b.nameAr.contains(q) ||
          b.shortName.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedPageIndex = widget.initialPageIndex;
    _initScreenData();
    SmsService.isPaused().then((paused) {
      if (mounted) setState(() => _smsPaused = paused);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) SmsService.start(context);
    });
  }

  Future<void> _initScreenData() async {
    await _loadUser();
    if (!mounted) return;
    final savedBanks = await BankSetupService.getSelectedBanks();
    if (!mounted) return;
    setState(() {
      _selectedBankCodes = savedBanks.toList();
      final firstPicked = _localBanks.where((b) => _selectedBankCodes.contains(b.code));
      if (firstPicked.isNotEmpty) _selectedBank = firstPicked.first;
    });
    await _fetchCategoryHierarchy();
    if (mounted && !_hasUploadedStatement) {
      setState(() {
        _selectedPageIndex = 2; // First time user must not bypass Extractor
      });
    }
  }

  @override
  void didUpdateWidget(covariant BmpfMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPageIndex != widget.initialPageIndex) {
      if (!_hasUploadedStatement && widget.initialPageIndex == 0) {
        _showToast('Please upload your first bank statement in Extractor to unlock Hierarchy analytics.');
        return;
      }
      setState(() {
        _selectedPageIndex = widget.initialPageIndex;
      });
      if (_selectedPageIndex == 0) {
        _fetchCategoryHierarchy();
      }
    }
  }

  @override
  void dispose() {
    _bankSearchController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() => _currentUser = user);
      _fetchLiveDbCount();
    }
    if (user != null && user.email.isNotEmpty) {
      final status = await _apiService.getUserStatus(
        userId: user.id,
        email: user.email,
      );
      if (mounted && (status['requirePasswordReset'] == true || user.requirePasswordReset)) {
        _showAdminForcedResetDialog(user.email);
      }
    }
  }

  void _showAdminForcedResetDialog(String email) {
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
          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: Colors.white,
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
                        color: Color(0xFF0F172A),
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
                        color: Color(0xFF475569),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      style: const TextStyle(color: Color(0xFF0F172A)),
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
                      style: const TextStyle(color: Color(0xFF0F172A)),
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
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
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
                              _showToast(LanguageService.tr('password_reset_success'));
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/login',
                                (route) => false,
                              );
                            } catch (e) {
                              setModalState(() {
                                modalError = 'Failed to update password. Please try again.';
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _fetchLiveDbCount() async {
    final count = await _apiService.getDbTransactionCount(userId: _currentUser?.id);
    if (mounted) {
      setState(() => _dbTxCount = count);
    }
  }

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (mounted) {
      setState(() {
        _currentUser = null;
      });
      _fetchLiveDbCount();
      _showToast('Signed out successfully');
      Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
    }
  }

  void _showLoading(String msg) {
    setState(() {
      _isLoading = true;
      _loadingMessage = msg;
    });
  }

  void _hideLoading() {
    setState(() => _isLoading = false);
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.redAccent : AppTheme.emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================================
  // BANK SELECTION & STATEMENT PARSER METHODS
  // ============================================================
  void _onSelectBank(LocalBank bank) {
    setState(() {
      _selectedBank = bank;
      _pdfParseResult = null;
      _selectedPdfFile = null;
      _extractorFlow = ExtractorFlowStep.connectBank;
    });
  }

  Future<void> _confirmBankSelectionAndProceed(LocalBank bank) async {
    if (!_selectedBankCodes.contains(bank.code)) {
      setState(() => _selectedBankCodes.add(bank.code));
    }
    await BankSetupService.addBank(bank.code);
    _apiService.saveUserBankSelection(
      bankCode: bank.code,
      bankName: bank.nameEn,
      userId: _currentUser?.id,
      email: _currentUser?.email,
    ).then((_) => SmsService.refreshSenders());
    if (!mounted) return;
    setState(() => _extractorFlow = ExtractorFlowStep.uploadStatement);
  }

  Future<void> _confirmAndUnsyncBank(String bankCode, String bankName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LanguageService.tr('Unsync Bank?', 'إلغاء ربط البنك؟'),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.tr(
            'Are you sure you want to unsync and remove "$bankName" from your connected accounts?',
            'هل أنت متأكد من إلغاء ربط وحذف "$bankName" من حساباتك المتصلة؟',
          ),
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              LanguageService.tr('Cancel', 'إلغاء'),
              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.white),
            label: Text(
              LanguageService.tr('Unsync & Remove', 'إلغاء الربط والحذف'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _showLoading('Unsyncing $bankName...');
    try {
      await BankSetupService.removeBank(bankCode);
      await _apiService.unsyncUserBank(
        bankCode: bankCode,
        bankName: bankName,
        userId: _currentUser?.id,
        email: _currentUser?.email,
      );

      if (!mounted) return;
      setState(() {
        _selectedBankCodes.removeWhere((c) => c.toUpperCase() == bankCode.toUpperCase());
        _userUploadedBanks.removeWhere(
          (ub) => (ub['bankCode']?.toString() ?? '').toUpperCase() == bankCode.toUpperCase(),
        );
        if (_selectedHierarchyBankCode.toUpperCase() == bankCode.toUpperCase()) {
          _selectedHierarchyBankCode = 'ALL';
        }
      });

      await _fetchCategoryHierarchy();
      await _fetchLiveDbCount();
      await SmsService.refreshSenders();
      _hideLoading();
      _showToast('$bankName has been unsynced and removed.');
    } catch (e) {
      _hideLoading();
      _showToast('Failed to unsync $bankName: $e', isError: true);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedPdfFile = result.files.first;
        _pdfParseResult = null;
        _extractorFlow = ExtractorFlowStep.uploadStatement;
      });
    }
  }

  Future<void> _parsePdf() async {
    if (_selectedPdfFile == null || _selectedPdfFile!.bytes == null) {
      _showToast('Please select a valid ${_selectedBank.nameEn} PDF statement', isError: true);
      return;
    }
    _showLoading('Parsing ${_selectedBank.nameEn} PDF layout & extracting transactions...');
    try {
      final res = await _apiService.parsePdfStatement(
        _selectedPdfFile!.bytes!,
        _selectedPdfFile!.name,
        bankCode: _selectedBank.code,
      );
      _hideLoading();
      setState(() {
        _pdfParseResult = BmpfParseResult.fromJson(res);
        _extractorFlow = ExtractorFlowStep.inspectData;
      });
      _showToast('Successfully extracted ${_pdfParseResult!.transactions.length} transactions for ${_selectedBank.nameEn}.');
    } catch (e) {
      _hideLoading();
      _showToast('Failed to parse statement: $e', isError: true);
    }
  }

  Future<void> _confirmPdfImport() async {
    if (_pdfParseResult == null) return;
    _showLoading('Processing ${_selectedBank.nameEn} statement transactions...');
    try {
      _currentUser ??= await AuthService.getUser();
      final payload = Map<String, dynamic>.from(_pdfParseResult!.rawJson);
      payload['bankCode'] = _selectedBank.code;
      payload['bankName'] = _selectedBank.nameEn;

      final success = await _apiService.confirmPdfImport(
        payload,
        userId: _currentUser?.id,
      );
      _hideLoading();
      if (success) {
        _showToast('${_selectedBank.nameEn} statement successfully imported! Redirecting to Categorization...');
        _fetchLiveDbCount();
        setState(() {
          _selectedPageIndex = 0;
        });
        _fetchCategoryHierarchy();
        if (!mounted) return;
        // Update URL path to /hierarchy or /categories
        Navigator.of(context).pushReplacementNamed('/categories');
      } else {
        _showToast('Statement import failed.', isError: true);
      }
    } catch (e) {
      _hideLoading();
      _showToast('Import error: $e', isError: true);
    }
  }

  // ============================================================
  // CATEGORY HIERARCHY METHODS & MULTI-BANK FILTERING
  // ============================================================
  LocalBank? _findBankByCode(String code) {
    try {
      return _localBanks.firstWhere(
        (b) => b.code.toUpperCase() == code.toUpperCase(),
        orElse: () => _localBanks.first,
      );
    } catch (_) {
      return _localBanks.first;
    }
  }

  DateTime? _parseTxDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(dateStr.trim());
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
    final parts = dateStr.trim().split(RegExp(r'[/.-]'));
    if (parts.length >= 3) {
      try {
        int p0 = int.parse(parts[0]);
        int p1 = int.parse(parts[1]);
        int p2 = int.parse(parts[2].split(' ').first);
        if (p0 > 1900) {
          return DateTime(p0, p1, p2);
        } else {
          final yearFull = p2 < 100 ? (2000 + p2) : p2;
          return DateTime(yearFull, p1, p0);
        }
      } catch (_) {}
    }
    return null;
  }

  DateTime? _parseTxDateTime(String? dateStr, [String? rawMessage]) {
    DateTime? parsed;
    if (dateStr != null && dateStr.trim().isNotEmpty) {
      parsed = DateTime.tryParse(dateStr.trim());
      if (parsed == null) {
        final parts = dateStr.trim().split(RegExp(r'[/.-]'));
        if (parts.length >= 3) {
          try {
            final p0 = int.parse(parts[0]);
            final p1 = int.parse(parts[1]);
            final p2Rest = parts[2].trim().split(RegExp(r'\s+'));
            final p2 = int.parse(p2Rest.first);
            int hr = 0, min = 0, sec = 0;
            if (p2Rest.length > 1) {
              final tParts = p2Rest[1].split(':');
              if (tParts.length >= 2) {
                hr = int.tryParse(tParts[0]) ?? 0;
                min = int.tryParse(tParts[1]) ?? 0;
                if (tParts.length >= 3) sec = int.tryParse(tParts[2]) ?? 0;
              }
            }
            if (p0 > 1900) {
              parsed = DateTime(p0, p1, p2, hr, min, sec);
            } else {
              final yearFull = p2 < 100 ? (2000 + p2) : p2;
              parsed = DateTime(yearFull, p1, p0, hr, min, sec);
            }
          } catch (_) {}
        }
      }
    }

    // If parsed time is 00:00:00 (or date was missing) and rawMessage contains an explicit timestamp ("on 29/10/2026 22:56:45"), extract it
    if ((parsed == null || (parsed.hour == 0 && parsed.minute == 0 && parsed.second == 0)) &&
        rawMessage != null &&
        rawMessage.isNotEmpty) {
      final m = RegExp(
        r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
      ).firstMatch(rawMessage);
      if (m != null) {
        final d = int.tryParse(m.group(1)!) ?? 1;
        final mo = int.tryParse(m.group(2)!) ?? 1;
        final yrRaw = int.tryParse(m.group(3)!) ?? 2026;
        final yr = yrRaw < 100 ? 2000 + yrRaw : yrRaw;
        final hr = int.tryParse(m.group(4)!) ?? 0;
        final mi = int.tryParse(m.group(5)!) ?? 0;
        final sc = int.tryParse(m.group(6) ?? '0') ?? 0;
        try {
          return DateTime(yr, mo, d, hr, mi, sc);
        } catch (_) {}
      }
    }

    return parsed ?? _parseTxDate(dateStr);
  }

  String _formatTxDateTime(BmpfTransaction tx, {bool includeSeconds = false}) {
    final dt = _parseTxDateTime(tx.postDate ?? tx.valueDate, tx.originalMessage ?? tx.narration);
    if (dt == null) return tx.postDate ?? '--';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hasTime = dt.hour != 0 || dt.minute != 0 || dt.second != 0;
    if (!hasTime) {
      // Check if raw postDate string explicitly had a non-zero time or if we should still show time when present in string
      final raw = tx.postDate ?? '';
      if (!raw.contains(':')) return '$y-$m-$d';
    }
    final periodEn = dt.hour >= 12 ? 'PM' : 'AM';
    final periodAr = dt.hour >= 12 ? 'م' : 'ص';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final hh = hour12.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    final timePart = includeSeconds && dt.second != 0
        ? '$hh:$mm:$ss ${LanguageService.isArabic ? periodAr : periodEn}'
        : '$hh:$mm ${LanguageService.isArabic ? periodAr : periodEn}';
    return '$y-$m-$d • $timePart';
  }

  int _compareTransactionsNewToOld(BmpfTransaction a, BmpfTransaction b) {
    final dtA = _parseTxDateTime(a.postDate ?? a.valueDate, a.originalMessage ?? a.narration);
    final dtB = _parseTxDateTime(b.postDate ?? b.valueDate, b.originalMessage ?? b.narration);
    if (dtA == null && dtB == null) return 0;
    if (dtA == null) return 1;
    if (dtB == null) return -1;
    return dtB.compareTo(dtA);
  }

  /// Returns the uppercase bank codes of all available cards shown in the carousel.
  Set<String> get _availableBankCodes {
    final codes = <String>{};
    for (final ub in _userUploadedBanks) {
      final code = (ub['bankCode']?.toString() ?? '').toUpperCase().trim();
      if (code.isNotEmpty && code != 'ALL') codes.add(code);
    }
    for (final cat in _rawCategories) {
      for (final tx in cat.transactions) {
        final code = tx.bankCode.toUpperCase().trim();
        if (code.isNotEmpty && code != 'ALL') codes.add(code);
      }
    }
    for (final code in _selectedBankCodes) {
      final upper = code.toUpperCase().trim();
      if (upper.isNotEmpty && upper != 'ALL') codes.add(upper);
    }
    return codes;
  }

  /// Checks whether a transaction's bankCode matches the active bank selection ('ALL' = sum of all available cards).
  bool _matchesSelectedBank(String txBankCode) {
    final filterBank = _selectedHierarchyBankCode.toUpperCase();
    final txCode = txBankCode.toUpperCase().trim();
    if (filterBank == 'ALL') {
      final available = _availableBankCodes;
      return available.isEmpty || available.contains(txCode);
    }
    return txCode == filterBank;
  }

  DateTime get _referenceTxDate {
    DateTime? latest;
    for (final cat in _rawCategories) {
      for (final tx in cat.transactions) {
        if (!_matchesSelectedBank(tx.bankCode)) continue;
        final d = _parseTxDate(tx.postDate);
        if (d != null && (latest == null || d.isAfter(latest))) {
          latest = d;
        }
      }
    }
    return latest ?? DateTime.now();
  }

  /// Returns the latest transaction date for a specific bank code (used so each bank card's active period is included when 'ALL' is selected).
  DateTime _referenceTxDateForBank(String bankCode) {
    final target = bankCode.toUpperCase().trim();
    DateTime? latest;
    for (final cat in _rawCategories) {
      for (final tx in cat.transactions) {
        if (tx.bankCode.toUpperCase().trim() != target) continue;
        final d = _parseTxDate(tx.postDate);
        if (d != null && (latest == null || d.isAfter(latest))) {
          latest = d;
        }
      }
    }
    return latest ?? _referenceTxDate;
  }

  /// Checks whether a transaction falls within the active time period ('DAY', 'WEEK', 'MONTH')
  /// relative to its reference date (each bank's latest date when 'ALL' is selected so all available cards sum together,
  /// or the selected bank's latest date when a single card is selected).
  bool _matchesTimePeriod(BmpfTransaction tx, {String? forBankCode}) {
    final period = _selectedTimePeriod;
    final txDate = _parseTxDate(tx.postDate);
    if (txDate == null) return period == 'MONTH';

    final isAll = (forBankCode ?? _selectedHierarchyBankCode).toUpperCase() == 'ALL';
    final refDate = isAll ? _referenceTxDateForBank(tx.bankCode) : _referenceTxDate;

    if (period == 'DAY') {
      return txDate.year == refDate.year &&
          txDate.month == refDate.month &&
          txDate.day == refDate.day;
    } else if (period == 'WEEK') {
      final diffDays = refDate.difference(txDate).inDays;
      return diffDays >= 0 && diffDays < 7;
    } else {
      return txDate.year == refDate.year && txDate.month == refDate.month;
    }
  }

  void _applyFilters() {
    if (_rawCategories.isEmpty) return;

    _categories = _rawCategories
        .map((node) {
          final filteredTx = node.transactions.where((t) {
            // Bank filter ("ALL" = sum of all available bank cards)
            if (!_matchesSelectedBank(t.bankCode)) {
              return false;
            }
            return _matchesTimePeriod(t);
          }).toList()
            ..sort(_compareTransactionsNewToOld);

          return BmpfCategoryNode(
            id: node.id,
            name: node.name,
            icon: node.icon,
            color: node.color,
            displayOrder: node.displayOrder,
            isEnabled: node.isEnabled,
            children: node.children,
            totalAmount: filteredTx.fold(0.0, (sum, t) => sum + t.amount),
            txnCount: filteredTx.length,
            transactions: filteredTx,
          );
        })
        .where((node) => node.txnCount > 0 && node.transactions.isNotEmpty)
        .toList();
    _budgetController.syncWithHierarchyCategories(
      _rawCategories,
      activePeriodNodes: _categories,
    );
  }

  void _applyBankFilter() => _applyFilters();

  void _onSelectHierarchyBank(String bankCode) {
    setState(() {
      _selectedHierarchyBankCode = bankCode;
      _selectedCategoryIndex = null;
      _applyFilters();
    });

    if (bankCode != 'ALL') {
      final bankMatches = _localBanks.where((b) => b.code.toUpperCase() == bankCode.toUpperCase());
      final bankName = bankMatches.isNotEmpty ? bankMatches.first.nameEn : bankCode;
      _apiService.saveUserBankSelection(
        bankCode: bankCode,
        bankName: bankName,
        userId: _currentUser?.id,
        email: _currentUser?.email,
      ).then((_) => SmsService.refreshSenders());
    }
  }

  Future<void> _fetchCategoryHierarchy() async {
    setState(() => _isLoadingCategories = true);
    try {
      final rawNodes = await _apiService.getCategoryHierarchy();
      final stats = await _apiService.getCategoryStats(userId: _currentUser?.id);
      final userBanksRaw = await _apiService.getUserBanks(userId: _currentUser?.id);

      final nodes = rawNodes
          .map((e) => BmpfCategoryNode.fromJson(e as Map<String, dynamic>))
          .where((n) => n.isEnabled)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Build stats lookup: categoryName -> stats data
      final statsMap = <String, Map<String, dynamic>>{};
      for (final s in stats) {
        if (s is Map<String, dynamic>) {
          final catName = (s['categoryName']?.toString() ?? '').toLowerCase().trim();
          statsMap[catName] = s;
        }
      }

      // Aggregate transaction totals & count per category using the live database engine
      for (final node in nodes) {
        final catKey = node.name.toLowerCase().trim();
        final statData = statsMap[catKey];

        if (statData != null) {
          final txListRaw = statData['transactions'] as List? ?? [];
          node.transactions = txListRaw.map((t) {
            final tMap = t as Map<String, dynamic>;
            final amt = (tMap['amount'] as num?)?.toDouble() ?? 0.0;
            final cleanDesc = tMap['generatedDescription']?.toString() ?? tMap['narration']?.toString() ?? 'Transaction';
            final rawOrig = tMap['originalMessage']?.toString() ?? tMap['narration']?.toString();
            return BmpfTransaction(
              narration: cleanDesc,
              originalMessage: rawOrig,
              amount: amt,
              direction: (tMap['transactionType']?.toString() ?? 'DEBIT').toUpperCase(),
              category: node.name,
              subcategory: tMap['subcategory']?.toString(),
              currency: tMap['currency']?.toString() ?? 'OMR',
              balance: (tMap['balanceAfter'] as num?)?.toDouble(),
              postDate: tMap['transactionDate']?.toString(),
              matchedMerchant: tMap['matchedKeyword']?.toString(),
              counterpartyName: tMap['counterpartyName']?.toString(),
              accountNumberMasked: tMap['accountNumberMasked']?.toString(),
              transactionReference: tMap['transactionReference']?.toString(),
              transactionTypeCode: tMap['transactionTypeCode']?.toString(),
              confidence: (tMap['confidenceScore'] as num?)?.toInt() ?? 100,
              bankCode: tMap['bankCode']?.toString() ?? 'BANK_MUSCAT',
              bankName: tMap['bankName']?.toString() ?? 'Bank Muscat',
            );
          }).toList()
            ..sort(_compareTransactionsNewToOld);

          node.txnCount = node.transactions.length;
          node.totalAmount = node.transactions.fold(0.0, (sum, t) => sum + t.amount);
        } else {
          node.txnCount = 0;
          node.totalAmount = 0.0;
          node.transactions = [];
        }
      }

      // Convert user uploaded banks list
      final detectedBanks = <Map<String, dynamic>>[];
      for (final b in userBanksRaw) {
        if (b is Map<String, dynamic>) {
          detectedBanks.add(b);
        }
      }

      // If userBanks endpoint was empty, derive dynamically from transactions
      if (detectedBanks.isEmpty) {
        final bankMap = <String, Map<String, dynamic>>{};
        for (final node in nodes) {
          for (final tx in node.transactions) {
            final code = tx.bankCode;
            if (!bankMap.containsKey(code)) {
              bankMap[code] = {
                'bankCode': code,
                'bankName': tx.bankName,
                'txCount': 0,
                'totalSpent': 0.0,
              };
            }
            bankMap[code]!['txCount'] = (bankMap[code]!['txCount'] as int) + 1;
            bankMap[code]!['totalSpent'] = (bankMap[code]!['totalSpent'] as double) + tx.amount;
          }
        }
        detectedBanks.addAll(bankMap.values);
      }

      if (mounted) {
        setState(() {
          _rawCategories = nodes;
          _userUploadedBanks = detectedBanks;
          _applyBankFilter();
          _budgetController.syncWithHierarchyCategories(
            _rawCategories,
            activePeriodNodes: _categories,
          );
          _isLoadingCategories = false;
        });
      }
      _apiService.getBudgetOverview(
        userId: _currentUser?.id,
        email: _currentUser?.email,
      ).then((overview) {
        if (mounted && overview.isNotEmpty) {
          _budgetController.applyServerOverview(overview);
          setState(() {});
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        _showToast('Failed to load categories: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.notifier,
      builder: (context, lang, _) {
        return Directionality(
          textDirection: LanguageService.textDirection,
          child: Scaffold(
            backgroundColor: _selectedPageIndex == 3
                ? Colors.white
                : const Color(0xFFF8FAFC),
            appBar: _buildAppBar(),
            body: Stack(
              children: [
                // Main Scrollable Page Content
                Positioned.fill(
                  child: _buildCurrentPage(),
                ),

                // Floating Bottom Navigation Bar (Centered & Compact like Image 2)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: SafeArea(
                    child: Center(
                      child: _buildFloatingBottomNavBar(),
                    ),
                  ),
                ),

                if (_isLoading) _buildLoadingOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Image.asset(
              'assets/themarip_logo_transparent.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.auto_awesome_rounded, size: 24, color: Color(0xFF7C3AED)),
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              children: [
                TextSpan(
                  text: 'Themar ',
                  style: TextStyle(color: Color(0xFF0F172A)),
                ),
                TextSpan(
                  text: 'IP',
                  style: TextStyle(color: Color(0xFF7C3AED)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_currentUser != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: const Color(0xFF7C3AED),
                child: Text(
                  _currentUser!.fullName.isNotEmpty ? _currentUser!.fullName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              label: Text(
                _currentUser!.fullName.isNotEmpty ? _currentUser!.fullName : _currentUser!.email,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFF1F5F9),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ] else ...[
          TextButton.icon(
            icon: const Icon(Icons.login, size: 16, color: Color(0xFF7C3AED)),
            label: const Text('Sign In', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.of(context).pushNamed('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE2E8F0))),
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('Security & Data Privacy', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'ThemarIP protects your personal financial analytics with bank-grade security and strict data privacy.',
              style: TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '• 256-bit AES Bank-Grade Encryption\n• Read-only statement extraction\n• No online banking passwords or debit PINs required\n• Tailored multi-bank layout parsing for all Omani banks',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.55),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showIosShortcutsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      ),
    );

    Map<String, dynamic>? config;
    try {
      config = await ApiService().getShortcutsConfig();
    } catch (e) {
      debugPrint('Failed to load shortcuts config: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final endpoint = config?['endpoint']?.toString() ?? 'https://themarip.up.railway.app/api/sms/ingest';
    final apiKey = config?['apiKey']?.toString() ?? (await AuthService.getToken() ?? '');
    final bearerToken = config?['bearerToken']?.toString() ?? (apiKey.isNotEmpty ? 'Bearer $apiKey' : '');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFFE2E8F0)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'iOS SMS Shortcuts Setup',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Use Apple Shortcuts on iPhone to automatically forward your bank transaction SMS directly to Themar.',
                style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),

              // Step 1: Endpoint & API Key
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. INGEST URL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0284C7), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            endpoint,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0284C7)),
                          tooltip: 'Copy URL',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: endpoint));
                            _showToast('API Endpoint copied to clipboard!');
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 16),
                    const Text('2. AUTHORIZATION HEADER VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0284C7), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            apiKey.isNotEmpty ? 'Bearer ${apiKey.substring(0, math.min(16, apiKey.length))}••••••••' : 'Sign in to generate key',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0284C7)),
                          tooltip: 'Copy Bearer Token',
                          onPressed: () {
                            if (apiKey.isEmpty) return;
                            Clipboard.setData(ClipboardData(text: bearerToken));
                            _showToast('Authorization header copied (with Bearer)!');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Instructions in Shortcuts app
              const Text(
                'How to configure Shortcuts in 3 minutes:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              _buildShortcutStep('1', 'Open "Shortcuts" App', 'Go to the "Automation" tab at the bottom and tap "+".'),
              _buildShortcutStep('2', 'Select "Message" Trigger', 'Sender: Choose your bank (e.g. BankMuscat). Select "Run Immediately" and turn off "Notify When Run".'),
              _buildShortcutStep('3', 'Add "Get Contents of URL"', 'Set Method to POST. Paste the Ingest URL above.'),
              _buildShortcutStep('4', 'Add Headers & JSON Body', 'Headers:\n• Authorization: Bearer <Your API Key>\n• Content-Type: application/json\n\nRequest Body (JSON):\n• sender (Text) -> Choose "Sender" variable\n• message (Text) -> Choose "Shortcut Input" (Message)'),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  final shortcutTemplate = 'URL: $endpoint\nMethod: POST\nHeader: Authorization: Bearer $apiKey\nHeader: Content-Type: application/json\nJSON Body:\n{\n  "sender": "<Bank Sender>",\n  "message": "<SMS Body Text>"\n}';
                  Clipboard.setData(ClipboardData(text: shortcutTemplate));
                  _showToast('Full Shortcut configuration copied!');
                },
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('Copy Complete Shortcut Template', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FLOATING BOTTOM NAVIGATION BAR (HIERARCHY • PROFILE)
  // ============================================================
  Widget _buildFloatingBottomNavBar() {
    final isHierarchy = _selectedPageIndex == 0;
    final isProfile = _selectedPageIndex == 1;

    return Container(
      width: 196,
      height: 66,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(33),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hierarchy Tab (Left)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_hasUploadedStatement) {
                  _showToast('Please upload your first bank statement to unlock Hierarchy analytics.');
                  return;
                }
                setState(() => _selectedPageIndex = 0);
                if (_categories.isEmpty) {
                  _fetchCategoryHierarchy();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isHierarchy
                      ? const Color(0xFF10B981).withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: isHierarchy
                      ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasUploadedStatement ? Icons.explore_rounded : Icons.lock_outline_rounded,
                      size: 20,
                      color: isHierarchy
                          ? const Color(0xFF059669)
                          : (_hasUploadedStatement ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      LanguageService.tr('Hierarchy', 'الفئات'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isHierarchy ? FontWeight.bold : FontWeight.w600,
                        color: isHierarchy
                            ? const Color(0xFF059669)
                            : (_hasUploadedStatement ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Profile Tab (Right)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPageIndex = 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isProfile
                      ? const Color(0xFF10B981).withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: isProfile
                      ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: isProfile ? const Color(0xFF059669) : const Color(0xFF475569),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      LanguageService.tr('Profile', 'حسابي'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isProfile ? FontWeight.bold : FontWeight.w600,
                        color: isProfile ? const Color(0xFF059669) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedPageIndex) {
      case 0:
        return _buildCategoriesPage();
      case 1:
        return _buildProfilePage();
      case 2:
        return _buildExtractorPage();
      case 3:
        return BudgetingFlowView(
          controller: _budgetController,
          onExitToHierarchy: () {
            setState(() => _selectedPageIndex = 0);
          },
          onBudgetStarted: (ctrl) async {
            // Optimistically activate budget locally so entered budget is never lost
            ctrl.markBudgetStarted();
            setState(() {});

            try {
              final result = await _apiService.saveBudgetSetup(
                userId: _currentUser?.id,
                email: _currentUser?.email,
                monthlyTotalOmr: ctrl.monthlyTotal,
                rollover: ctrl.rollover,
                categoryBudgetsOmr: ctrl.categoryBudgets,
              );
              if (result.isNotEmpty && result['hasConfiguredBudget'] == true) {
                ctrl.applyServerOverview(result);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageService.tr(
                        'Budget saved successfully to database',
                        'تم حفظ الميزانية بنجاح في قاعدة البيانات',
                      ),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            } catch (e) {
              final errorStr = e.toString().toLowerCase();
              final isNetworkError = errorStr.contains('socketexception') ||
                  errorStr.contains('failed host lookup') ||
                  errorStr.contains('connection error') ||
                  errorStr.contains('nodename') ||
                  errorStr.contains('network is unreachable') ||
                  errorStr.contains('timed out');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isNetworkError
                          ? LanguageService.tr(
                              'Budget saved locally. Server offline or unreachable (No internet). Changes will sync automatically.',
                              'تم حفظ الميزانية محلياً. لا يوجد اتصال بالإنترنت، ستتم المزامنة تلقائياً.',
                            )
                          : LanguageService.tr(
                              'Budget saved locally. Server sync pending.',
                              'تم حفظ الميزانية محلياً. في انتظار المزامنة مع الخادم.',
                            ),
                    ),
                    backgroundColor: const Color(0xFFF59E0B),
                    duration: const Duration(seconds: 4),
                  ),
                );
                setState(() {});
              }
            }
          },
        );
      default:
        return _buildCategoriesPage();
    }
  }

  // ============================================================
  // PAGE 3: USER PROFILE & SETTINGS
  // ============================================================
  Widget _buildProfilePage() {
    final user = _currentUser;
    final userName = (user?.fullName.isNotEmpty == true) ? user!.fullName : 'Turki';
    final userEmail = (user?.email.isNotEmpty == true) ? user!.email : 'turki@themar.om';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'T';

    // Combine uploaded banks and selected banks so all connected banks appear in Profile
    final profileBanks = <Map<String, dynamic>>[];
    final seenCodes = <String>{};
    for (final ub in _userUploadedBanks) {
      final code = (ub['bankCode']?.toString() ?? '').toUpperCase();
      if (code.isNotEmpty && code != 'ALL' && !seenCodes.contains(code)) {
        seenCodes.add(code);
        profileBanks.add(ub);
      }
    }
    for (final code in _selectedBankCodes) {
      final upper = code.toUpperCase();
      if (upper.isNotEmpty && upper != 'ALL' && !seenCodes.contains(upper)) {
        seenCodes.add(upper);
        final bankDef = _findBankByCode(upper);
        profileBanks.add({
          'bankCode': upper,
          'bankName': bankDef?.nameEn ?? upper,
          'txCount': 0,
          'totalSpent': 0.0,
        });
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Top Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Account Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Regulated financial identity & connected banks',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(LanguageService.tr('verified_badge'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // User Identity Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      userEmail,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Personal Account Tier 1',
                            style: TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Budgeting & Spending Targets (Moved from tool bar to Profile)
        _buildProfileBudgetCard(),
        const SizedBox(height: 24),

        // Connected Banks Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONNECTED BANK STATEMENTS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669), letterSpacing: 0.8),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPageIndex = 2;
                  _extractorFlow = ExtractorFlowStep.selectBank;
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF0284C7)),
              label: const Text('Add Bank', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // List of banks with Unsync action
        if (profileBanks.isNotEmpty)
          ...profileBanks.map((ub) {
            final bCode = ub['bankCode']?.toString() ?? '';
            final bankDef = _findBankByCode(bCode);
            final bName = ub['bankName']?.toString() ?? bankDef?.nameEn ?? bCode;
            final spent = (ub['totalSpent'] as num?)?.toDouble() ?? 0.0;
            final txCount = (ub['txCount'] as num?)?.toInt() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        bankDef?.logoAsset ?? 'assets/banks/bank_muscat.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(Icons.account_balance, color: Colors.black, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bName,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '$txCount transactions • ${spent.toStringAsFixed(3)} OMR',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Connected', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _confirmAndUnsyncBank(bCode, bName),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link_off_rounded, size: 13, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.tr('Unsync', 'إلغاء الربط'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          })
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No bank statements uploaded yet. Tap "Add Bank" to connect your first statement.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        if (SmsService.isSupported) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_smsPaused ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_smsPaused ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _smsPaused ? Icons.pause_circle_outline_rounded : Icons.sms_rounded,
                        size: 20,
                        color: _smsPaused ? const Color(0xFFD97706) : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bank SMS Auto-Listener',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            _smsPaused
                                ? 'Paused — App has stopped listening to SMS'
                                : 'Active — Automatically logging verified bank SMS',
                            style: TextStyle(
                              fontSize: 11,
                              color: _smsPaused ? const Color(0xFFD97706) : const Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: !_smsPaused,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (enabled) async {
                        final paused = !enabled;
                        setState(() => _smsPaused = paused);
                        await SmsService.setPaused(paused);
                        _showToast(
                          paused
                              ? 'SMS Auto-Listener paused. Stopped listening to incoming SMS.'
                              : 'SMS Auto-Listener resumed & synced!',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await SmsService.refreshSenders();
                      await _fetchCategoryHierarchy();
                      await _fetchLiveDbCount();
                      _showToast('SMS rules synced & queued messages flushed!');
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF0284C7)),
                    label: const Text(
                      'Sync Rules & Flush Queued SMS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (defaultTargetPlatform != TargetPlatform.android) ...[
          const SizedBox(height: 24),

          // iOS Shortcuts Automation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'iOS SMS Automation (Shortcuts)',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Forward incoming bank SMS to Themar automatically',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'iPhone users can use Apple Shortcuts Automation to read bank SMS and send them securely to Themar, just like Android.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showIosShortcutsDialog,
                    icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                    label: const Text('Setup iOS Shortcuts', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Language Selection Card (English Default + Arabic)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F6EF7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language_rounded, size: 20, color: Color(0xFF4F6EF7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.tr('app_language'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LanguageService.tr('language_desc'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LanguageSelectorPill(
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Security & Data Privacy Card (No CBO reference)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService.tr('security_privacy_title'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                LanguageService.tr('security_privacy_bullets'),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Sign Out Button
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
          label: Text(LanguageService.tr('sign_out'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),

        const Center(
          child: Text(
            'ThemarIP v2.5 • Financial Literacy & Wealth Intelligence',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE BUDGETING CARD (ACCESS BUDGET FROM PROFILE)
  // ============================================================
  Widget _buildProfileBudgetCard() {
    final hasBudget = _budgetController.hasConfiguredBudget;
    final totalBudget = _budgetController.monthlyTotal;
    final spentAmount = _budgetController.totalSpent;
    final remainingAmount = _budgetController.remainingTotal;
    final spendRatio = (totalBudget > 0 ? (spentAmount / totalBudget) : 0.0).clamp(0.0, 1.0);
    final isWarning = totalBudget > 0 && (spentAmount / totalBudget) > 0.8;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.pie_chart_rounded,
                  size: 22,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageService.tr('Budget & Spending Goals', 'الميزانية وأهداف الإنفاق'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasBudget
                          ? '${LanguageService.tr('Target', 'الهدف')}: ${BudgetConstants.formatOmr(totalBudget)} • ${LanguageService.tr('Spent', 'المصروف')}: ${BudgetConstants.formatOmr(spentAmount)}'
                          : LanguageService.tr('Set monthly limits & track thresholds', 'تحديد أهداف الميزانية الشهرية والتحكم بها'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(spendRatio * 100).toStringAsFixed(0)}% ${LanguageService.tr('used', 'مستخدمة')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? AppColors.pink : AppColors.mint,
                  ),
                ),
                Text(
                  '${BudgetConstants.formatOmr(remainingAmount)} ${LanguageService.tr('remaining', 'متبقي')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: spendRatio,
                minHeight: 6,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isWarning ? AppColors.pink : AppColors.mint,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  if (_budgetController.monthlyTotal <= 0) {
                    _budgetController.setMonthlyTotal(200.0);
                  }
                  _budgetController.setStep(hasBudget ? 1 : 0);
                  _selectedPageIndex = 3;
                });
              },
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: Text(
                hasBudget
                    ? LanguageService.tr('Manage & Re-setup Budget', 'إدارة الميزانية وإعادة الضبط')
                    : LanguageService.tr('Set Up Budgeting', 'إعداد الميزانية'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXTRACTOR CONTROLLER PAGE
  // ============================================================
  Widget _buildExtractorPage() {
    switch (_extractorFlow) {
      case ExtractorFlowStep.selectBank:
        return _buildBankListScreen();
      case ExtractorFlowStep.connectBank:
        return _buildConnectBankScreen();
      case ExtractorFlowStep.uploadStatement:
        return _buildStatementUploadScreen();
      case ExtractorFlowStep.inspectData:
        return _buildInspectionScreen();
    }
  }

  // ============================================================
  // SCREEN 1: SELECT PRIMARY BANK ACCOUNT (MATCHING IMAGE 1)
  // ============================================================
  Widget _buildBankListScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Top Row: Back button (if has statements) + Help button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasUploadedStatement)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF475569)),
                label: const Text('Back to Dashboard', style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: () {
                  setState(() {
                    _selectedPageIndex = 0;
                  });
                },
              )
            else
              const SizedBox.shrink(),
            TextButton(
              onPressed: _showHelpDialog,
              child: const Text(
                'Help',
                style: TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),

        // Headline
        const Text(
          'Select your primary\nbank account',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        const Text(
          'It\'s fast, secure and reliable to connect your bank',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 14),

        // Bank-Grade Security Trust Pill
        Row(
          children: const [
            Icon(Icons.shield_outlined, size: 16, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Protected with 256-bit bank-grade encryption & privacy',
                style: TextStyle(color: Color(0xFF7C3AED), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Search Input (Matching Image 1)
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _bankSearchController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  onChanged: (val) => setState(() => _bankSearchText = val),
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_bankSearchText.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _bankSearchText = '';
                      _bankSearchController.clear();
                    });
                  },
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // "Most popular" Section Header
        const Text(
          'Most popular',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 10),

        // Bank List Card Container (Matching Image 1)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBanks.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72, endIndent: 16, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                return InkWell(
                  onTap: () => _onSelectBank(bank),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _buildBankLogo(bank, size: 44, circular: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bank.nameEn,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${bank.nameAr} · ${bank.badgeText}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SCREEN 2: CONNECT TO BANK (MATCHING IMAGE 2)
  // ============================================================
  Widget _buildConnectBankScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Top Bar: Back Arrow on Left, Help on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () => setState(() => _extractorFlow = ExtractorFlowStep.selectBank),
            ),
            TextButton(
              onPressed: _showHelpDialog,
              child: const Text(
                'Help',
                style: TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Center Connection Graphic with Dashed Arc and Security Badge (Image 2)
        Center(
          child: SizedBox(
            width: 260,
            height: 140,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Curved Dashed Arc between the two cards
                Positioned(
                  top: 24,
                  child: CustomPaint(
                    size: const Size(220, 80),
                    painter: _DashedArcPainter(color: const Color(0xFF0284C7).withValues(alpha: 0.85)),
                  ),
                ),
                // Security Shield Badge at the center top of the arc
                Positioned(
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0284C7), width: 1.6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                  ),
                ),
                // Connected Cards: Bank Logo & ThemarIP Logo
                Positioned(
                  bottom: 0,
                  left: 10,
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        _selectedBank.logoAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _buildBankEmblemIcon(_selectedBank, 60),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 10,
                  child: SizedBox(
                    width: 94,
                    height: 94,
                    child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF7C3AED).withValues(alpha: 0.25),
                              const Color(0xFF06B6D4).withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: Image.asset(
                          'assets/themarip_logo_transparent.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.auto_awesome_rounded, size: 36, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Headline
        Text(
          'Connect to ${_selectedBank.nameEn}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),

        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'It\'ll take you securely to upload and extract your verified account statement. Just follow the on-screen instructions.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.45),
          ),
        ),
        const SizedBox(height: 24),

        // Security & Encryption Verification Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.security_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'Your data is encrypted & safe',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• Protected with 256-bit AES bank-grade encryption.\n• Read-only statement extraction — your online banking passwords and debit PINs are never requested.\n• Tailored multi-bank financial intelligence for Omani accounts.',
                style: TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // How to download bank statement guide (Requirement 2)
        _buildBankStatementGuide(_selectedBank),
        const SizedBox(height: 28),

        // Big Purple Continue Button (Matching Image 2)
        ElevatedButton(
          onPressed: () => _confirmBankSelectionAndProceed(_selectedBank),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            elevation: 3,
          ),
          child: const Text(
            'Continue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildBankStatementGuide(LocalBank bank) {
    final List<Map<String, String>> steps;
    if (bank.code == 'BANK_MUSCAT') {
      steps = [
        {'step': '1', 'title': 'Open mBanking App', 'desc': 'Log in to your Bank Muscat mobile banking application.'},
        {'step': '2', 'title': 'Select Account', 'desc': 'Tap your primary account and choose "Account Statement".'},
        {'step': '3', 'title': 'Download e-Statement', 'desc': 'Choose the statement date range and select "Download PDF".'},
        {'step': '4', 'title': 'Save & Upload', 'desc': 'Save the PDF to your device, then click "Continue" below to upload.'},
      ];
    } else if (bank.code == 'NBO') {
      steps = [
        {'step': '1', 'title': 'Open NBO App', 'desc': 'Log in to the National Bank of Oman mobile application.'},
        {'step': '2', 'title': 'View Statement', 'desc': 'Navigate to Accounts -> Select Account -> "Download e-Statement".'},
        {'step': '3', 'title': 'Select Period', 'desc': 'Pick your desired statement period (last 1-3 months).'},
        {'step': '4', 'title': 'Export & Continue', 'desc': 'Save the generated PDF on your device, then tap "Continue" below.'},
      ];
    } else {
      steps = [
        {'step': '1', 'title': 'Open Banking App', 'desc': 'Log in to your ${bank.nameEn} mobile app or online banking portal.'},
        {'step': '2', 'title': 'Navigate to Statements', 'desc': 'Go to Accounts -> Statements / e-Statements.'},
        {'step': '3', 'title': 'Download PDF', 'desc': 'Select your desired period and tap "Download / Export PDF".'},
        {'step': '4', 'title': 'Upload to ThemarIP', 'desc': 'Save the PDF file, then tap "Continue" below to extract your data.'},
      ];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to download your ${bank.shortName} statement',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Text(
                      'Follow these simple steps before continuing',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Text('Guide', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    s['step']!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['title']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(height: 1),
                      Text(s['desc']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ============================================================
  // SCREEN 3: UPLOAD STATEMENT PDF (TAILORED TO SELECTED BANK)
  // ============================================================
  Widget _buildStatementUploadScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Navigation bar
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _extractorFlow = ExtractorFlowStep.selectBank),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: const [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 4),
                    Text('Change Bank', style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _buildBankLogo(_selectedBank, size: 32, circular: true),
          ],
        ),
        const SizedBox(height: 16),

        // Bank Profile Header Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildBankLogo(_selectedBank, size: 48, circular: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _selectedBank.nameEn,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedBank.nameAr,
                          style: TextStyle(fontSize: 11.5, color: _selectedBank.primaryColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedBank.formatDescription,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Drag & Drop / Upload Zone
        InkWell(
          onTap: _pickPdf,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedPdfFile != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedPdfFile != null ? _selectedPdfFile!.name : 'Choose ${_selectedBank.nameEn} Statement',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedPdfFile != null
                      ? '${(_selectedPdfFile!.size / 1024).toStringAsFixed(1)} KB · Ready for extraction'
                      : 'Upload official account statement (.pdf)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedPdfFile != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(_selectedPdfFile != null ? 'Change File' : 'Browse Statement PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action CTA: Parse & Extract
        if (_selectedPdfFile != null) ...[
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _parsePdf,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              'Parse & Extract ${_selectedBank.shortName} Transactions',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // SCREEN 4: STATEMENT INSPECTION & CONFIRM (MATCHING STEP 3)
  // ============================================================
  Widget _buildInspectionScreen() {
    if (_pdfParseResult == null) return _buildStatementUploadScreen();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Top Row: Back to Upload & Bank Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => setState(() => _extractorFlow = ExtractorFlowStep.uploadStatement),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: const [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 4),
                    Text('Upload Another', style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _confirmPdfImport,
              icon: const Icon(Icons.cloud_done, size: 16),
              label: const Text('Save & Categorize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Metrics Grid
        Row(
          children: [
            _buildMetricBox('Total Extracted', '${_pdfParseResult!.transactions.length} txns', const Color(0xFF0F172A)),
            const SizedBox(width: 8),
            _buildMetricBox('Quality Score', '${_pdfParseResult!.extractionConfidence}% PASS', const Color(0xFF059669)),
            const SizedBox(width: 8),
            _buildMetricBox('Bank Target', _selectedBank.shortName, _selectedBank.primaryColor),
          ],
        ),
        const SizedBox(height: 18),

        // Extracted Transactions List
        const Text('Extracted Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        ...([..._pdfParseResult!.transactions]..sort(_compareTransactionsNewToOld)).map((tx) => _buildTransactionCard(tx)),
      ],
    );
  }

  // ============================================================
  // BANK LOGO WIDGET (USES OFFICIAL LOGO ASSETS)
  // ============================================================
  Widget _buildBankLogo(LocalBank bank, {double size = 42, bool circular = false}) {
    return buildBankLogoWidget(bank, size: size, circular: circular);
  }

  Widget _buildBankEmblemIcon(LocalBank bank, double size) {
    return buildBankEmblemIconWidget(bank, size);
  }

  Widget _buildMetricBox(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BmpfTransaction tx) {
    final isCredit = tx.direction == 'CREDIT';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !tx.isBalanceValid ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCredit ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.narration,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatTxDateTime(tx)} · ${tx.category}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(3)} OMR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? const Color(0xFF059669) : const Color(0xFFEF4444),
                ),
              ),
              if (tx.balance != null)
                Text(
                  'Bal: ${tx.balance!.toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MULTI-BANK HIERARCHY FILTER & SPENDING BEHAVIOR ANALYTICS
  // ============================================================
  // ============================================================
  // ============================================================
  // MULTI-BANK SOLID SATURATED CARDS & FILTER SYSTEM
  // ============================================================
  Widget _buildBankCardCarousel() {
    final List<Map<String, dynamic>> cardDataList = [];

    final bankCodesFound = <String>{};
    if (_userUploadedBanks.isNotEmpty) {
      for (final ub in _userUploadedBanks) {
        final code = ub['bankCode']?.toString() ?? '';
        if (code.isNotEmpty && code != 'ALL' && !bankCodesFound.contains(code)) {
          bankCodesFound.add(code);
          final bankDef = _findBankByCode(code);
          final spent = (ub['totalSpent'] as num?)?.toDouble() ?? 0.0;
          final txs = (ub['txCount'] as num?)?.toInt() ?? 0;
          cardDataList.add({
            'code': code,
            'name': ub['bankName']?.toString() ?? bankDef?.nameEn ?? code,
            'shortName': bankDef?.shortName ?? code,
            'txCount': txs,
            'totalSpent': spent,
            'logoAsset': bankDef?.logoAsset,
          });
        }
      }
    }

    // Also extract real banks from transactions if not yet listed
    final bankMap = <String, List<BmpfTransaction>>{};
    for (final cat in _rawCategories) {
      for (final tx in cat.transactions) {
        if (tx.bankCode.isNotEmpty && tx.bankCode != 'ALL') {
          bankMap.putIfAbsent(tx.bankCode, () => []).add(tx);
        }
      }
    }
    for (final entry in bankMap.entries) {
      final code = entry.key;
      if (!bankCodesFound.contains(code)) {
        bankCodesFound.add(code);
        final bankDef = _findBankByCode(code);
        final spent = entry.value.fold<double>(0.0, (sum, t) => sum + t.amount);
        cardDataList.add({
          'code': code,
          'name': bankDef?.nameEn ?? code,
          'shortName': bankDef?.shortName ?? code,
          'txCount': entry.value.length,
          'totalSpent': spent,
          'logoAsset': bankDef?.logoAsset,
        });
      }
    }

    if (_selectedBankCodes.isNotEmpty) {
      // Include all banks with uploaded statements/transactions PLUS any additional banks the user connected.
      final existingUpper = {for (final c in cardDataList) (c['code'] as String).toUpperCase()};
      for (final bank in _localBanks) {
        if (!_selectedBankCodes.any((sc) => sc.toUpperCase() == bank.code.toUpperCase())) continue;
        if (!existingUpper.contains(bank.code.toUpperCase())) {
          cardDataList.add({
            'code': bank.code,
            'name': bank.nameEn,
            'shortName': bank.shortName,
            'txCount': 0,
            'totalSpent': 0.0,
            'logoAsset': bank.logoAsset,
          });
        }
      }
    }
    // No default bank card: if the user selected nothing, only "All" and "Add" are shown.

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cardDataList.length + 2, // 1 for 'All' at start + 1 for 'Add' at end
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAllBankIconButton();
          } else if (index == cardDataList.length + 1) {
            return _buildAddBankIconButton();
          } else {
            return _buildRealBankCard(cardDataList[index - 1]);
          }
        },
      ),
    );
  }

  Widget _buildAllBankIconButton() {
    final isLit = _selectedHierarchyBankCode == 'ALL';
    return GestureDetector(
      onTap: () => _onSelectHierarchyBank('ALL'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 66,
        height: 104,
        decoration: BoxDecoration(
          color: isLit ? const Color(0xFF10B981).withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLit ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isLit ? 1.8 : 1.0,
          ),
          boxShadow: isLit
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: isLit ? const Color(0xFF059669) : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService.tr('All', 'الكل'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isLit ? FontWeight.bold : FontWeight.w600,
                color: isLit ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddBankIconButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPageIndex = 2;
          _extractorFlow = ExtractorFlowStep.selectBank;
        });
      },
      child: CustomPaint(
        painter: _DashedRoundedRectPainter(
          color: const Color(0xFF10B981),
          strokeWidth: 1.6,
          radius: 16,
          dashLength: 5,
          gapLength: 4,
        ),
        child: Container(
          width: 66,
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                color: Color(0xFF059669),
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                LanguageService.tr('Add', 'إضافة'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealBankCard(Map<String, dynamic> item) {
    final code = item['code'] as String;
    final rawName = item['name'] as String;
    final bankDef = _findBankByCode(code);
    final name = LanguageService.isArabic ? (bankDef?.nameAr ?? rawName) : (bankDef?.nameEn ?? rawName);
    final spent = item['totalSpent'] as double;
    final txCount = item['txCount'] as int;
    final theme = _getBankSolidTheme(code);
    final Color bgColor = theme['color'] as Color;
    final Color textColor = theme['textColor'] as Color;
    final bool isLight = theme['isLight'] as bool;
    final Color circle1 = theme['circle1'] as Color;
    final Color circle2 = theme['circle2'] as Color;

    final isAll = _selectedHierarchyBankCode == 'ALL';
    final isSelected = _selectedHierarchyBankCode.toUpperCase() == code.toUpperCase();
    final double cardOpacity = (isAll || isSelected) ? 1.0 : 0.35;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: cardOpacity,
      child: GestureDetector(
        onTap: () {
          if (isSelected) {
            // Tap it again to return to all
            _onSelectHierarchyBank('ALL');
          } else {
            // Filter to this bank
            _onSelectHierarchyBank(code);
          }
        },
        onLongPress: () => _confirmAndUnsyncBank(code, name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 240,
          height: 104,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: isSelected ? Border.all(color: const Color(0xFF0F172A), width: 2.2) : null,
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: isSelected ? 0.45 : 0.22),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Top-right decorative bubble circle
                Positioned(
                  right: -15,
                  top: -20,
                  child: Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circle1,
                    ),
                  ),
                ),
                // Bottom-right decorative bubble circle
                Positioned(
                  right: 25,
                  bottom: -32,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circle2,
                    ),
                  ),
                ),
                // Card Inner Contents
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Bank Name on Left, Unsync + Bank Emblem Icon on Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: LanguageService.tr('Unsync Bank', 'إلغاء ربط البنك'),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _confirmAndUnsyncBank(code, name),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isLight
                                          ? Colors.black.withValues(alpha: 0.12)
                                          : Colors.white.withValues(alpha: 0.24),
                                    ),
                                    child: Icon(
                                      Icons.link_off_rounded,
                                      size: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLight
                                      ? Colors.black.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.22),
                                ),
                                child: Icon(
                                  Icons.account_balance_outlined,
                                  size: 15,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Bottom Row: Large Amount with Txns label beside it
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            spent.toStringAsFixed(3),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LanguageService.tr('OMR', 'ر.ع'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textColor.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LanguageService.isArabic ? '• $txCount عملية' : '• $txCount Txns',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: textColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getBankSolidTheme(String code) {
    final upper = code.toUpperCase();
    if (upper.contains('MUSCAT')) {
      return {
        'color': const Color(0xFFFF486E), // Hot coral
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.18),
        'circle2': Colors.black.withValues(alpha: 0.10),
      };
    } else if (upper.contains('DHOFAR')) {
      return {
        'color': const Color(0xFFFFC038), // Warm golden yellow
        'isLight': true,
        'textColor': const Color(0xFF1A1A1A), // Dark text for yellow card
        'circle1': const Color(0xFFFFAE00).withValues(alpha: 0.35),
        'circle2': const Color(0xFFE09200).withValues(alpha: 0.25),
      };
    } else if (upper.contains('NBO')) {
      return {
        'color': const Color(0xFF0284C7), // Saturated cyan / royal blue
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.20),
        'circle2': Colors.black.withValues(alpha: 0.12),
      };
    } else if (upper.contains('SOHAR')) {
      return {
        'color': const Color(0xFFF97316), // Vivid orange
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.18),
        'circle2': Colors.black.withValues(alpha: 0.10),
      };
    } else if (upper.contains('AHLI')) {
      return {
        'color': const Color(0xFFBE123C), // Burgundy
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.18),
        'circle2': Colors.black.withValues(alpha: 0.10),
      };
    } else if (upper.contains('NIZWA')) {
      return {
        'color': const Color(0xFF059669), // Emerald
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.18),
        'circle2': Colors.black.withValues(alpha: 0.10),
      };
    } else if (upper.contains('OAB')) {
      return {
        'color': const Color(0xFF1D4ED8), // Cobalt
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.18),
        'circle2': Colors.black.withValues(alpha: 0.10),
      };
    } else {
      return {
        'color': const Color(0xFF8B5CF6), // Electric violet
        'isLight': false,
        'textColor': Colors.white,
        'circle1': Colors.white.withValues(alpha: 0.18),
        'circle2': Colors.black.withValues(alpha: 0.10),
      };
    }
  }

  void _onSelectTimePeriod(String period) {
    setState(() {
      _selectedTimePeriod = period;
      _selectedCategoryIndex = null;
      _applyFilters();
    });
  }

  Widget _buildMonthFilterBar() {
    final AlignmentGeometry activeAlign = _selectedTimePeriod == 'DAY'
        ? AlignmentDirectional.centerStart
        : (_selectedTimePeriod == 'WEEK'
            ? AlignmentDirectional.center
            : AlignmentDirectional.centerEnd);

    return Center(
      child: Container(
        width: 280,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            // Sliding White Pill Indicator
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: activeAlign,
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                heightFactor: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Day / Week / Month Interactive Labels
            Row(
              children: [
                _buildTimeSegmentItem(
                  key: 'DAY',
                  label: LanguageService.tr('Day', 'يوم'),
                ),
                _buildTimeSegmentItem(
                  key: 'WEEK',
                  label: LanguageService.tr('Week', 'أسبوع'),
                ),
                _buildTimeSegmentItem(
                  key: 'MONTH',
                  label: LanguageService.tr('Month', 'شهر'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSegmentItem({required String key, required String label}) {
    final isSelected = _selectedTimePeriod == key;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onSelectTimePeriod(key),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              letterSpacing: 0.1,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAGE 2: CATEGORY HIERARCHY TREE
  // ============================================================
  Widget _buildCategoriesPage() {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    }

    return ListenableBuilder(
      listenable: _budgetController,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LanguageService.tr('Category Hierarchy', 'تصنيف المصاريف والفئات'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                InkWell(
                  onTap: () {
                    _onSelectHierarchyBank('ALL');
                    _fetchCategoryHierarchy();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedHierarchyBankCode == 'ALL'
                          ? const Color(0xFF10B981).withValues(alpha: 0.14)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedHierarchyBankCode == 'ALL'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 14,
                          color: _selectedHierarchyBankCode == 'ALL' ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          LanguageService.tr('All Connected Banks', 'جميع البنوك المرتبطة'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _selectedHierarchyBankCode == 'ALL' ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Multi-Bank Card Carousel with Add (+) Button (Matching Image 3)
            _buildBankCardCarousel(),
            const SizedBox(height: 16),

            if (_rawCategories.isNotEmpty || _categories.isNotEmpty) ...[
              _buildCategoryPieChartCard(),
              const SizedBox(height: 20),
            ],

            if (_categories.isNotEmpty) ...[
              _buildCategoriesSectionHeader(),
              const SizedBox(height: 12),
            ],

            if (_categories.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Text(
                    LanguageService.tr(
                      'No categories found for this selection.',
                      'لا توجد فئات تحتوي على عمليات لهذا الاختيار.',
                    ),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ..._categories.asMap().entries.map((entry) => _buildCategoryNode(entry.value, index: entry.key)),

            const SizedBox(height: 110), // Padding for floating menu bar
          ],
        );
      },
    );
  }

  // ============================================================
  // CATEGORIES SECTION HEADER (WITH QUICK "MANAGE ▶" BUDGET ACCESS)
  // ============================================================
  Widget _buildCategoriesSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            LanguageService.tr('Categories', 'الفئات'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                if (_budgetController.monthlyTotal <= 0) {
                  _budgetController.setMonthlyTotal(200.0);
                }
                _budgetController.setStep(1); // Set to Category Budgets Screen (Attachment 1)
                _selectedPageIndex = 3;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LanguageService.tr('Manage', 'إدارة'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7B2FF7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.flip(
                    flipX: LanguageService.isArabic,
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 15,
                      color: Color(0xFF7B2FF7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAID IN AND SPENT BAR CHART CARD (MATCHING ATTACHED 2)
  // ============================================================
  Widget _buildCategoryPieChartCard() {
    double totalPaidIn = 0.0;
    double totalSpent = 0.0;

    for (final cat in _categories) {
      final isIncomeCategory = cat.name.toLowerCase() == 'income';
      if (cat.transactions.isNotEmpty) {
        for (final tx in cat.transactions) {
          final isCredit = tx.direction.toUpperCase() == 'CREDIT' ||
              isIncomeCategory ||
              (tx.narration.toLowerCase().contains('has been credited') &&
                  !tx.narration.toLowerCase().contains('is debited'));
          if (isCredit) {
            totalPaidIn += tx.amount;
          } else {
            totalSpent += tx.amount;
          }
        }
      } else if (cat.totalAmount > 0) {
        if (isIncomeCategory) {
          totalPaidIn += cat.totalAmount;
        } else {
          totalSpent += cat.totalAmount;
        }
      }
    }

    const double chartHeight = 182.0;
    final double maxVal = math.max(totalPaidIn, totalSpent);
    final double paidInHeight = maxVal > 0
        ? (totalPaidIn > 0 ? math.max(18.0, (totalPaidIn / maxVal) * (chartHeight - 16)) : 12.0)
        : 12.0;
    final double spentHeight = maxVal > 0
        ? (totalSpent > 0 ? math.max(18.0, (totalSpent / maxVal) * (chartHeight - 16)) : 12.0)
        : 12.0;

    return Stack(
      children: [
    Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      child: Column(
        children: [
          Text(
            LanguageService.tr('Paid in and spent', 'الإيداعات والمصروفات'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          // Day / Week / Month 4-D Glass Switcher inside "Paid in and spent" Bar Chart Card
          _buildMonthFilterBar(),
          const SizedBox(height: 24),

          // Dashed Horizontal Grid + Two 4-D Volumetric Bars (flips to heatmap)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: _buildFlipTransition,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              children: [...previous, ?current],
            ),
            child: _showPaidSpentHeatmap
                ? SizedBox(
                    key: const ValueKey('paid_spent_heatmap'),
                    height: chartHeight,
                    width: double.infinity,
                    child: _buildPaidSpentHeatmap(),
                  )
                : SizedBox(
            key: const ValueKey('paid_spent_bars'),
            height: chartHeight,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PaidInSpentGridPainter(),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Center(
                        child: _build4DBar(
                          targetHeight: paidInHeight,
                          maxHeight: chartHeight,
                          isGreen: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _build4DBar(
                          targetHeight: spentHeight,
                          maxHeight: chartHeight,
                          isGreen: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 18),

          // Labels & Totals Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Total paid in
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF34D399), Color(0xFF046C4E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          LanguageService.tr('Total paid in', 'إجمالي الإيداعات'),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildFormattedAmountText(totalPaidIn, isPositive: true),
                  ],
                ),
              ),

              // Right: Total spent
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFF9B5E), Color(0xFFF26A1B)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF26A1B).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          LanguageService.tr('Total spent', 'إجمالي المصروفات'),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildFormattedAmountText(totalSpent, isPositive: false),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
        PositionedDirectional(
          top: 12,
          end: 12,
          child: _buildHeatmapToggleButton(),
        ),
      ],
    );
  }

  // ============================================================
  // HEATMAP TOGGLE (FIRE ICON) + FLIP + SPEND/INCOME HEATMAP
  // ============================================================
  Widget _buildHeatmapToggleButton() {
    final active = _showPaidSpentHeatmap;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showPaidSpentHeatmap = !_showPaidSpentHeatmap);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF9B5E), Color(0xFFF26A1B)],
                )
              : null,
          color: active ? null : const Color(0xFFFFF4EC),
          border: Border.all(
            color: active ? Colors.transparent : const Color(0xFFFFD9C2),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF26A1B).withValues(alpha: active ? 0.35 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(
            active ? Icons.bar_chart_rounded : Icons.local_fire_department_rounded,
            key: ValueKey(active),
            size: 22,
            color: active ? Colors.white : const Color(0xFFF26A1B),
          ),
        ),
      ),
    );
  }

  Widget _buildFlipTransition(Widget child, Animation<double> animation) {
    final rotate = Tween<double>(begin: math.pi, end: 0.0).animate(animation);
    return AnimatedBuilder(
      animation: rotate,
      child: child,
      builder: (context, child) {
        final isIncoming = child?.key == ValueKey(_showPaidSpentHeatmap
            ? 'paid_spent_heatmap'
            : 'paid_spent_bars');
        var angle = rotate.value;
        // Hide the back face of each side during the flip.
        if (angle > math.pi / 2) {
          return const SizedBox.shrink();
        }
        if (!isIncoming) angle = -angle;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: child,
        );
      },
    );
  }

  Widget _buildPaidSpentHeatmap() {
    final refDate = _referenceTxDate;
    final refDay = DateTime(refDate.year, refDate.month, refDate.day);
    final isMonth = _selectedTimePeriod != 'DAY' && _selectedTimePeriod != 'WEEK';

    // Build the list of days covered by the heatmap.
    final List<DateTime> days = [];
    if (isMonth) {
      final daysInMonth = DateTime(refDay.year, refDay.month + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        days.add(DateTime(refDay.year, refDay.month, d));
      }
    } else {
      for (int i = 6; i >= 0; i--) {
        days.add(refDay.subtract(Duration(days: i)));
      }
    }

    final Map<DateTime, double> paidIn = {};
    final Map<DateTime, double> spent = {};
    for (final cat in _rawCategories) {
      final isIncomeCategory = cat.name.toLowerCase() == 'income';
      for (final tx in cat.transactions) {
        if (!_matchesSelectedBank(tx.bankCode)) continue;
        final d = _parseTxDate(tx.postDate);
        if (d == null) continue;
        // When 'ALL' is selected in Month mode, align each bank card's active month day-of-month
        // into the heatmap grid so all available bank cards sum together.
        DateTime key = DateTime(d.year, d.month, d.day);
        if (isMonth && _selectedHierarchyBankCode.toUpperCase() == 'ALL') {
          final bankRef = _referenceTxDateForBank(tx.bankCode);
          if (d.year == bankRef.year && d.month == bankRef.month) {
            final clampedDay = d.day.clamp(1, days.length);
            key = DateTime(refDay.year, refDay.month, clampedDay);
          }
        }
        final isCredit = tx.direction.toUpperCase() == 'CREDIT' ||
            isIncomeCategory ||
            (tx.narration.toLowerCase().contains('has been credited') &&
                !tx.narration.toLowerCase().contains('is debited'));
        if (isCredit) {
          paidIn[key] = (paidIn[key] ?? 0) + tx.amount;
        } else {
          spent[key] = (spent[key] ?? 0) + tx.amount;
        }
      }
    }

    double maxIn = 0, maxOut = 0;
    for (final d in days) {
      maxIn = math.max(maxIn, paidIn[d] ?? 0);
      maxOut = math.max(maxOut, spent[d] ?? 0);
    }

    Widget cell(DateTime day, {required double height}) {
      final inVal = paidIn[day] ?? 0;
      final outVal = spent[day] ?? 0;
      final inT = maxIn > 0 ? (inVal / maxIn).clamp(0.0, 1.0) : 0.0;
      final outT = maxOut > 0 ? (outVal / maxOut).clamp(0.0, 1.0) : 0.0;
      final isRef = day == refDay;
      Color shade(Color base, double t) => t <= 0
          ? const Color(0xFFF1F5F9)
          : Color.lerp(base.withValues(alpha: 0.18), base, 0.25 + 0.75 * t)!;
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isRef ? const Color(0xFF0F172A) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: Container(color: shade(const Color(0xFF10B981), inT))),
                  Expanded(child: Container(color: shade(const Color(0xFFF26A1B), outT))),
                ],
              ),
              Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: (inT > 0.55 || outT > 0.55)
                        ? Colors.white
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    const gap = 5.0;
    final weekdayLabels = isMonth
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : days
            .map((d) => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1])
            .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Arrange into rows of 7.
        final List<List<DateTime?>> rows = [];
        if (isMonth) {
          final leading = days.first.weekday - 1;
          final cells = <DateTime?>[
            ...List<DateTime?>.filled(leading, null),
            ...days,
          ];
          while (cells.length % 7 != 0) {
            cells.add(null);
          }
          for (int i = 0; i < cells.length; i += 7) {
            rows.add(cells.sublist(i, i + 7));
          }
        } else {
          rows.add(days);
        }

        const labelHeight = 16.0;
        final available = constraints.maxHeight - labelHeight - gap;
        final cellHeight = isMonth
            ? (available - gap * (rows.length - 1)) / rows.length
            : math.min(available, 90.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: labelHeight,
              child: Row(
                children: [
                  for (int i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: Center(
                        child: Text(
                          weekdayLabels[i],
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: gap),
            for (int r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              Row(
                children: [
                  for (int i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: rows[r][i] == null
                          ? SizedBox(height: cellHeight)
                          : cell(rows[r][i]!, height: cellHeight),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _build4DBar({
    required double targetHeight,
    required double maxHeight,
    required bool isGreen,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 14.0, end: targetHeight),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, animatedHeight, _) {
        final safeHeight = animatedHeight.clamp(14.0, maxHeight);
        return SizedBox(
          width: 124,
          height: maxHeight,
          child: CustomPaint(
            painter: _Bar4DPainter(
              barHeight: safeHeight,
              isGreen: isGreen,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormattedAmountText(double amount, {required bool isPositive}) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intRaw = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '00';
    final intFormatted = intRaw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF0F172A)),
        children: [
          if (isPositive)
            const TextSpan(
              text: '+ ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          TextSpan(
            text: LanguageService.tr('OMR ', 'ر.ع '),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: intFormatted,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
          TextSpan(
            text: '.$decPart',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _resolveAdminCategoryColor(BmpfCategoryNode node) {
    final nameLower = node.name.toLowerCase().trim();
    if (node.color.startsWith('#') && node.color.toUpperCase() != '#7C3AED') {
      try {
        return Color(int.parse(node.color.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    if (nameLower.contains('food') || nameLower.contains('grocer') || nameLower.contains('restaur') || nameLower.contains('coffee')) {
      return const Color(0xFF10B981); // Admin Portal Food: #10B981
    } else if (nameLower.contains('transport') || nameLower.contains('fuel') || nameLower.contains('car') || nameLower.contains('taxi')) {
      return const Color(0xFF3B82F6); // Admin Portal Transport: #3B82F6
    } else if (nameLower.contains('shop') || nameLower.contains('cloth') || nameLower.contains('electr')) {
      return const Color(0xFF8B5CF6); // Admin Portal Shopping: #8B5CF6
    } else if (nameLower.contains('bill') || nameLower.contains('util') || nameLower.contains('telecom') || nameLower.contains('water') || nameLower.contains('electr')) {
      return const Color(0xFFF59E0B); // Admin Portal Bills & Utilities: #F59E0B
    } else if (nameLower.contains('entertain') || nameLower.contains('stream') || nameLower.contains('game') || nameLower.contains('movie')) {
      return const Color(0xFFEC4899); // Admin Portal Entertainment: #EC4899
    } else if (nameLower.contains('health') || nameLower.contains('pharm') || nameLower.contains('hospital') || nameLower.contains('doctor')) {
      return const Color(0xFFF43F5E); // Admin Portal Health: #F43F5E
    } else if (nameLower.contains('travel') || nameLower.contains('flight') || nameLower.contains('hotel')) {
      return const Color(0xFF06B6D4); // Admin Portal Travel: #06B6D4
    } else if (nameLower.contains('income') || nameLower.contains('salary') || nameLower.contains('deposit')) {
      return const Color(0xFF059669); // Admin Portal Income: #34D399 / #059669
    } else if (nameLower.contains('transfer') || nameLower.contains('atm')) {
      return const Color(0xFF6366F1); // Transfers
    } else if (nameLower.contains('other') || nameLower.contains('uncategor')) {
      return const Color(0xFF64748B); // Admin Portal Other: #64748B
    }
    try {
      if (node.color.startsWith('#')) {
        return Color(int.parse(node.color.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}
    return const Color(0xFF7C3AED);
  }

  IconData _resolveAdminCategoryIcon(BmpfCategoryNode node) {
    final iconKey = node.icon.toLowerCase().trim();
    final nameLower = node.name.toLowerCase().trim();

    switch (iconKey) {
      case 'utensils':
      case 'food':
        return Icons.restaurant_rounded;
      case 'coffee':
        return Icons.coffee_rounded;
      case 'car':
      case 'transport':
        return Icons.directions_car_filled_rounded;
      case 'bike':
      case 'truck':
        return Icons.delivery_dining_rounded;
      case 'shopping-bag':
      case 'shopping-cart':
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'file-text':
      case 'receipt':
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'zap':
      case 'bolt':
      case 'utilities':
        return Icons.bolt_rounded;
      case 'wifi':
      case 'telecom':
      case 'phone':
        return Icons.wifi_rounded;
      case 'tv':
      case 'film':
      case 'entertainment':
        return Icons.live_tv_rounded;
      case 'heart-pulse':
      case 'heart':
      case 'health':
        return Icons.monitor_heart_rounded;
      case 'plane':
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'trending-up':
      case 'income':
      case 'wallet':
        return Icons.trending_up_rounded;
      case 'arrow-left-right':
      case 'repeat':
      case 'transfers':
        return Icons.swap_horiz_rounded;
      case 'briefcase':
      case 'work':
      case 'business':
        return Icons.work_rounded;
      case 'tag':
      case 'circle-help':
      case 'help-circle':
        return Icons.local_offer_rounded;
    }

    if (nameLower.contains('delivery')) return Icons.delivery_dining_rounded;
    if (nameLower.contains('coffee') || nameLower.contains('cafe')) return Icons.coffee_rounded;
    if (nameLower.contains('grocer') || nameLower.contains('supermarket')) return Icons.local_grocery_store_rounded;
    if (nameLower.contains('food') || nameLower.contains('restaur') || nameLower.contains('dining')) return Icons.restaurant_rounded;
    if (nameLower.contains('fuel') || nameLower.contains('petrol')) return Icons.local_gas_station_rounded;
    if (nameLower.contains('transport') || nameLower.contains('car') || nameLower.contains('taxi')) return Icons.directions_car_filled_rounded;
    if (nameLower.contains('shop') || nameLower.contains('cloth') || nameLower.contains('mall')) return Icons.shopping_bag_rounded;
    if (nameLower.contains('telecom') || nameLower.contains('wifi') || nameLower.contains('mobile')) return Icons.wifi_rounded;
    if (nameLower.contains('bill') || nameLower.contains('util') || nameLower.contains('electr') || nameLower.contains('water')) return Icons.receipt_long_rounded;
    if (nameLower.contains('entertain') || nameLower.contains('stream') || nameLower.contains('game') || nameLower.contains('movie')) return Icons.live_tv_rounded;
    if (nameLower.contains('health') || nameLower.contains('pharm') || nameLower.contains('doctor') || nameLower.contains('hospital')) return Icons.monitor_heart_rounded;
    if (nameLower.contains('travel') || nameLower.contains('flight') || nameLower.contains('hotel')) return Icons.flight_takeoff_rounded;
    if (nameLower.contains('income') || nameLower.contains('salary') || nameLower.contains('refund')) return Icons.trending_up_rounded;
    if (nameLower.contains('transfer') || nameLower.contains('atm') || nameLower.contains('saving')) return Icons.swap_horiz_rounded;
    if (nameLower.contains('business') || nameLower.contains('work')) return Icons.work_rounded;
    if (nameLower.contains('educat') || nameLower.contains('book') || nameLower.contains('school')) return Icons.school_rounded;
    return Icons.local_offer_rounded;
  }

  Widget _build4DCategoryIcon(BmpfCategoryNode node, Color catColor) {
    final iconData = _resolveAdminCategoryIcon(node);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        iconData,
        size: 20,
        color: catColor,
      ),
    );
  }

  String _localizedCategoryName(String name) {
    if (!LanguageService.isArabic) return name;
    final key = name.trim().toLowerCase();
    const map = <String, String>{
      'food': 'الطعام والمطاعم',
      'transport': 'المواصلات والوقود',
      'shopping': 'التسوق والمقاضي',
      'bills': 'الفواتير والخدمات',
      'bills & utilities': 'الفواتير والخدمات',
      'telecom': 'الاتصالات والإنترنت',
      'entertainment': 'الترفيه والاشتراكات',
      'health': 'الصحة والصيدليات',
      'income': 'الدخل والإيداعات',
      'transfers': 'التحويلات والسحب',
      'other': 'أخرى',
      'business': 'الأعمال',
      'travel': 'السفر',
      'food delivery': 'توصيل الطعام',
      'fast food': 'وجبات سريعة',
      'coffee shops': 'المقاهي والقهوة',
      'fuel': 'الوقود',
      'parking': 'مواقف السيارات',
      'taxi & ride': 'سيارات الأجرة',
      'groceries': 'المقاضي والسوبرماركت',
      'online shopping': 'التسوق الإلكتروني',
      'electricity': 'الكهرباء',
      'water': 'المياه',
      'internet': 'الإنترنت',
      'subscriptions': 'الاشتراكات',
      'mobile': 'الهاتف النقال',
      'landline': 'الهاتف الثابت',
      'streaming': 'البث الرقمي',
      'gaming': 'الألعاب',
      'events & cinema': 'السينما والفعاليات',
      'pharmacy': 'الصيدلية',
      'hospital & clinic': 'المستشفيات والعيادات',
      'fitness': 'اللياقة البدنية',
      'salary': 'الراتب',
      'freelance': 'إيداعات وأعمال حرة',
      'refund': 'استرداد نقدي',
      'investment': 'الاستثمار',
      'internal transfer': 'تحويل داخلي',
      'savings': 'الادخار',
      'atm withdrawal': 'سحب صراف آلي',
      'uncategorized': 'غير مصنف',
      'miscellaneous': 'متفرقات',
    };
    return map[key] ?? name;
  }

  Widget _buildCategoryNode(BmpfCategoryNode node, {int? index}) {
    final Color catColor = _resolveAdminCategoryColor(node);

    final isExpanded = _expandedCategoryIds.contains(node.id);
    final isSelectedFromChart = index != null && _selectedCategoryIndex == index;

    // Budget reflection: P1_BaseBaisa (configured budget) vs P1_FinalSpentBaisa (node.totalAmount)
    final isIncomeOrTransfer = node.name.toLowerCase() == 'income' ||
        node.name.toLowerCase() == 'transfers';
    final bool hasCategoryBudget = !isIncomeOrTransfer &&
        _budgetController.hasBudgetForCategory(node.name);
    final double baseBudgetOmr = hasCategoryBudget
        ? _budgetController.budgetForCategory(node.name)
        : 0.0;
    final double spentOmr = node.totalAmount;
    final int baseBaisa = (baseBudgetOmr * 1000).round();
    final int spentBaisa = (spentOmr * 1000).round();
    final int remainingBaisa = baseBaisa - spentBaisa;
    final double remainingOmr = remainingBaisa / 1000.0;
    final bool isOverBudget = hasCategoryBudget && remainingBaisa < 0;
    final double spendRatio = hasCategoryBudget && baseBudgetOmr > 0
        ? (spentOmr / baseBudgetOmr).clamp(0.0, 1.0)
        : 0.0;
    final bool isWarningOrOver =
        hasCategoryBudget && (spentOmr / baseBudgetOmr) > 0.85;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelectedFromChart ? catColor : const Color(0xFFE2E8F0),
          width: isSelectedFromChart ? 2.0 : 1.0,
        ),
        boxShadow: isSelectedFromChart
            ? [
                BoxShadow(
                  color: catColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Header Row
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategoryIds.remove(node.id);
                } else {
                  _expandedCategoryIds.add(node.id);
                  if (index != null) _selectedCategoryIndex = index;
                }
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _build4DCategoryIcon(node, catColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _localizedCategoryName(node.name),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${node.totalAmount.toStringAsFixed(3)} ${LanguageService.tr('OMR', 'ر.ع')}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: node.totalAmount > 0
                                  ? catColor
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            node.txnCount > 0
                                ? (LanguageService.isArabic
                                    ? '${node.txnCount} عملية'
                                    : '${node.txnCount} txns')
                                : LanguageService.tr('No txns', 'لا توجد عمليات'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                  if (hasCategoryBudget) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOverBudget
                              ? '${remainingOmr.abs().toStringAsFixed(3)} ${LanguageService.tr('OMR over budget', 'ر.ع تجاوز الميزانية')} (${baseBudgetOmr.toStringAsFixed(3)} ${LanguageService.tr('OMR budget', 'ر.ع ميزانية')})'
                              : '${remainingOmr.toStringAsFixed(3)} ${LanguageService.tr('OMR left of', 'ر.ع متبقي من')} ${baseBudgetOmr.toStringAsFixed(3)} ${LanguageService.tr('OMR', 'ر.ع')}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isWarningOrOver
                                ? AppColors.pink
                                : AppColors.mint,
                          ),
                        ),
                        Text(
                          '${((spentOmr / baseBudgetOmr) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isWarningOrOver
                                ? AppColors.pink
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: spendRatio,
                        minHeight: 6,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isWarningOrOver ? AppColors.pink : AppColors.mint,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded Associated Transactions
          if (isExpanded) ...[
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.all(12),
              child: node.transactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          LanguageService.tr(
                            'No transactions categorized here yet.',
                            'لا توجد عمليات مصنفة في هذه الفئة بعد.',
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.isArabic
                              ? 'العمليات (${node.transactions.length})'
                              : 'Transactions (${node.transactions.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        ...([...node.transactions]..sort(_compareTransactionsNewToOld)).map((tx) {
                          final bankDef = _findBankByCode(tx.bankCode);
                          final isCredit = tx.direction.toUpperCase() == 'CREDIT' ||
                              node.name.toLowerCase() == 'income' ||
                              (tx.narration.toLowerCase().contains('has been credited') &&
                                  !tx.narration.toLowerCase().contains('is debited'));
                          final displayBankName = LanguageService.isArabic
                              ? (bankDef?.nameAr ?? tx.bankName)
                              : (bankDef?.nameEn ?? tx.bankName);
                          return InkWell(
                            onTap: () => _showTransactionDetailsSheet(tx, displayBankName, isCredit),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    margin: const EdgeInsetsDirectional.only(end: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: ClipOval(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Image.asset(
                                          bankDef?.logoAsset ?? 'assets/banks/bank_muscat.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => Center(
                                            child: Text(
                                              bankDef?.shortName ?? 'BM',
                                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.narration,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$displayBankName • ${_formatTxDateTime(tx)}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(3)} ${LanguageService.tr('OMR', 'ر.ع')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isCredit ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTransactionDetailsSheet(BmpfTransaction tx, String displayBankName, bool isCredit) {
    final rawMessage = tx.originalMessage ?? tx.narration;
    final dateTimeStr = _formatTxDateTime(tx, includeSeconds: true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: LanguageService.textDirection,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tx.narration,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(3)} ${LanguageService.tr('OMR', 'ر.ع')}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isCredit ? const Color(0xFF059669) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildTxDetailRow(LanguageService.tr('Bank', 'البنك'), displayBankName),
                    _buildTxDetailRow(
                      LanguageService.tr('Direction', 'النوع'),
                      isCredit ? LanguageService.tr('Incoming (Credit)', 'وارد (إيداع)') : LanguageService.tr('Outgoing (Debit)', 'صادر (خصم)'),
                    ),
                    if (tx.counterpartyName != null && tx.counterpartyName!.isNotEmpty)
                      _buildTxDetailRow(LanguageService.tr('Party / Merchant', 'الجهة / التاجر'), tx.counterpartyName!),
                    if (tx.accountNumberMasked != null && tx.accountNumberMasked!.isNotEmpty)
                      _buildTxDetailRow(LanguageService.tr('Account / Card', 'الحساب / البطاقة'), tx.accountNumberMasked!),
                    if (tx.transactionReference != null && tx.transactionReference!.isNotEmpty)
                      _buildTxDetailRow(LanguageService.tr('Reference', 'المرجع'), tx.transactionReference!),
                    _buildTxDetailRow(LanguageService.tr('Date & Time', 'التاريخ والوقت'), dateTimeStr),
                    _buildTxDetailRow(LanguageService.tr('Confidence', 'دقة التحليل'), '${tx.confidence}%'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                LanguageService.tr('Original Bank Message', 'رسالة البنك الأصلية'),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SelectableText(
                  rawMessage,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontFamily: 'monospace', height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTxDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAID IN AND SPENT DASHED GRID & 4-D VOLUMETRIC BAR PAINTERS
// ============================================================
class _PaidInSpentGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const int lineCount = 4;
    const double dashWidth = 4.0;
    const double dashSpace = 4.0;

    for (int i = 0; i < lineCount; i++) {
      final double y = (size.height / (lineCount - 1)) * i;
      double startX = 0.0;
      while (startX < size.width) {
        final double endX = math.min(startX + dashWidth, size.width);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Bar4DPainter extends CustomPainter {
  final double barHeight;
  final bool isGreen;

  _Bar4DPainter({
    required this.barHeight,
    required this.isGreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double barWidth = 116.0;
    const double topRadius = 24.0;
    final double centerX = size.width / 2;
    final double left = centerX - (barWidth / 2);
    final double right = centerX + (barWidth / 2);
    final double bottomY = size.height;
    final double topY = (size.height - barHeight).clamp(4.0, size.height - 14.0);

    final Rect rect = Rect.fromLTRB(left, topY, right, bottomY);
    final RRect barRRect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(topRadius),
      topRight: const Radius.circular(topRadius),
      bottomLeft: Radius.zero,
      bottomRight: Radius.zero,
    );

    final Color shadowColor = isGreen ? const Color(0xFF059669) : const Color(0xFFF26A1B);

    // 1. Soft 3D Ambient Shadow behind the thick bar
    canvas.save();
    final shadowPaint = Paint()
      ..color = shadowColor.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.translate(3, 2);
    canvas.drawRRect(barRRect, shadowPaint);
    canvas.restore();

    // 2. Main Thick Rounded-Top Bar with Soft 3D Horizontal Pillow Shading (matching attached image)
    final List<Color> horizontalColors = isGreen
        ? const [
            Color(0xFF6EE7B7), // Soft bright left bevel edge
            Color(0xFF10B981), // Fresh emerald body
            Color(0xFF059669), // Rich emerald core
            Color(0xFF10B981), // Smooth right edge
          ]
        : const [
            Color(0xFFFFA873), // Soft bright left bevel edge
            Color(0xFFF26A1B), // Core #f26a1b
            Color(0xFFDE580B), // Rich deep orange shading
            Color(0xFFF26A1B), // Smooth right edge (#f26a1b)
          ];

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: horizontalColors,
        stops: const [0.0, 0.22, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRRect(barRRect, bodyPaint);

    // 3. Soft Top-Edge 3D Pillow Highlight (smooth inner glow along top curve like attached image)
    canvas.save();
    canvas.clipRRect(barRRect);
    final topGlowRect = Rect.fromLTWH(left, topY, barWidth, math.min(28.0, bottomY - topY));
    final topGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(topGlowRect);
    canvas.drawRect(topGlowRect, topGlowPaint);

    // 4. Soft Left-Edge Inner Bevel Highlight
    final leftGlowRect = Rect.fromLTWH(left, topY, 22.0, bottomY - topY);
    final leftGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.26),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(leftGlowRect);
    canvas.drawRect(leftGlowRect, leftGlowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Bar4DPainter oldDelegate) =>
      oldDelegate.barHeight != barHeight || oldDelegate.isGreen != isGreen;
}

class DashedArcPainter extends CustomPainter {
  final Color color;
  DashedArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, -size.height * 0.35, size.width, size.height);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 6.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 6.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedArcPainter extends DashedArcPainter {
  _DashedArcPainter({required super.color});
}

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gapLength;

  _DashedRoundedRectPainter({
    required this.color,
    this.strokeWidth = 1.6,
    this.radius = 16.0,
    this.dashLength = 5.0,
    this.gapLength = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}
