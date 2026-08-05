import '../../../core/api/api_client.dart';
import '../domain/brand.dart';

/// A manually-curated logo from the server (`brand_logos` table) — for apps the
/// auto-resolver can't find. Matched against the user's typed text.
class CustomLogo {
  const CustomLogo({
    required this.name,
    required this.category,
    required this.keywords,
    required this.logoUrl,
  });

  final String name;
  final String category;
  final String keywords;
  final String logoUrl;

  factory CustomLogo.fromJson(Map<String, dynamic> j) => CustomLogo(
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? 'Other',
        keywords: j['keywords'] as String? ?? '',
        logoUrl: j['logo_url'] as String? ?? '',
      );

  /// A Brand that renders this exact uploaded image (its logoUrl is fixed).
  Brand toBrand() => Brand(name: name, domain: '', overrideLogoUrl: logoUrl);
}

/// Loads the curated logos once and matches the user's text against them, so a
/// manual entry always wins over the domain-guessing resolver.
class CustomLogoStore {
  CustomLogoStore._();
  static final CustomLogoStore instance = CustomLogoStore._();

  final ApiClient _api = ApiClient.instance;
  List<CustomLogo> _logos = [];
  bool _loaded = false;

  /// Fetch the curated logos from the server. Best-effort; failure = no
  /// overrides (the resolver still works).
  Future<void> load() async {
    try {
      final data = await _api.get('/brand-logos') as List;
      _logos = data
          .map((e) => CustomLogo.fromJson(e as Map<String, dynamic>))
          .toList();
      _loaded = true;
    } catch (_) {
      _logos = [];
    }
  }

  bool get isLoaded => _loaded;

  /// Auto-save a brand the user picked, so the curated set grows from real
  /// usage. Best-effort + idempotent (server ignores duplicate names). Skips
  /// brands that have no usable logo URL.
  Future<void> saveUserPick(Brand brand, {String category = 'Other'}) async {
    final urls = brand.logoUrlCandidates;
    if (urls.isEmpty) return;
    // Don't re-save something we already have a curated match for.
    if (match(brand.name) != null) return;
    try {
      await _api.post('/brand-logos', {
        'name': brand.name,
        'logo_url': urls.first,
        'category': category,
        'keywords': brand.name.toLowerCase(),
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  /// The best curated match for [query], or null if none is close enough.
  CustomLogo? match(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _logos.isEmpty) return null;

    CustomLogo? best;
    var bestScore = 0;
    for (final logo in _logos) {
      final hay = '${logo.name} ${logo.keywords}'.toLowerCase();
      final score = _score(q, logo.name.toLowerCase(), hay);
      if (score > bestScore) {
        bestScore = score;
        best = logo;
      }
    }
    // Require a real signal, not an incidental substring.
    return bestScore >= 2 ? best : null;
  }

  /// Simple relevance score: exact name = strongest, then name-contains, then a
  /// keyword token match.
  int _score(String q, String name, String haystack) {
    if (name == q) return 100;
    if (name.startsWith(q) || q.startsWith(name)) return 20;
    if (name.contains(q) || q.contains(name)) return 10;
    // Token overlap against the keyword blob.
    final qTokens = q.split(RegExp(r'\s+')).where((t) => t.length >= 2);
    var hits = 0;
    for (final t in qTokens) {
      if (haystack.contains(t)) hits += 2;
    }
    return hits;
  }
}
