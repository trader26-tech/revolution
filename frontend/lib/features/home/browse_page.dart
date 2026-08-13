import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../documents/data/documents_store.dart';
import '../documents/presentation/documents_page.dart';
import '../tasks/data/task_store.dart';
import '../tasks/domain/task.dart';
import 'presentation/collection_page.dart';
import 'presentation/widgets/home_dashboard.dart';

/// The Browse tab — the launcher to every category's collection (Subscriptions,
/// SIPs, Policies…), the local Documents library, and the "All" view. Moved out
/// of the Home feed onto its own nav destination, so Home stays purely today's
/// bubbles and Browse is where you go to explore everything you track.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, required this.store});

  final TaskStore store;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _documents = DocumentsStore();

  @override
  void initState() {
    super.initState();
    _documents.load();
  }

  @override
  void dispose() {
    _documents.dispose();
    super.dispose();
  }

  void _openDocuments() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentsPage(store: _documents)),
    );
  }

  void _openCollection(TaskCategory? category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionPage(store: widget.store, category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 4, 22, 2),
            child: Text(
              'Browse',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.ink,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 0),
            child: Text(
              'Everything you track, by category.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([widget.store, _documents]),
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 120),
                  children: [
                    BrowseGrid(
                      tasks: widget.store.tasks,
                      onOpenCategory: _openCollection,
                      onOpenAll: () => _openCollection(null),
                      onOpenDocuments: _openDocuments,
                      documentCount: _documents.totalCount,
                      showHeader: false,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
