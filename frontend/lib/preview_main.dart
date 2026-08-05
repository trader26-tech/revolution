// Throwaway preview: details page without List / Payment Method. Not shipped.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/details/domain/item_details.dart';
import 'features/details/presentation/item_details_page.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ItemDetailsPage(
        title: 'Renew car insurance',
        initial: ItemDetails(name: 'Renew car insurance'),
      ),
    );
  }
}
