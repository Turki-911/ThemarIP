import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../state/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';

/// Screen 3: RolloverScreen
/// - Heading "Do you want your budgets to roll over?"
/// - Two selectable option cards in a 2-column row, each with a small donut graphic
///   drawn with CustomPaint:
///   1) "Yes, roll over" (OMR 800 becomes OMR 900 after saving OMR 100)
///   2) "No, start fresh" (Every month begins at your set amount)
/// - Selected card has a 2px purple border and soft purple tint (#F0E8FE)
/// - Button: "Continue"
class RolloverScreen extends StatelessWidget {
  final BudgetController controller;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const RolloverScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isRollover = controller.rollover;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetWizardHeader(
              activeStep: 2,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.rolloverHeading,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.rolloverSubtext,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _RolloverOptionCard(
                              title: BudgetConstants.rolloverYesTitle,
                              subtitle: BudgetConstants.rolloverYesSubtitle,
                              showRolloverSegment: true,
                              isSelected: isRollover,
                              onTap: () => controller.setRollover(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RolloverOptionCard(
                              title: BudgetConstants.rolloverNoTitle,
                              subtitle: BudgetConstants.rolloverNoSubtitle,
                              showRolloverSegment: false,
                              isSelected: !isRollover,
                              onTap: () => controller.setRollover(false),
                            ),
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
              label: BudgetConstants.continueLabel,
              child: FilledButton(
                onPressed: onContinue,
                child: const Text(BudgetConstants.continueLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RolloverOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showRolloverSegment;
  final bool isSelected;
  final VoidCallback onTap;

  const _RolloverOptionCard({
    required this.title,
    required this.subtitle,
    required this.showRolloverSegment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $subtitle',
      child: Material(
        color: isSelected
            ? AppColors.primaryPurpleSoft
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryPurple
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RolloverOptionMiniDonut(
                  showRolloverSegment: showRolloverSegment,
                  isSelected: isSelected,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.labelSmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
