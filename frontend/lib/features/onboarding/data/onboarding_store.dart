import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has completed onboarding. One boolean, on-device.
class OnboardingStore {
  const OnboardingStore();

  static const _key = 'onboarding_complete_v1';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Test/utility hook — clears the flag so onboarding shows again.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
