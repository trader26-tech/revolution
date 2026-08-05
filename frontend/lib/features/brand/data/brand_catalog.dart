import '../domain/brand.dart';

/// A category header + the brands shown under it in the icon picker.
class BrandCategory {
  const BrandCategory(this.title, this.emoji, this.brands);
  final String title;
  final String emoji;
  final List<Brand> brands;
}

/// Maps typed names → logo domains, and provides popular suggestions grouped by
/// category.
///
/// The user can type *any* name; if we know a domain for it (or can guess one),
/// we fetch that brand's real logo. Otherwise the name still works — it just
/// shows a coloured letter-avatar. So coverage is effectively unlimited.
class BrandCatalog {
  const BrandCatalog._();

  /// The category-wise suggestions shown before the user types — ~10 of the
  /// most relevant real brands per category, so tapping is faster than typing.
  static const List<BrandCategory> categories = [
    BrandCategory('Identity & Government', '🪪', [
      Brand(name: 'mParivahan', domain: 'parivahan.gov.in'),
      Brand(name: 'DigiLocker', domain: 'digilocker.gov.in'),
      Brand(name: 'Passport Seva', domain: 'passportindia.gov.in'),
      Brand(name: 'UIDAI Aadhaar', domain: 'uidai.gov.in'),
      Brand(name: 'Election Commission', domain: 'eci.gov.in'),
      Brand(name: 'Vahan', domain: 'vahan.parivahan.gov.in'),
      Brand(name: 'India.gov', domain: 'india.gov.in'),
      Brand(name: 'UMANG', domain: 'web.umang.gov.in'),
    ]),
    BrandCategory('Vehicle', '🚗', [
      Brand(name: 'Maruti Suzuki', domain: 'marutisuzuki.com'),
      Brand(name: 'Hyundai', domain: 'hyundai.com'),
      Brand(name: 'Tata Motors', domain: 'tatamotors.com'),
      Brand(name: 'Mahindra', domain: 'mahindra.com'),
      Brand(name: 'Honda', domain: 'honda.com'),
      Brand(name: 'Royal Enfield', domain: 'royalenfield.com'),
      Brand(name: 'Bajaj Auto', domain: 'bajajauto.com'),
      Brand(name: 'Bosch', domain: 'bosch.com'),
      Brand(name: 'Castrol', domain: 'castrol.com'),
      Brand(name: 'FASTag', domain: 'fastag.org'),
    ]),
    BrandCategory('Insurance', '🛡️', [
      Brand(name: 'LIC', domain: 'licindia.in'),
      Brand(name: 'HDFC Life', domain: 'hdfclife.com'),
      Brand(name: 'ICICI Prudential', domain: 'iciciprulife.com'),
      Brand(name: 'SBI Life', domain: 'sbilife.co.in'),
      Brand(name: 'Star Health', domain: 'starhealth.in'),
      Brand(name: 'Max Life', domain: 'maxlifeinsurance.com'),
      Brand(name: 'Bajaj Allianz', domain: 'bajajallianz.com'),
      Brand(name: 'Tata AIG', domain: 'tataaig.com'),
      Brand(name: 'Acko', domain: 'acko.com'),
      Brand(name: 'Digit', domain: 'godigit.com'),
    ]),
    BrandCategory('Banking & Finance', '🏦', [
      Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'),
      Brand(name: 'ICICI Bank', domain: 'icicibank.com'),
      Brand(name: 'SBI', domain: 'sbi.co.in'),
      Brand(name: 'Axis Bank', domain: 'axisbank.com'),
      Brand(name: 'Kotak', domain: 'kotak.com'),
      Brand(name: 'Zerodha', domain: 'zerodha.com'),
      Brand(name: 'Groww', domain: 'groww.in'),
      Brand(name: 'Paytm', domain: 'paytm.com'),
      Brand(name: 'PhonePe', domain: 'phonepe.com'),
      Brand(name: 'CRED', domain: 'cred.club'),
    ]),
    BrandCategory('Utilities', '💡', [
      Brand(name: 'Jio', domain: 'jio.com'),
      Brand(name: 'Airtel', domain: 'airtel.in'),
      Brand(name: 'Vi', domain: 'myvi.in'),
      Brand(name: 'BSNL', domain: 'bsnl.co.in'),
      Brand(name: 'Tata Power', domain: 'tatapower.com'),
      Brand(name: 'Adani Electricity', domain: 'adanielectricity.com'),
      Brand(name: 'ACT Fibernet', domain: 'actcorp.in'),
      Brand(name: 'Tata Play', domain: 'tataplay.com'),
      Brand(name: 'BESCOM', domain: 'bescom.org'),
      Brand(name: 'Indane Gas', domain: 'indane.co.in'),
    ]),
    BrandCategory('Health', '💊', [
      Brand(name: 'Apollo Pharmacy', domain: 'apollopharmacy.in'),
      Brand(name: 'Tata 1mg', domain: '1mg.com'),
      Brand(name: 'PharmEasy', domain: 'pharmeasy.in'),
      Brand(name: 'Netmeds', domain: 'netmeds.com'),
      Brand(name: 'Practo', domain: 'practo.com'),
      Brand(name: 'Cult.fit', domain: 'cult.fit'),
      Brand(name: 'Dr Lal PathLabs', domain: 'lalpathlabs.com'),
      Brand(name: 'Pristyn Care', domain: 'pristyncare.com'),
    ]),
    BrandCategory('Home', '🏠', [
      Brand(name: 'Urban Company', domain: 'urbancompany.com'),
      Brand(name: 'NoBroker', domain: 'nobroker.in'),
      Brand(name: 'Housejoy', domain: 'housejoy.in'),
      Brand(name: 'Pepperfry', domain: 'pepperfry.com'),
      Brand(name: 'Godrej', domain: 'godrej.com'),
      Brand(name: 'Kent', domain: 'kent.co.in'),
      Brand(name: 'Eureka Forbes', domain: 'eurekaforbes.com'),
      Brand(name: 'HomeTriangle', domain: 'hometriangle.com'),
    ]),
    BrandCategory('Family & Personal', '🎁', [
      Brand(name: 'BookMyShow', domain: 'bookmyshow.com'),
      Brand(name: 'Ferns N Petals', domain: 'fnp.com'),
      Brand(name: 'Archies', domain: 'archiesonline.com'),
      Brand(name: 'FirstCry', domain: 'firstcry.com'),
      Brand(name: 'Byjus', domain: 'byjus.com'),
      Brand(name: 'Unacademy', domain: 'unacademy.com'),
      Brand(name: 'Vedantu', domain: 'vedantu.com'),
      Brand(name: 'Zomato', domain: 'zomato.com'),
    ]),
    BrandCategory('Digital', '🎬', [
      Brand(name: 'Netflix', domain: 'netflix.com'),
      Brand(name: 'Amazon Prime', domain: 'primevideo.com'),
      Brand(name: 'Disney+ Hotstar', domain: 'hotstar.com'),
      Brand(name: 'Spotify', domain: 'spotify.com'),
      Brand(name: 'YouTube', domain: 'youtube.com'),
      Brand(name: 'JioCinema', domain: 'jiocinema.com'),
      Brand(name: 'Google One', domain: 'one.google.com'),
      Brand(name: 'iCloud', domain: 'icloud.com'),
      Brand(name: 'ChatGPT', domain: 'openai.com'),
      Brand(name: 'Canva', domain: 'canva.com'),
    ]),
  ];

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
