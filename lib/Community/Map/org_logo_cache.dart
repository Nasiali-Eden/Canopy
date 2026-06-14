// lib/Community/Map/org_logo_cache.dart
//
// Process-wide cache of organisation logo image BYTES, warmed up at app start so
// the map's logo markers render immediately instead of downloading on open.
//
// We cache raw bytes (not a decoded image or BitmapDescriptor) because the map
// decodes each logo at two sizes (normal + hero) — the slow part is the network
// fetch, which this de-duplicates and pre-runs. `bytes(url)` caches the Future,
// so warmUp() and the later map call share one download.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class OrgLogoCache {
  OrgLogoCache._();
  static final OrgLogoCache instance = OrgLogoCache._();

  final Map<String, Future<Uint8List?>> _bytes = {};

  /// Cached logo bytes for [url] (null if it failed). Safe to call repeatedly —
  /// the in-flight/resolved Future is reused.
  Future<Uint8List?> bytes(String url) =>
      _bytes.putIfAbsent(url, () => _download(url));

  Future<Uint8List?> _download(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 12));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      final data = Uint8List.fromList(
        await resp.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk)),
      );
      client.close(force: true);
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Kick off downloads for every org logo at app start. Fire-and-forget; the
  /// caller should NOT await this (it runs in the background).
  Future<void> warmUp() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('organizations').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final url = (data['logoUrl'] ?? data['profilePhoto']) as String?;
        if (url != null && url.isNotEmpty) {
          // Start the download; the Future is cached for the map to await later.
          bytes(url);
        }
      }
    } catch (_) {
      // Offline / permission — the map will lazily fetch on open instead.
    }
  }
}
