// lib/theme/heritage_tone.dart
//
// How bright the Heritage photo is right now. The Heritage page measures its
// photo and publishes the result here; the floating bottom bar reads it so its
// glass, icons and labels always contrast with what is behind them.

import 'package:flutter/foundation.dart';

class HeritageTone {
  HeritageTone._();

  /// True while the photo behind the page is dark (light ink reads on it).
  static final ValueNotifier<bool> photoDark = ValueNotifier<bool>(true);
}
