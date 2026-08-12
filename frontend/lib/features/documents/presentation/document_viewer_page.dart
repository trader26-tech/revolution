import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../domain/document.dart';

/// Views a LOCAL document INSIDE the app — a full-screen reader that renders the
/// file itself (no bounce to an external app):
///   • images → a pinch-to-zoom viewer
///   • PDFs   → scrollable, zoomable pages (rendered by pdfx)
/// A Share button in the top bar sends the actual on-device file.
class DocumentViewerPage extends StatelessWidget {
  const DocumentViewerPage({super.key, required this.doc});

  final DocItem doc;

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    await Share.shareXFiles(
      [XFile(doc.localPath, name: doc.originalName ?? doc.name)],
      subject: doc.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            _ViewerBar(title: doc.name, onShare: _share),
            const SizedBox(height: 4),
            Expanded(
              child: doc.isPdf
                  ? _PdfView(path: doc.localPath)
                  : _ImageView(path: doc.localPath),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerBar extends StatelessWidget {
  const _ViewerBar({required this.title, required this.onShare});
  final String title;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
          ),
          GlassIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: 'Share',
            accent: true,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

/// Pinch-to-zoom image viewer.
class _ImageView extends StatelessWidget {
  const _ImageView({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, err, _) => const _ViewerError(),
        ),
      ),
    );
  }
}

/// In-app PDF reader — scrollable, zoomable pages.
class _PdfView extends StatefulWidget {
  const _PdfView({required this.path});
  final String path;

  @override
  State<_PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<_PdfView> {
  late final PdfControllerPinch _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = PdfControllerPinch(
        document: PdfDocument.openFile(widget.path),
      );
    } catch (_) {
      _failed = true;
    }
  }

  @override
  void dispose() {
    if (!_failed) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _ViewerError(path: widget.path);
    return PdfViewPinch(
      controller: _controller,
      onDocumentError: (_) {
        if (mounted) setState(() => _failed = true);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        errorBuilder: (_, err) => _ViewerError(path: widget.path),
      ),
    );
  }
}

/// Shown when a format can't be rendered in-app — offers the OS viewer as a
/// last resort so the file is never a dead end.
class _ViewerError extends StatelessWidget {
  const _ViewerError({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off_rounded,
                size: 40, color: AppColors.inkFaint),
            const SizedBox(height: 14),
            const Text(
              "Can't preview this file here",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (path != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => OpenFilex.open(path!),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open with…'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
