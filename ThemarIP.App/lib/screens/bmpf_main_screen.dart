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
  ExtractorFlowStep _extractorFlow = ExtractorFlowStep.selectBank;
  final TextEditingController _bankSearchController = TextEditingController();
  String _bankSearchText = '';

  UserModel? _currentUser;
  int _dbTxCount = 0;
  bool _isLoading = false;
  String _loadingMessage = '';

  // 1. PDF State
  PlatformFile? _selectedPdfFile;
  BmpfParseResult? _pdfParseResult;

  // Category Hierarchy State
  List<BmpfCategoryNode> _categories = [];
  List<BmpfCategoryNode> _rawCategories = [];
  String _selectedHierarchyBankCode = 'ALL';
  List<Map<String, dynamic>> _userUploadedBanks = [];
  bool _isLoadingCategories = false;
  final Set<String> _expandedCategoryIds = {};
  int? _selectedCategoryIndex;

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
    _bankSearchController.dispose();
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
    setState(() {
      _selectedBank = bank;
      _pdfParseResult = null;
      _selectedPdfFile = null;
      _extractorFlow = ExtractorFlowStep.connectBank;
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

  void _applyBankFilter() {
    if (_rawCategories.isEmpty) return;

    if (_selectedHierarchyBankCode == 'ALL') {
      _categories = _rawCategories.map((node) {
        return BmpfCategoryNode(
          id: node.id,
          name: node.name,
          icon: node.icon,
          color: node.color,
          displayOrder: node.displayOrder,
          isEnabled: node.isEnabled,
          children: node.children,
          totalAmount: node.transactions.fold(0.0, (sum, t) => sum + t.amount),
          txnCount: node.transactions.length,
          transactions: List<BmpfTransaction>.from(node.transactions),
        );
      }).toList();
    } else {
      _categories = _rawCategories.map((node) {
        final filteredTx = node.transactions.where((t) => t.bankCode.toUpperCase() == _selectedHierarchyBankCode.toUpperCase()).toList();
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
      }).toList();
    }
  }

  void _onSelectHierarchyBank(String bankCode) {
    setState(() {
      _selectedHierarchyBankCode = bankCode;
      _selectedCategoryIndex = null;
      _applyBankFilter();
    });
  }

  Future<void> _fetchCategoryHierarchy() async {
    setState(() => _isLoadingCategories = true);
    try {
      final rawNodes = await _apiService.getCategoryHierarchy();
      final stats = await _apiService.getCategoryStats(userId: _currentUser?.id);
      final userBanksRaw = await _apiService.getUserBanks(userId: _currentUser?.id);

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
              bankCode: tMap['bankCode']?.toString() ?? 'BANK_MUSCAT',
              bankName: tMap['bankName']?.toString() ?? 'Bank Muscat',
            );
          }).toList();

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
      backgroundColor: const Color(0xFF0F1424),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Main Scrollable Page Content
          Positioned.fill(
            child: _selectedPageIndex == 0 ? _buildExtractorPage() : _buildCategoriesPage(),
          ),

          // Floating Bottom Navigation Bar (Matching Image 3)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              child: _buildFloatingBottomNavBar(),
            ),
          ),

          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF141928),
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'assets/themarip_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.spa_rounded, size: 16, color: Color(0xFF34D399)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'THEMAR PFM',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
              ),
              Text(
                'CENTRAL BANK OF OMAN REGULATED',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399), letterSpacing: 0.8),
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF28364F))),
        title: Row(
          children: const [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('CBO Compliance & Security', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'ThemarIP is officially registered and operates under the Central Bank of Oman (CBO) regulatory guidelines.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '• 256-bit AES Bank-Grade Encryption\n• Read-only statement extraction\n• No online banking passwords or debit PINs required\n• Tailored multi-bank layout parsing for all Omani banks',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.55),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FLOATING BOTTOM NAVIGATION BAR (MATCHING IMAGE 3)
  // ============================================================
  Widget _buildFloatingBottomNavBar() {
    return Row(
      children: [
        // Left Capsule / Pill Container (Extractor & Hierarchy)
        Expanded(
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF28364F), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Extractor Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPageIndex = 0;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPageIndex == 0
                            ? const Color(0xFF10B981).withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: _selectedPageIndex == 0
                            ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 18,
                            color: _selectedPageIndex == 0 ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Extractor',
                            style: TextStyle(
                              color: _selectedPageIndex == 0 ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                              fontSize: 12.5,
                              fontWeight: _selectedPageIndex == 0 ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Hierarchy Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPageIndex = 1;
                      });
                      if (_categories.isEmpty) {
                        _fetchCategoryHierarchy();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPageIndex == 1
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: _selectedPageIndex == 1
                            ? Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.6))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_rounded,
                            size: 18,
                            color: _selectedPageIndex == 1 ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hierarchy',
                            style: TextStyle(
                              color: _selectedPageIndex == 1 ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
                              fontSize: 12.5,
                              fontWeight: _selectedPageIndex == 1 ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Right Floating Action Button (Image 3)
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedPageIndex = 0;
              _extractorFlow = ExtractorFlowStep.uploadStatement;
            });
            _pickPdf();
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF161F30).withValues(alpha: 0.96),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF28364F), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.crop_free_rounded, size: 26, color: Colors.white),
            ),
          ),
        ),
      ],
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
        // Top Row: Help button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _showHelpDialog,
              child: const Text(
                'Help',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
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
            color: Colors.white,
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        const Text(
          'It\'s fast, secure and reliable to connect your bank',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
        ),
        const SizedBox(height: 14),

        // Central Bank of Oman Registration Trust Pill (Matching Image 1)
        Row(
          children: const [
            Icon(Icons.shield_outlined, size: 16, color: Color(0xFFA78BFA)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ThemarIP is registered with the Central Bank of Oman',
                style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12, fontWeight: FontWeight.w600),
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
            color: const Color(0xFF161F30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF28364F)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _bankSearchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (val) => setState(() => _bankSearchText = val),
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
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
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // "Most popular" Section Header
        const Text(
          'Most popular',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 10),

        // Bank List Card Container (Matching Image 1)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141C2B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF243046)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredBanks.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72, endIndent: 16, color: Color(0xFF243046)),
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
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${bank.nameAr} · ${bank.badgeText}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
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
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => setState(() => _extractorFlow = ExtractorFlowStep.selectBank),
            ),
            TextButton(
              onPressed: _showHelpDialog,
              child: const Text(
                'Help',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
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
                    painter: _DashedArcPainter(color: const Color(0xFF38BDF8).withValues(alpha: 0.85)),
                  ),
                ),
                // Security Shield Badge at the center top of the arc
                Positioned(
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1.6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 16),
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
                          color: Colors.black.withValues(alpha: 0.25),
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
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF34D399).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/themarip_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.spa_rounded, size: 30, color: Color(0xFF34D399)),
                            ),
                          ),
                        ),
                      ),
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
            color: Colors.white,
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.45),
          ),
        ),
        const SizedBox(height: 24),

        // Security & Central Bank of Oman Verification Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141D2D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF28364F)),
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
                    style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• ThemarIP is officially registered and licensed with the Central Bank of Oman (CBO).\n• Protected with 256-bit AES encryption.\n• Read-only statement extraction — your online banking passwords and debit PINs are never requested.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Big Purple Continue Button (Matching Image 2)
        ElevatedButton(
          onPressed: () => setState(() => _extractorFlow = ExtractorFlowStep.uploadStatement),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA78BFA),
            foregroundColor: Colors.black,
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
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text('Change Bank', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
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
            color: const Color(0xFF141C2B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF28364F)),
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
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedBank.nameAr,
                          style: TextStyle(fontSize: 11.5, color: _selectedBank.accentColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedBank.formatDescription,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
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
              color: const Color(0xFF141D2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedPdfFile != null ? const Color(0xFF10B981) : const Color(0xFF28364F),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Color(0xFFA78BFA),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedPdfFile != null ? _selectedPdfFile!.name : 'Choose ${_selectedBank.nameEn} Statement',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedPdfFile != null
                      ? '${(_selectedPdfFile!.size / 1024).toStringAsFixed(1)} KB · Ready for extraction'
                      : 'Upload official account statement (.pdf)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedPdfFile != null ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
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
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text('Upload Another', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
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
            _buildMetricBox('Total Extracted', '${_pdfParseResult!.transactions.length} txns', Colors.white),
            const SizedBox(width: 8),
            _buildMetricBox('Quality Score', '${_pdfParseResult!.extractionConfidence}% PASS', const Color(0xFF10B981)),
            const SizedBox(width: 8),
            _buildMetricBox('Bank Target', _selectedBank.shortName, _selectedBank.accentColor),
          ],
        ),
        const SizedBox(height: 18),

        // Extracted Transactions List
        const Text('Extracted Transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 10),
        ..._pdfParseResult!.transactions.map((tx) => _buildTransactionCard(tx)),
      ],
    );
  }

  // ============================================================
  // BANK LOGO WIDGET (USES OFFICIAL LOGO ASSETS)
  // ============================================================
  Widget _buildBankLogo(LocalBank bank, {double size = 42, bool circular = false}) {
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
            errorBuilder: (context, error, stackTrace) => _buildBankEmblemIcon(bank, size),
          ),
        ),
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
      default:
        return Icon(bank.defaultIcon, color: bank.primaryColor, size: size * 0.45);
    }
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
  // MULTI-BANK HIERARCHY FILTER & SPENDING BEHAVIOR ANALYTICS
  // ============================================================
  Widget _buildBankHierarchyFilterBar() {
    final List<Map<String, dynamic>> banksList = [];

    final totalAllTx = _rawCategories.fold<int>(0, (sum, c) => sum + c.transactions.length);
    final totalAllSpent = _rawCategories.fold<double>(0.0, (sum, c) => sum + c.totalAmount);

    banksList.add({
      'code': 'ALL',
      'name': 'All Banks',
      'shortName': 'ALL',
      'txCount': totalAllTx,
      'totalSpent': totalAllSpent,
    });

    if (_userUploadedBanks.isNotEmpty) {
      for (final ub in _userUploadedBanks) {
        final code = ub['bankCode']?.toString() ?? '';
        if (code.isNotEmpty && !banksList.any((b) => b['code'] == code)) {
          final bankDef = _findBankByCode(code);
          banksList.add({
            'code': code,
            'name': ub['bankName']?.toString() ?? bankDef?.nameEn ?? code,
            'shortName': bankDef?.shortName ?? code,
            'txCount': (ub['txCount'] as num?)?.toInt() ?? 0,
            'totalSpent': (ub['totalSpent'] as num?)?.toDouble() ?? 0.0,
            'logoAsset': bankDef?.logoAsset,
          });
        }
      }
    } else {
      final bankMap = <String, int>{};
      for (final cat in _rawCategories) {
        for (final tx in cat.transactions) {
          bankMap[tx.bankCode] = (bankMap[tx.bankCode] ?? 0) + 1;
        }
      }
      for (final entry in bankMap.entries) {
        final bankDef = _findBankByCode(entry.key);
        banksList.add({
          'code': entry.key,
          'name': bankDef?.nameEn ?? entry.key,
          'shortName': bankDef?.shortName ?? entry.key,
          'txCount': entry.value,
          'logoAsset': bankDef?.logoAsset,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF34D399)),
            const SizedBox(width: 8),
            const Text(
              'ACCOUNT & BANK FILTER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF34D399),
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            Text(
              _selectedHierarchyBankCode == 'ALL'
                  ? 'All Statements Combined'
                  : 'Filter: ${_findBankByCode(_selectedHierarchyBankCode)?.shortName ?? _selectedHierarchyBankCode}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: banksList.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = banksList[index];
              final code = item['code'] as String;
              final isSelected = _selectedHierarchyBankCode.toUpperCase() == code.toUpperCase();
              final isAll = code == 'ALL';
              final bankDef = isAll ? null : _findBankByCode(code);
              final txCount = item['txCount'] as int? ?? 0;

              return InkWell(
                onTap: () => _onSelectHierarchyBank(code),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isAll ? const Color(0xFF1E1B4B) : const Color(0xFF0F291E))
                        : const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? (isAll ? const Color(0xFFA78BFA) : const Color(0xFF34D399))
                          : const Color(0xFF26324A),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: isAll
                                  ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                                  : const Color(0xFF34D399).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAll) ...[
                        Icon(
                          Icons.dashboard_customize_rounded,
                          size: 15,
                          color: isSelected ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 7),
                      ] else ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Image.asset(
                                bankDef?.logoAsset ?? 'assets/banks/bank_muscat.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    bankDef?.shortName ?? code,
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Text(
                        isAll ? 'All Banks' : (bankDef?.nameEn ?? item['name'] as String),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                      if (txCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isAll ? const Color(0xFF7C3AED) : const Color(0xFF059669))
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$txCount',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBankBehaviorInsightCard() {
    final isAll = _selectedHierarchyBankCode == 'ALL';
    final totalSpentInView = _categories.fold<double>(0.0, (sum, c) => sum + c.totalAmount);
    final totalTxInView = _categories.fold<int>(0, (sum, c) => sum + c.transactions.length);
    final totalAllSpent = _rawCategories.fold<double>(0.0, (sum, c) => sum + c.totalAmount);

    BmpfCategoryNode? topCategory;
    for (final c in _categories) {
      if (c.totalAmount > 0 && (topCategory == null || c.totalAmount > topCategory.totalAmount)) {
        topCategory = c;
      }
    }

    final topCatPercent = totalSpentInView > 0 && topCategory != null
        ? ((topCategory.totalAmount / totalSpentInView) * 100).toStringAsFixed(1)
        : '0.0';

    final avgTxAmount = totalTxInView > 0 ? (totalSpentInView / totalTxInView).toStringAsFixed(3) : '0.000';

    if (isAll) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF161E34), Color(0xFF111827)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2E3D5B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Color(0xFFA78BFA), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userUploadedBanks.length > 1
                            ? 'Consolidated Multi-Bank Behavior'
                            : 'Spending Behavior Overview',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _userUploadedBanks.length > 1
                            ? 'Combined activity across ${_userUploadedBanks.length} local bank statements'
                            : (_userUploadedBanks.isNotEmpty
                                ? 'Activity from ${_userUploadedBanks.first['bankName'] ?? 'uploaded statement'}'
                                : 'Activity from uploaded statement'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF34D399)),
                      SizedBox(width: 4),
                      Text('Unified PFM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Total Net Outflow',
                    value: '${totalSpentInView.toStringAsFixed(3)} OMR',
                    subtitle: '$totalTxInView total transactions',
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: const Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Primary Expense Group',
                    value: topCategory != null ? topCategory.name : 'General',
                    subtitle: topCategory != null ? '$topCatPercent% of total' : '--',
                    icon: Icons.pie_chart_outline_rounded,
                    accentColor: const Color(0xFFA78BFA),
                  ),
                ),
              ],
            ),
            if (_userUploadedBanks.length >= 2) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bank Activity Share:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    ..._userUploadedBanks.map((ub) {
                      final bCode = ub['bankCode']?.toString() ?? '';
                      final bankDef = _findBankByCode(bCode);
                      final spent = (ub['totalSpent'] as num?)?.toDouble() ?? 0.0;
                      final share = totalAllSpent > 0 ? (spent / totalAllSpent) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              child: ClipOval(
                                child: Image.asset(
                                  bankDef?.logoAsset ?? 'assets/banks/bank_muscat.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(Icons.account_balance, size: 10, color: Colors.black),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 110,
                              child: Text(
                                bankDef?.nameEn ?? bCode,
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: share.clamp(0.01, 1.0),
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFF1E293B),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    bCode.contains('MUSCAT') ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(share * 100).toStringAsFixed(0)}% (${spent.toStringAsFixed(1)} OMR)',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
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
    } else {
      final bank = _findBankByCode(_selectedHierarchyBankCode);
      final bankShare = totalAllSpent > 0 ? ((totalSpentInView / totalAllSpent) * 100).toStringAsFixed(1) : '100.0';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F291E), Color(0xFF0B1B15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF34D399).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        bank?.logoAsset ?? 'assets/banks/bank_muscat.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Center(
                          child: Text(bank?.shortName ?? 'BM', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Single Bank Behavior: ${bank?.nameEn ?? _selectedHierarchyBankCode}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text(
                        'Regulated under CBO • Dedicated spending profile',
                        style: TextStyle(fontSize: 11, color: Color(0xFF34D399)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _onSelectHierarchyBank('ALL'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 12, color: Color(0xFF94A3B8)),
                        SizedBox(width: 4),
                        Text('Reset All', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: '${bank?.shortName ?? "Bank"} Outflow',
                    value: '${totalSpentInView.toStringAsFixed(3)} OMR',
                    subtitle: '$bankShare% of total wallet',
                    icon: Icons.account_balance,
                    accentColor: const Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Top Expense in ${bank?.shortName ?? "Bank"}',
                    value: topCategory != null ? topCategory.name : 'General',
                    subtitle: topCategory != null ? '$topCatPercent% ($totalTxInView txns)' : '--',
                    icon: Icons.category_rounded,
                    accentColor: const Color(0xFFFBBF24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avg ticket in ${bank?.shortName ?? "this bank"}: $avgTxAmount OMR. Represents $totalTxInView active transactions categorized.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: accentColor.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 2),
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

        // Multi-Bank Account & Behavior Filter Bar
        _buildBankHierarchyFilterBar(),
        const SizedBox(height: 16),

        // Multi-Bank Spending Behavior Intelligence Card
        _buildBankBehaviorInsightCard(),
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
              child: Text('No categories found for this selection.', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          )
        else
          ..._categories.asMap().entries.map((entry) => _buildCategoryNode(entry.value, entry.key)),

        const SizedBox(height: 110), // Padding for floating menu bar
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
                          final bankDef = _findBankByCode(tx.bankCode);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
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
                                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${bankDef?.nameEn ?? tx.bankName}${tx.postDate != null ? ' • ${tx.postDate!.substring(0, math.min(10, tx.postDate!.length))}' : ''}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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

class _DashedArcPainter extends CustomPainter {
  final Color color;
  _DashedArcPainter({required this.color});

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
