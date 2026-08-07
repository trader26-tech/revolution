import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'rev_templates.dart';

/// A browsable gallery of every Rev pose template — for picking the right one
/// while designing screens. Push it from anywhere:
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const RevGalleryPage()),
/// );
/// ```
class RevGalleryPage extends StatefulWidget {
  const RevGalleryPage({super.key});

  @override
  State<RevGalleryPage> createState() => _RevGalleryPageState();
}

class _RevGalleryPageState extends State<RevGalleryPage> {
  RevFacing _facing = RevFacing.right;

  void _flip() => setState(() => _facing =
      _facing == RevFacing.right ? RevFacing.left : RevFacing.right);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.ink),
        title: const Text(
          'Rev templates',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        actions: [
          IconButton(
            onPressed: _flip,
            tooltip: 'Flip facing',
            icon: const Icon(Icons.flip_rounded, color: AppColors.inkSoft),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: RevPose.values.length,
          itemBuilder: (_, i) => _PoseCard(
            pose: RevPose.values[i],
            facing: _facing,
            onTap: () => _openDetail(RevPose.values[i]),
          ),
        ),
      ),
    );
  }

  void _openDetail(RevPose pose) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PoseDetailSheet(pose: pose, initialFacing: _facing),
    );
  }
}

class _PoseCard extends StatelessWidget {
  const _PoseCard({
    required this.pose,
    required this.facing,
    required this.onTap,
  });

  final RevPose pose;
  final RevFacing facing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Rev(pose: pose, size: 110, facing: facing),
                ),
              ),
              Text(
                pose.label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pose.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoseDetailSheet extends StatefulWidget {
  const _PoseDetailSheet({required this.pose, required this.initialFacing});

  final RevPose pose;
  final RevFacing initialFacing;

  @override
  State<_PoseDetailSheet> createState() => _PoseDetailSheetState();
}

class _PoseDetailSheetState extends State<_PoseDetailSheet> {
  late RevFacing _facing = widget.initialFacing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Rev(pose: widget.pose, size: 240, facing: _facing),
            const SizedBox(height: 14),
            Text(
              widget.pose.label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pose.hint,
              style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            SegmentedButton<RevFacing>(
              segments: const [
                ButtonSegment(
                  value: RevFacing.right,
                  label: Text('Faces right'),
                ),
                ButtonSegment(
                  value: RevFacing.left,
                  label: Text('Faces left'),
                ),
              ],
              selected: {_facing},
              onSelectionChanged: (s) => setState(() => _facing = s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }
}
