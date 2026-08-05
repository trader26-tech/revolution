import '../domain/brand.dart';

/// Maps typed names → logo domains, and provides popular suggestions.
///
/// The user can type *any* name; if we know a domain for it (or can guess one),
/// we fetch that brand's real logo. Otherwise the name still works — it just
/// shows a coloured letter-avatar. So coverage is effectively unlimited.
class BrandCatalog {
  const BrandCatalog._();

  /// Curated popular brands across the things this app tracks — streaming,
  /// Indian banks, brokers/investing, insurers, utilities. Shown as instant
  /// suggestions before the user even types.
  static const List<Brand> popular = [
    // Streaming / subscriptions
    Brand(name: 'Netflix', domain: 'netflix.com'),
    Brand(name: 'Amazon Prime', domain: 'primevideo.com'),
    Brand(name: 'Spotify', domain: 'spotify.com'),
    Brand(name: 'YouTube', domain: 'youtube.com'),
    Brand(name: 'Disney+ Hotstar', domain: 'hotstar.com'),
    Brand(name: 'Apple', domain: 'apple.com'),
    // Indian banks
    Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'),
    Brand(name: 'ICICI Bank', domain: 'icicibank.com'),
    Brand(name: 'SBI', domain: 'sbi.co.in'),
    Brand(name: 'Axis Bank', domain: 'axisbank.com'),
    Brand(name: 'Kotak', domain: 'kotak.com'),
    // Investing / brokers
    Brand(name: 'Zerodha', domain: 'zerodha.com'),
    Brand(name: 'Groww', domain: 'groww.in'),
    Brand(name: 'Upstox', domain: 'upstox.com'),
    Brand(name: 'Coin (Zerodha)', domain: 'coin.zerodha.com'),
    // Insurance
    Brand(name: 'LIC', domain: 'licindia.in'),
    Brand(name: 'HDFC Life', domain: 'hdfclife.com'),
    Brand(name: 'Star Health', domain: 'starhealth.in'),
    // Utilities / telecom
    Brand(name: 'Airtel', domain: 'airtel.in'),
    Brand(name: 'Jio', domain: 'jio.com'),
    Brand(name: 'Google', domain: 'google.com'),
  ];

  /// A few common name → domain aliases so short/informal names still resolve.
  static const Map<String, String> _aliases = {
    'prime': 'primevideo.com',
    'amazon prime': 'primevideo.com',
    'hotstar': 'hotstar.com',
    'disney': 'hotstar.com',
    'sbi': 'sbi.co.in',
    'lic': 'licindia.in',
    'hdfc': 'hdfcbank.com',
    'icici': 'icicibank.com',
    'axis': 'axisbank.com',
    'kotak': 'kotak.com',
    'jio': 'jio.com',
    'airtel': 'airtel.in',
    'groww': 'groww.in',
    'zerodha': 'zerodha.com',
    'upstox': 'upstox.com',
    'youtube': 'youtube.com',
    'netflix': 'netflix.com',
    'spotify': 'spotify.com',
  };

  /// Best-effort brand for a free-typed query. Resolution order:
  ///   1. exact match against a popular brand's name,
  ///   2. an alias,
  ///   3. if the query already looks like a domain, use it,
  ///   4. otherwise guess `<slug>.com` (works for a surprising number of apps),
  ///      still falling back to a letter-avatar if that logo 404s.
  static Brand resolve(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();

    for (final b in popular) {
      if (b.name.toLowerCase() == lower) return b;
    }
    if (_aliases.containsKey(lower)) {
      return Brand(name: q, domain: _aliases[lower]!);
    }
    if (_looksLikeDomain(lower)) {
      return Brand(name: q, domain: lower);
    }
    final slug = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (slug.isEmpty) return Brand(name: q, domain: '');
    return Brand(name: q, domain: '$slug.com');
  }

  /// Popular brands whose name contains [query] (for the live suggestion list).
  ///
  /// The free-typed guess goes first (so ANY name works), then matching popular
  /// brands. The whole list is de-duplicated by domain so the same logo never
  /// appears twice.
  static List<Brand> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return popular;

    final ordered = <Brand>[
      resolve(query), // the typed guess, first
      ...popular.where((b) => b.name.toLowerCase().contains(q)),
    ];

    final seen = <String>{};
    final out = <Brand>[];
    for (final b in ordered) {
      // Key on domain (or lowercase name when there's no domain) so duplicates
      // pointing at the same logo collapse to one entry.
      final key = b.domain.isNotEmpty ? b.domain : 'name:${b.name.toLowerCase()}';
      if (seen.add(key)) out.add(b);
    }
    return out;
  }

  static bool _looksLikeDomain(String s) =>
      RegExp(r'^[a-z0-9-]+\.[a-z.]{2,}$').hasMatch(s);
}
