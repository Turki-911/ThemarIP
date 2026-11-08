import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/bank_setup_service.dart';
import '../services/language_service.dart';
import '../services/sms_service.dart';
import 'bmpf_main_screen.dart';

/// Shown after onboarding/sign-in:
/// Step 1: User selects which bank or wallet to connect from the list.
/// Step 2: Confirmation / "Connect to Bank" screen (matching the exact connection UI with security badges & guide).
/// User taps "Continue" to confirm selection and proceed to the dashboard.
class BankSetupScreen extends StatefulWidget {
  const BankSetupScreen({super.key});

  @override
  State<BankSetupScreen> createState() => _BankSetupScreenState();
}

class _BankSetupScreenState extends State<BankSetupScreen> {
  final ApiService _apiService = ApiService();
  final Set<String> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _isSaving = false;

  // Step state: false = bank list selection, true = confirm "Connect to Bank" screen
  bool _showingConnectConfirmation = false;
  LocalBank? _pendingSelectedBank;

  @override
  void initState() {
    super.initState();
    BankSetupService.getSelectedBanks().then((codes) async {
      if (!mounted) return;
      if (codes.isNotEmpty) {
        setState(() => _selected.addAll(codes));
        return;
      }
      // Existing users: pre-check banks already linked to their account on the server.
      final serverBanks = await _apiService.getUserBanks();
      final known = kLocalBanks.map((b) => b.code).toSet();
      final preset = serverBanks
          .whereType<Map>()
          .map((b) => b['bankCode']?.toString().toUpperCase() ?? '')
          .where(known.contains);
      if (mounted && preset.isNotEmpty) setState(() => _selected.addAll(preset));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocalBank> get _filteredBanks {
    if (_searchText.trim().isEmpty) return kLocalBanks;
    final q = _searchText.toLowerCase();
    return kLocalBanks.where((b) {
      return b.nameEn.toLowerCase().contains(q) ||
          b.nameAr.contains(q) ||
          b.shortName.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q);
    }).toList();
  }

  void _onSelectBankFromList(LocalBank bank) {
    setState(() {
      _selected.clear();
      _selected.add(bank.code);
      _pendingSelectedBank = bank;
      _showingConnectConfirmation = true;
    });
  }

  Future<void> _finish({bool skip = false}) async {
    setState(() => _isSaving = true);
    final codes = skip
        ? <String>[]
        : kLocalBanks.where((b) => _selected.contains(b.code)).map((b) => b.code).toList();

    await BankSetupService.saveSelection(codes);

    // Register each selected bank with the backend (enables its SMS rule for this user).
    await Future.wait(codes.map((code) {
      final bank = kLocalBanks.firstWhere((b) => b.code == code);
      return _apiService.saveUserBankSelection(bankCode: bank.code, bankName: bank.nameEn);
    }));
    await SmsService.refreshSenders();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/categories');
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Connecting Your Bank', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: const Text(
          'Select the bank or digital wallet where you receive transaction notifications. '
          'ThemarIP reads only transaction SMS & statement PDFs using bank-grade 256-bit encryption. '
          'Your banking credentials and passwords are never requested or stored.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.notifier,
      builder: (context, lang, _) {
        final isAr = LanguageService.isArabic;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                child: _showingConnectConfirmation && _pendingSelectedBank != null
                    ? _buildConnectBankConfirmationScreen(_pendingSelectedBank!, isAr)
                    : _buildBankListScreen(isAr),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // STEP 1: SELECT PRIMARY BANK ACCOUNT
  // ============================================================
  Widget _buildBankListScreen(bool isAr) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Top Row: Skip button on End, Help button on Start/End
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _showHelpDialog,
              child: Text(
                LanguageService.tr('Help', 'مساعدة'),
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _isSaving ? null : () => _finish(skip: true),
              child: Text(
                LanguageService.tr('Skip for now', 'تخطي الآن'),
                style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Headline
        Text(
          LanguageService.tr(
            'Select your primary\nbank account',
            'اختر حسابك البنكي\nالرئيسي أو المحفظة',
          ),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          LanguageService.tr(
            "It's fast, secure and reliable to connect your bank",
            'ربط حسابك البنكي سريع وآمن وموثوق تماماً',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 14),

        // Bank-Grade Security Trust Pill
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LanguageService.tr(
                  'Protected with 256-bit bank-grade encryption & privacy',
                  'محمي بتشفير بنكي فائق الأمان 256-bit وخصوصية تامة',
                ),
                style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
                  controller: _searchController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  onChanged: (val) => setState(() => _searchText = val),
                  decoration: InputDecoration(
                    hintText: LanguageService.tr('Search', 'بحث'),
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchText.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchText = '';
                      _searchController.clear();
                    });
                  },
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // "Most popular" Section Header
        Text(
          LanguageService.tr('Most popular', 'الأكثر استخداماً'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),

        // Bank List Container (Matching Image 1 exactly)
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
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: Color(0xFFE2E8F0),
              ),
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                final isSelected = _selected.contains(bank.code);
                return InkWell(
                  onTap: () => _onSelectBankFromList(bank),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        buildBankLogoWidget(bank, size: 44, circular: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? bank.nameAr : bank.nameEn,
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
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF94A3B8),
                          size: 22,
                        ),
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
  // STEP 2: CONNECT TO BANK CONFIRMATION (MATCHING IMAGE 2)
  // ============================================================
  Widget _buildConnectBankConfirmationScreen(LocalBank bank, bool isAr) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        // Top Bar: Back Arrow on Left, Help on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () => setState(() => _showingConnectConfirmation = false),
            ),
            TextButton(
              onPressed: _showHelpDialog,
              child: Text(
                LanguageService.tr('Help', 'مساعدة'),
                style: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600),
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
                    painter: DashedArcPainter(color: const Color(0xFF0284C7).withValues(alpha: 0.85)),
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
                        bank.logoAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => buildBankEmblemIconWidget(bank, 60),
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
          isAr ? 'الربط مع ${bank.nameAr}' : 'Connect to ${bank.nameEn}',
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
            LanguageService.tr(
              "It'll take you securely to upload and extract your verified account statement. Just follow the on-screen instructions.",
              'سيتم توجيهك بأمان لرفع وتحليل كشف حسابك المعتمد ومطابقة إشعاراتك البنكية. اتبع التعليمات البسيطة أدناه.',
            ),
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
                children: [
                  const Icon(Icons.security_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService.tr('Your data is encrypted & safe', 'بياناتك مشفرة وآمنة تماماً'),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                LanguageService.tr(
                  '• Protected with 256-bit AES bank-grade encryption.\n• Read-only statement extraction — your online banking passwords and debit PINs are never requested.\n• Tailored multi-bank financial intelligence for Omani accounts.',
                  '• محمي بتشفير بنكي معتمد AES 256-bit.\n• استخراج كشوفات وإشعارات فقط — لا نطلب كلمة سر حسابك أو رقم PIN أبداً.\n• ذكاء مالي مخصص للحسابات والمحافظ البنكية العُمانية.',
                ),
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // How to download bank statement guide
        _buildBankStatementGuide(bank, isAr),
        const SizedBox(height: 28),

        // Big Purple Continue Button (Matching Image 2)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : () => _finish(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
              elevation: 3,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(
                    LanguageService.tr('Continue', 'متابعة'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankStatementGuide(LocalBank bank, bool isAr) {
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
}
