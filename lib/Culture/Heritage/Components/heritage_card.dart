import 'package:flutter/material.dart';
import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';

/// HeritageCard — reusable card wrapper for Layer 4
/// Features warm background, gold-tinted shadows, consistent styling
class HeritageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final BorderSide? leftBorder; // For dispute/status indicators
  final VoidCallback? onTap;

  const HeritageCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.leftBorder,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: HeritageTheme.heritageCardBackground,
        borderRadius: BorderRadius.circular(HeritageTheme.cardBorderRadius),
        boxShadow: [HeritageTheme.heritageCardShadow],
        border: leftBorder != null ? Border(left: leftBorder!) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HeritageTheme.cardBorderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
