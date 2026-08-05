/// Where a logo image comes from. Each is a free, keyless service that returns
/// a real PNG for a domain (formats Flutter can decode — we deliberately avoid
/// .ico / .svg sources like DuckDuckGo, which won't render). We show the SAME
/// brand from several sources so the user can pick the crispest — like choosing
/// from search results.
enum LogoSource { iconHorse, googleLarge, googleSmall }

extension LogoSourceInfo on LogoSource {
  /// The image URL for [domain] from this source (empty domain → '').
  String urlFor(String domain) {
    if (domain.isEmpty) return '';
    switch (this) {
      case LogoSource.iconHorse:
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

  /// First letter for the fallback avatar.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
