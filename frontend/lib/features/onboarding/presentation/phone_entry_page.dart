import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../panda/presentation/panda_mascot.dart';
import '../data/verification_repository.dart';
import 'whatsapp_verify_page.dart';

/// A supported dialing region. `code` is the ISO region passed to the backend,
/// which uses it to interpret numbers typed without a country code.
class _Region {
  const _Region(this.code, this.dial, this.flag, this.label);
  final String code;
  final String dial;
  final String flag;
  final String label;
}

const _regions = <_Region>[
  _Region('IN', '+91', '🇮🇳', 'India'),
  _Region('KW', '+965', '🇰🇼', 'Kuwait'),
  _Region('AE', '+971', '🇦🇪', 'UAE'),
  _Region('SA', '+966', '🇸🇦', 'Saudi Arabia'),
  _Region('US', '+1', '🇺🇸', 'United States'),
  _Region('GB', '+44', '🇬🇧', 'United Kingdom'),
];

/// First onboarding screen: collect and verify the user's phone number.
///
/// On success it invokes [onVerified] with the confirmed E.164 number.
class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key, this.repository, this.onVerified});

  final VerificationRepository? repository;
  final ValueChanged<String>? onVerified;

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  late final VerificationRepository _repo =
      widget.repository ?? VerificationRepository();
  final _controller = TextEditingController();

  _Region _region = _regions.first;
  bool _submitting = false;
  String? _error;

  bool get _canSubmit => _controller.text.trim().length >= 6 && !_submitting;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    // Send the number with its dial code prefixed so the backend gets an
    // unambiguous E.164 value; region is a fallback for how it's interpreted.
    final raw = _controller.text.trim();
    final phone = raw.startsWith('+') ? raw : '${_region.dial}$raw';

    try {
      final start = await _repo.start(phone, region: _region.code);
      if (!mounted) return;
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => WhatsAppVerifyPage(start: start, repository: _repo),
        ),
      );
      if (verified == true && mounted) {
        widget.onVerified?.call(start.phone);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    // The backend returns 422 with a validation message for bad numbers.
    if (s.contains('valid') || s.contains('phone') || s.contains('country')) {
      return "That number doesn't look right. Check the country and try again.";
    }
    return "Couldn't start verification. Check your connection and try again.";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(child: PandaMascot(size: 160, mood: PandaMood.happy)),
                const SizedBox(height: 20),
                Text(
                  "HOT RELOAD WORKS ✅",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Pip will verify it in one tap over WhatsApp — no SMS, no code to type back.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 28),
                _PhoneField(
                  controller: _controller,
                  region: _region,
                  onRegionTap: _pickRegion,
                  onChanged: (_) => setState(() {}),
                  onSubmit: _submit,
                  hasError: _error != null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Your number stays private.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickRegion() async {
    final picked = await showModalBottomSheet<_Region>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final r in _regions)
            ListTile(
              leading: Text(r.flag, style: const TextStyle(fontSize: 24)),
              title: Text(r.label),
              trailing: Text(r.dial),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _region = picked);
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.region,
    required this.onRegionTap,
    required this.onChanged,
    required this.onSubmit,
    required this.hasError,
  });

  final TextEditingController controller;
  final _Region region;
  final VoidCallback onRegionTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? scheme.error : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onRegionTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Text(region.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(region.dial,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 28, color: scheme.outlineVariant),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
              ],
              style: Theme.of(context).textTheme.titleMedium,
              decoration: const InputDecoration(
                hintText: 'Phone number',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
