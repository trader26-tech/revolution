/// A brand/app the user can attach to an item — its display name, the domain
/// its logo is fetched from, and an accent colour used for the letter-avatar
/// fallback when no logo loads.
class Brand {
  const Brand({required this.name, required this.domain});

  final String name;

  /// The domain whose logo we fetch (e.g. 'netflix.com'). Empty for a purely
  /// user-typed name with no known domain → always uses the letter avatar.
  final String domain;

  /// The logo URL for this brand's domain — Google's favicon service, which is
  /// rock-solid reliable and returns a real image for effectively any domain
  /// (128px). Empty when there's no domain (→ letter-avatar fallback).
  ///
  /// (We moved off Clearbit's logo API — it was discontinued and now fails, so
  /// no logos loaded.)
  String get logoUrl => domain.isEmpty
      ? ''
      : 'https://www.google.com/s2/favicons?domain=$domain&sz=128';

  /// First letter for the fallback avatar.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
