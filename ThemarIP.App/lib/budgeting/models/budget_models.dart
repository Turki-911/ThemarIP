import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Immutable definition of a budgeting category.
/// Exactly matches the canonical Admin Portal / PfmCategories.
class BudgetCategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final double threeMonthAverageOmr;
  final double sampleSpendRatio;
  final double? liveSpentOmr;
  final int liveTxnCount;
  final Color? color;

  const BudgetCategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.threeMonthAverageOmr,
    this.sampleSpendRatio = 0.50,
    this.liveSpentOmr,
    this.liveTxnCount = 0,
    this.color,
  });

  BudgetCategoryModel copyWith({
    String? id,
    String? name,
    IconData? icon,
    double? threeMonthAverageOmr,
    double? sampleSpendRatio,
    double? liveSpentOmr,
    int? liveTxnCount,
    Color? color,
  }) {
    return BudgetCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      threeMonthAverageOmr: threeMonthAverageOmr ?? this.threeMonthAverageOmr,
      sampleSpendRatio: sampleSpendRatio ?? this.sampleSpendRatio,
      liveSpentOmr: liveSpentOmr ?? this.liveSpentOmr,
      liveTxnCount: liveTxnCount ?? this.liveTxnCount,
      color: color ?? this.color,
    );
  }
}

/// Centralized strings, constants, and OMR currency formatting helper.
class BudgetConstants {
  const BudgetConstants._();

  static const String currencyCode = 'OMR';
  static const double defaultThreeMonthMonthlyAverageOmr = 400.000;
  static const double committedSpendingOmr = 0.640;
  static const int excludedCategoriesCount = 2;
  static const double overspentWarningThreshold = 0.85;
  static const double maxContentWidth = 440.0;
  static const int totalWizardSteps = 4;

  // Screen 1 strings
  static const String welcomeLabel = 'Welcome to budgeting';
  static const String monthlyTotalHeading =
      'How much do you want to spend each month?';
  static const String monthlyTotalSubtext =
      'Include day-to-day spending and recurring payments.';
  static const String threeMonthAverageLabel = '3-month average ';
  static const String continueLabel = 'Continue';

  // Screen 2 strings
  static const String categoryBudgetsHeading =
      'Set a budget for each category';
  static const String categoryBudgetsSubtext =
      'Start from scratch, or let us suggest amounts from your recent spending.';
  static const String autoFillButtonLabel = 'Auto fill from averages';
  static const String leftToAllocateSuffix = ' left to allocate';
  static const String overYourTotalSuffix = ' over your total';

  // Screen 3 strings
  static const String rolloverHeading =
      'Do you want your budgets to roll over?';
  static const String rolloverSubtext =
      'Anything left over or overspent carries into next month. This applies to your total and parent categories.';
  static const String rolloverYesTitle = 'Yes, roll over';
  static const String rolloverYesSubtitle =
      'OMR 800 becomes OMR 900 after saving OMR 100';
  static const String rolloverNoTitle = 'No, start fresh';
  static const String rolloverNoSubtitle =
      'Every month begins at your set amount';

  // Screen 4 strings
  static const String confirmHeading = 'Confirm your budget';
  static const String confirmSubtext =
      'Review your setup. You can edit it anytime.';
  static const String yourBudgetsLabel = 'Your budgets';
  static const String excludedCategoriesLabel = 'Excluded categories';
  static const String excludedCategoriesValue = '2 categories';
  static const String periodLabel = 'Period';
  static const String periodValue = 'First day of the month';
  static const String rollingBudgetsLabel = 'Rolling budgets';
  static const String startBudgetingLabel = 'Start budgeting';

  // Screen 5 strings
  static const String dashboardTitle = 'Budgeting';
  static const String editLabel = 'Edit';
  static const String rollingActiveLabel = 'Rolling active';
  static const String spendingLabel = 'Spending';
  static const String committedSpendingLabel = 'Committed spending';
  static const String dailyAllowanceTitle = 'Daily allowance';

  /// Canonical categories matching the Admin Portal exactly (no duplicates).
  static const List<BudgetCategoryModel> defaultCategories = [
    BudgetCategoryModel(
      id: 'food',
      name: 'Food',
      icon: Icons.restaurant_rounded,
      color: Color(0xFF10B981),
      threeMonthAverageOmr: 21.900,
      sampleSpendRatio: 0.70,
    ),
    BudgetCategoryModel(
      id: 'transport',
      name: 'Transport',
      icon: Icons.directions_car_filled_rounded,
      color: Color(0xFF3B82F6),
      threeMonthAverageOmr: 19.530,
      sampleSpendRatio: 0.55,
    ),
    BudgetCategoryModel(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF8B5CF6),
      threeMonthAverageOmr: 2.050,
      sampleSpendRatio: 0.40,
    ),
    BudgetCategoryModel(
      id: 'telecom',
      name: 'Telecom',
      icon: Icons.wifi_rounded,
      color: Color(0xFF06B6D4),
      threeMonthAverageOmr: 20.000,
      sampleSpendRatio: 0.80,
    ),
    BudgetCategoryModel(
      id: 'other',
      name: 'Other',
      icon: Icons.local_offer_rounded,
      color: Color(0xFF64748B),
      threeMonthAverageOmr: 6.790,
      sampleSpendRatio: 0.50,
    ),
    BudgetCategoryModel(
      id: 'bills',
      name: 'Bills',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
      threeMonthAverageOmr: 120.000,
      sampleSpendRatio: 0.70,
    ),
    BudgetCategoryModel(
      id: 'entertainment',
      name: 'Entertainment',
      icon: Icons.live_tv_rounded,
      color: Color(0xFFEC4899),
      threeMonthAverageOmr: 30.000,
      sampleSpendRatio: 0.50,
    ),
    BudgetCategoryModel(
      id: 'health',
      name: 'Health',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFFF43F5E),
      threeMonthAverageOmr: 20.000,
      sampleSpendRatio: 0.30,
    ),
    BudgetCategoryModel(
      id: 'business',
      name: 'Business',
      icon: Icons.work_rounded,
      color: Color(0xFF6366F1),
      threeMonthAverageOmr: 60.000,
      sampleSpendRatio: 0.35,
    ),
    BudgetCategoryModel(
      id: 'charity',
      name: 'Charity',
      icon: Icons.favorite_rounded,
      color: Color(0xFF10B981),
      threeMonthAverageOmr: 10.000,
      sampleSpendRatio: 0.50,
    ),
  ];

  /// Standard fallback base budgets (in OMR) for each canonical category.
  static const Map<String, double> defaultBaseBudgets = {
    'food': 50.000,
    'transport': 35.000,
    'shopping': 25.000,
    'bills': 120.000,
    'bills & utilities': 120.000,
    'telecom': 25.000,
    'entertainment': 30.000,
    'health': 20.000,
    'business': 60.000,
    'charity': 10.000,
    'other': 15.000,
  };

  static IconData resolveOutlineIconForCategory(String name, [String? iconKey]) {
    final lower = name.trim().toLowerCase();
    final key = (iconKey ?? '').trim().toLowerCase();
    if (lower.contains('food') ||
        lower.contains('eat') ||
        lower.contains('restaur') ||
        lower.contains('grocer') ||
        key == 'utensils' ||
        key == 'food') {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('transport') ||
        lower.contains('car') ||
        lower.contains('fuel') ||
        key == 'car') {
      return Icons.directions_car_filled_rounded;
    }
    if (lower.contains('shop') || key.contains('shopping')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('telecom') ||
        lower.contains('wifi') ||
        lower.contains('internet') ||
        key == 'wifi') {
      return Icons.wifi_rounded;
    }
    if (lower.contains('bill') ||
        lower.contains('util') ||
        lower.contains('electr') ||
        key == 'file-text' ||
        key == 'zap') {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('entertain') ||
        lower.contains('game') ||
        lower.contains('stream') ||
        key == 'tv') {
      return Icons.live_tv_rounded;
    }
    if (lower.contains('business') ||
        lower.contains('work') ||
        key == 'briefcase') {
      return Icons.work_rounded;
    }
    if (lower.contains('health') ||
        lower.contains('hospital') ||
        lower.contains('pharm') ||
        key == 'heart-pulse') {
      return Icons.monitor_heart_rounded;
    }
    if (lower.contains('charity') ||
        lower.contains('sadaq') ||
        key == 'heart') {
      return Icons.favorite_rounded;
    }
    if (lower.contains('travel') ||
        lower.contains('flight') ||
        key == 'plane') {
      return Icons.flight_takeoff_rounded;
    }
    return Icons.local_offer_rounded;
  }

  static final NumberFormat _omrFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'OMR ',
    decimalDigits: 3,
  );

  static final NumberFormat _numberOnlyFormat = NumberFormat(
    '0.000',
    'en_US',
  );

  /// Formats any amount as "OMR 690.500" (always 3 decimal places, safe against NaN/Infinity).
  static String formatOmr(double value) {
    final safe = (value.isNaN || value.isInfinite) ? 0.0 : value;
    return _omrFormat.format(safe);
  }

  /// Formats a positive number with 3 decimals without the currency prefix for text fields.
  static String formatAmountInput(double value) {
    if (value.isNaN || value.isInfinite || value <= 0) return '';
    return _numberOnlyFormat.format(value);
  }
}
