import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages bilingual English (default) & Arabic localization across ThemarIP.
class LanguageService {
  static const String _langKey = 'themarip_app_language';

  /// Reactive language code notifier ('en' default, or 'ar').
  static final ValueNotifier<String> notifier = ValueNotifier<String>('en');

  static String get current => notifier.value;
  static bool get isArabic => notifier.value == 'ar';
  static TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  static const Map<String, Map<String, String>> _strings = {
    'skip': {'en': 'Skip', 'ar': 'تخطي'},
    'back': {'en': 'Back', 'ar': 'رجوع'},
    'continue_btn': {'en': 'Continue', 'ar': 'متابعة'},
    'slide1_card1_title': {'en': 'Subscriptions', 'ar': 'الاشتراكات الشهرية'},
    'slide1_card1_sub': {
      'en': 'Increased by OMR 6.500',
      'ar': 'ارتفعت بمقدار 6.500 ر.ع',
    },
    'slide1_card2_title': {
      'en': 'Committed Spending',
      'ar': 'الالتزامات والفواتير',
    },
    'slide1_card2_sub': {
      'en': '3 bills left till salary day',
      'ar': '3 فواتير متبقية حتى يوم الراتب',
    },
    'slide1_card3_title': {
      'en': 'Grocery & Family Budget',
      'ar': 'ميزانية المنزل والمقاضي',
    },
    'slide1_card3_sub': {
      'en': 'You are on track and saved OMR 25.000 this month',
      'ar': 'أنت على المسار الصحيح ووفرت 25.000 ر.ع هذا الشهر',
    },
    'slide1_title': {
      'en': 'Never lose control of your money again',
      'ar': 'لا تفقد السيطرة على أموالك ومصاريفك بعد اليوم',
    },
    'slide1_subtitle': {
      'en':
          'Always know about your upcoming charges in OMR, cut back on unnecessary spending and improve your financial life in Oman.',
      'ar':
          'تعرف دائماً على التزاماتك القادمة بالريال العُماني، وقلل المصاريف غير الضرورية وحسّن حياتك المالية في سلطنة عُمان.',
    },
    'slide2_title': {
      'en': 'Why do we connect your bank account?',
      'ar': 'لماذا نربط كشوفات وإشعارات حسابك البنكي؟',
    },
    'slide2_security': {
      'en': 'Protected with 256-bit bank-grade encryption & privacy',
      'ar': 'محمي بتشفير بنكي فائق الأمان 256-bit وخصوصية تامة',
    },
    'slide2_item1_title': {
      'en': 'Cancel wasteful subscriptions',
      'ar': 'إلغاء الاشتراكات غير الضرورية',
    },
    'slide2_item1_sub': {
      'en': 'Say goodbye to paying twice for the same service',
      'ar': 'وداعاً للدفع المكرر أو الاشتراكات المنسية كل شهر',
    },
    'slide2_item2_title': {
      'en': 'Stay ahead of monthly commitments',
      'ar': 'استعد لالتزاماتك الشهرية مبكراً',
    },
    'slide2_item2_sub': {
      'en':
          'Plan utilities, Jamiyah, installments, and household bills before salary day',
      'ar': 'خطط للفواتير، الجمعية، الأقساط ومصاريف الأسرة قبل نزول الراتب',
    },
    'slide2_item3_title': {
      'en': 'Build your monthly savings',
      'ar': 'عزز مدخراتك الشهرية بالريال العُماني',
    },
    'slide2_item3_sub': {
      'en':
          'Set smart OMR budgets for groceries, Karak & cafes, and fuel to grow your savings',
      'ar': 'حدد ميزانيات ذكية للمقاضي والمقاهي والوقود لتنمية مدخراتك الشهرية',
    },
    'slide2_item4_title': {
      'en': 'All your Omani banks in one place',
      'ar': 'جميع حساباتك البنكية العُمانية في مكان واحد',
    },
    'slide2_item4_sub': {
      'en':
          'See Bank Muscat, NBO, Bank Dhofar, Bank Nizwa, and Sohar International in one unified view',
      'ar':
          'تابع بنك مسقط، البنك الوطني العُماني، بنك ظفار، وبنك نزوى في لوحة موحدة',
    },
    'select_language': {'en': 'Language', 'ar': 'اللغة'},
    'welcome_back': {'en': 'Welcome Back ✨', 'ar': 'مرحباً بعودتك ✨'},
    'email_address': {'en': 'EMAIL ADDRESS', 'ar': 'البريد الإلكتروني'},
    'password': {'en': 'PASSWORD', 'ar': 'كلمة المرور'},
    'forgot_password': {'en': 'Forgot Password?', 'ar': 'نسيت كلمة المرور؟'},
    'sign_in': {'en': 'Sign In', 'ar': 'تسجيل الدخول'},
    'no_account': {'en': "Don't have an account?", 'ar': 'ليس لديك حساب؟'},
    'create_account': {'en': 'Create Account', 'ar': 'إنشاء حساب جديد'},
    'reset_password': {'en': 'Reset Password', 'ar': 'إعادة تعيين كلمة المرور'},
    'admin_reset_required_title': {
      'en': 'Set Your New Password',
      'ar': 'تعيين كلمة المرور الجديدة',
    },
    'admin_reset_required_sub': {
      'en':
          'An administrator has enabled password reset for your account. Please enter your new password and re-enter it again as confirmation.',
      'ar':
          'تم تفعيل إعادة تعيين كلمة المرور لحسابك من قِبل الإدارة. يرجى إدخال كلمة المرور الجديدة وإعادة إدخالها للتأكيد.',
    },
    'enter_new_password': {
      'en': 'ENTER NEW PASSWORD',
      'ar': 'أدخل كلمة المرور الجديدة',
    },
    'confirm_new_password': {
      'en': 'RE-ENTER NEW PASSWORD (CONFIRMATION)',
      'ar': 'أعد إدخال كلمة المرور الجديدة للتأكيد',
    },
    'password_min_error': {
      'en': 'Password must be at least 6 characters.',
      'ar': 'يجب أن تتكون كلمة المرور من 6 أحرف أو أرقام على الأقل.',
    },
    'passwords_do_not_match': {
      'en': 'New password and confirmation password do not match.',
      'ar': 'كلمة المرور الجديدة وتأكيد كلمة المرور غير متطابقتين.',
    },
    'password_reset_success': {
      'en':
          'Password updated successfully! Please sign in with your new password.',
      'ar': 'تم تحديث كلمة المرور بنجاح! يرجى تسجيل الدخول بكلمة المرور الجديدة.',
    },
    'update_password': {'en': 'Update Password', 'ar': 'تحديث كلمة المرور'},
    'cancel': {'en': 'Cancel', 'ar': 'إلغاء'},
    'verified_badge': {'en': 'Verified', 'ar': 'موثق'},
    'app_language': {
      'en': 'App Language / لغة التطبيق',
      'ar': 'لغة التطبيق / App Language',
    },
    'language_desc': {
      'en': 'Default language is English (Switch to Arabic anytime)',
      'ar': 'اللغة الافتراضية هي الإنجليزية (يمكنك التبديل للعربية في أي وقت)',
    },
    'security_privacy_title': {
      'en': 'Security & Data Privacy',
      'ar': 'الأمان وخصوصية البيانات',
    },
    'security_privacy_bullets': {
      'en':
          '• Read-only statement & SMS analytics — your banking credentials and PINs are never collected.\n• All financial insights are processed securely with AES-256 data protection.',
      'ar':
          '• قراءة تحليلية فقط للكشوفات والإشعارات — لا نطلب أبداً أرقامك السرية البنكية.\n• جميع التحليلات المالية محمية بتشفير AES-256 فائق الأمان.',
    },
    'sign_out': {
      'en': 'Sign Out of ThemarIP',
      'ar': 'تسجيل الخروج من ثمار',
    },
  };

  /// Initialize from SharedPreferences, always defaulting to 'en' (English).
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_langKey);
      if (saved == 'ar' || saved == 'en') {
        notifier.value = saved!;
      } else {
        notifier.value = 'en';
      }
    } catch (_) {
      notifier.value = 'en';
    }
  }

  /// Switch language between 'en' (English) and 'ar' (Arabic).
  static Future<void> setLanguage(String code) async {
    final normalized = (code == 'ar') ? 'ar' : 'en';
    notifier.value = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langKey, normalized);
    } catch (_) {}
  }

  /// Translates either by dictionary key `tr('welcome_back')` or inline `tr('English', 'Arabic')`.
  static String tr(String keyOrEn, [String? ar]) {
    if (ar != null) {
      return isArabic ? ar : keyOrEn;
    }
    final entry = _strings[keyOrEn];
    if (entry != null) {
      return isArabic ? (entry['ar'] ?? entry['en'] ?? keyOrEn) : (entry['en'] ?? keyOrEn);
    }
    return keyOrEn;
  }
}

/// Sleek bilingual toggle pill for Login, Onboarding, and Settings screens.
class LanguageSelectorPill extends StatelessWidget {
  final bool compact;
  final VoidCallback? onChanged;

  const LanguageSelectorPill({
    super.key,
    this.compact = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.notifier,
      builder: (context, lang, _) {
        final isAr = lang == 'ar';
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF28364F)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(
                label: 'English',
                selected: !isAr,
                onTap: () async {
                  await LanguageService.setLanguage('en');
                  onChanged?.call();
                },
              ),
              _buildOption(
                label: 'العربية',
                selected: isAr,
                onTap: () async {
                  await LanguageService.setLanguage('ar');
                  onChanged?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11.5 : 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
