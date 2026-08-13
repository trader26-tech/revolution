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
///   • what you PAY   — a premium, on any cadence (every N months / years), and
///   • what you GET   — a return, either a lump sum or amortized into a stream
///     of equal payouts (a monthly pension / an annual payout).
///
/// The form is deliberately GRADUAL: it opens as just a name, and reveals the
/// pay / get sections only as the earlier fields fill in — so it never reads as
/// a wall of inputs. A single compact "deal" strip shows the net at a glance,
/// instead of a large summary card.
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

  // Return side: for a lump sum we fill [_returnTotal]; for an amortized payout
  // (pension / annual) we fill [_perPayout] and the payout count instead.
  final _returnTotal = TextEditingController();
  final _perPayout = TextEditingController();

  /// Premium cadence: a unit (months / years) …
  RepeatCadence _cycle = RepeatCadence.monthly;

  /// … and an interval — "every N units". 1 = every month / year, 2 = every
  /// two months, 3 (months) = quarterly, and so on. Max fidelity, no presets.
  int _every = 1;

  /// When the policy matures — the day the return arrives / starts.
  DateTime _maturity = DateTime(DateTime.now().year + 10, DateTime.now().month,
      DateTime.now().day);

  PayoutMethod _payout = PayoutMethod.lumpSum;

  /// For an amortized payout: how many installments there are.
  int _payoutCount = 12;

  PlatformFile? _doc;
  bool _saving = false;

  bool get _isEdit => widget.editTask != null;
  bool get _valid => _name.text.trim().isNotEmpty;

  bool get _isAmortized => _payout != PayoutMethod.lumpSum;

  /// Progressive reveal — a section only appears once the prior one is started.
  bool get _showPay => _name.text.trim().isNotEmpty;
  bool get _showGet => _showPay && _premium.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    if (t != null) {
      _name.text = t.title;
      if (t.amount != null) _premium.text = _trim(t.amount!);
      if (t.repeat == RepeatCadence.monthly ||
          t.repeat == RepeatCadence.yearly) {
        _cycle = t.repeat;
      }
      if (t.repeatTimes > 1) _every = t.repeatTimes;
      if (t.maturityAt != null) _maturity = t.maturityAt!;
      if (t.payoutMethod != null) _payout = t.payoutMethod!;
      if (t.payoutAmount != null) {
        _perPayout.text = _trim(t.payoutAmount!);
        if (t.payoutCount != null) _payoutCount = t.payoutCount!;
      } else if (t.returnAmount != null) {
        _returnTotal.text = _trim(t.returnAmount!);
      }
    }
    _name.addListener(() => setState(() {}));
    _premium.addListener(() => setState(() {}));
    _returnTotal.addListener(() => setState(() {}));
    _perPayout.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _premium.dispose();
    _returnTotal.dispose();
    _perPayout.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[^0-9.]'), ''));

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// The total return, resolved from whichever side the user is filling:
  /// per-payout × count for an amortized plan, else the lump-sum total.
  double? get _resolvedReturn {
    if (_isAmortized) {
      final per = _num(_perPayout);
      if (per == null) return null;
      return per * _payoutCount;
    }
    return _num(_returnTotal);
  }

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

  /// A live [Task] built from the current inputs — drives the compact deal strip
  /// (premiumPeriods / totalPaidIn / netGain all live on Task).
  Task get _preview => Task(
        id: 'preview',
        title: _name.text,
        amount: _num(_premium),
        repeat: _cycle,
        repeatTimes: _every,
        returnAmount: _resolvedReturn,
        maturityAt: _maturity,
        payoutMethod: _payout,
        payoutAmount: _isAmortized ? _num(_perPayout) : null,
        payoutCount: _isAmortized ? _payoutCount : null,
      );

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final premium = _num(_premium);
      final ret = _resolvedReturn;
      final perPayout = _isAmortized ? _num(_perPayout) : null;
      final count = _isAmortized ? _payoutCount : null;

      if (_isEdit) {
        // Editing: patch the existing task in place.
        final updated = widget.editTask!.copyWith(
          title: _name.text.trim(),
          amount: premium,
          clearAmount: premium == null,
          repeat: _cycle,
          repeatTimes: _every,
          dueAt: _maturity, // the reminder fires as maturity approaches
          returnAmount: ret,
          clearReturnAmount: ret == null,
          maturityAt: _maturity,
          payoutMethod: _payout,
          payoutAmount: perPayout,
          clearPayoutAmount: perPayout == null,
          payoutCount: count,
          clearPayoutCount: count == null,
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
        repeatTimes: _every,
        amount: premium,
        currency: 'INR',
        category: 'policies',
        returnAmount: ret,
        maturityAt: _maturity,
        payoutMethod: _payout,
        payoutAmount: perPayout,
        payoutCount: count,
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
        // ── Name (always shown) ──
        const AddFieldLabel('POLICY NAME'),
        const SizedBox(height: 10),
        AddTextField(
          controller: _name,
          hint: 'LIC Jeevan Anand, PPF, endowment…',
          accent: _accent,
          textCapitalization: TextCapitalization.sentences,
        ),

        // ── What you PAY (revealed once a name is typed) ──
        _Reveal(
          shown: _showPay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              const SizedBox(height: 14),
              // "Every N months / years" — arbitrary cadence, max fidelity.
              _CadencePicker(
                every: _every,
                unit: _cycle,
                accent: _accent,
                onEveryChanged: (n) {
                  HapticFeedback.selectionClick();
                  setState(() => _every = n);
                },
                onUnitChanged: (u) {
                  HapticFeedback.selectionClick();
                  setState(() => _cycle = u);
                },
              ),
            ],
          ),
        ),

        // ── What you GET (revealed once a premium is typed) ──
        _Reveal(
          shown: _showGet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _SectionHeader(
                icon: Icons.south_west_rounded,
                label: 'What you get back',
                accent: _accent,
              ),
              const SizedBox(height: 12),
              const AddFieldLabel('HOW IT PAYS OUT'),
              const SizedBox(height: 10),
              _PayoutChips(
                value: _payout,
                accent: _accent,
                onChanged: (p) {
                  HapticFeedback.selectionClick();
                  setState(() => _payout = p);
                },
              ),
              const SizedBox(height: 20),

              // Lump sum → one total. Amortized → per-payout × count.
              if (_isAmortized) ...[
                AddFieldLabel(_payout == PayoutMethod.monthlyPension
                    ? 'AMOUNT PER MONTH'
                    : 'AMOUNT PER YEAR'),
                const SizedBox(height: 10),
                AddTextField(
                  controller: _perPayout,
                  hint: '5000',
                  accent: _accent,
                  prefix: '₹',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 16),
                AddFieldLabel(_payout == PayoutMethod.monthlyPension
                    ? 'FOR HOW MANY MONTHS'
                    : 'FOR HOW MANY YEARS'),
                const SizedBox(height: 10),
                _CountStepper(
                  value: _payoutCount,
                  accent: _accent,
                  suffix:
                      _payout == PayoutMethod.monthlyPension ? 'months' : 'years',
                  onChanged: (n) {
                    HapticFeedback.selectionClick();
                    setState(() => _payoutCount = n);
                  },
                ),
              ] else ...[
                const AddFieldLabel('RETURN AMOUNT'),
                const SizedBox(height: 10),
                AddTextField(
                  controller: _returnTotal,
                  hint: '1000000',
                  accent: _accent,
                  prefix: '₹',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
              ],

              const SizedBox(height: 22),
              const AddFieldLabel('MATURITY DATE'),
              const SizedBox(height: 10),
              AddDateField(
                  date: _maturity, accent: _accent, onTap: _pickMaturity),

              const SizedBox(height: 20),
              // The compact deal strip — net at a glance, not a giant card.
              _DealStrip(task: _preview, cycle: _cycle, accent: _accent),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // ── Optional document (always available) ──
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

// ── Progressive-reveal wrapper ───────────────────────────────────────────────

/// Fades + slides a section into view once [shown] flips true. Keeps the form
/// feeling light: fields appear as they become relevant instead of all at once.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.shown, required this.child});
  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: shown ? 1 : 0,
        child: shown ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}

// ── The compact "deal" strip ─────────────────────────────────────────────────

/// A single-line-ish strip showing the trade: total paid in vs. return, and the
/// net gain. Far lighter than a full summary card — it stays quiet until the
/// numbers exist, then shows only the rows we can actually compute.
class _DealStrip extends StatelessWidget {
  const _DealStrip({
    required this.task,
    required this.cycle,
    required this.accent,
  });

  final Task task;
  final RepeatCadence cycle;
  final Color accent;

  String _money(double v) {
    final whole = v.round();
    final s = whole.abs().toString();
    final buf = StringBuffer();
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
    final paid = task.totalPaidIn;
    final ret = task.returnAmount;
    final gain = task.netGain;

    // Not enough yet — one quiet hint line.
    if (paid == null && ret == null) {
      return _hint('Fill in the return to see the net of this deal.');
    }

    final gainPositive = (gain ?? 0) >= 0;
    final gainColor =
        gainPositive ? const Color(0xFF4ADE80) : const Color(0xFFF87171);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (paid != null)
                Expanded(
                  child: _miniStat('You pay in', _money(paid), AppColors.ink),
                ),
              if (ret != null)
                Expanded(
                  child: _miniStat('You get back', _money(ret), AppColors.ink),
                ),
            ],
          ),
          if (gain != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      gainPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 17,
                      color: gainColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gainPositive ? 'Net gain' : 'Net cost',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                Text(
                  _money(gain.abs()),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: gainColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _hint(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, size: 18, color: AppColors.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
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

// ── Premium cadence: "every [N] [months / years]" ────────────────────────────

/// A stepper for the interval N plus a two-way unit toggle. Together they cover
/// every real cadence — monthly, bi-monthly, quarterly (every 3 months),
/// half-yearly (every 6 months), yearly, every 2 years — with no fixed presets.
class _CadencePicker extends StatelessWidget {
  const _CadencePicker({
    required this.every,
    required this.unit,
    required this.accent,
    required this.onEveryChanged,
    required this.onUnitChanged,
  });

  final int every;
  final RepeatCadence unit;
  final Color accent;
  final ValueChanged<int> onEveryChanged;
  final ValueChanged<RepeatCadence> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final unitWord = unit == RepeatCadence.monthly ? 'month' : 'year';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Every',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            _Stepper(
              value: every,
              min: 1,
              max: 24,
              accent: accent,
              onChanged: onEveryChanged,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                every == 1 ? unitWord : '${unitWord}s',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final u in const [RepeatCadence.monthly, RepeatCadence.yearly])
              Expanded(
                child: GestureDetector(
                  onTap: () => onUnitChanged(u),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: u == RepeatCadence.monthly ? 10 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: u == unit
                          ? accent
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: u == unit ? accent : AppColors.cardBorder,
                        width: u == unit ? 1.6 : 1,
                      ),
                    ),
                    child: Text(
                      u == RepeatCadence.monthly ? 'Months' : 'Years',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: u == unit ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── A generic − N + stepper pill ─────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, value > min,
              () => onChanged((value - 1).clamp(min, max))),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _btn(Icons.add_rounded, value < max,
              () => onChanged((value + 1).clamp(min, max))),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? accent : AppColors.inkFaint,
        ),
      ),
    );
  }
}

// ── Payout-count stepper with a unit suffix ("× 20 years") ───────────────────

class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.value,
    required this.accent,
    required this.suffix,
    required this.onChanged,
  });

  final int value;
  final Color accent;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stepper(
          value: value,
          min: 1,
          max: 600,
          accent: accent,
          onChanged: onChanged,
        ),
        const SizedBox(width: 12),
        Text(
          suffix,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
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
