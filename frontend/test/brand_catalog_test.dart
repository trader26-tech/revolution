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
}
