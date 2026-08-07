/// Where a logo image comes from. Each is a free, keyless service that returns
/// a real PNG for a domain (formats Flutter can decode — we avoid .ico / .svg
/// sources, which won't render).
///
/// ORDER MATTERS — the first URL that loads is shown:
///  1. [googleFavicon] — Google's CURRENT favicon endpoint
///     (`t2.gstatic.com/faviconV2`). It returns a real `image/png` DIRECTLY (no
///     redirect) at up to 256px and resolves essentially any domain, so it's
///     both the most reliable AND crisp — hence first.
///  2. [iconHorse] — a sharp 200-256px source when it responds; a small free
///     service that can be slow, so it's the backup.
///  3. [googleSmall] — the legacy `google.com/s2/favicons` form as a last
///     resort (it 301-redirects, but Flutter follows redirects to a PNG).
///
/// NOTE: the old primary (`www.google.com/s2/favicons?...&sz=256`) now
/// 301-redirects to an HTML page for many domains, which Flutter can't decode —
/// that's why logos stopped loading. faviconV2 fixes it.
enum LogoSource { googleFavicon, iconHorse, googleSmall }

extension LogoSourceInfo on LogoSource {
  /// The image URL for [domain] from this source (empty domain → '').
  String urlFor(String domain) {
    if (domain.isEmpty) return '';
    switch (this) {
      case LogoSource.googleFavicon:
        // Google's current favicon service — real PNG, no redirect, up to 256px.
        return 'https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON'
            '&fallback_opts=TYPE,SIZE,URL&size=256&url=https://$domain';
      case LogoSource.iconHorse:
        return 'https://icon.horse/icon/$domain';
      case LogoSource.googleSmall:
        return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
    }
  }
}

/// A brand/app the user can attach to an item — its display name and the domain
/// its logo is fetched from.
class Brand {
  const Brand({
    required this.name,
    required this.domain,
    this.source,
    this.overrideLogoUrl,
    this.assetPath,
  });

  final String name;

  /// The domain whose logo we fetch (e.g. 'netflix.com'). Empty for a purely
  /// user-typed name with no known domain → always uses the letter avatar.
  final String domain;

  /// The source this brand's logo was chosen from (set once the user picks a
  /// specific variant). Null → use the default best source.
  final LogoSource? source;

  /// A fixed logo URL (a manually-uploaded custom logo). When set, it's used
  /// directly and wins over any domain-based guessing.
  final String? overrideLogoUrl;

  /// A logo BUNDLED with the app (e.g. 'assets/images/aadhaar.png').
  ///
  /// For brands where no network source serves a usable image — Aadhaar's
  /// favicon is capped at 16px and Wikimedia blocks hotlinking, so the mark can
  /// only be shipped locally. Wins over every network candidate, and renders
  /// instantly and offline.
  final String? assetPath;

  /// The logo URL, from [source] if chosen, else the default best source
  /// (Google's faviconV2 — reliable real PNGs for essentially any domain).
  String get logoUrl =>
      (source ?? LogoSource.googleFavicon).urlFor(domain);

  /// The same brand pinned to a specific [LogoSource].
  Brand withSource(LogoSource s) =>
      Brand(name: name, domain: domain, source: s);

  /// Candidate domains to try, in order. For a real/aliased domain it's just
  /// that one. For a plain guessed `<slug>.com` we also try `.in`, `.co`,
  /// `.app`, `.io` — so a wrong TLD guess still often finds the real logo.
  List<String> get candidateDomains {
    if (domain.isEmpty) return const [];
    if (!domain.endsWith('.com')) return [domain];
    final slug = domain.substring(0, domain.length - 4);
    return [domain, '$slug.in', '$slug.co', '$slug.app', '$slug.io'];
  }

  /// Every logo URL to try, in priority order. A custom uploaded URL wins; then
  /// (domain × source) candidates. The widget shows the first that loads.
  List<String> get logoUrlCandidates {
    if (overrideLogoUrl != null && overrideLogoUrl!.isNotEmpty) {
      return [overrideLogoUrl!];
    }
    if (source != null) {
      return candidateDomains.map((d) => source!.urlFor(d)).toList();
    }
    final urls = <String>[];
    for (final d in candidateDomains) {
      for (final s in LogoSource.values) {
        urls.add(s.urlFor(d));
      }
    }
    return urls;
  }

  /// First letter for the fallback avatar.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
