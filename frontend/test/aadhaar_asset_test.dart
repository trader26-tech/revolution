import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revolution/features/brand/domain/brand.dart';
import 'package:revolution/features/brand/presentation/brand_logo.dart';

void main() {
  testWidgets('bundled Aadhaar logo renders from assets', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: BrandLogo(
            brand: Brand(
              name: 'Aadhaar',
              domain: 'uidai.gov.in',
              assetPath: 'assets/images/aadhaar.png',
            ),
            size: 40,
            bare: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // An asset-backed logo must resolve to a real Image, not the letter avatar.
    expect(find.byType(Image), findsOneWidget);
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<AssetImage>());
    expect((img.image as AssetImage).assetName, 'assets/images/aadhaar.png');
    expect(tester.takeException(), isNull);
  });
}
