import 'package:flutter/material.dart';
import 'models/budget_models.dart';
import 'screens/category_budgets_screen.dart';
import 'screens/confirm_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/monthly_total_screen.dart';
import 'screens/rollover_screen.dart';
import 'state/budget_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/budget_widgets.dart';

/// Standalone entrypoint so `flutter run -t lib/budgeting/main.dart` can launch
/// the 5-screen Budgeting experience directly, while `BudgetingFlowView` embeds
/// seamlessly inside the main app's bottom navigation bar next to Hierarchy.
void main() {
  runApp(const BudgetingStandaloneApp());
}

class BudgetingStandaloneApp extends StatelessWidget {
  const BudgetingStandaloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThemarIP — Budgeting',
      debugShowCheckedModeBanner: false,
      theme: BudgetingTheme.lightTheme,
      home: const BudgetingFlowView(),
    );
  }
}

/// Self-contained 5-screen Budgeting module (MonthlyTotal -> CategoryBudgets ->
/// Rollover -> Confirm -> Dashboard) driven by a single in-memory [BudgetController].
class BudgetingFlowView extends StatefulWidget {
  final BudgetController? controller;
  final VoidCallback? onExitToHierarchy;
  final ValueChanged<BudgetController>? onBudgetStarted;
  final EdgeInsetsGeometry contentPadding;

  const BudgetingFlowView({
    super.key,
    this.controller,
    this.onExitToHierarchy,
    this.onBudgetStarted,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 14, 20, 96),
  });

  @override
  State<BudgetingFlowView> createState() => _BudgetingFlowViewState();
}

class _BudgetingFlowViewState extends State<BudgetingFlowView> {
  late final BudgetController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? BudgetController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BudgetingTheme.lightTheme,
      child: Container(
        color: AppColors.scaffoldBackground,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: BudgetConstants.maxContentWidth,
              ),
              child: Padding(
                padding: widget.contentPadding,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildStepScreen(_controller.currentStep),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepScreen(int step) {
    switch (step) {
      case 0:
        return MonthlyTotalScreen(
          key: const ValueKey('budget_step_0'),
          controller: _controller,
          onExit: widget.onExitToHierarchy,
          onContinue: () => _controller.setStep(1),
        );
      case 1:
        return CategoryBudgetsScreen(
          key: const ValueKey('budget_step_1'),
          controller: _controller,
          onBack: () {
            if (_controller.isBudgetActive) {
              if (widget.onExitToHierarchy != null) {
                widget.onExitToHierarchy!();
              } else {
                _controller.setStep(4);
              }
            } else {
              _controller.setStep(0);
            }
          },
          onContinue: () => _controller.setStep(2),
        );
      case 2:
        return RolloverScreen(
          key: const ValueKey('budget_step_2'),
          controller: _controller,
          onBack: () => _controller.setStep(1),
          onContinue: () => _controller.setStep(3),
        );
      case 3:
        return ConfirmScreen(
          key: const ValueKey('budget_step_3'),
          controller: _controller,
          onBack: () => _controller.setStep(2),
          onStartBudgeting: () {
            widget.onBudgetStarted?.call(_controller);
            _controller.setStep(4);
          },
        );
      case 4:
      default:
        return DashboardScreen(
          key: const ValueKey('budget_step_4'),
          controller: _controller,
          onBack: widget.onExitToHierarchy,
          onEditCategories: () => _controller.setStep(1),
        );
    }
  }
}
