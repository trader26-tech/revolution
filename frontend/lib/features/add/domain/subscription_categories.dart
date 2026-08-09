import 'package:flutter/material.dart';

import '../../tasks/domain/task.dart';

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

/// A typical plan for a subscription — a sensible default INR price and cycle we
/// pre-fill so the user starts from a real number instead of a blank field.
/// These are indicative popular-tier prices (₹, monthly unless noted); the user
/// can always change them.
class SubDefault {
  const SubDefault(this.price, this.cycle);
  final double price;
  final RepeatCadence cycle;
}

/// Look up a typical plan by name (case-insensitive contains). Returns null when
/// we don't have a good default → we leave the price blank.
SubDefault? subscriptionDefault(String name) {
  final n = name.toLowerCase();
  for (final entry in _defaults) {
    for (final key in entry.$1) {
      if (n.contains(key)) return entry.$2;
    }
  }
  return null;
}

const _m = RepeatCadence.monthly;
const _y = RepeatCadence.yearly;

/// ([name-fragments], default plan). First match wins.
const List<(List<String>, SubDefault)> _defaults = [
  // Video
  (['netflix'], SubDefault(499, _m)),
  (['prime'], SubDefault(1499, _y)),
  (['hotstar', 'disney'], SubDefault(1499, _y)),
  (['jiocinema'], SubDefault(999, _y)),
  (['sonyliv'], SubDefault(999, _y)),
  (['zee5'], SubDefault(699, _y)),
  (['apple tv'], SubDefault(99, _m)),
  (['youtube premium'], SubDefault(149, _m)),
  // Music
  (['spotify'], SubDefault(119, _m)),
  (['apple music'], SubDefault(99, _m)),
  (['youtube music'], SubDefault(99, _m)),
  (['jiosaavn', 'saavn'], SubDefault(99, _m)),
  (['gaana'], SubDefault(99, _m)),
  (['wynk'], SubDefault(49, _m)),
  (['audible'], SubDefault(199, _m)),
  (['kuku'], SubDefault(399, _y)),
  (['pocket fm'], SubDefault(299, _m)),
  // Cloud & tools
  (['google one'], SubDefault(130, _m)),
  (['icloud'], SubDefault(75, _m)),
  (['microsoft 365', 'office 365'], SubDefault(4899, _y)),
  (['dropbox'], SubDefault(1200, _m)),
  (['notion'], SubDefault(800, _m)),
  (['zoom'], SubDefault(1400, _m)),
  (['canva'], SubDefault(3999, _y)),
  (['adobe'], SubDefault(1699, _m)),
  (['grammarly'], SubDefault(1000, _m)),
  (['expressvpn', 'nordvpn', 'vpn'], SubDefault(800, _m)),
  (['truecaller'], SubDefault(75, _m)),
  // AI
  (['chatgpt', 'openai'], SubDefault(1700, _m)),
  (['claude'], SubDefault(1700, _m)),
  (['gemini'], SubDefault(1950, _m)),
  (['perplexity'], SubDefault(1700, _m)),
  (['midjourney'], SubDefault(850, _m)),
  // Learning
  (['coursera'], SubDefault(4000, _m)),
  (['udemy'], SubDefault(500, _m)),
  (['linkedin'], SubDefault(1400, _m)),
  (['unacademy'], SubDefault(999, _m)),
  (['duolingo'], SubDefault(6500, _y)),
  (['skillshare'], SubDefault(1500, _m)),
  // Gaming
  (['playstation', 'ps plus'], SubDefault(749, _m)),
  (['xbox', 'game pass'], SubDefault(699, _m)),
  (['nintendo'], SubDefault(299, _y)),
  (['apple arcade'], SubDefault(99, _m)),
  // Food & shopping
  (['swiggy'], SubDefault(99, _m)),
  (['zomato'], SubDefault(149, _m)),
  (['flipkart plus'], SubDefault(0, _y)),
  (['myntra'], SubDefault(0, _y)),
  (['zepto'], SubDefault(99, _m)),
  // Connectivity
  (['jio'], SubDefault(349, _m)),
  (['airtel'], SubDefault(379, _m)),
  (['vi '], SubDefault(359, _m)),
  (['tata play'], SubDefault(400, _m)),
  (['act fibernet', 'jiofiber'], SubDefault(700, _m)),
  // Fitness
  (['cult'], SubDefault(1250, _m)),
  (['healthifyme'], SubDefault(1000, _m)),
  (['calm', 'headspace'], SubDefault(500, _m)),
  // Dating
  (['tinder'], SubDefault(699, _m)),
  (['bumble'], SubDefault(600, _m)),
];
