import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget_models.dart';
import '../state/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';

/// Screen 2: CategoryBudgetsScreen
/// - Heading "Set a budget for each category"
/// - Progress card showing "X% set", "OMR allocated / OMR total",
///   rounded purple LinearProgressIndicator, and "OMR N left to allocate"
///   (turns pink and says "over your total" when allocation exceeds total)
/// - Card listing each category with circular icon chip, name, "3-month avg OMR …",
///   and compact amount TextField
/// - Buttons: "Auto fill from averages" (scales averages so they sum to monthlyTotal)
///   and "Continue"
class CategoryBudgetsScreen extends StatefulWidget {
  final BudgetController controller;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const CategoryBudgetsScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<CategoryBudgetsScreen> createState() => _CategoryBudgetsScreenState();
}

class _CategoryBudgetsScreenState extends State<CategoryBudgetsScreen> {
  final Map<String, TextEditingController> _fieldControllers = {};

  TextEditingController _getControllerFor(String catId) {
    if (!_fieldControllers.containsKey(catId)) {
      final currentVal = widget.controller.budgetForCategory(catId);
      _fieldControllers[catId] = TextEditingController(
        text: currentVal > 0
            ? BudgetConstants.formatAmountInput(currentVal)
            : '',
      );
    }
    return _fieldControllers[catId]!;
  }

  @override
  void initState() {
    super.initState();
    for (final cat in widget.controller.categories) {
      _getControllerFor(cat.id);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _fieldControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _handleAutoFill() {
    FocusScope.of(context).unfocus();
    widget.controller.autoFillFromAverages();
    for (final cat in widget.controller.categories) {
      final amount = widget.controller.budgetForCategory(cat.id);
      final text = BudgetConstants.formatAmountInput(amount);
      final ctrl = _fieldControllers[cat.id];
      if (ctrl != null) {
        ctrl.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetWizardHeader(
              activeStep: 1,
              onBack: widget.onBack,
              trailingLabel: 'Re-setup',
              onTrailingTap: () {
                widget.controller.setStep(0);
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.categoryBudgetsHeading,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.categoryBudgetsSubtext,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    _AllocationProgressCard(controller: widget.controller),
                    BudgetSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < widget.controller.categories.length;
                              i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.divider,
                              ),
                            _CategoryBudgetRow(
                              category: widget.controller.categories[i],
                              textController: _getControllerFor(
                                widget.controller.categories[i].id,
                              ),
                              onChanged: (val) => widget.controller
                                  .setCategoryBudgetFromString(
                                widget.controller.categories[i].id,
                                val,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: BudgetConstants.autoFillButtonLabel,
              child: OutlinedButton(
                onPressed: _handleAutoFill,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text(
                  BudgetConstants.autoFillButtonLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: BudgetConstants.continueLabel,
              child: FilledButton(
                onPressed: widget.onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text(
                  BudgetConstants.continueLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AllocationProgressCard extends StatelessWidget {
  final BudgetController controller;

  const _AllocationProgressCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = controller.allocationPercentage;
    final allocatedStr = BudgetConstants.formatOmr(controller.totalAllocated);
    final totalStr = BudgetConstants.formatOmr(controller.monthlyTotal);
    final remaining = controller.remainingToAllocate;
    final isOver = controller.isOverAllocated;

    final statusText = isOver
        ? '${BudgetConstants.formatOmr(remaining.abs())}${BudgetConstants.overYourTotalSuffix}'
        : '${BudgetConstants.formatOmr(remaining)}${BudgetConstants.leftToAllocateSuffix}';

    return BudgetSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pct% set',
                style: textTheme.titleMedium,
              ),
              InkWell(
                onTap: () => controller.setStep(0),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$allocatedStr / $totalStr',
                        textAlign: TextAlign.right,
                        style: textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.primaryPurple,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: controller.allocationProgressFraction,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? AppColors.pink : AppColors.primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: textTheme.bodyMedium?.copyWith(
              color: isOver ? AppColors.pink : AppColors.mutedText,
              fontWeight: isOver ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  final BudgetCategoryModel category;
  final TextEditingController textController;
  final ValueChanged<String> onChanged;

  const _CategoryBudgetRow({
    required this.category,
    required this.textController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avgText =
        '3-month avg ${BudgetConstants.formatOmr(category.threeMonthAverageOmr)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CategoryIconChip(
            categoryName: category.name,
            icon: category.icon,
            color: category.color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  avgText,
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 124,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.chipGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  BudgetConstants.currencyCode,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: '${category.name} budget in OMR',
                    child: TextField(
                      controller: textController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      textAlign: TextAlign.right,
                      style: textTheme.titleMedium?.copyWith(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: '0.000',
                        hintStyle: TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: onChanged,
                    ),
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
