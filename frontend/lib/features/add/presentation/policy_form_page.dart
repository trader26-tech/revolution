import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/category_visuals.dart';
import '../../tasks/domain/task.dart';
import 'widgets/add_scaffold.dart';

/// The Policies form — a savings/endowment plan has TWO halves:
///   • what you PAY   — a premium, monthly or yearly, until maturity, and
///   • what you GET   — a return amount, at a maturity date, paid a certain way.
///
/// The form makes the trade legible: as you fill it, a live summary card shows
/// what you'll have paid in by maturity and the net gain on top — so you see
/// the whole deal at a glance, not just the numbers in isolation.
///
/// Like insurance it can attach the policy document, so it OWNS its save
/// (create the task → upload the doc → pop true). Returns true if it created
/// something, so the caller refreshes.
class PolicyFormPage extends StatefulWidget {
  const PolicyFormPage({super.key, required this.store, this.editTask});

  final TaskStore store;

  /// When set, the form opens pre-filled to EDIT this policy instead of adding.
  final Task? editTask;

  @override
  State<PolicyFormPage> createState() => _PolicyFormPageState();
}

class _PolicyFormPageState extends State<PolicyFormPage> {
  static final _accent = TaskCategory.policies.color;

  final _name = TextEditingController();
  final _premium = TextEditingController();
  final _return = TextEditingController();

  /// Premium cadence — a savings plan is usually paid monthly or yearly.
  RepeatCadence _cycle = RepeatCadence.yearly;

  /// When the policy matures — the day the return arrives / starts.
  DateTime _maturity = DateTime(DateTime.now().year + 10, DateTime.now().month,
      DateTime.now().day);

  PayoutMethod _payout = PayoutMethod.lumpSum;

  PlatformFile? _doc;
  bool _saving = false;

  bool get _isEdit => widget.editTask != null;
  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    if (t != null) {
      _name.text = t.title;
      if (t.amount != null) _premium.text = _trim(t.amount!);
      if (t.returnAmount != null) _return.text = _trim(t.returnAmount!);
      if (t.repeat == RepeatCadence.monthly ||
          t.repeat == RepeatCadence.yearly) {
        _cycle = t.repeat;
      }
      if (t.maturityAt != null) _maturity = t.maturityAt!;
      if (t.payoutMethod != null) _payout = t.payoutMethod!;
    }
    _name.addListener(() => setState(() {}));
    _premium.addListener(() => setState(() {}));
    _return.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _premium.dispose();
    _return.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[^0-9.]'), ''));

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _doc = result.files.first);
    }
  }

  Future<void> _pickMaturity() async {
    final picked = await showOrbitDatePicker(
      context,
      initial: _maturity,
      firstDate: DateTime(DateTime.now().year),
      lastDate: DateTime(DateTime.now().year + 60),
      title: 'Maturity date',
    );
    if (picked != null) setState(() => _maturity = picked);
  }

  /// A live [Task] built from the current inputs — drives the summary preview
  /// (premiumPeriods / totalPaidIn / netGain all live on Task).
  Task get _preview => Task(
        id: 'preview',
        title: _name.text,
        amount: _num(_premium),
        repeat: _cycle,
        returnAmount: _num(_return),
        maturityAt: _maturity,
        payoutMethod: _payout,
      );

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final premium = _num(_premium);
      final ret = _num(_return);

      if (_isEdit) {
        // Editing: patch the existing task in place.
        final updated = widget.editTask!.copyWith(
          title: _name.text.trim(),
          amount: premium,
          clearAmount: premium == null,
          repeat: _cycle,
          dueAt: _maturity, // the reminder fires as maturity approaches
          returnAmount: ret,
          clearReturnAmount: ret == null,
          maturityAt: _maturity,
          payoutMethod: _payout,
          category: TaskCategory.policies,
        );
        widget.store.update(updated);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // Adding: create → upload doc → pop.
      final created = await widget.store.add(
        _name.text.trim(),
        dueAt: _maturity,
        repeat: _cycle,
        amount: premium,
        currency: 'INR',
        category: 'policies',
        returnAmount: ret,
        maturityAt: _maturity,
        payoutMethod: _payout,
      );
      final doc = _doc;
      if (doc != null && doc.bytes != null) {
        await ApiClient.instance.uploadDocument(
          created.id,
          bytes: doc.bytes!,
          filename: doc.name,
          contentType: _mimeFor(doc.extension),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AddScaffold(
      title: _isEdit ? 'Edit policy' : 'Add a policy',
      accent: _accent,
      icon: TaskCategory.policies.icon,
      canSave: _valid && !_saving,
      onSave: _save,
      saveLabel: _saving ? 'Saving…' : (_isEdit ? 'Save' : 'Add'),
      children: [
        // ── Name ──
        const AddFieldLabel('POLICY NAME'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _name,
          hint: 'LIC Jeevan Anand, PPF, endowment…',
          accent: _accent,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 24),

        // ── What you PAY ──
        _SectionHeader(
          icon: Icons.north_east_rounded,
          label: 'What you pay',
          accent: _accent,
        ),
        const SizedBox(height: 12),
        const AddFieldLabel('PREMIUM'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _premium,
          hint: '25000',
          accent: _accent,
          prefix: '₹',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: 14),
        // Monthly vs yearly — the two cadences a plan is ever paid on.
        _CadenceToggle(
          value: _cycle,
          accent: _accent,
          onChanged: (c) {
            HapticFeedback.selectionClick();
            setState(() => _cycle = c);
          },
        ),
        const SizedBox(height: 24),

        // ── What you GET ──
        _SectionHeader(
          icon: Icons.south_west_rounded,
          label: 'What you get back',
          accent: _accent,
        ),
        const SizedBox(height: 12),
        const AddFieldLabel('RETURN AMOUNT'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _return,
          hint: '1000000',
          accent: _accent,
          prefix: '₹',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        const SizedBox(height: 22),
        const AddFieldLabel('MATURITY DATE'),
        const SizedBox(height: 10),
        AddDateField(date: _maturity, accent: _accent, onTap: _pickMaturity),
        const SizedBox(height: 22),
        const AddFieldLabel('HOW YOU GET IT'),
        const SizedBox(height: 10),
        _PayoutChips(
          value: _payout,
          accent: _accent,
          onChanged: (p) {
            HapticFeedback.selectionClick();
            setState(() => _payout = p);
          },
        ),
        const SizedBox(height: 24),

        // ── The live deal summary ──
        _DealSummary(task: _preview, cycle: _cycle, accent: _accent),
        const SizedBox(height: 24),

        // ── Optional document ──
        const AddFieldLabel('POLICY DOCUMENT  (optional)'),
        const SizedBox(height: 10),
        _DocumentCard(
          file: _doc,
          hasExisting: _isEdit && (widget.editTask?.hasDocument ?? false),
          accent: _accent,
          onPick: _pickDocument,
          onClear: () => setState(() => _doc = null),
        ),
      ],
    );
  }
}

// ── The live "deal" card — the heart of this form ────────────────────────────

/// Shows the trade at a glance: total you'll pay in by maturity, the return,
/// and the net gain on top — computed live from the current inputs. Only the
/// rows we can actually compute are shown, so a half-filled form still reads
/// cleanly instead of showing "—" everywhere.
class _DealSummary extends StatelessWidget {
  const _DealSummary({
    required this.task,
    required this.cycle,
    required this.accent,
  });

  final Task task;
  final RepeatCadence cycle;
  final Color accent;

  String _money(double v) {
    // Compact Indian-style grouping without a locale dep: just group and prefix.
    final whole = v.round();
    final s = whole.abs().toString();
    final buf = StringBuffer();
    // Last 3 digits, then groups of 2 (1,00,000 style).
    final rev = s.split('').reversed.toList();
    for (var i = 0; i < rev.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) buf.write(',');
      buf.write(rev[i]);
    }
    final grouped = buf.toString().split('').reversed.join();
    return '${v < 0 ? '-' : ''}₹$grouped';
  }

  @override
  Widget build(BuildContext context) {
    final periods = task.premiumPeriods;
    final paid = task.totalPaidIn;
    final gain = task.netGain;
    final ret = task.returnAmount;

    // Nothing to show yet — keep the form quiet until there's a real figure.
    if (paid == null && ret == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_rounded, size: 20, color: AppColors.inkFaint),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Fill in the premium and return to see the whole deal.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final gainPositive = (gain ?? 0) >= 0;
    final gainColor =
        gainPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                'THE DEAL',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (paid != null)
            _SummaryRow(
              label: periods != null
                  ? 'You pay in ($periods ${cycle == RepeatCadence.monthly ? "months" : "years"})'
                  : 'You pay in',
              value: _money(paid),
              valueColor: AppColors.ink,
            ),
          if (ret != null) ...[
            const SizedBox(height: 10),
            _SummaryRow(
              label: 'You get back',
              value: _money(ret),
              valueColor: AppColors.ink,
            ),
          ],
          if (gain != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.hairline),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      gainPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 18,
                      color: gainColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gainPositive ? 'Net gain' : 'Net cost',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                Text(
                  _money(gain.abs()),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: gainColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            task.payoutMethod?.blurb ?? '',
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── A small labelled section header (pay / get) ──────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ── Monthly / Yearly premium toggle ──────────────────────────────────────────

class _CadenceToggle extends StatelessWidget {
  const _CadenceToggle({
    required this.value,
    required this.accent,
    required this.onChanged,
  });
  final RepeatCadence value;
  final Color accent;
  final ValueChanged<RepeatCadence> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in const [RepeatCadence.monthly, RepeatCadence.yearly])
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                margin: EdgeInsets.only(
                    right: c == RepeatCadence.monthly ? 10 : 0),
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c == value
                      ? accent
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: c == value ? accent : AppColors.cardBorder,
                    width: c == value ? 1.6 : 1,
                  ),
                ),
                child: Text(
                  c == RepeatCadence.monthly ? 'Per month' : 'Per year',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: c == value ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Payout method chips ──────────────────────────────────────────────────────

class _PayoutChips extends StatelessWidget {
  const _PayoutChips({
    required this.value,
    required this.accent,
    required this.onChanged,
  });
  final PayoutMethod value;
  final Color accent;
  final ValueChanged<PayoutMethod> onChanged;

  IconData _icon(PayoutMethod p) => switch (p) {
        PayoutMethod.lumpSum => Icons.payments_rounded,
        PayoutMethod.monthlyPension => Icons.calendar_month_rounded,
        PayoutMethod.annualPayout => Icons.event_repeat_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in PayoutMethod.values)
          GestureDetector(
            onTap: () => onChanged(p),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    p == value ? accent : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: p == value ? accent : AppColors.cardBorder,
                  width: p == value ? 1.6 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(p),
                      size: 16,
                      color: p == value ? Colors.white : AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p == value ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Document attach (mirrors the insurance form's tile) ──────────────────────

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.file,
    required this.hasExisting,
    required this.accent,
    required this.onPick,
    required this.onClear,
  });

  final PlatformFile? file;
  final bool hasExisting;
  final Color accent;
  final VoidCallback onPick;
  final VoidCallback onClear;

  bool get _isPdf => (file?.extension ?? '').toLowerCase() == 'pdf';

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded, size: 26, color: accent),
              const SizedBox(height: 6),
              Text(
                hasExisting ? 'Replace the document' : 'Attach the policy',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'PDF or photo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Attached · tap the icon on Home to view',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accent.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

/// Best-effort MIME for a picked file extension.
String _mimeFor(String? ext) => switch ((ext ?? '').toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
