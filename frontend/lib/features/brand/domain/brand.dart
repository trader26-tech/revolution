/// A brand/app the user can attach to an item — its display name, the domain
/// its logo is fetched from, and an accent colour used for the letter-avatar
/// fallback when no logo loads.
class Brand {
  const Brand({required this.name, required this.domain});

  final String name;

  /// The domain whose logo we fetch (e.g. 'netflix.com'). Empty for a purely
  /// user-typed name with no known domain → always uses the letter avatar.
  final String domain;

  /// The Clearbit logo URL for this brand's domain (512px, good for retina).
  /// Empty when there's no domain.
  String get logoUrl =>
      domain.isEmpty ? '' : 'https://logo.clearbit.com/$domain?size=256';

  /// First letter for the fallback avatar.
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}
