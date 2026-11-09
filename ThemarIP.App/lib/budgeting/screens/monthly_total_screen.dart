import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget_models.dart';
import '../state/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/budget_widgets.dart';

/// Screen 1: MonthlyTotalScreen
/// - Small "Welcome to budgeting" label
/// - Heading "How much do you want to spend each month?"
/// - Subtext "Include day-to-day spending and recurring payments."
/// - Large OMR TextField (numeric keyboard, decimal allowed)
/// - Tappable "3-month average OMR 690.500" that fills the field
/// - Continue button disabled until amount > 0
/// - 4-step progress indicator at the top
class MonthlyTotalScreen extends StatefulWidget {
  final BudgetController controller;
  final VoidCallback onContinue;
  final VoidCallback? onExit;

  const MonthlyTotalScreen({
    super.key,
    required this.controller,
    required this.onContinue,
    this.onExit,
  });

  @override
  State<MonthlyTotalScreen> createState() => _MonthlyTotalScreenState();
}

class _MonthlyTotalScreenState extends State<MonthlyTotalScreen> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.controller.monthlyTotal > 0
          ? BudgetConstants.formatAmountInput(widget.controller.monthlyTotal)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _fillThreeMonthAverage() {
    widget.controller.fillMonthlyTotalWithAverage();
    final formatted = BudgetConstants.formatAmountInput(
      BudgetConstants.defaultThreeMonthMonthlyAverageOmr,
    );
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final canContinue = widget.controller.monthlyTotal > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BudgetWizardHeader(
              activeStep: 0,
              onBack: widget.onExit,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      BudgetConstants.welcomeLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.monthlyTotalHeading,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      BudgetConstants.monthlyTotalSubtext,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    _LargeOmrInputCard(
                      controller: _amountController,
                      onChanged: widget.controller.setMonthlyTotalFromString,
                    ),
                    const SizedBox(height: 6),
                    _AverageSuggestionButton(
                      onTap: _fillThreeMonthAverage,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              enabled: canContinue,
              label: BudgetConstants.continueLabel,
              child: FilledButton(
                onPressed: canContinue ? widget.onContinue : null,
                child: const Text(BudgetConstants.continueLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LargeOmrInputCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _LargeOmrInputCard({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BudgetSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Text(
            BudgetConstants.currencyCode,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Monthly budget amount in OMR',
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.right,
                style: textTheme.headlineMedium?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: '0.000',
                  hintStyle: textTheme.headlineMedium?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.divider,
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
    );
  }
}

class _AverageSuggestionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AverageSuggestionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final averageFormatted = BudgetConstants.formatOmr(
      BudgetConstants.defaultThreeMonthMonthlyAverageOmr,
    );

    return Center(
      child: Semantics(
        button: true,
        label: 'Use 3-month average $averageFormatted',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: BudgetConstants.threeMonthAverageLabel),
                    TextSpan(
                      text: averageFormatted,
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
