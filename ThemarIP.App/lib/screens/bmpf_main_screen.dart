import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../config/app_theme.dart';
import '../models/bmpf_models.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
  });
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
    badgeText: 'Active / Sandbox',
    defaultIcon: Icons.sailing,
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
  ),
];

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

  // Page switcher: 0 = Ingestion/Extractor (/upload), 1 = Category Hierarchy (/hierarchy or /categories)
  int _selectedPageIndex = 0;

  // Selected Local Bank for statement parsing format
  LocalBank _selectedBank = _localBanks[0];

  UserModel? _currentUser;
  int _dbTxCount = 0;
  bool _isLoading = false;
  String _loadingMessage = '';

  // 1. PDF State
  PlatformFile? _selectedPdfFile;
  BmpfParseResult? _pdfParseResult;

  // Category Hierarchy State
  List<BmpfCategoryNode> _categories = [];
  bool _isLoadingCategories = false;
  final Set<String> _expandedCategoryIds = {};
  int? _selectedCategoryIndex;

  @override
  void initState() {
    super.initState();
    _selectedPageIndex = widget.initialPageIndex;
    _loadUser();
    _fetchLiveDbCount();
    if (_selectedPageIndex == 1) {
      _fetchCategoryHierarchy();
    }
  }

  @override
  void didUpdateWidget(covariant BmpfMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPageIndex != widget.initialPageIndex) {
      setState(() {
        _selectedPageIndex = widget.initialPageIndex;
      });
      if (_selectedPageIndex == 1) {
        _fetchCategoryHierarchy();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (mounted) {
      setState(() => _currentUser = user);
      _fetchLiveDbCount();
    }
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
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
    if (_selectedBank.code == bank.code) return;
    setState(() {
      _selectedBank = bank;
      _pdfParseResult = null; // Reset previous parse for new bank format
    });
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
          _selectedPageIndex = 1;
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
  // CATEGORY HIERARCHY METHODS
  // ============================================================
  Future<void> _fetchCategoryHierarchy() async {
    setState(() => _isLoadingCategories = true);
    try {
      final rawNodes = await _apiService.getCategoryHierarchy();
      final stats = await _apiService.getCategoryStats(userId: _currentUser?.id);

      final nodes = rawNodes.map((e) => BmpfCategoryNode.fromJson(e as Map<String, dynamic>)).toList();

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
          node.txnCount = (statData['txnCount'] as num?)?.toInt() ?? 0;
          final txListRaw = statData['transactions'] as List? ?? [];
          node.transactions = txListRaw.map((t) {
            final tMap = t as Map<String, dynamic>;
            final amt = (tMap['amount'] as num?)?.toDouble() ?? 0.0;
            return BmpfTransaction(
              narration: tMap['narration']?.toString() ?? 'Transaction',
              amount: amt,
              direction: (tMap['transactionType']?.toString() ?? 'DEBIT').toUpperCase(),
              category: node.name,
              subcategory: tMap['subcategory']?.toString(),
              currency: tMap['currency']?.toString() ?? 'OMR',
              balance: (tMap['balanceAfter'] as num?)?.toDouble(),
              postDate: tMap['transactionDate']?.toString(),
              matchedMerchant: tMap['matchedKeyword']?.toString(),
            );
          }).toList();

          node.totalAmount = node.transactions.fold(0.0, (sum, t) => sum + t.amount);
        } else {
          node.txnCount = 0;
          node.totalAmount = 0.0;
          node.transactions = [];
        }
      }

      if (mounted) {
        setState(() {
          _categories = nodes;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        _showToast('Failed to load categories: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: _selectedPageIndex == 0 ? _buildExtractorPage() : _buildCategoriesPage(),
              ),
            ],
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF121824),
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.description, size: 20, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'THEMAR PFM',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MULTI-BANK EXTRACTOR',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _selectedBank.primaryColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _selectedBank.accentColor.withValues(alpha: 0.7), width: 0.8),
                    ),
                    child: Text(
                      _selectedBank.shortName,
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: _selectedBank.accentColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_currentUser != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 6),
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
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF1E293B),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 19, color: Color(0xFF94A3B8)),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ] else ...[
          TextButton.icon(
            icon: const Icon(Icons.login, size: 16, color: Color(0xFF7C3AED)),
            label: const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.of(context).pushNamed('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      color: const Color(0xFF121824),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildPageTab(
                  index: 0,
                  label: 'Extractor',
                  icon: Icons.file_copy_outlined,
                  route: '/upload',
                ),
                const SizedBox(width: 8),
                _buildPageTab(
                  index: 1,
                  label: 'Hierarchy',
                  icon: Icons.account_tree_outlined,
                  route: '/categories',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTab({
    required int index,
    required String label,
    required IconData icon,
    required String route,
  }) {
    final isSelected = _selectedPageIndex == index;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGE 1: EXTRACTOR / INGESTION (PDF | LOCAL BANK SELECTION)
  // ============================================================
  Widget _buildExtractorPage() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Title & Description Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.document_scanner_rounded, size: 26, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Bank Statement Extractor',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select your local bank in Oman to configure the specialized parsing layout, then upload your official PDF account statement.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Step 1: Select Local Bank
        _buildBankSelectionSection(),

        const SizedBox(height: 28),

        // Step 2: Upload Statement PDF for selected bank
        _buildPdfSourceSection(),
      ],
    );
  }

  // 1. BANK SELECTION UI (LOCAL BANKS IN OMAN)
  Widget _buildBankSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance, color: Color(0xFF60A5FA), size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              '1. Select Local Bank (Oman)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                '${_localBanks.length} Banks Available',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose the bank that issued your statement to apply specialized format parsing & column rules.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final int crossAxisCount;
            final double childAspectRatio;
            if (constraints.maxWidth > 900) {
              crossAxisCount = 4;
              childAspectRatio = 1.7;
            } else if (constraints.maxWidth > 600) {
              crossAxisCount = 3;
              childAspectRatio = 1.55;
            } else {
              crossAxisCount = 2;
              childAspectRatio = 1.25;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localBanks.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                return _buildBankCard(_localBanks[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBankCard(LocalBank bank) {
    final isSelected = _selectedBank.code == bank.code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onSelectBank(bank),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? bank.primaryColor.withValues(alpha: 0.16)
                : const Color(0xFF151D2C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? bank.primaryColor
                  : const Color(0xFF26324A),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: bank.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Logo + Selected badge / status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBankLogo(bank, size: 38),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: bank.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: bank.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        bank.shortName,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Bank Name in English & Arabic
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.nameEn,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bank.nameAr,
                    style: TextStyle(
                      color: isSelected ? bank.accentColor : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Format tag
              Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 11,
                    color: isSelected ? bank.accentColor : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      bank.badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isSelected ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildBankLogo(LocalBank bank, {double size = 42}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bank.primaryColor,
            bank.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: bank.accentColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bank.primaryColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: _buildBankEmblemIcon(bank, size),
      ),
    );
  }

  Widget _buildBankEmblemIcon(LocalBank bank, double size) {
    switch (bank.code) {
      case 'BANK_MUSCAT':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, color: bank.accentColor, size: size * 0.42),
            Text(
              'BM',
              style: TextStyle(
                color: Colors.white,
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
            Icon(Icons.sailing_rounded, color: bank.accentColor, size: size * 0.42),
            Text(
              'NBO',
              style: TextStyle(
                color: bank.accentColor,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.22,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        );
      case 'BANK_DHOFAR':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waves, color: bank.accentColor, size: size * 0.42),
            Text(
              'BD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.22,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
          ],
        );
      case 'OAB':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, color: Colors.white, size: size * 0.42),
            Text(
              'OAB',
              style: TextStyle(
                color: bank.accentColor,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.22,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        );
      case 'SOHAR_INTL':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.diamond_outlined, color: Colors.white, size: size * 0.42),
            Text(
              'SI',
              style: TextStyle(
                color: bank.accentColor,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.20,
                letterSpacing: -0.2,
                height: 1.0,
              ),
            ),
          ],
        );
      case 'AHLI_BANK':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, color: bank.accentColor, size: size * 0.42),
            Text(
              'AB',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.20,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        );
      case 'BANK_NIZWA':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: bank.accentColor, size: size * 0.42),
            Text(
              'BN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.20,
                letterSpacing: -0.2,
                height: 1.0,
              ),
            ),
          ],
        );
      case 'ALIZZ_ISLAMIC':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, color: bank.accentColor, size: size * 0.42),
            Text(
              'AIB',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.18,
                letterSpacing: -0.2,
                height: 1.0,
              ),
            ),
          ],
        );
      default:
        return Icon(bank.defaultIcon, color: Colors.white, size: size * 0.45);
    }
  }

  // 2. PDF SOURCE UI (TAILORED TO SELECTED BANK)
  Widget _buildPdfSourceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _selectedBank.primaryColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.cloud_upload_outlined, color: _selectedBank.accentColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '2. Upload ${_selectedBank.nameEn} Statement',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          color: const Color(0xFF121824),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _selectedBank.primaryColor.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Selected Bank Header Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182234),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF26324A)),
                  ),
                  child: Row(
                    children: [
                      _buildBankLogo(_selectedBank, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedBank.nameEn,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedBank.nameAr,
                                  style: TextStyle(fontSize: 11, color: _selectedBank.accentColor, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _selectedBank.formatDescription,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedBank.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _selectedBank.primaryColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _selectedBank.badgeText,
                          style: TextStyle(
                            color: _selectedBank.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Icon(Icons.upload_file_rounded, size: 46, color: _selectedBank.accentColor),
                const SizedBox(height: 10),
                Text(
                  'Select ${_selectedBank.nameEn} Statement PDF',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload official ${_selectedBank.nameEn} multi-page statement (.pdf) for automated extraction.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.file_open, size: 18),
                  label: Text(_selectedPdfFile != null ? 'Change File' : 'Choose ${_selectedBank.shortName} PDF File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedBank.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_selectedPdfFile != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPdfFile!.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Target Format: ${_selectedBank.nameEn} (${_selectedBank.code})',
                                style: TextStyle(color: _selectedBank.accentColor, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(_selectedPdfFile!.size / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _parsePdf,
                      icon: const Icon(Icons.memory, size: 18),
                      label: Text(
                        'Parse & Validate ${_selectedBank.shortName} Statement',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // PDF Preview Section
        if (_pdfParseResult != null) ...[
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF121824),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: _selectedBank.primaryColor.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildBankLogo(_selectedBank, size: 32),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedBank.nameEn} Inspection',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                'Profile: ${_selectedBank.code} Format',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
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
                  const SizedBox(height: 14),

                  // Metrics Grid
                  Row(
                    children: [
                      _buildMetricBox('Total', '${_pdfParseResult!.transactions.length} txns', Colors.white),
                      const SizedBox(width: 8),
                      _buildMetricBox('Quality', '${_pdfParseResult!.extractionConfidence}% PASS', const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildMetricBox('Bank Target', _selectedBank.shortName, _selectedBank.accentColor),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Transactions List
                  ..._pdfParseResult!.transactions.map((tx) => _buildTransactionCard(tx)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricBox(String title, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF182234),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF26324A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
        color: const Color(0xFF182234),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !tx.isBalanceValid ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF26324A),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${tx.postDate ?? '--'} · ${tx.category}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
                  color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
              if (tx.balance != null)
                Text(
                  'Bal: ${tx.balance!.toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                ),
            ],
          ),
        ],
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Hierarchy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 2),
                Text(
                  _dbTxCount > 0
                      ? 'Automated Financial Categorization • $_dbTxCount transactions'
                      : 'Automated Financial Categorization',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED)),
              onPressed: _fetchCategoryHierarchy,
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_categories.isNotEmpty) ...[
          _buildCategoryPieChartCard(),
          const SizedBox(height: 16),
        ],

        if (_categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF121824),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF26324A)),
            ),
            child: const Center(
              child: Text('No categories found.', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          )
        else
          ..._categories.asMap().entries.map((entry) => _buildCategoryNode(entry.value, entry.key)),
      ],
    );
  }

  // ============================================================
  // LUXURY DONUT BI SPENDING CHART (UX ENHANCED)
  // ============================================================
  Widget _buildCategoryPieChartCard() {
    final validCategories = _categories.where((c) => c.totalAmount > 0).toList();
    final totalSpent = validCategories.fold<double>(0.0, (sum, c) => sum + c.totalAmount);

    // If user tapped a specific category, show it. Otherwise show Overview with totalSpent.
    final isCategorySelected = _selectedCategoryIndex != null && _selectedCategoryIndex! < _categories.length;
    final activeCat = isCategorySelected ? _categories[_selectedCategoryIndex!] : null;

    final displayName = activeCat != null ? activeCat.name : 'Overview';
    final activeAmount = activeCat != null ? activeCat.totalAmount : totalSpent;
    final activePercent = activeCat != null
        ? (totalSpent > 0 ? ((activeAmount / totalSpent) * 100).toStringAsFixed(1) : '0.0')
        : (totalSpent > 0 ? '100.0' : '0.0');
    final activeColor = activeCat != null ? _parseColor(activeCat.color, const Color(0xFF7C3AED)) : const Color(0xFF7C3AED);

    return Card(
      color: const Color(0xFF121824),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF26324A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Indicator Pill (matches design: category name & amount pill + chart icon)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182234),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF26324A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        displayName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-${activeAmount.toStringAsFixed(3)} OMR',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: activeColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($activePercent%)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182234),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF26324A)),
                  ),
                  child: const Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFFA78BFA)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Interactive Donut Chart with Center Total
            SizedBox(
              height: 230,
              width: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Segments Custom Painted
                  CustomPaint(
                    size: const Size(230, 230),
                    painter: _LuxuryDonutPainter(
                      categories: _categories,
                      totalSpent: totalSpent,
                      selectedId: activeCat?.id,
                    ),
                  ),

                  // Center Circle Card with Total Spent
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = null),
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF26324A), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            totalSpent > 0 ? '${totalSpent.toStringAsFixed(2)} OMR' : '0.00 OMR',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Total Spent',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Horizontal Interactive Chips Bar to tap & highlight categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  final isSelected = activeCat?.id == cat.id;
                  final color = _parseColor(cat.color, const Color(0xFF7C3AED));

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = isSelected ? null : idx;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF182234),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? color : const Color(0xFF26324A),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(cat.icon),
                            size: 13,
                            color: isSelected ? color : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || !hex.startsWith('#')) return fallback;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'shopping-bag':
      case 'shopping':
      case 'shopping-cart':
        return Icons.shopping_bag_outlined;
      case 'coffee':
      case 'utensils':
      case 'food':
        return Icons.restaurant;
      case 'car':
      case 'transport':
        return Icons.directions_car_outlined;
      case 'home':
      case 'utilities':
        return Icons.home_outlined;
      case 'settings':
      case 'services':
        return Icons.settings_outlined;
      case 'entertainment':
      case 'film':
        return Icons.movie_outlined;
      case 'heart':
      case 'health':
        return Icons.favorite_outline;
      case 'briefcase':
      case 'business':
        return Icons.work_outline;
      default:
        return Icons.hub_outlined;
    }
  }

  Widget _buildCategoryNode(BmpfCategoryNode node, [int? index]) {
    Color catColor = const Color(0xFF7C3AED);
    try {
      if (node.color.startsWith('#')) {
        catColor = Color(int.parse(node.color.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}

    final isExpanded = _expandedCategoryIds.contains(node.id);
    final isSelectedFromChart = index != null && _selectedCategoryIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121824),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelectedFromChart ? catColor : const Color(0xFF26324A),
          width: isSelectedFromChart ? 2.0 : 1.0,
        ),
        boxShadow: isSelectedFromChart
            ? [
                BoxShadow(
                  color: catColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.label, size: 18, color: catColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      node.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${node.totalAmount.toStringAsFixed(3)} OMR',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: node.totalAmount > 0 ? catColor : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.txnCount > 0 ? '${node.txnCount} txns' : 'No txns',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Associated Transactions
          if (isExpanded) ...[
            const Divider(color: Color(0xFF26324A), height: 1),
            Container(
              color: const Color(0xFF0F141E),
              padding: const EdgeInsets.all(12),
              child: node.transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'No transactions categorized here yet.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transactions (${node.transactions.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 8),
                        ...node.transactions.map((tx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tx.narration,
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '-${tx.amount.toStringAsFixed(3)} OMR',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                                ),
                              ],
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


  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF121824),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
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
// LUXURY DONUT CHART CUSTOM PAINTER
// ============================================================
class _LuxuryDonutPainter extends CustomPainter {
  final List<BmpfCategoryNode> categories;
  final double totalSpent;
  final String? selectedId;

  _LuxuryDonutPainter({
    required this.categories,
    required this.totalSpent,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 36.0;

    // Background track ring
    final bgPaint = Paint()
      ..color = const Color(0xFF182234).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - (strokeWidth / 2), bgPaint);

    if (totalSpent <= 0 || categories.isEmpty) {
      // Empty placeholder ring
      final emptyPaint = Paint()
        ..color = const Color(0xFF26324A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - (strokeWidth / 2), emptyPaint);
      return;
    }

    final validCategories = categories.where((c) => c.totalAmount > 0).toList();
    if (validCategories.isEmpty) return;

    double startAngle = -math.pi / 2; // start from top (12 o'clock)
    const gapAngle = 0.04; // sleek separation gap between slices

    for (final cat in validCategories) {
      final sweepAngle = (cat.totalAmount / totalSpent) * 2 * math.pi;
      final isSelected = selectedId == cat.id;

      Color catColor = const Color(0xFF7C3AED);
      if (cat.color.startsWith('#')) {
        try {
          catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }

      final sliceWidth = isSelected ? strokeWidth + 6.0 : strokeWidth;
      final slicePaint = Paint()
        ..color = isSelected ? catColor : catColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sliceWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(
        center: center,
        radius: radius - (strokeWidth / 2) + (isSelected ? 2.0 : 0.0),
      );

      final effectiveSweep = math.max(0.01, sweepAngle - gapAngle);
      canvas.drawArc(rect, startAngle + (gapAngle / 2), effectiveSweep, false, slicePaint);

      // Draw subtle glow shadow for the selected slice
      if (isSelected) {
        final glowPaint = Paint()
          ..color = catColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sliceWidth + 8.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawArc(rect, startAngle + (gapAngle / 2), effectiveSweep, false, glowPaint);
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _LuxuryDonutPainter oldDelegate) {
    return oldDelegate.totalSpent != totalSpent ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.categories.length != categories.length;
  }
}

