import 'package:flutter/material.dart';
import '../../../Shared/theme/app_theme.dart';
import '../heritage_theme.dart';

/// ContentTypePill — small pill label identifying content type
/// Each type has fixed colour and styling
class ContentTypePill extends StatelessWidget {
  final String
      contentType; // e.g., 'Stories', 'Food', 'Music', 'Ceremony', 'Craft', 'Place', 'Language', 'Ingredients'
  final double fontSize;
  final FontWeight fontWeight;
  final bool showEmoji;

  // Emoji mapping for content types
  static const Map<String, String> contentTypeEmoji = {
    'Stories': '📖',
    'Food': '🍳',
    'Music': '🎵',
    'Ceremony': '🕯️',
    'Craft': '🛠️',
    'Place': '📍',
    'Language': '🗣️',
    'Ingredients': '🌿',
  };

  const ContentTypePill({
    required this.contentType,
    this.fontSize = 10,
    this.fontWeight = FontWeight.w700,
    this.showEmoji = false,
    Key? key,
  }) : super(key: key);

  Color get pillColor {
    return HeritageTheme.contentTypePillColours[contentType] ??
        AppTheme.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(0.12),
        border: Border.all(
          color: pillColor.withOpacity(0.35),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(HeritageTheme.pillBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showEmoji && contentTypeEmoji.containsKey(contentType))
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                contentTypeEmoji[contentType]!,
                style: TextStyle(fontSize: fontSize + 2),
              ),
            ),
          Text(
            contentType,
            style: TextStyle(
              color: pillColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ),
    );
  }
}
