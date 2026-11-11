import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../theme/app_theme.dart';

/// Responsive shell that wraps a budgeting screen in a SafeArea, Centers it,
/// and constrains its maximum width to 440px for phones and tablets.
class BudgetPageShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BudgetPageShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: BudgetConstants.maxContentWidth,
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Top navigation bar showing an optional back chevron, the 4-step progress indicator,
/// and an optional trailing action (e.g., "Edit" on the Dashboard).
class BudgetWizardHeader extends StatelessWidget {
  final int? activeStep;
  final VoidCallback? onBack;
  final String? centerTitle;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const BudgetWizardHeader({
    super.key,
    this.activeStep,
    this.onBack,
    this.centerTitle,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            Semantics(
              button: true,
              label: 'Back',
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onBack,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 30,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 48, height: 48),
          if (centerTitle != null)
            Text(
              centerTitle!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
            )
          else if (activeStep != null)
            _StepProgressDots(activeStep: activeStep!)
          else
            const SizedBox.shrink(),
          if (trailingLabel != null && onTrailingTap != null)
            Semantics(
              button: true,
              label: trailingLabel,
              child: TextButton(
                onPressed: onTrailingTap,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  trailingLabel!,
                  style: const TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

class _StepProgressDots extends StatelessWidget {
  final int activeStep;

  const _StepProgressDots({required this.activeStep});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Step ${activeStep + 1} of ${BudgetConstants.totalWizardSteps}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(BudgetConstants.totalWizardSteps, (index) {
          final isCompletedOrCurrent = index <= activeStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: isCompletedOrCurrent
                  ? AppColors.primaryPurple
                  : const Color(0xFFEDEBF7),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

/// White rounded card with 20px corners, subtle border and soft elevation.
class BudgetSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const BudgetSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Category Icon Chip styled identically to the Category Hierarchy page:
/// 38x38 rounded-rectangle (10px radius) with 12% opacity tint background and vibrant category glyph color.
class CategoryIconChip extends StatelessWidget {
  final IconData? icon;
  final String? categoryName;
  final Color? color;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const CategoryIconChip({
    super.key,
    this.icon,
    this.categoryName,
    this.color,
    this.size = 38,
    this.iconSize = 20,
    this.iconColor,
  });

  static Color resolveCategoryColor(String? name, [Color? explicitColor]) {
    if (explicitColor != null) return explicitColor;
    if (name == null || name.isEmpty) return const Color(0xFF7C3AED);

    final nameLower = name.toLowerCase().trim();
    if (nameLower.contains('food') ||
        nameLower.contains('grocer') ||
        nameLower.contains('restaur') ||
        nameLower.contains('coffee') ||
        nameLower.contains('eat') ||
        nameLower.contains('dining')) {
      return const Color(0xFF10B981); // Admin Portal Food: #10B981
    } else if (nameLower.contains('transport') ||
        nameLower.contains('fuel') ||
        nameLower.contains('car') ||
        nameLower.contains('taxi') ||
        nameLower.contains('petrol')) {
      return const Color(0xFF3B82F6); // Admin Portal Transport: #3B82F6
    } else if (nameLower.contains('shop') ||
        nameLower.contains('cloth') ||
        nameLower.contains('mall')) {
      return const Color(0xFF8B5CF6); // Admin Portal Shopping: #8B5CF6
    } else if (nameLower.contains('telecom') ||
        nameLower.contains('wifi') ||
        nameLower.contains('mobile') ||
        nameLower.contains('internet') ||
        nameLower.contains('phone')) {
      return const Color(0xFF06B6D4); // Admin Portal Telecom: #06B6D4
    } else if (nameLower.contains('bill') ||
        nameLower.contains('util') ||
        nameLower.contains('electr') ||
        nameLower.contains('water')) {
      return const Color(0xFFF59E0B); // Admin Portal Bills & Utilities: #F59E0B
    } else if (nameLower.contains('entertain') ||
        nameLower.contains('stream') ||
        nameLower.contains('game') ||
        nameLower.contains('movie') ||
        nameLower.contains('tv')) {
      return const Color(0xFFEC4899); // Admin Portal Entertainment: #EC4899
    } else if (nameLower.contains('health') ||
        nameLower.contains('pharm') ||
        nameLower.contains('hospital') ||
        nameLower.contains('doctor')) {
      return const Color(0xFFF43F5E); // Admin Portal Health: #F43F5E
    } else if (nameLower.contains('travel') ||
        nameLower.contains('flight') ||
        nameLower.contains('hotel')) {
      return const Color(0xFF06B6D4); // Admin Portal Travel: #06B6D4
    } else if (nameLower.contains('income') ||
        nameLower.contains('salary') ||
        nameLower.contains('deposit')) {
      return const Color(0xFF059669); // Admin Portal Income: #059669
    } else if (nameLower.contains('transfer') ||
        nameLower.contains('atm') ||
        nameLower.contains('saving')) {
      return const Color(0xFF6366F1); // Transfers
    } else if (nameLower.contains('other') ||
        nameLower.contains('uncategor')) {
      return const Color(0xFF64748B); // Admin Portal Other: #64748B
    }
    return const Color(0xFF7C3AED);
  }

  static IconData resolveCategoryIcon(String? name, [IconData? explicitIcon]) {
    if (explicitIcon != null &&
        explicitIcon != Icons.category_outlined &&
        explicitIcon != Icons.help_outline) {
      return explicitIcon;
    }
    if (name == null || name.isEmpty) return Icons.local_offer_rounded;

    final nameLower = name.toLowerCase().trim();
    if (nameLower.contains('coffee') || nameLower.contains('cafe')) {
      return Icons.coffee_rounded;
    }
    if (nameLower.contains('grocer') || nameLower.contains('supermarket')) {
      return Icons.local_grocery_store_rounded;
    }
    if (nameLower.contains('food') ||
        nameLower.contains('restaur') ||
        nameLower.contains('dining') ||
        nameLower.contains('eat')) {
      return Icons.restaurant_rounded;
    }
    if (nameLower.contains('fuel') || nameLower.contains('petrol')) {
      return Icons.local_gas_station_rounded;
    }
    if (nameLower.contains('transport') ||
        nameLower.contains('car') ||
        nameLower.contains('taxi')) {
      return Icons.directions_car_filled_rounded;
    }
    if (nameLower.contains('shop') ||
        nameLower.contains('cloth') ||
        nameLower.contains('mall')) {
      return Icons.shopping_bag_rounded;
    }
    if (nameLower.contains('telecom') ||
        nameLower.contains('wifi') ||
        nameLower.contains('mobile') ||
        nameLower.contains('internet') ||
        nameLower.contains('phone')) {
      return Icons.wifi_rounded;
    }
    if (nameLower.contains('bill') ||
        nameLower.contains('util') ||
        nameLower.contains('electr') ||
        nameLower.contains('water')) {
      return Icons.receipt_long_rounded;
    }
    if (nameLower.contains('entertain') ||
        nameLower.contains('stream') ||
        nameLower.contains('game') ||
        nameLower.contains('movie')) {
      return Icons.live_tv_rounded;
    }
    if (nameLower.contains('health') ||
        nameLower.contains('pharm') ||
        nameLower.contains('doctor') ||
        nameLower.contains('hospital')) {
      return Icons.monitor_heart_rounded;
    }
    if (nameLower.contains('travel') ||
        nameLower.contains('flight') ||
        nameLower.contains('hotel')) {
      return Icons.flight_takeoff_rounded;
    }
    if (nameLower.contains('income') ||
        nameLower.contains('salary') ||
        nameLower.contains('refund')) {
      return Icons.trending_up_rounded;
    }
    if (nameLower.contains('transfer') ||
        nameLower.contains('atm') ||
        nameLower.contains('saving')) {
      return Icons.swap_horiz_rounded;
    }
    if (nameLower.contains('business') || nameLower.contains('work')) {
      return Icons.work_rounded;
    }
    if (nameLower.contains('educat') ||
        nameLower.contains('book') ||
        nameLower.contains('school')) {
      return Icons.school_rounded;
    }
    return Icons.local_offer_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final catColor = resolveCategoryColor(categoryName, color ?? iconColor);
    final iconData = resolveCategoryIcon(categoryName, icon);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        iconData,
        size: iconSize,
        color: catColor,
      ),
    );
  }
}

/// CustomPaint donut chart used on the DashboardScreen:
/// Draws a purple arc with round caps over a light purple track (#EDE6FC).
class BudgetDashboardDonut extends StatelessWidget {
  final double progress;
  final String centerAmountText;
  final String centerSubtext;
  final double size;

  const BudgetDashboardDonut({
    super.key,
    required this.progress,
    required this.centerAmountText,
    required this.centerSubtext,
    this.size = 224,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0);

    return Semantics(
      label: '$centerAmountText $centerSubtext',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _DashboardDonutPainter(progress: safeProgress),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      centerAmountText,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      centerSubtext,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedText,
                            fontSize: 13.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardDonutPainter extends CustomPainter {
  final double progress;

  const _DashboardDonutPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 22.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = AppColors.donutTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.001) {
      final arcPaint = Paint()
        ..color = AppColors.primaryPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardDonutPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Small 64x64 donut graphic drawn with CustomPaint for the Rollover option cards.
class RolloverOptionMiniDonut extends StatelessWidget {
  final bool showRolloverSegment;
  final bool isSelected;

  const RolloverOptionMiniDonut({
    super.key,
    required this.showRolloverSegment,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _RolloverMiniDonutPainter(
          showRolloverSegment: showRolloverSegment,
          innerColor:
              isSelected ? AppColors.primaryPurpleSoft : AppColors.cardBackground,
        ),
      ),
    );
  }
}

class _RolloverMiniDonutPainter extends CustomPainter {
  final bool showRolloverSegment;
  final Color innerColor;

  const _RolloverMiniDonutPainter({
    required this.showRolloverSegment,
    required this.innerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 11.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Base track or rollover secondary segment
    final trackPaint = Paint()
      ..color = showRolloverSegment
          ? AppColors.rolloverRingAccent
          : AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Primary 78% purple arc
    final primaryPaint = Paint()
      ..color = AppColors.primaryPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * 0.78,
      false,
      primaryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RolloverMiniDonutPainter oldDelegate) {
    return oldDelegate.showRolloverSegment != showRolloverSegment ||
        oldDelegate.innerColor != innerColor;
  }
}
