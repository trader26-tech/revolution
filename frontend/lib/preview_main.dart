// Throwaway preview: first add row after tapping +. Not shipped.
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/tasks/presentation/widgets/quick_add_row.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    final focus = FocusNode();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 20),
            children: [
              QuickAddRow(
                controller: controller,
                focusNode: focus,
                onSubmitText: () {},
                onTapOutsideEmpty: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
