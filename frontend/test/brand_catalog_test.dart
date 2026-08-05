import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/brand/data/brand_catalog.dart';

void main() {
  test('known brands resolve to real domains', () {
    expect(BrandCatalog.resolve('Netflix').domain, 'netflix.com');
    expect(BrandCatalog.resolve('hdfc').domain, 'hdfcbank.com');
    expect(BrandCatalog.resolve('zerodha').domain, 'zerodha.com');
  });
  test('any typed name still gets a guessed domain (unlimited coverage)', () {
    expect(BrandCatalog.resolve('Some Random App').domain, 'somerandomapp.com');
  });
  test('a bare domain is used as-is', () {
    expect(BrandCatalog.resolve('example.io').domain, 'example.io');
  });
  test('search always offers the typed guess first', () {
    final r = BrandCatalog.search('coolapp');
    expect(r.first.domain, 'coolapp.com');
  });
  test('empty query returns popular list', () {
    expect(BrandCatalog.search('').isNotEmpty, true);
  });

  test('search returns no duplicate domains', () {
    final r = BrandCatalog.search('hdfc');
    final domains = r.map((b) => b.domain).toList();
    expect(domains.toSet().length, domains.length);
  });

  test('popular Indian apps resolve to correct logo domains', () {
    expect(BrandCatalog.resolve('Swiggy').domain, 'swiggy.com');
    expect(BrandCatalog.resolve('Zepto').domain, 'zeptonow.com');
    expect(BrandCatalog.resolve('Blinkit').domain, 'blinkit.com');
    expect(BrandCatalog.resolve('Zomato').domain, 'zomato.com');
    expect(BrandCatalog.resolve('PhonePe').domain, 'phonepe.com');
    expect(BrandCatalog.resolve('Cred').domain, 'cred.club');
    expect(BrandCatalog.resolve('Myntra').domain, 'myntra.com');
    expect(BrandCatalog.resolve('Groww').domain, 'groww.in');
  });

  test('guessed domain offers multiple TLD + source candidates', () {
    final b = BrandCatalog.resolve('SomeNewApp');
    // .com guess → should also try .in/.co/.app/.io, across sources.
    expect(b.logoUrlCandidates.length, greaterThan(4));
    expect(b.logoUrlCandidates.first.contains('somenewapp.com'), true);
  });
}

// (added) dedup: search must never return two entries with the same domain.
