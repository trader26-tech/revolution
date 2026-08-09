import 'package:flutter/material.dart';

/// The subscription sub-categories. Every top subscription is tagged to one of
/// these; the user can also type a custom category. Icons are Material (render
/// reliably), all tinted to the single Orbit accent at the call site.
class SubCategory {
  const SubCategory(this.name, this.icon);
  final String name;
  final IconData icon;
}

/// The 8 built-in subscription categories, in display order.
const List<SubCategory> kSubCategories = [
  SubCategory('Entertainment', Icons.movie_rounded),
  SubCategory('Music', Icons.music_note_rounded),
  SubCategory('Cloud & Tools', Icons.cloud_rounded),
  SubCategory('AI', Icons.auto_awesome_rounded),
  SubCategory('Learning', Icons.school_rounded),
  SubCategory('Gaming', Icons.sports_esports_rounded),
  SubCategory('Food & Shopping', Icons.shopping_bag_rounded),
  SubCategory('Other', Icons.category_rounded),
];

/// Look up the icon for a category name (built-in or custom → a default).
IconData subCategoryIcon(String? name) {
  if (name == null) return Icons.category_rounded;
  for (final c in kSubCategories) {
    if (c.name.toLowerCase() == name.toLowerCase()) return c.icon;
  }
  return Icons.bookmark_rounded; // a custom category
}

/// The default category name.
const String kOtherSubCategory = 'Other';

/// Auto-categorise a subscription from its name (case-insensitive contains).
/// Returns one of [kSubCategories] names, or 'Other' if unknown. Covers the
/// top ~100 Indian subscriptions across all eight buckets.
String subCategoryFor(String name) {
  final n = name.toLowerCase();
  for (final entry in _rules) {
    for (final key in entry.$2) {
      if (n.contains(key)) return entry.$1;
    }
  }
  return kOtherSubCategory;
}

/// (category, [name-fragments that map to it]). Order matters — the first match
/// wins, so put more specific fragments earlier where needed.
const List<(String, List<String>)> _rules = [
  (
    'Music',
    [
      'spotify', 'apple music', 'youtube music', 'jiosaavn', 'saavn', 'gaana',
      'wynk', 'amazon music', 'audible', 'kuku', 'pocket fm', 'hungama',
      'soundcloud', 'tidal', 'resso',
    ]
  ),
  (
    'AI',
    [
      'chatgpt', 'openai', 'claude', 'gemini', 'perplexity', 'midjourney',
      'copilot', 'grok', 'jasper', 'runway', 'elevenlabs',
    ]
  ),
  (
    'Learning',
    [
      'coursera', 'udemy', 'linkedin premium', 'linkedin learning', 'unacademy',
      'byju', 'vedantu', 'duolingo', 'skillshare', 'scaler', 'skool',
      'khan', 'brilliant', 'masterclass', 'pratilipi',
    ]
  ),
  (
    'Gaming',
    [
      'playstation', 'ps plus', 'xbox', 'game pass', 'nintendo', 'apple arcade',
      'steam', 'ea play', 'ubisoft', 'dream11', 'rummy',
    ]
  ),
  (
    'Food & Shopping',
    [
      'swiggy', 'zomato', 'amazon', 'flipkart', 'myntra', 'bigbasket',
      'blinkit', 'zepto', 'tata neu', 'nykaa', 'ajio', 'meesho',
    ]
  ),
  (
    'Cloud & Tools',
    [
      'google one', 'icloud', 'microsoft 365', 'office 365', 'dropbox',
      'notion', 'evernote', 'zoom', 'workspace', 'google drive', 'onedrive',
      'canva', 'adobe', 'figma', 'grammarly', '1password', 'lastpass',
      'expressvpn', 'nordvpn', 'vpn', 'github', 'medium', 'patreon',
      'truecaller', 'play pass', 'setu', 'slack',
    ]
  ),
  (
    'Entertainment',
    [
      'netflix', 'prime', 'hotstar', 'disney', 'jiocinema', 'sonyliv', 'zee5',
      'apple tv', 'youtube', 'aha', 'mx player', 'hoichoi', 'discovery',
      'lionsgate', 'chaupal', 'manorama', 'hulu', 'hbo', 'crunchyroll',
      'tinder', 'bumble', 'the hindu', 'et prime', 'inshorts', 'times prime',
      'kindle',
    ]
  ),
];
