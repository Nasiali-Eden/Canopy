// lib/theme/canopy_map_style.dart
//
// Google Maps JSON styles built from CanopyMapColors (canopy_tokens.dart):
// POI icons, transit and business labels off; parks and water on. Use
// `canopyMapStyle(context)` for the GoogleMap `style:` parameter so the map
// follows the app's light/dark theme.

import 'package:flutter/material.dart';

import 'canopy_components.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String canopyMapStyleFor(CanopyMapColors c) => '''[
  {"elementType":"geometry","stylers":[{"color":"${_hex(c.land)}"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"${_hex(c.label)}"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"${_hex(c.land)}"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","stylers":[{"visibility":"on"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"${_hex(c.park)}"}]},
  {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"${_hex(c.road)}"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"${_hex(c.roadMajor)}"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"${_hex(c.built)}"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"${_hex(c.water)}"}]}
]''';

String canopyMapStyle(BuildContext context) =>
    canopyMapStyleFor(context.canopy.map);
