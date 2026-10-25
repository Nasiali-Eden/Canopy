// lib/Culture/Heritage/Services/heritage_bundled_images.dart
//
// Canopy-owned fallback photographs for Kenya's Heritage pages. They stand in
// until an organisation uploads its own banner / card / background (the
// uploaded image always wins). Returned as `asset:` URLs so every place that
// already renders a node image (HeritageMedia) handles them unchanged.

class HeritageBundledImages {
  HeritageBundledImages._();

  static const _prefix = 'asset:';
  static const _dir = 'images/heritage';

  static const _categories = {
    'oral_tradition': 'cat_stories',
    'food_tradition': 'cat_food',
    'ingredient': 'cat_ingredients',
    'music_tradition': 'cat_music',
    'instrument': 'cat_instruments',
    'ceremony': 'cat_ceremonies',
    'craft_technique': 'cat_crafts',
  };

  static bool isAsset(String? url) => url != null && url.startsWith(_prefix);
  static String assetPath(String url) => url.substring(_prefix.length);

  static String _a(String name) => '$_prefix$_dir/$name.jpg';

  /// Fallback for a hierarchy node's rectangular backdrop, or null.
  static String? bg(String nodeId) {
    if (nodeId == 'country_kenya') return _a('country_banner');
    if (nodeId.startsWith('country_kenya__cat_')) {
      final name = _categories[nodeId.substring('country_kenya__cat_'.length)];
      return name == null ? null : _a(name);
    }
    if (nodeId.startsWith('community_') && nodeId.contains('luhya')) return _a('community_luhya');
    return null;
  }

  /// Photo for an entry that has no cover of its own, by content type.
  static String? forContentType(String contentType) {
    final name = _categories[contentType];
    return name == null ? null : _a(name);
  }

  /// Fallback for the square Heritage-tab card image, or null.
  static String? card(String nodeId) => nodeId == 'country_kenya' ? _a('country_card') : null;
}
