import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../mascot/presentation/bobo_mascot.dart';
import '../data/verification_repository.dart';
import '../domain/phone_verification.dart';

/// Second onboarding screen: the user taps once to open WhatsApp with the code
/// pre-filled, sends it, and we poll the backend until the inbound message
/// arrives and flips the attempt to 'verified'.
///
/// Pops with `true` when verified, `false`/null if the user backs out.
class WhatsAppVerifyPage extends StatefulWidget {
  const WhatsAppVerifyPage({
    super.key,
    required this.start,
    required this.repository,
  });

  final VerificationStart start;
  final VerificationRepository repository;

  @override
  State<WhatsAppVerifyPage> createState() => _WhatsAppVerifyPageState();
}

class _WhatsAppVerifyPageState extends State<WhatsAppVerifyPage> {
  Timer? _poll;
  bool _verified = false;
  bool _expired = false;
  bool _openedWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final state = await widget.repository.status(widget.start.id);
      if (!mounted) return;
      if (state.verified) {
        _poll?.cancel();
        setState(() => _verified = true);
        // Let the success state show briefly, then hand back to onboarding.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.of(context).pop(true);
      } else if (state.isExpired) {
        _poll?.cancel();
        setState(() => _expired = true);
      }
    } catch (_) {
      // Transient network hiccup — keep polling.
    }
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(widget.start.whatsappUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _openedWhatsApp = ok);
    if (!ok && mounted) {
      // WhatsApp not installed / link failed — offer the manual fallback.
      _showManualFallback();
    }
  }

  void _showManualFallback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Couldn\'t open WhatsApp. Copy the message below and send it to us.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: _verified
                ? _VerifiedView(phone: widget.start.phone)
                : _expired
                    ? _ExpiredView(onRetry: () => Navigator.of(context).pop(false))
                    : _PendingView(
                        start: widget.start,
                        openedWhatsApp: _openedWhatsApp,
                        onOpenWhatsApp: _openWhatsApp,
                      ),
          ),
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView({
    required this.start,
    required this.openedWhatsApp,
    required this.onOpenWhatsApp,
  });

  final VerificationStart start;
  final bool openedWhatsApp;
  final VoidCallback onOpenWhatsApp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(child: BoboMascot(size: 140, mood: BoboMood.excited)),
        const SizedBox(height: 20),
        Text(
          'Verify over WhatsApp',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the button, then just hit send in WhatsApp. '
          'Bobo confirms your number the moment it arrives — nothing to type back.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        _MessagePreview(message: start.whatsappMessage, phone: start.phone),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onOpenWhatsApp,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366), // WhatsApp green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.chat_bubble),
          label: Text(openedWhatsApp ? 'Open WhatsApp again' : 'Verify on WhatsApp'),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              openedWhatsApp
                  ? 'Waiting for your message…'
                  : 'Waiting for you to send…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        if (start.debugCode != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'DEV: code is ${start.debugCode}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.message, required this.phone});
  final String message;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This message is ready to send:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied ✅')),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Verifying $phone',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 40),
        const BoboMascot(size: 160, mood: BoboMood.happy),
        const SizedBox(height: 24),
        Icon(Icons.verified, size: 48, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          'Number verified!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          phone,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ExpiredView extends StatelessWidget {
  const _ExpiredView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.timer_off, size: 48, color: scheme.error),
        const SizedBox(height: 16),
        Text(
          'That code expired',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'No worries — head back and we\'ll get you a fresh one.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
