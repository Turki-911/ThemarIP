import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../state/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';

/// Screen 5: DashboardScreen
/// - AppBar-style top row with a back arrow, title "Budgeting", and an "Edit"
///   TextButton that returns to the category screen (step 1).
/// - Card with "Rolling active" indicator (only if rollover is on) and a donut
///   drawn with CustomPaint (purple arc with round caps over light purple track).
///   Amount left in center ("OMR X" over "left of OMR total").
///   Below it, rows for "Spending" and "Committed spending" (OMR 0.640).
/// - "Daily allowance" card: amount left divided by days remaining in the current
///   month, including today.
/// - Card listing each budgeted category with its amount left, a rounded progress
///   bar (mint, or pink above 85% used) and "spent of budget" text.
/// - Does NOT include a Category/Merchant tab switcher or any merchant view.
class DashboardScreen extends StatelessWidget {
  final BudgetController controller;
  final VoidCallback onEditCategories;
  final VoidCallback? onBack;

  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onEditCategories,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final budgetedCategories = controller.budgetedCategories;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetWizardHeader(
              onBack: onBack ?? onEditCategories,
              centerTitle: BudgetConstants.dashboardTitle,
              trailingLabel: BudgetConstants.editLabel,
              onTrailingTap: onEditCategories,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OverviewDonutCard(controller: controller),
                    _DailyAllowanceCard(controller: controller),
                    if (budgetedCategories.isNotEmpty)
                      BudgetSurfaceCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < budgetedCategories.length;
                                i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.divider,
                                ),
                              _CategorySpendProgressRow(
                                category: budgetedCategories[i],
                                controller: controller,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewDonutCard extends StatelessWidget {
  final BudgetController controller;

  const _OverviewDonutCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final leftFormatted = BudgetConstants.formatOmr(
      controller.dashboardAmountLeft,
    );
    final totalFormatted = BudgetConstants.formatOmr(
      controller.dashboardEffectiveBudget,
    );
    final spendingFormatted = BudgetConstants.formatOmr(
      controller.totalDashboardSpending,
    );
    final committedFormatted = BudgetConstants.formatOmr(
      controller.committedSpending,
    );

    return BudgetSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.rollover)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: _RollingActiveBadge(),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: BudgetDashboardDonut(
                progress: controller.dashboardDonutFraction,
                centerAmountText: leftFormatted,
                centerSubtext: 'left of $totalFormatted',
              ),
            ),
          ),
          const SizedBox(height: 6),
          _LegendAmountRow(
            dotColor: AppColors.primaryPurple,
            label: BudgetConstants.spendingLabel,
            amountText: spendingFormatted,
          ),
          const SizedBox(height: 6),
          _LegendAmountRow(
            dotColor: AppColors.pink,
            label: BudgetConstants.committedSpendingLabel,
            amountText: committedFormatted,
          ),
        ],
      ),
    );
  }
}

class _RollingActiveBadge extends StatelessWidget {
  const _RollingActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          BudgetConstants.rollingActiveLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mint,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _LegendAmountRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String amountText;

  const _LegendAmountRow({
    required this.dotColor,
    required this.label,
    required this.amountText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            amountText,
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _DailyAllowanceCard extends StatelessWidget {
  final BudgetController controller;

  const _DailyAllowanceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = controller.daysRemainingInCurrentMonth;
    final dayWord = days == 1 ? 'day' : 'days';
    final allowanceText = BudgetConstants.formatOmr(controller.dailyAllowance);

    return BudgetSurfaceCard(
      child: Row(
        children: [
          const CategoryIconChip(icon: Icons.date_range_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BudgetConstants.dailyAllowanceTitle,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'For the next $days $dayWord',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            allowanceText,
            style: textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _CategorySpendProgressRow extends StatelessWidget {
  final BudgetCategoryModel category;
  final BudgetController controller;

  const _CategorySpendProgressRow({
    required this.category,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final budget = controller.budgetForCategory(category.id);
    final spent = controller.spentForCategory(category.id);
    final remaining = controller.remainingForCategory(category.id);
    final ratio = controller.spendRatioForCategory(category.id);
    final isWarning = ratio > BudgetConstants.overspentWarningThreshold;

    final leftText = '${BudgetConstants.formatOmr(remaining)} left';
    final spentOfBudgetText =
        '${BudgetConstants.formatOmr(spent)} of ${BudgetConstants.formatOmr(budget)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CategoryIconChip(icon: category.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.name,
                  style: textTheme.titleMedium,
                ),
              ),
              Text(
                leftText,
                style: textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? AppColors.pink : AppColors.mint,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            spentOfBudgetText,
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
