/// A dialing country for the phone-number picker.
class CountryCode {
  const CountryCode({
    required this.iso,
    required this.dial,
    required this.flag,
    required this.name,
    this.maxLen = 15,
    this.groups = const [5, 5],
  });

  final String iso; // 'IN'
  final String dial; // '+91'
  final String flag; // 🇮🇳
  final String name; // 'India'

  /// Max national-number length (rough), used for light validation.
  final int maxLen;

  /// How to space the national number for readability, left-to-right. E.g. India
  /// is [5, 5] → "98765 43210"; US is [3, 3, 4] → "987 654 3210". Leftover
  /// digits beyond the pattern are appended in one final group.
  final List<int> groups;

  /// Format [digits] (national part, digits only) with this country's spacing.
  String format(String digits) {
    if (digits.isEmpty) return '';
    final out = <String>[];
    var i = 0;
    for (final g in groups) {
      if (i >= digits.length) break;
      out.add(digits.substring(i, (i + g).clamp(0, digits.length)));
      i += g;
    }
    if (i < digits.length) out.add(digits.substring(i)); // remainder
    return out.join(' ');
  }
}

/// A compact, common set — the three used most (India, USA, Kuwait) first, so
/// they're the first options in the picker; India stays the default. Extend as
/// needed.
const List<CountryCode> kCountryCodes = [
  CountryCode(iso: 'IN', dial: '+91', flag: '🇮🇳', name: 'India', maxLen: 10, groups: [5, 5]),
  CountryCode(iso: 'US', dial: '+1', flag: '🇺🇸', name: 'United States', maxLen: 10, groups: [3, 3, 4]),
  CountryCode(iso: 'KW', dial: '+965', flag: '🇰🇼', name: 'Kuwait', maxLen: 8, groups: [4, 4]),
  CountryCode(iso: 'GB', dial: '+44', flag: '🇬🇧', name: 'United Kingdom', groups: [4, 6]),
  CountryCode(iso: 'AE', dial: '+971', flag: '🇦🇪', name: 'UAE', groups: [2, 3, 4]),
  CountryCode(iso: 'SG', dial: '+65', flag: '🇸🇬', name: 'Singapore', groups: [4, 4]),
  CountryCode(iso: 'AU', dial: '+61', flag: '🇦🇺', name: 'Australia', groups: [3, 3, 3]),
  CountryCode(iso: 'CA', dial: '+1', flag: '🇨🇦', name: 'Canada', maxLen: 10, groups: [3, 3, 4]),
  CountryCode(iso: 'DE', dial: '+49', flag: '🇩🇪', name: 'Germany', groups: [4, 7]),
  CountryCode(iso: 'FR', dial: '+33', flag: '🇫🇷', name: 'France', groups: [1, 2, 2, 2, 2]),
  CountryCode(iso: 'SA', dial: '+966', flag: '🇸🇦', name: 'Saudi Arabia', groups: [2, 3, 4]),
  CountryCode(iso: 'JP', dial: '+81', flag: '🇯🇵', name: 'Japan', groups: [2, 4, 4]),
  CountryCode(iso: 'CN', dial: '+86', flag: '🇨🇳', name: 'China', groups: [3, 4, 4]),
];

/// Split a stored E.164 number (e.g. '+919876543210') into its country and the
/// national part ('9876543210'). Falls back to India + the raw digits when the
/// dial code isn't recognised. Longer dial codes are matched first so '+1' vs
/// '+91' don't collide.
({CountryCode country, String national}) splitE164(String? e164) {
  final raw = (e164 ?? '').trim();
  final candidates = [...kCountryCodes]
    ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
  for (final c in candidates) {
    if (raw.startsWith(c.dial)) {
      return (country: c, national: raw.substring(c.dial.length));
    }
  }
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return (country: kCountryCodes.first, national: digits);
}
