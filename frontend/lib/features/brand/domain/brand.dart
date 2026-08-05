/// Where a logo image comes from. Each is a free, keyless service that returns
/// a real PNG for a domain (formats Flutter can decode — we avoid .ico / .svg
/// sources, which won't render).
///
/// ORDER MATTERS: we try the HIGH-RESOLUTION sources first (icon.horse and
/// allesedv both serve 200-256px logos), so the crispest image that loads wins.
/// Google's favicon service comes last as the always-reliable fallback — it's
/// low-res (often 16-48px) but resolves essentially any domain, so a logo is
/// almost always shown even when the sharp sources miss.
// High-res sources first (allesedv & icon.horse serve 200-256px). A probe (see
// LogoResolver) skips any that return a tiny placeholder, so the FIRST real
// high-res image wins. Google is the low-res but always-reliable safety net.
enum LogoSource { allesedv, iconHorse, googleLarge, googleSmall }

extension LogoSourceInfo on LogoSource {
  /// The image URL for [domain] from this source (empty domain → '').
  String urlFor(String domain) {
    if (domain.isEmpty) return '';
    switch (this) {
      case LogoSource.allesedv:
        // 256px PNGs — high-res for many brands Google serves tiny.
        return 'https://f1.allesedv.com/256/$domain';
      case LogoSource.iconHorse:
        // Crisp, up to 256px when the site publishes a large icon.
        return 'https://icon.horse/icon/$domain';
      case LogoSource.googleLarge:
        return 'https://www.google.com/s2/favicons?domain=$domain&sz=256';
      case LogoSource.googleSmall:
        return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
    }
  }
}

/// A brand/app the user can attach to an item — its display name and the domain
/// its logo is fetched from.
class Brand {
  const Brand({required this.name, required this.domain, this.source});

  final String name;

  /// The domain whose logo we fetch (e.g. 'netflix.com'). Empty for a purely
  /// user-typed name with no known domain → always uses the letter avatar.
  final String domain;

  /// The source this brand's logo was chosen from (set once the user picks a
  /// specific variant). Null → use the default best source.
  final LogoSource? source;

  /// The logo URL, from [source] if chosen, else the default best source
  /// (icon.horse, which gives the crispest brand logos).
  String get logoUrl =>
      (source ?? LogoSource.iconHorse).urlFor(domain);

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

  /// Every (domain × source) logo URL to try, in priority order: for each
  /// candidate domain, each source. The widget shows the first that loads.
  List<String> get logoUrlCandidates {
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
