/// A dialing country for the phone-number picker.
class CountryCode {
  const CountryCode({
    required this.iso,
    required this.dial,
    required this.flag,
    required this.name,
    this.maxLen = 15,
  });

  final String iso; // 'IN'
  final String dial; // '+91'
  final String flag; // 🇮🇳
  final String name; // 'India'

  /// Max national-number length (rough), used for light validation.
  final int maxLen;
}

/// A compact, common set — India first (the default). Extend as needed.
const List<CountryCode> kCountryCodes = [
  CountryCode(iso: 'IN', dial: '+91', flag: '🇮🇳', name: 'India', maxLen: 10),
  CountryCode(iso: 'US', dial: '+1', flag: '🇺🇸', name: 'United States', maxLen: 10),
  CountryCode(iso: 'GB', dial: '+44', flag: '🇬🇧', name: 'United Kingdom'),
  CountryCode(iso: 'AE', dial: '+971', flag: '🇦🇪', name: 'UAE'),
  CountryCode(iso: 'SG', dial: '+65', flag: '🇸🇬', name: 'Singapore'),
  CountryCode(iso: 'AU', dial: '+61', flag: '🇦🇺', name: 'Australia'),
  CountryCode(iso: 'CA', dial: '+1', flag: '🇨🇦', name: 'Canada', maxLen: 10),
  CountryCode(iso: 'DE', dial: '+49', flag: '🇩🇪', name: 'Germany'),
  CountryCode(iso: 'FR', dial: '+33', flag: '🇫🇷', name: 'France'),
  CountryCode(iso: 'SA', dial: '+966', flag: '🇸🇦', name: 'Saudi Arabia'),
  CountryCode(iso: 'JP', dial: '+81', flag: '🇯🇵', name: 'Japan'),
  CountryCode(iso: 'CN', dial: '+86', flag: '🇨🇳', name: 'China'),
];
