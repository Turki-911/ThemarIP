import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/language_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/terms');
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.notifier,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0E101C),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  children: [
                    // Top Header Bar (Back button on Slide 2, Language Selector, Skip)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage > 0)
                          IconButton(
                            onPressed: _prevPage,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: LanguageService.tr('back'),
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: Image.asset(
                                  'assets/themarip_logo_transparent.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppTheme.primaryPurple,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Themar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: 'IP',
                                      style: TextStyle(color: AppTheme.primaryPurple),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LanguageSelectorPill(
                              compact: true,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacementNamed('/terms');
                              },
                              child: Text(
                                LanguageService.tr('skip'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Main PageView (Slide 1 & Slide 2 matching attached Omani financial designs)
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (idx) => setState(() => _currentPage = idx),
                        children: [
                          _buildSlideOneOmaniControl(),
                          _buildSlideTwoWhyConnect(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Dots Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        2,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: _currentPage == index ? 24 : 7,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF4F6EF7)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Full-Width Pill "Continue" Button (Matching attached screenshots)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4361EE),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: const Color(0xFF4361EE).withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('continue_btn'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
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
      },
    );
  }

  /// Slide 1 — Matches Image #1:
  /// 3 stacked Omani summary cards (Subscriptions, Committed Spending, Grocery Budget)
  /// with overlapping merchant/service circles + "Never lose control of your money again"
  Widget _buildSlideOneOmaniControl() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Card 1: Subscriptions (Talabat, Shahid, Netflix)
          _buildStackedInsightCard(
            title: LanguageService.tr('slide1_card1_title'),
            subtitle: LanguageService.tr('slide1_card1_sub'),
            badges: const [
              _MerchantBadgeData(
                label: 'T',
                bgColor: Color(0xFFFF5A00),
                textColor: Colors.white,
              ),
              _MerchantBadgeData(
                label: 'SH',
                bgColor: Color(0xFF00C853),
                textColor: Colors.black,
              ),
              _MerchantBadgeData(
                label: 'N',
                bgColor: Color(0xFFE50914),
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Card 2: Committed Spending (Omantel, Ooredoo, Nama Utilities)
          _buildStackedInsightCard(
            title: LanguageService.tr('slide1_card2_title'),
            subtitle: LanguageService.tr('slide1_card2_sub'),
            badges: const [
              _MerchantBadgeData(
                label: 'O',
                bgColor: Color(0xFF4338CA),
                textColor: Colors.white,
              ),
              _MerchantBadgeData(
                label: 'OO',
                bgColor: Color(0xFFEF4444),
                textColor: Colors.white,
              ),
              _MerchantBadgeData(
                icon: Icons.bolt_rounded,
                bgColor: Color(0xFF0284C7),
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Card 3: Grocery & Family Budget (Lulu, Al Meera, Oman Oil)
          _buildStackedInsightCard(
            title: LanguageService.tr('slide1_card3_title'),
            subtitle: LanguageService.tr('slide1_card3_sub'),
            badges: const [
              _MerchantBadgeData(
                icon: Icons.shopping_bag_rounded,
                bgColor: Color(0xFF10B981),
                textColor: Colors.white,
              ),
              _MerchantBadgeData(
                icon: Icons.local_grocery_store_rounded,
                bgColor: Color(0xFFF59E0B),
                textColor: Colors.white,
              ),
              _MerchantBadgeData(
                icon: Icons.local_gas_station_rounded,
                bgColor: Color(0xFF3B82F6),
                textColor: Colors.white,
              ),
            ],
          ),

          const SizedBox(height: 36),

          // Headline: "Never lose control of your money again"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              LanguageService.tr('slide1_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle tailored to Oman
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              LanguageService.tr('slide1_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                color: Color(0xFFB4BCD0),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStackedInsightCard({
    required String title,
    required String subtitle,
    required List<_MerchantBadgeData> badges,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2032),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFB4BCD0),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Overlapping circular badges
          SizedBox(
            width: 96,
            height: 42,
            child: Stack(
              alignment: Alignment.centerRight,
              children: List.generate(badges.length, (i) {
                final badge = badges[i];
                return Positioned(
                  right: (badges.length - 1 - i) * 26.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badge.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1D2032),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: badge.icon != null
                        ? Icon(badge.icon, color: badge.textColor, size: 19)
                        : Text(
                            badge.label ?? '',
                            style: TextStyle(
                              color: badge.textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Slide 2 — Matches Image #2:
  /// "Why do we connect your bank account?" + 256-bit Encryption badge +
  /// Dark container with 4 Omani financial literacy benefits
  Widget _buildSlideTwoWhyConnect() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              LanguageService.tr('slide2_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Shield security subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF94A3B8),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  LanguageService.tr('slide2_security'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Dark rounded feature container with 4 items
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFF191C2B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  iconData: Icons.block_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  iconBg: const Color(0xFF3A1D2E),
                  title: LanguageService.tr('slide2_item1_title'),
                  subtitle: LanguageService.tr('slide2_item1_sub'),
                ),
                const SizedBox(height: 22),
                _buildFeatureRow(
                  iconData: Icons.insights_rounded,
                  iconColor: const Color(0xFFA855F7),
                  iconBg: const Color(0xFF2B1E3E),
                  title: LanguageService.tr('slide2_item2_title'),
                  subtitle: LanguageService.tr('slide2_item2_sub'),
                ),
                const SizedBox(height: 22),
                _buildFeatureRow(
                  iconData: Icons.savings_outlined,
                  iconColor: const Color(0xFF2DD4BF),
                  iconBg: const Color(0xFF153238),
                  title: LanguageService.tr('slide2_item3_title'),
                  subtitle: LanguageService.tr('slide2_item3_sub'),
                ),
                const SizedBox(height: 22),
                _buildFeatureRow(
                  iconData: Icons.account_balance_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  iconBg: const Color(0xFF382C1E),
                  title: LanguageService.tr('slide2_item4_title'),
                  subtitle: LanguageService.tr('slide2_item4_sub'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    IconData? icon,
    IconData? iconData,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    final resolvedIcon = iconData ?? icon ?? Icons.star_rounded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            resolvedIcon,
            color: iconColor,
            size: 23,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13.8,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MerchantBadgeData {
  final String? label;
  final IconData? icon;
  final Color bgColor;
  final Color textColor;

  const _MerchantBadgeData({
    this.label,
    this.icon,
    required this.bgColor,
    required this.textColor,
  });
}
