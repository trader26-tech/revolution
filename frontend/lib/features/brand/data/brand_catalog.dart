import 'package:flutter/material.dart';

import '../domain/brand.dart';
import 'custom_logo_store.dart';

/// A category header + the brands shown under it in the icon picker.
///
/// Uses a Material [icon] (not an emoji) so the header always renders — some
/// emojis show as a "□?" tofu box on devices missing that glyph.
class BrandCategory {
  const BrandCategory(this.title, this.icon, this.brands);
  final String title;
  final IconData icon;
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

  /// Category-wise suggestions shown before the user types — ~10 top real
  /// brands each. ORDERED BY WHAT MATTERS MOST to a user tracking money & apps:
  /// banking/investing and insurance first, then the subscriptions they pay
  /// regularly, then utilities/health, with vehicle/home/family and finally the
  /// occasional government renewals last.
  static const List<BrandCategory> categories = [
    BrandCategory('Banking & Finance', Icons.account_balance_rounded, [
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
    BrandCategory('Insurance', Icons.shield_rounded, [
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
    BrandCategory('Digital & Subscriptions', Icons.play_circle_rounded, [
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
    BrandCategory('Utilities', Icons.bolt_rounded, [
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
    BrandCategory('Health', Icons.favorite_rounded, [
      Brand(name: 'Apollo Pharmacy', domain: 'apollopharmacy.in'),
      Brand(name: 'Tata 1mg', domain: '1mg.com'),
      Brand(name: 'PharmEasy', domain: 'pharmeasy.in'),
      Brand(name: 'Netmeds', domain: 'netmeds.com'),
      Brand(name: 'Practo', domain: 'practo.com'),
      Brand(name: 'Cult.fit', domain: 'cult.fit'),
      Brand(name: 'Dr Lal PathLabs', domain: 'lalpathlabs.com'),
      Brand(name: 'Pristyn Care', domain: 'pristyncare.com'),
    ]),
    BrandCategory('Vehicle', Icons.directions_car_rounded, [
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
    BrandCategory('Home', Icons.home_rounded, [
      Brand(name: 'Urban Company', domain: 'urbancompany.com'),
      Brand(name: 'NoBroker', domain: 'nobroker.in'),
      Brand(name: 'Housejoy', domain: 'housejoy.in'),
      Brand(name: 'Pepperfry', domain: 'pepperfry.com'),
      Brand(name: 'Godrej', domain: 'godrej.com'),
      Brand(name: 'Kent', domain: 'kent.co.in'),
      Brand(name: 'Eureka Forbes', domain: 'eurekaforbes.com'),
      Brand(name: 'HomeTriangle', domain: 'hometriangle.com'),
    ]),
    BrandCategory('Family & Personal', Icons.people_rounded, [
      Brand(name: 'BookMyShow', domain: 'bookmyshow.com'),
      Brand(name: 'Ferns N Petals', domain: 'fnp.com'),
      Brand(name: 'Archies', domain: 'archiesonline.com'),
      Brand(name: 'FirstCry', domain: 'firstcry.com'),
      Brand(name: 'Byjus', domain: 'byjus.com'),
      Brand(name: 'Unacademy', domain: 'unacademy.com'),
      Brand(name: 'Vedantu', domain: 'vedantu.com'),
      Brand(name: 'Zomato', domain: 'zomato.com'),
    ]),
    BrandCategory('Identity & Government', Icons.badge_rounded, [
      Brand(name: 'mParivahan', domain: 'parivahan.gov.in'),
      Brand(name: 'DigiLocker', domain: 'digilocker.gov.in'),
      Brand(name: 'Passport Seva', domain: 'passportindia.gov.in'),
      Brand(name: 'UIDAI Aadhaar', domain: 'uidai.gov.in'),
      Brand(name: 'Election Commission', domain: 'eci.gov.in'),
      Brand(name: 'Vahan', domain: 'vahan.parivahan.gov.in'),
      Brand(name: 'India.gov', domain: 'india.gov.in'),
      Brand(name: 'UMANG', domain: 'web.umang.gov.in'),
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

  /// India's most-subscribed services — the ONLY brands shown in the
  /// Subscriptions add picker, so the grid is a curated, on-brand shelf (logos
  /// auto-load by domain). The user can still type any name, but these surface
  /// instantly. Ordered roughly by how commonly Indians subscribe.
  static const List<Brand> topSubscriptions = [
    // Streaming — video
    Brand(name: 'Netflix', domain: 'netflix.com'),
    Brand(name: 'Amazon Prime', domain: 'primevideo.com'),
    Brand(name: 'Disney+ Hotstar', domain: 'hotstar.com'),
    Brand(name: 'JioCinema', domain: 'jiocinema.com'),
    Brand(name: 'SonyLIV', domain: 'sonyliv.com'),
    Brand(name: 'ZEE5', domain: 'zee5.com'),
    Brand(name: 'Apple TV+', domain: 'tv.apple.com'),
    Brand(name: 'YouTube Premium', domain: 'youtube.com'),
    Brand(name: 'Aha', domain: 'aha.video'),
    Brand(name: 'MX Player', domain: 'mxplayer.in'),
    Brand(name: 'Hoichoi', domain: 'hoichoi.tv'),
    Brand(name: 'Discovery+', domain: 'discoveryplus.in'),
    Brand(name: 'Lionsgate Play', domain: 'lionsgateplay.com'),
    Brand(name: 'Chaupal', domain: 'chaupal.tv'),
    Brand(name: 'ManoramaMAX', domain: 'manoramamax.com'),
    // Streaming — music & audio
    Brand(name: 'Spotify', domain: 'spotify.com'),
    Brand(name: 'Apple Music', domain: 'music.apple.com'),
    Brand(name: 'YouTube Music', domain: 'music.youtube.com'),
    Brand(name: 'JioSaavn', domain: 'jiosaavn.com'),
    Brand(name: 'Gaana', domain: 'gaana.com'),
    Brand(name: 'Wynk Music', domain: 'wynk.in'),
    Brand(name: 'Amazon Music', domain: 'music.amazon.com'),
    Brand(name: 'Audible', domain: 'audible.in'),
    Brand(name: 'Kuku FM', domain: 'kukufm.com'),
    Brand(name: 'Pocket FM', domain: 'pocketfm.com'),
    Brand(name: 'Hungama', domain: 'hungama.com'),
    // Cloud / storage / productivity
    Brand(name: 'Google One', domain: 'one.google.com'),
    Brand(name: 'iCloud+', domain: 'icloud.com'),
    Brand(name: 'Microsoft 365', domain: 'microsoft.com'),
    Brand(name: 'Dropbox', domain: 'dropbox.com'),
    Brand(name: 'Notion', domain: 'notion.so'),
    Brand(name: 'Evernote', domain: 'evernote.com'),
    Brand(name: 'Zoom', domain: 'zoom.us'),
    Brand(name: 'Google Workspace', domain: 'workspace.google.com'),
    // AI & creative tools
    Brand(name: 'ChatGPT Plus', domain: 'openai.com'),
    Brand(name: 'Claude', domain: 'claude.ai'),
    Brand(name: 'Gemini', domain: 'gemini.google.com'),
    Brand(name: 'Perplexity', domain: 'perplexity.ai'),
    Brand(name: 'Canva', domain: 'canva.com'),
    Brand(name: 'Adobe', domain: 'adobe.com'),
    Brand(name: 'Grammarly', domain: 'grammarly.com'),
    Brand(name: 'Figma', domain: 'figma.com'),
    Brand(name: 'Midjourney', domain: 'midjourney.com'),
    // Reading & news
    Brand(name: 'Kindle Unlimited', domain: 'amazon.in'),
    Brand(name: 'Audible', domain: 'audible.in'),
    Brand(name: 'Times Prime', domain: 'timesprime.com'),
    Brand(name: 'The Hindu', domain: 'thehindu.com'),
    Brand(name: 'ET Prime', domain: 'economictimes.indiatimes.com'),
    Brand(name: 'Inshorts Prime', domain: 'inshorts.com'),
    // Health & fitness
    Brand(name: 'Cult.fit', domain: 'cult.fit'),
    Brand(name: 'HealthifyMe', domain: 'healthifyme.com'),
    Brand(name: 'Fitbit Premium', domain: 'fitbit.com'),
    Brand(name: 'Strava', domain: 'strava.com'),
    Brand(name: 'Calm', domain: 'calm.com'),
    Brand(name: 'Headspace', domain: 'headspace.com'),
    // Learning
    Brand(name: 'Coursera', domain: 'coursera.org'),
    Brand(name: 'Udemy', domain: 'udemy.com'),
    Brand(name: 'LinkedIn Premium', domain: 'linkedin.com'),
    Brand(name: 'Unacademy', domain: 'unacademy.com'),
    Brand(name: "BYJU'S", domain: 'byjus.com'),
    Brand(name: 'Vedantu', domain: 'vedantu.com'),
    Brand(name: 'Duolingo', domain: 'duolingo.com'),
    Brand(name: 'Skillshare', domain: 'skillshare.com'),
    // Gaming
    Brand(name: 'PlayStation Plus', domain: 'playstation.com'),
    Brand(name: 'Xbox Game Pass', domain: 'xbox.com'),
    Brand(name: 'Nintendo Online', domain: 'nintendo.com'),
    Brand(name: 'Apple Arcade', domain: 'apple.com'),
    Brand(name: 'Steam', domain: 'steampowered.com'),
    // Food, shopping & memberships
    Brand(name: 'Swiggy One', domain: 'swiggy.com'),
    Brand(name: 'Zomato Gold', domain: 'zomato.com'),
    Brand(name: 'Amazon', domain: 'amazon.in'),
    Brand(name: 'Flipkart Plus', domain: 'flipkart.com'),
    Brand(name: 'Myntra Insider', domain: 'myntra.com'),
    Brand(name: 'BigBasket', domain: 'bigbasket.com'),
    Brand(name: 'Blinkit', domain: 'blinkit.com'),
    Brand(name: 'Zepto Pass', domain: 'zeptonow.com'),
    Brand(name: 'Tata Neu', domain: 'tataneu.com'),
    // Dating & social
    Brand(name: 'Tinder', domain: 'tinder.com'),
    Brand(name: 'Bumble', domain: 'bumble.com'),
    Brand(name: 'LinkedIn', domain: 'linkedin.com'),
    // Utilities & connectivity (recurring plans)
    Brand(name: 'Jio', domain: 'jio.com'),
    Brand(name: 'Airtel', domain: 'airtel.in'),
    Brand(name: 'Vi', domain: 'myvi.in'),
    Brand(name: 'Tata Play', domain: 'tataplay.com'),
    Brand(name: 'ACT Fibernet', domain: 'actcorp.in'),
    Brand(name: 'JioFiber', domain: 'jio.com'),
    Brand(name: 'ExpressVPN', domain: 'expressvpn.com'),
    Brand(name: 'NordVPN', domain: 'nordvpn.com'),
    Brand(name: 'Google Play Pass', domain: 'play.google.com'),
    Brand(name: 'Truecaller Premium', domain: 'truecaller.com'),
    Brand(name: 'Setu', domain: 'setu.co'),
    Brand(name: 'Rummy Circle', domain: 'rummycircle.com'),
    Brand(name: 'Dream11', domain: 'dream11.com'),
    Brand(name: 'Pratilipi', domain: 'pratilipi.com'),
    Brand(name: 'Scaler', domain: 'scaler.com'),
    Brand(name: 'Skool', domain: 'skool.com'),
    Brand(name: 'Medium', domain: 'medium.com'),
    Brand(name: 'Patreon', domain: 'patreon.com'),
  ];

  /// Curated subscriptions whose name matches [query] (for the subs picker).
  /// The free-typed guess is offered first so any service can still be added,
  /// then matching curated subscriptions; de-duplicated by domain.
  static List<Brand> searchSubscriptions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _dedupe(topSubscriptions);
    final ordered = <Brand>[
      resolve(query),
      ...topSubscriptions.where((b) => b.name.toLowerCase().contains(q)),
    ];
    return _dedupe(ordered);
  }

  static List<Brand> _dedupe(List<Brand> brands) {
    final seen = <String>{};
    final out = <Brand>[];
    for (final b in brands) {
      final key =
          b.domain.isNotEmpty ? b.domain : 'name:${b.name.toLowerCase()}';
      if (seen.add(key)) out.add(b);
    }
    return out;
  }

  /// Resolve a KNOWN subscription's logo from a typed name — covers the full
  /// top-subscriptions shelf (not just `popular`/aliases). Tries, in order:
  /// exact name, alias, then a best contains-match against the shelf. Returns a
  /// brand with an empty domain if nothing known matches (→ no blank favicon).
  ///
  /// Used by the subscription form's type-ahead so "JioSaavn", "YouTube
  /// Premium", "ChatGPT Plus" etc. all pop their icon as you type — consistent
  /// with the category auto-fill, which also spans the whole shelf.
  static Brand resolveSubscription(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();
    if (lower.isEmpty) return Brand(name: q, domain: '');

    // 1. A known brand via the general resolver (popular/catalog/alias/custom).
    final known = resolveKnown(q);
    if (known.domain.isNotEmpty) return known;

    // 2. Exact match on the subscriptions shelf.
    for (final b in topSubscriptions) {
      if (b.name.toLowerCase() == lower) return b;
    }
    // 3. The shelf entry that best contains the query (or vice-versa) — e.g.
    //    "youtube premium" → the YouTube Premium entry; "saavn" → JioSaavn.
    Brand? best;
    for (final b in topSubscriptions) {
      final name = b.name.toLowerCase();
      if (name.contains(lower) || lower.contains(name)) {
        // Prefer the shortest matching name (the tightest fit).
        if (best == null || b.name.length < best.name.length) best = b;
      }
    }
    if (best != null) return best;

    return Brand(name: q, domain: '');
  }

  /// The investment PLATFORMS shown in the SIP form's picker — brokers, mutual-
  /// fund apps, new-age fintechs, and the banks people run SIPs through. Logos
  /// auto-load by domain. Ordered by how commonly Indians invest through them.
  static const List<Brand> sipPlatforms = [
    // Discount brokers / new-age
    Brand(name: 'Zerodha', domain: 'zerodha.com'),
    Brand(name: 'Groww', domain: 'groww.in'),
    Brand(name: 'Upstox', domain: 'upstox.com'),
    Brand(name: 'Angel One', domain: 'angelone.in'),
    Brand(name: 'Dhan', domain: 'dhan.co'),
    Brand(name: 'Fyers', domain: 'fyers.in'),
    Brand(name: 'Paytm Money', domain: 'paytmmoney.com'),
    Brand(name: '5paisa', domain: '5paisa.com'),
    // Mutual-fund / wealth apps
    Brand(name: 'Coin by Zerodha', domain: 'coin.zerodha.com'),
    Brand(name: 'Kuvera', domain: 'kuvera.in'),
    Brand(name: 'ET Money', domain: 'etmoney.com'),
    Brand(name: 'INDmoney', domain: 'indmoney.com'),
    Brand(name: 'smallcase', domain: 'smallcase.com'),
    Brand(name: 'Groww MF', domain: 'groww.in'),
    Brand(name: 'Navi', domain: 'navi.com'),
    Brand(name: 'Zfunds', domain: 'zfunds.in'),
    Brand(name: 'MF Central', domain: 'mfcentral.com'),
    Brand(name: 'Kfintech', domain: 'kfintech.com'),
    Brand(name: 'CAMS', domain: 'camsonline.com'),
    // AMCs (fund houses) people SIP into directly
    Brand(name: 'SBI Mutual Fund', domain: 'sbimf.com'),
    Brand(name: 'HDFC Mutual Fund', domain: 'hdfcfund.com'),
    Brand(name: 'ICICI Prudential MF', domain: 'icicipruamc.com'),
    Brand(name: 'Axis Mutual Fund', domain: 'axismf.com'),
    Brand(name: 'Nippon India MF', domain: 'mf.nipponindiaim.com'),
    Brand(name: 'Kotak Mutual Fund', domain: 'kotakmf.com'),
    Brand(name: 'Mirae Asset', domain: 'miraeassetmf.co.in'),
    Brand(name: 'Parag Parikh MF', domain: 'amc.ppfas.com'),
    Brand(name: 'Quant Mutual Fund', domain: 'quantmutual.com'),
    Brand(name: 'UTI Mutual Fund', domain: 'utimf.com'),
    Brand(name: 'Tata Mutual Fund', domain: 'tatamutualfund.com'),
    Brand(name: 'DSP Mutual Fund', domain: 'dspim.com'),
    Brand(name: 'Motilal Oswal MF', domain: 'motilaloswalmf.com'),
    // Banks (many run SIPs / RDs / bank-linked funds)
    Brand(name: 'HDFC Bank', domain: 'hdfcbank.com'),
    Brand(name: 'ICICI Bank', domain: 'icicibank.com'),
    Brand(name: 'SBI', domain: 'sbi.co.in'),
    Brand(name: 'Axis Bank', domain: 'axisbank.com'),
    Brand(name: 'Kotak', domain: 'kotak.com'),
    // Gold / alt
    Brand(name: 'Jar', domain: 'myjar.app'),
    Brand(name: 'Gullak', domain: 'gullak.money'),
    Brand(name: 'MobiKwik Xtra', domain: 'mobikwik.com'),
    // Global
    Brand(name: 'Vested', domain: 'vestedfinance.com'),
    Brand(name: 'Interactive Brokers', domain: 'interactivebrokers.com'),
  ];

  /// Curated platforms whose name matches [query] (SIP form picker). Free-typed
  /// guess first (so any platform works), then curated matches; de-duped.
  static List<Brand> searchPlatforms(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _dedupe(sipPlatforms);
    final ordered = <Brand>[
      resolve(query),
      ...sipPlatforms.where((b) => b.name.toLowerCase().contains(q)),
    ];
    return _dedupe(ordered);
  }

  /// Resolve a KNOWN platform's logo from a typed name — covers the platforms
  /// shelf (broker/AMC/fintech/bank). Empty domain when nothing known matches.
  static Brand resolvePlatform(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();
    if (lower.isEmpty) return Brand(name: q, domain: '');

    final known = resolveKnown(q);
    if (known.domain.isNotEmpty) return known;

    for (final b in sipPlatforms) {
      if (b.name.toLowerCase() == lower) return b;
    }
    Brand? best;
    for (final b in sipPlatforms) {
      final name = b.name.toLowerCase();
      if (name.contains(lower) || lower.contains(name)) {
        if (best == null || b.name.length < best.name.length) best = b;
      }
    }
    return best ?? Brand(name: q, domain: '');
  }

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

    // Manually-curated logos win over everything — this is the override you
    // upload for apps the auto-resolver can't find.
    final custom = CustomLogoStore.instance.match(q);
    if (custom != null) return custom.toBrand();

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

  /// Like [resolve], but ONLY returns a logo domain for a brand we actually
  /// KNOW (curated/custom/alias/catalog, or an explicit domain). For a plain
  /// free-typed name ("test", "hshhsh") it returns an empty domain → the widget
  /// shows the clean letter tile instead of fetching a blank grey favicon for a
  /// guessed domain that doesn't exist.
  ///
  /// Used on the task list so unknown names get the nice blue letter tile, not
  /// an ugly grey placeholder.
  static Brand resolveKnown(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();
    if (q.isEmpty) return Brand(name: q, domain: '');

    final custom = CustomLogoStore.instance.match(q);
    if (custom != null) return custom.toBrand();

    for (final b in popular) {
      if (b.name.toLowerCase() == lower) return b;
    }
    for (final cat in categories) {
      for (final b in cat.brands) {
        if (b.name.toLowerCase() == lower) return b;
      }
    }
    if (_aliases.containsKey(lower)) {
      return Brand(name: q, domain: _aliases[lower]!);
    }
    if (_looksLikeDomain(lower)) {
      return Brand(name: q, domain: lower);
    }
    // Unknown free-typed name → no logo fetch, just the letter tile.
    return Brand(name: q, domain: '');
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
