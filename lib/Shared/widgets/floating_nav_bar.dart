// lib/Shared/widgets/floating_nav_bar.dart
//
// DEPRECATED — kept only so existing imports keep compiling.
//
// The bottom bar no longer floats. The app now uses a single fixed bar seated
// flush at the bottom edge: lib/Shared/widgets/canopy_bottom_bar.dart.
//
// Migrate remaining call sites to CanopyBottomBar / CanopyNavDestination and
// delete this file. Nothing here adds behaviour — these are aliases.

import 'canopy_bottom_bar.dart';

export 'canopy_bottom_bar.dart';

@Deprecated('Use CanopyNavDestination from canopy_bottom_bar.dart')
typedef FloatingNavDestination = CanopyNavDestination;

@Deprecated('Use CanopyBottomBar from canopy_bottom_bar.dart')
typedef FloatingNavBar = CanopyBottomBar;
