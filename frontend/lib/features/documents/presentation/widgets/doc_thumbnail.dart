import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/document.dart';

/// The little preview shown in a document row (and reusable elsewhere): the
/// actual IMAGE for image files, a rendered FIRST-PAGE for PDFs, so you can see
/// the attached document right in the list. Falls back to a format glyph.
class DocThumbnail extends StatelessWidget {
  const DocThumbnail({super.key, required this.doc, this.size = 44});

  final DocItem doc;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: doc.isPdf
            ? _PdfThumb(path: doc.localPath, size: size)
            : _ImageThumb(path: doc.localPath, size: size),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.path, required this.size});
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 3).round(), // crisp on hi-dpi, cheap to decode
      errorBuilder: (_, err, _) =>
          _GlyphTile(size: size, icon: Icons.image_rounded),
    );
  }
}

/// Renders the PDF's first page to a small bitmap once, cached in a static map
/// so scrolling the list doesn't re-render.
class _PdfThumb extends StatefulWidget {
  const _PdfThumb({required this.path, required this.size});
  final String path;
  final double size;

  @override
  State<_PdfThumb> createState() => _PdfThumbState();
}

class _PdfThumbState extends State<_PdfThumb> {
  static final Map<String, Uint8List?> _cache = {};
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.path)) {
      setState(() {
        _bytes = _cache[widget.path];
        _loading = false;
      });
      return;
    }
    try {
      final doc = await PdfDocument.openFile(widget.path);
      final page = await doc.getPage(1);
      final px = (widget.size * 3).round();
      final img = await page.render(
        width: px.toDouble(),
        height: (px * page.height / page.width),
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await doc.close();
      _cache[widget.path] = img?.bytes;
      if (mounted) {
        setState(() {
          _bytes = img?.bytes;
          _loading = false;
        });
      }
    } catch (_) {
      _cache[widget.path] = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _GlyphTile(size: widget.size, icon: Icons.picture_as_pdf_rounded);
    }
    final b = _bytes;
    if (b == null) {
      return _GlyphTile(size: widget.size, icon: Icons.picture_as_pdf_rounded);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(b, fit: BoxFit.cover),
        // A tiny PDF corner badge so it's obviously a document, not a photo.
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: const BoxDecoration(
              color: Color(0xE6E4342B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(6)),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.size, required this.icon});
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.accent.withValues(alpha: 0.12),
      child: Icon(icon, size: size * 0.46, color: AppColors.accent),
    );
  }
}
