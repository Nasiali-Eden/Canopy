import 'package:flutter/material.dart';
import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';

/// VisibilityDot — small 8×8 rounded square showing visibility status
/// Accompanied by a label to its right
class VisibilityDot extends StatelessWidget {
  final String visibility; // 'public', 'community', 'restricted', 'sealed'
  final double dotSize;
  final double labelFontSize;

  const VisibilityDot({
    required this.visibility,
    this.dotSize = 8,
    this.labelFontSize = 10,
    Key? key,
  }) : super(key: key);

  Color get dotColor {
    switch (visibility.toLowerCase()) {
      case 'public':
        return HeritageTheme.visibilityPublic;
      case 'community':
        return HeritageTheme.visibilityCommunitOnly;
      case 'restricted':
        return HeritageTheme.visibilityRestricted;
      case 'sealed':
        return HeritageTheme.visibilitySealed;
      default:
        return AppTheme.darkGreen;
    }
  }

  String get visibilityLabel {
    switch (visibility.toLowerCase()) {
      case 'public':
        return 'Public';
      case 'community':
        return 'Community Only';
      case 'restricted':
        return 'Restricted';
      case 'sealed':
        return 'Sealed';
      default:
        return visibility;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 6),
        Text(
          visibilityLabel,
          style: TextStyle(
            color: AppTheme.darkGreen.withOpacity(0.5),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
