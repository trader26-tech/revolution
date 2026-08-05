import 'package:http/http.dart' as http;

import '../domain/brand.dart';

/// Resolves the best logo URL for a brand by actually probing the candidate
/// sources and choosing the first that returns a real, reasonably-sized image.
///
/// Why probe instead of just letting `Image.network` try in order? Some sources
/// return a *valid but useless* image on a miss (e.g. allesedv serves a 51-byte
/// 1×1 GIF). `Image.network` would happily "succeed" on that and stop, showing a
/// blank. Probing lets us skip those and land on a source that has a real logo.
///
/// Results are cached per (domain) so we probe each brand only once per session.
class LogoResolver {
  LogoResolver._();
  static final LogoResolver instance = LogoResolver._();

  final Map<String, String?> _cache = {};
  final http.Client _client = http.Client();

  /// Returns the best working logo URL for [brand], or null if none qualifies
  /// (→ caller shows the letter avatar). Cached by the brand's candidate set.
  Future<String?> resolve(Brand brand) async {
    final candidates = brand.logoUrlCandidates;
    if (candidates.isEmpty) return null;

    final key = candidates.first; // stable per brand/domain
    if (_cache.containsKey(key)) return _cache[key];

    for (final url in candidates) {
      if (await _isRealImage(url)) {
        _cache[key] = url;
        return url;
      }
    }
    _cache[key] = null;
    return null;
  }

  /// A URL qualifies if it returns 200, an image content-type, and enough bytes
  /// to be a real logo (filters out 1×1 placeholder gifs / empty responses).
  Future<bool> _isRealImage(String url) async {
    try {
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return false;
      final type = (res.headers['content-type'] ?? '').toLowerCase();
      final isImage = type.startsWith('image/');
      // Flutter can't render svg/ico via Image.network; and .gif from these
      // services is almost always a placeholder (a real logo is png/jpeg).
      final renderable = !type.contains('svg') &&
          !type.contains('icon') &&
          !type.contains('gif');
      // Real logos are comfortably larger than a placeholder; 600 bytes filters
      // tiny 16×16 favicons while keeping genuine small PNG logos.
      final bigEnough = res.bodyBytes.length >= 600;
      return isImage && renderable && bigEnough;
    } catch (_) {
      return false;
    }
  }
}
