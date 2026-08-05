import '../domain/brand.dart';

/// Maps typed names → logo domains, and provides popular suggestions.
///
/// The user can type *any* name; if we know a domain for it (or can guess one),
/// we fetch that brand's real logo. Otherwise the name still works — it just
/// shows a coloured letter-avatar. So coverage is effectively unlimited.
class BrandCatalog {
  const BrandCatalog._();

  /// Curated popular brands across the things this app tracks — streaming,
  /// Indian banks, brokers/investing, insurers, utilities. Shown as instant
  /// suggestions before the user even types.
  static const List<Brand> popular = [
    // Streaming / subscriptions
    Brand(name: 'Netflix', domain: 'netflix.com'),
    Brand(name: 'Amazon Prime', domain: 'primevideo.com'),
    Brand(name: 'Spotify', domain: 'spotify.com'),
    Brand(name: 'YouTube', domain: 'youtube.com'),
    Brand(name: 'Disney+ Hotstar', domain: 'hotstar.com'),
    Brand(name: 'Apple', domain: 'apple.com'),
    // Indian banks
    Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'),
    Brand(name: 'ICICI Bank', domain: 'icicibank.com'),
    Brand(name: 'SBI', domain: 'sbi.co.in'),
    Brand(name: 'Axis Bank', domain: 'axisbank.com'),
    Brand(name: 'Kotak', domain: 'kotak.com'),
    // Investing / brokers
    Brand(name: 'Zerodha', domain: 'zerodha.com'),
    Brand(name: 'Groww', domain: 'groww.in'),
    Brand(name: 'Upstox', domain: 'upstox.com'),
    Brand(name: 'Coin (Zerodha)', domain: 'coin.zerodha.com'),
    // Insurance
    Brand(name: 'LIC', domain: 'licindia.in'),
    Brand(name: 'HDFC Life', domain: 'hdfclife.com'),
    Brand(name: 'Star Health', domain: 'starhealth.in'),
    // Utilities / telecom
    Brand(name: 'Airtel', domain: 'airtel.in'),
    Brand(name: 'Jio', domain: 'jio.com'),
    Brand(name: 'Google', domain: 'google.com'),
  ];

  /// A few common name → domain aliases so short/informal names still resolve.
  /// Name → domain for apps whose logo domain isn't just `<name>.com`. This is
  /// what pushes coverage to ~90-95% — anything not here still falls back to a
  /// smart domain guess. Keys are lowercase; multiple keys can point at one app.
  static const Map<String, String> _aliases = {
    // Streaming / media
    'prime': 'primevideo.com', 'amazon prime': 'primevideo.com',
    'prime video': 'primevideo.com',
    'hotstar': 'hotstar.com', 'disney': 'hotstar.com',
    'disney+': 'hotstar.com', 'jiocinema': 'jiocinema.com',
    'sony liv': 'sonyliv.com', 'sonyliv': 'sonyliv.com',
    'zee5': 'zee5.com', 'youtube': 'youtube.com', 'yt': 'youtube.com',
    'netflix': 'netflix.com', 'spotify': 'spotify.com',
    'gaana': 'gaana.com', 'wynk': 'wynk.in',
    // Food / grocery / quick-commerce
    'swiggy': 'swiggy.com', 'zomato': 'zomato.com',
    'zepto': 'zeptonow.com', 'blinkit': 'blinkit.com',
    'grofers': 'blinkit.com', 'bigbasket': 'bigbasket.com',
    'bbnow': 'bigbasket.com', 'dunzo': 'dunzo.com',
    'instamart': 'swiggy.com',
    // Payments / fintech / banks
    'paytm': 'paytm.com', 'phonepe': 'phonepe.com',
    'gpay': 'pay.google.com', 'google pay': 'pay.google.com',
    'cred': 'cred.club', 'bhim': 'bhimupi.org.in',
    'sbi': 'sbi.co.in', 'lic': 'licindia.in',
    'hdfc': 'hdfcbank.com', 'hdfc bank': 'hdfcbank.com',
    'icici': 'icicibank.com', 'icici bank': 'icicibank.com',
    'axis': 'axisbank.com', 'axis bank': 'axisbank.com',
    'kotak': 'kotak.com', 'pnb': 'pnbindia.in',
    'bob': 'bankofbaroda.in', 'canara': 'canarabank.com',
    'idfc': 'idfcfirstbank.com', 'yes bank': 'yesbank.in',
    'indusind': 'indusind.com', 'au bank': 'aubank.in',
    // Investing / brokers
    'zerodha': 'zerodha.com', 'kite': 'zerodha.com',
    'groww': 'groww.in', 'upstox': 'upstox.com',
    'angel one': 'angelone.in', 'angelone': 'angelone.in',
    'coin': 'coin.zerodha.com', 'smallcase': 'smallcase.com',
    'indmoney': 'indmoney.com', 'ind money': 'indmoney.com',
    'kuvera': 'kuvera.in', 'et money': 'etmoney.com',
    'dhan': 'dhan.co', 'fyers': 'fyers.in',
    // Insurance
    'hdfc life': 'hdfclife.com', 'star health': 'starhealth.in',
    'policybazaar': 'policybazaar.com', 'acko': 'acko.com',
    'digit': 'godigit.com', 'max life': 'maxlifeinsurance.com',
    'tata aig': 'tataaig.com', 'bajaj allianz': 'bajajallianz.com',
    // Shopping
    'amazon': 'amazon.in', 'flipkart': 'flipkart.com',
    'myntra': 'myntra.com', 'ajio': 'ajio.com',
    'meesho': 'meesho.com', 'nykaa': 'nykaa.com',
    'tata neu': 'tataneu.com', 'tataneu': 'tataneu.com',
    'jiomart': 'jiomart.com', 'snapdeal': 'snapdeal.com',
    'firstcry': 'firstcry.com', 'pharmeasy': 'pharmeasy.in',
    'apollo': 'apollopharmacy.in', 'tata 1mg': '1mg.com', '1mg': '1mg.com',
    // Travel / transport
    'ola': 'olacabs.com', 'uber': 'uber.com',
    'rapido': 'rapido.bike', 'irctc': 'irctc.co.in',
    'makemytrip': 'makemytrip.com', 'mmt': 'makemytrip.com',
    'goibibo': 'goibibo.com', 'ixigo': 'ixigo.com',
    'redbus': 'redbus.in', 'bookmyshow': 'bookmyshow.com',
    'oyo': 'oyorooms.com', 'indigo': 'goindigo.in',
    'air india': 'airindia.com', 'vistara': 'airvistara.com',
    // Telecom / utilities
    'jio': 'jio.com', 'airtel': 'airtel.in',
    'vi': 'myvi.in', 'vodafone': 'myvi.in', 'bsnl': 'bsnl.co.in',
    'tata power': 'tatapower.com', 'adani': 'adanielectricity.com',
    // Big tech / productivity
    'google': 'google.com', 'apple': 'apple.com',
    'microsoft': 'microsoft.com', 'meta': 'meta.com',
    'whatsapp': 'whatsapp.com', 'instagram': 'instagram.com',
    'facebook': 'facebook.com', 'linkedin': 'linkedin.com',
    'x': 'x.com', 'twitter': 'x.com', 'telegram': 'telegram.org',
    'chatgpt': 'openai.com', 'openai': 'openai.com',
    'canva': 'canva.com', 'notion': 'notion.so',
    'adobe': 'adobe.com', 'dropbox': 'dropbox.com',
    'zoom': 'zoom.us', 'slack': 'slack.com',
    'github': 'github.com', 'figma': 'figma.com',
  };

  /// Best-effort brand for a free-typed query:
  ///   1. exact match against a popular brand's name,
  ///   2. an alias (the big map above),
  ///   3. if the query already looks like a domain, use it,
  ///   4. otherwise guess a domain — the widget then tries `.com`, `.in`, `.co`,
  ///      `.app` and multiple logo sources, so a wrong guess still often finds a
  ///      real logo before falling back to a letter avatar.
  static Brand resolve(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();

    for (final b in popular) {
      if (b.name.toLowerCase() == lower) return b;
    }
    if (_aliases.containsKey(lower)) {
      return Brand(name: q, domain: _aliases[lower]!);
    }
    if (_looksLikeDomain(lower)) {
      return Brand(name: q, domain: lower);
    }
    final slug = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (slug.isEmpty) return Brand(name: q, domain: '');
    return Brand(name: q, domain: '$slug.com');
  }

  /// Popular brands whose name contains [query] (for the live suggestion list).
  ///
  /// The free-typed guess goes first (so ANY name works), then matching popular
  /// brands. The whole list is de-duplicated by domain so the same logo never
  /// appears twice.
  static List<Brand> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return popular;

    final ordered = <Brand>[
      resolve(query), // the typed guess, first
      ...popular.where((b) => b.name.toLowerCase().contains(q)),
    ];

    final seen = <String>{};
    final out = <Brand>[];
    for (final b in ordered) {
      // Key on domain (or lowercase name when there's no domain) so duplicates
      // pointing at the same logo collapse to one entry.
      final key = b.domain.isNotEmpty ? b.domain : 'name:${b.name.toLowerCase()}';
      if (seen.add(key)) out.add(b);
    }
    return out;
  }

  static bool _looksLikeDomain(String s) =>
      RegExp(r'^[a-z0-9-]+\.[a-z.]{2,}$').hasMatch(s);
}
