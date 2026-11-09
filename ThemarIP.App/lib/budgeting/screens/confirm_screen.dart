import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../state/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';

/// Screen 4: ConfirmScreen
/// - Heading "Confirm your budget"
/// - Card with rows:
///   1) Your budgets (total allocated and number of categories)
///   2) Excluded categories (2 categories)
///   3) Period (First day of the month)
///   4) "Rolling budgets" Switch bound to state
/// - Button: "Start budgeting"
class ConfirmScreen extends StatelessWidget {
  final BudgetController controller;
  final VoidCallback onBack;
  final VoidCallback onStartBudgeting;

  const ConfirmScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onStartBudgeting,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final allocatedOmr = BudgetConstants.formatOmr(
          controller.dashboardEffectiveBudget,
        );
        final catCount = controller.budgetedCategoriesCount;
        final categoryWord = catCount == 1 ? 'category' : 'categories';
        final yourBudgetsValue = '$allocatedOmr across $catCount $categoryWord';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetWizardHeader(
              activeStep: 3,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.confirmHeading,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.confirmSubtext,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    BudgetSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          _ConfirmSummaryRow(
                            icon: Icons.pie_chart_outline_rounded,
                            label: BudgetConstants.yourBudgetsLabel,
                            value: yourBudgetsValue,
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.divider,
                          ),
                          const _ConfirmSummaryRow(
                            icon: Icons.visibility_off_outlined,
                            label: BudgetConstants.excludedCategoriesLabel,
                            value: BudgetConstants.excludedCategoriesValue,
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.divider,
                          ),
                          const _ConfirmSummaryRow(
                            icon: Icons.calendar_today_outlined,
                            label: BudgetConstants.periodLabel,
                            value: BudgetConstants.periodValue,
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.divider,
                          ),
                          _RollingSwitchRow(
                            value: controller.rollover,
                            onChanged: controller.setRollover,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: BudgetConstants.startBudgetingLabel,
              child: FilledButton(
                onPressed: onStartBudgeting,
                child: const Text(BudgetConstants.startBudgetingLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConfirmSummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          CategoryIconChip(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RollingSwitchRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RollingSwitchRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const CategoryIconChip(icon: Icons.autorenew_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              BudgetConstants.rollingBudgetsLabel,
              style: textTheme.titleMedium,
            ),
          ),
          Semantics(
            toggled: value,
            label: BudgetConstants.rollingBudgetsLabel,
            child: SizedBox(
              height: 48,
              child: Switch(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
