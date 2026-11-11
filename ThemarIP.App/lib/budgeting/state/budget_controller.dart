import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/bmpf_models.dart';
import '../models/budget_models.dart';

/// Single in-memory ChangeNotifier managing the Budgeting flow AND
/// reflecting configured budgets directly into the Category Hierarchy screen.
class BudgetController extends ChangeNotifier {
  double _monthlyTotal = 200.0;
  List<BudgetCategoryModel> _categories = List.of(
    BudgetConstants.defaultCategories,
  );
  final Map<String, double> _categoryBudgets = {};
  final Map<String, double> _sampleSpendRatios = {
    for (final cat in BudgetConstants.defaultCategories)
      cat.id: cat.sampleSpendRatio,
  };
  bool _rollover = true;
  int _currentStep = 0;
  bool _isBudgetActive = false;

  List<BudgetCategoryModel> get categories => List.unmodifiable(_categories);

  double get monthlyTotal => _monthlyTotal;
  Map<String, double> get categoryBudgets =>
      Map.unmodifiable(_categoryBudgets);
  Map<String, double> get sampleSpendRatios =>
      Map.unmodifiable(_sampleSpendRatios);
  bool get rollover => _rollover;
  int get currentStep => _currentStep;
  bool get isBudgetActive => _isBudgetActive;

  static String _normalizeKey(String raw) {
    return raw.trim().toLowerCase();
  }

  /// Synchronizes the budgeting categories with the user's live Categorization
  /// (`BmpfCategoryNode` list from Category Hierarchy) so Budgeting and
  /// Categorization share the exact same categories and actual spent amounts
  /// (`P1_FinalSpentBaisa` / `node.totalAmount`).
  void syncWithHierarchyCategories(
    List<BmpfCategoryNode> rawNodes, {
    List<BmpfCategoryNode>? activePeriodNodes,
  }) {
    if (rawNodes.isEmpty) return;

    // Map active period spent amounts by category name/id
    final periodSpentByName = <String, double>{};
    final periodTxCountByName = <String, int>{};
    final sourceForPeriod = activePeriodNodes ?? rawNodes;
    for (final node in sourceForPeriod) {
      final key = _normalizeKey(node.name);
      // Calculate debit spend (excluding Income credits)
      double debitSpend = 0.0;
      if (node.transactions.isNotEmpty) {
        for (final tx in node.transactions) {
          final isCredit = tx.direction.toUpperCase() == 'CREDIT' ||
              key == 'income' ||
              (tx.narration.toLowerCase().contains('has been credited') &&
                  !tx.narration.toLowerCase().contains('is debited'));
          if (!isCredit) {
            debitSpend += tx.amount;
          }
        }
      } else if (key != 'income') {
        debitSpend = node.totalAmount;
      }
      periodSpentByName[key] = debitSpend;
      periodTxCountByName[key] = node.txnCount;
    }

    // Build unified category list from the user's actual Categorization nodes
    // (excluding Income and Transfers which are non-expense / excluded categories).
    final synced = <BudgetCategoryModel>[];
    final seenKeys = <String>{};

    for (final node in rawNodes) {
      final key = _normalizeKey(node.name);
      if (key == 'income' || key == 'transfers' || seenKeys.contains(key)) {
        continue;
      }

      final activeSpend = periodSpentByName[key] ?? 0.0;
      final txCount = periodTxCountByName[key] ?? node.txnCount;

      final defaultMatch = BudgetConstants.defaultCategories.where(
        (d) => _normalizeKey(d.name) == key || _normalizeKey(d.id) == key,
      );
      final fallbackAvg = defaultMatch.isNotEmpty
          ? defaultMatch.first.threeMonthAverageOmr
          : (BudgetConstants.defaultBaseBudgets[key] ?? 30.000);
      final fallbackRatio = defaultMatch.isNotEmpty
          ? defaultMatch.first.sampleSpendRatio
          : 0.50;

      seenKeys.add(key);
      synced.add(
        BudgetCategoryModel(
          id: key,
          name: node.name,
          icon: BudgetConstants.resolveOutlineIconForCategory(
            node.name,
            node.icon,
          ),
          threeMonthAverageOmr: activeSpend > 0 ? activeSpend : fallbackAvg,
          sampleSpendRatio: fallbackRatio,
          liveSpentOmr: activeSpend,
          liveTxnCount: txCount,
        ),
      );
      _sampleSpendRatios.putIfAbsent(key, () => fallbackRatio);
    }

    if (synced.isNotEmpty) {
      // Sort so categories with live spend appear first (matching Category Hierarchy order)
      synced.sort((a, b) {
        final aHasSpend = (a.liveSpentOmr ?? 0) > 0 ? 0 : 1;
        final bHasSpend = (b.liveSpentOmr ?? 0) > 0 ? 0 : 1;
        if (aHasSpend != bHasSpend) return aHasSpend.compareTo(bHasSpend);
        return 0;
      });
      _categories = synced;
      notifyListeners();
    }
  }

  /// Applies saved budget data returned from `/api/budgeting/overview`.
  void applyServerOverview(Map<String, dynamic> data) {
    final hasBudget = data['hasConfiguredBudget'] == true;
    if (!hasBudget) {
      _isBudgetActive = false;
      _monthlyTotal = 0.0;
      _categoryBudgets.clear();
      notifyListeners();
      return;
    }

    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      final totalOmr =
          (settings['totalMonthlyBudgetOmr'] as num?)?.toDouble() ?? 0.0;
      _monthlyTotal = totalOmr;
      _isBudgetActive = totalOmr > 0;
      _rollover = settings['rolloverEnabled'] != false;
    }

    _categoryBudgets.clear();
    final serverCats = data['categories'] as List?;
    if (serverCats != null && serverCats.isNotEmpty) {
      for (final item in serverCats) {
        if (item is Map<String, dynamic>) {
          final name = (item['categoryName']?.toString() ?? '').trim();
          final baseOmr = (item['baseAmountOmr'] as num?)?.toDouble() ?? 0.0;
          if (name.isNotEmpty && baseOmr > 0) {
            final key = _normalizeKey(name);
            _categoryBudgets[key] = baseOmr;
          }
        }
      }
    }
    notifyListeners();
  }

  void markBudgetStarted() {
    _isBudgetActive = true;
    notifyListeners();
  }

  /// Parses user text safely: strips non-numeric characters, treats empty/invalid as 0.0.
  static double parseSafeAmount(String raw) {
    if (raw.trim().isEmpty) return 0.0;
    final sanitized = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (sanitized.isEmpty) return 0.0;
    final firstDot = sanitized.indexOf('.');
    final normalized = firstDot == -1
        ? sanitized
        : sanitized.substring(0, firstDot + 1) +
            sanitized.substring(firstDot + 1).replaceAll('.', '');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return 0.0;
    }
    return parsed;
  }

  void setStep(int step) {
    final clamped = step.clamp(0, 4);
    if (_currentStep != clamped) {
      _currentStep = clamped;
      notifyListeners();
    }
  }

  void nextStep() => setStep(_currentStep + 1);
  void previousStep() => setStep(_currentStep - 1);

  void setMonthlyTotal(double amount) {
    final safe = (amount.isNaN || amount.isInfinite || amount < 0)
        ? 0.0
        : amount;
    if (_monthlyTotal != safe) {
      _monthlyTotal = safe;
      notifyListeners();
    }
  }

  void setMonthlyTotalFromString(String text) {
    setMonthlyTotal(parseSafeAmount(text));
  }

  void fillMonthlyTotalWithAverage() {
    setMonthlyTotal(BudgetConstants.defaultThreeMonthMonthlyAverageOmr);
  }

  bool hasBudgetForCategory(String categoryIdOrName) {
    if (!_isBudgetActive || _monthlyTotal <= 0) return false;
    final key = _normalizeKey(categoryIdOrName);
    return (_categoryBudgets[key] ?? 0.0) > 0;
  }

  /// Looks up the configured base budget (`P1_BaseBaisa / 1000.0`) for a category.
  /// If no budget has been set up, returns 0.0 (no estimated budget added).
  double budgetForCategory(String categoryIdOrName) {
    if (!_isBudgetActive || _monthlyTotal <= 0) return 0.0;
    final key = _normalizeKey(categoryIdOrName);
    return _categoryBudgets[key] ?? 0.0;
  }

  void setCategoryBudget(String categoryIdOrName, double amount) {
    final key = _normalizeKey(categoryIdOrName);
    final safe = (amount.isNaN || amount.isInfinite || amount < 0)
        ? 0.0
        : amount;
    if (_categoryBudgets[key] != safe) {
      _categoryBudgets[key] = safe;
      notifyListeners();
    }
  }

  void setCategoryBudgetFromString(String categoryIdOrName, String text) {
    setCategoryBudget(categoryIdOrName, parseSafeAmount(text));
  }

  /// Auto-fills category budgets by scaling the category averages
  /// proportionally so their sum equals [monthlyTotal].
  void autoFillFromAverages() {
    final sumAverages = _categories.fold<double>(
      0.0,
      (sum, c) => sum + c.threeMonthAverageOmr,
    );
    if (sumAverages <= 0) return;

    final targetTotal = _monthlyTotal > 0 ? _monthlyTotal : sumAverages;
    final scale = targetTotal / sumAverages;

    double runningBaisaSum = 0;
    final totalTargetBaisa = (targetTotal * 1000).roundToDouble();

    for (var i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final key = _normalizeKey(cat.id);
      if (i == _categories.length - 1) {
        final remainderBaisa = math.max(0.0, totalTargetBaisa - runningBaisaSum);
        _categoryBudgets[key] = remainderBaisa / 1000.0;
      } else {
        final scaledBaisa =
            (cat.threeMonthAverageOmr * scale * 1000).roundToDouble();
        runningBaisaSum += scaledBaisa;
        _categoryBudgets[key] = scaledBaisa / 1000.0;
      }
    }
    notifyListeners();
  }

  void setRollover(bool value) {
    if (_rollover != value) {
      _rollover = value;
      notifyListeners();
    }
  }

  /// Total amount allocated across all categories.
  double get totalAllocated {
    return _categories.fold<double>(
      0.0,
      (sum, c) => sum + budgetForCategory(c.id),
    );
  }

  /// Difference between [monthlyTotal] and [totalAllocated] (negative when over total).
  double get remainingToAllocate => _monthlyTotal - totalAllocated;

  bool get isOverAllocated => remainingToAllocate < -0.0004;

  /// Percentage (0..100) of [monthlyTotal] currently allocated.
  int get allocationPercentage {
    if (_monthlyTotal <= 0) return 0;
    final ratio = (totalAllocated / _monthlyTotal) * 100.0;
    if (ratio.isNaN || ratio.isInfinite) return 0;
    return ratio.round().clamp(0, 100);
  }

  /// Progress bar fraction (0.0 .. 1.0) for allocation.
  double get allocationProgressFraction {
    if (_monthlyTotal <= 0) return 0.0;
    final fraction = totalAllocated / _monthlyTotal;
    if (fraction.isNaN || fraction.isInfinite) return 0.0;
    return fraction.clamp(0.0, 1.0);
  }

  /// Categories that have a budget > 0 configured.
  List<BudgetCategoryModel> get budgetedCategories {
    return _categories.where((c) => budgetForCategory(c.id) > 0).toList();
  }

  int get budgetedCategoriesCount => budgetedCategories.length;

  /// Effective total budget used on the dashboard (sum of allocated categories if > 0, else monthlyTotal).
  double get dashboardEffectiveBudget {
    final allocated = totalAllocated;
    return allocated > 0 ? allocated : _monthlyTotal;
  }

  /// Actual spent amount (`P1_FinalSpentBaisa / 1000.0`) for a category.
  double spentForCategory(String categoryIdOrName) {
    final key = _normalizeKey(categoryIdOrName);
    final match = _categories.where(
      (c) => _normalizeKey(c.id) == key || _normalizeKey(c.name) == key,
    );
    if (match.isNotEmpty && match.first.liveSpentOmr != null) {
      return match.first.liveSpentOmr!;
    }
    final budget = budgetForCategory(key);
    final ratio = _sampleSpendRatios[key] ?? 0.50;
    return ((budget * ratio * 1000).round()) / 1000.0;
  }

  /// Remaining amount for a category: `P1_BaseBaisa - P1_FinalSpentBaisa` (in OMR).
  double signedRemainingForCategory(String categoryIdOrName, {double? actualSpentOmr}) {
    final budget = budgetForCategory(categoryIdOrName);
    final spent = actualSpentOmr ?? spentForCategory(categoryIdOrName);
    return ((budget - spent) * 1000).round() / 1000.0;
  }

  /// Clamped remaining amount (>= 0).
  double remainingForCategory(String categoryIdOrName) {
    return math.max(0.0, signedRemainingForCategory(categoryIdOrName));
  }

  /// Spend ratio (0.0 .. 1.0+) for a category: `P1_FinalSpentBaisa / P1_BaseBaisa`.
  double spendRatioForCategory(String categoryIdOrName, {double? actualSpentOmr}) {
    final budget = budgetForCategory(categoryIdOrName);
    if (budget <= 0) return 0.0;
    final spent = actualSpentOmr ?? spentForCategory(categoryIdOrName);
    final ratio = spent / budget;
    if (ratio.isNaN || ratio.isInfinite) return 0.0;
    return math.max(0.0, ratio);
  }

  /// Total normal spending across budgeted categories.
  double get totalDashboardSpending {
    return budgetedCategories.fold<double>(
      0.0,
      (sum, c) => sum + spentForCategory(c.id),
    );
  }

  /// Total spending across active budgeted categories.
  double get totalSpent => totalDashboardSpending;

  /// Whether the user has an active, configured budget.
  bool get hasConfiguredBudget =>
      _isBudgetActive && _monthlyTotal > 0 && (_categoryBudgets.values.any((v) => v > 0) || _categoryBudgets.isNotEmpty);

  /// Total remaining allowance from monthlyTotal minus spending.
  double get remainingTotal {
    final effective = _monthlyTotal > 0 ? _monthlyTotal : totalAllocated;
    final remaining = effective - totalSpent;
    return remaining < 0 ? 0.0 : remaining;
  }

  double get committedSpending => BudgetConstants.committedSpendingOmr;

  /// Amount left in the period (never negative or NaN).
  double get dashboardAmountLeft {
    final budget = dashboardEffectiveBudget;
    if (budget <= 0) return 0.0;
    final left = budget - totalDashboardSpending - committedSpending;
    if (left.isNaN || left.isInfinite || left < 0) return 0.0;
    return left;
  }

  /// Donut progress fraction (0.0 .. 1.0).
  double get dashboardDonutFraction {
    final budget = dashboardEffectiveBudget;
    if (budget <= 0) return 0.0;
    final used = (totalDashboardSpending + committedSpending) / budget;
    if (used.isNaN || used.isInfinite) return 0.0;
    return used.clamp(0.0, 1.0);
  }

  /// Days remaining in the current month, including today.
  int get daysRemainingInCurrentMonth {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return math.max(1, daysInMonth - now.day + 1);
  }

  /// Daily allowance = amount left divided by days remaining in the current month.
  double get dailyAllowance {
    final days = daysRemainingInCurrentMonth;
    if (days <= 0) return 0.0;
    final allowance = dashboardAmountLeft / days;
    if (allowance.isNaN || allowance.isInfinite || allowance < 0) return 0.0;
    return allowance;
  }
}
