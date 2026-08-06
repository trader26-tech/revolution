import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the user has completed the one-time onboarding intro, so
/// it only shows on the very first launch. After that the app goes straight to
/// phone login (if needed) → home.
class OnboardingStore extends ChangeNotifier {
  OnboardingStore._();
  static final OnboardingStore instance = OnboardingStore._();

  static const _key = 'onboarding_complete_v1';

  bool _complete = false;
  bool get isComplete => _complete;

  /// Load the flag at startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _complete = prefs.getBool(_key) ?? false;
    } catch (_) {
      _complete = false;
    }
    notifyListeners();
  }

  Future<void> markComplete() async {
    _complete = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }

  /// Dev/testing: replay onboarding on next launch.
  Future<void> reset() async {
    _complete = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
