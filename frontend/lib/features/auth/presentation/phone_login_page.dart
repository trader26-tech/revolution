import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../mascot/presentation/bobo_mascot.dart';
import '../data/auth_repository.dart';
import '../data/auth_store.dart';

/// A supported dialing region. `dial` is prefixed to numbers typed without one.
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

/// Phone-number login. Enter a number → the backend finds-or-creates the
/// account → [onLoggedIn] fires with the session.
///
/// No OTP yet: the number is taken at face value (verification lands later).
/// An existing number logs into that account; a new one creates it.
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({
    super.key,
    required this.onLoggedIn,
    this.repository,
  });

  final AuthRepository? repository;
  final ValueChanged<AuthSession> onLoggedIn;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  late final AuthRepository _auth = widget.repository ?? AuthRepository();
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

    final raw = _controller.text.trim();
    final phone = raw.startsWith('+') ? raw : '${_region.dial}$raw';

    try {
      final result = await _auth.loginWithPhone(phone);
      if (!mounted) return;
      // A tiny welcome differs for new vs returning accounts.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isNew ? 'Welcome to Revolution! 🐼' : 'Welcome back! 🐼',
          ),
        ),
      );
      widget.onLoggedIn(result.session);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('valid') || s.contains('phone')) {
      return "That number doesn't look right. Check the country and try again.";
    }
    return "Couldn't sign you in. Check your connection and try again.";
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
                const Center(child: BoboMascot(size: 160, mood: BoboMood.happy)),
                const SizedBox(height: 20),
                Text(
                  "What's your number?",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in with your phone number. New here? This creates your '
                  'account. Coming back? It opens the one you already have.',
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
