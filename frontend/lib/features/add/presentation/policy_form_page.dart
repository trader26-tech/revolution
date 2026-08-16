import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/orbit_date_picker.dart';
import '../../../core/widgets/starfield.dart';
import '../../details/domain/currency.dart' show currencyOf, formatAmount;
import '../../tasks/data/task_store.dart';
import '../../tasks/domain/task.dart';
import 'widgets/orbit_form.dart';

/// The Policies form — a savings/endowment plan, in the SAME orbit design
/// language as the SIP / subscription / occasion forms so the add surface reads
/// as one consistent story:
///   • an identity card   — the policy name + the premium you pay, and
///   • a "Plan" card       — how often you pay (frequency), when it matures, and
///                           how it pays back, and
///   • a "Return" card     — the amount you get (a lump sum, or a per-installment
///                           stream), and
///   • an optional document.
/// A compact "deal" strip shows the net of it all at a glance.
///
/// Like insurance it OWNS its save (create the task → upload the doc → pop true).
/// Returns true if it created something, so the caller refreshes.
class PolicyFormPage extends StatefulWidget {
  const PolicyFormPage(
      {super.key, required this.store, this.editTask, this.onDelete});

  final TaskStore store;

  /// When set, the form opens pre-filled to EDIT this policy instead of adding.
  final Task? editTask;

  /// Edit mode only — confirm + delete this task (returns true when deleted).
  final Future<bool> Function()? onDelete;

  @override
  State<PolicyFormPage> createState() => _PolicyFormPageState();
}

class _PolicyFormPageState extends State<PolicyFormPage> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _premium = TextEditingController();
  final _premiumFocus = FocusNode();

  // Return side: for a lump sum we fill [_returnTotal]; for an amortized payout
  // (pension / annual) we fill [_perPayout] and the payout count instead.
  final _returnTotal = TextEditingController();
  final _perPayout = TextEditingController();

  String _currency = 'INR';

  /// Premium cadence: a unit (months / years) and an interval — "every N units".
  /// Shown through the shared frequency picker, exactly like the SIP form, so
  /// "Every month / Every 2 months / Every year" reads consistently everywhere.
  RepeatCadence _cycle = RepeatCadence.yearly;
  int _every = 1;

  /// When the FIRST premium is due — the reminder starts here, then recurs on
  /// the cadence. Defaults to today.
  DateTime _start = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

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

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    if (t != null) {
      _name.text = t.title;
      _currency = t.currency;
      if (t.amount != null) {
        _premium.text = formatAmount(_trim(t.amount!), currencyOf(_currency).grouping);
      }
      if (t.repeat == RepeatCadence.monthly ||
          t.repeat == RepeatCadence.yearly) {
        _cycle = t.repeat;
      }
      if (t.repeatTimes > 1) _every = t.repeatTimes;
      // The first-premium/reminder date is the task's dueAt.
      if (t.dueAt != null) _start = t.dueAt!;
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
    _nameFocus.dispose();
    _premium.dispose();
    _premiumFocus.dispose();
    _returnTotal.dispose();
    _perPayout.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'[^0-9.]'), ''));

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String get _symbol => currencyOf(_currency).symbol;

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

  Future<void> _pickStart() async {
    final picked = await showOrbitDatePicker(
      context,
      initial: _start,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 60),
      title: 'First premium date',
    );
    if (picked != null) setState(() => _start = picked);
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

  Future<void> _pickFrequency() async {
    final r = await showFrequencyPicker(
      context,
      unit: _cycle == RepeatCadence.monthly
          ? RepeatCadence.monthly
          : RepeatCadence.yearly,
      interval: _every,
    );
    if (r != null) {
      setState(() {
        // A policy premium is monthly or yearly; clamp anything else to yearly.
        _cycle = r.unit == RepeatCadence.monthly
            ? RepeatCadence.monthly
            : RepeatCadence.yearly;
        _every = r.interval;
      });
    }
  }

  Future<void> _pickCurrency() async {
    final picked = await showCurrencyPicker(context, _currency);
    if (picked != null) {
      setState(() {
        _currency = picked;
        _premium.text =
            formatAmount(_premium.text, currencyOf(picked).grouping);
      });
    }
  }

  Future<void> _pickPayout() async {
    final picked = await showModalBottomSheet<PayoutMethod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayoutSheet(selected: _payout),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _payout = picked);
    }
  }

  String _dateLabel(DateTime d) {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  /// A live [Task] built from the current inputs — drives the compact deal strip.
  Task get _preview => Task(
        id: 'preview',
        title: _name.text,
        amount: _num(_premium),
        currency: _currency,
        repeat: _cycle,
        repeatTimes: _every,
        returnAmount: _resolvedReturn,
        maturityAt: _maturity,
        payoutMethod: _payout,
        payoutAmount: _isAmortized ? _num(_perPayout) : null,
        payoutCount: _isAmortized ? _payoutCount : null,
      );

  Future<void> _handleDelete() async {
    final deleted = await widget.onDelete!();
    // Policy returns bool (saved?) to openEditForm — false = not saved; the task
    // is already removed, so just pop.
    if (deleted && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final premium = _num(_premium);
      final ret = _resolvedReturn;
      final perPayout = _isAmortized ? _num(_perPayout) : null;
      final count = _isAmortized ? _payoutCount : null;

      if (_isEdit) {
        final updated = widget.editTask!.copyWith(
          title: _name.text.trim(),
          amount: premium,
          clearAmount: premium == null,
          currency: _currency,
          repeat: _cycle,
          repeatTimes: _every,
          dueAt: _start, // the reminder fires at the first premium, then recurs
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

      final created = await widget.store.add(
        _name.text.trim(),
        dueAt: _start,
        repeat: _cycle,
        repeatTimes: _every,
        amount: premium,
        currency: _currency,
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
    final payoutIsMonthly = _payout == PayoutMethod.monthlyPension;
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Starfield(
        intensity: 0.5,
        child: SafeArea(
          child: Column(
            children: [
              OrbitFormHeader(
                title: _isEdit ? 'Edit policy' : 'Add a policy',
                canSave: _valid && !_saving,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: _save,
                onDelete: widget.onDelete == null ? null : _handleDelete,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    // ── Identity: policy name + premium you pay ──
                    OrbitIdentityCard(
                      iconName: null,
                      iconDomain: null,
                      nameController: _name,
                      nameFocus: _nameFocus,
                      amountController: _premium,
                      amountFocus: _premiumFocus,
                      onPickIcon: () {}, // a policy has no brand logo
                      currency: _currency,
                      onPickCurrency: _pickCurrency,
                      nameHint: 'LIC Jeevan Anand, PPF, endowment…',
                      amountHint: '25000',
                      emptyIcon: Icons.account_balance_rounded,
                    ),
                    const OrbitSaveHint(),
                    const SizedBox(height: 18),

                    // ── The plan: how often you pay · maturity · payout style ──
                    const _GroupLabel('THE PLAN'),
                    const SizedBox(height: 8),
                    OrbitGroupCard(
                      children: [
                        OrbitNavRow(
                          label: 'First premium',
                          value: _dateLabel(_start),
                          onTap: _pickStart,
                        ),
                        const OrbitRowDivider(),
                        OrbitNavRow(
                          label: 'Premium every',
                          value: frequencyLabel(_cycle, _every),
                          onTap: _pickFrequency,
                        ),
                        const OrbitRowDivider(),
                        OrbitNavRow(
                          label: 'Matures on',
                          value: _dateLabel(_maturity),
                          onTap: _pickMaturity,
                        ),
                        const OrbitRowDivider(),
                        OrbitNavRow(
                          label: 'Pays back as',
                          value: _payout.label,
                          onTap: _pickPayout,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── The return: lump sum, or a per-installment stream ──
                    const _GroupLabel('THE RETURN'),
                    const SizedBox(height: 8),
                    OrbitGroupCard(
                      children: _isAmortized
                          ? [
                              _AmountRow(
                                label: payoutIsMonthly
                                    ? 'Amount / month'
                                    : 'Amount / year',
                                controller: _perPayout,
                                symbol: _symbol,
                                hint: '5000',
                              ),
                              const OrbitRowDivider(),
                              _StepperRow(
                                label:
                                    payoutIsMonthly ? 'For months' : 'For years',
                                value: _payoutCount,
                                suffix: payoutIsMonthly ? 'months' : 'years',
                                onChanged: (n) => setState(
                                    () => _payoutCount = n),
                              ),
                            ]
                          : [
                              _AmountRow(
                                label: 'Return amount',
                                controller: _returnTotal,
                                symbol: _symbol,
                                hint: '1000000',
                              ),
                            ],
                    ),
                    const SizedBox(height: 14),

                    // ── The deal at a glance ──
                    _DealStrip(task: _preview, cycle: _cycle),
                    const SizedBox(height: 18),

                    // ── Optional document ──
                    const _GroupLabel('DOCUMENT  ·  OPTIONAL'),
                    const SizedBox(height: 8),
                    _DocumentCard(
                      file: _doc,
                      hasExisting:
                          _isEdit && (widget.editTask?.hasDocument ?? false),
                      onPick: _pickDocument,
                      onClear: () => setState(() => _doc = null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small uppercase section label above a group card — matches the calm,
/// aligned rhythm the other orbit forms use.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

/// A group-card row with a label on the left and a right-aligned amount input
/// (currency symbol + number) — so money entry lives in the same aligned rows
/// as everything else, not in a separate free-floating field.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.controller,
    required this.symbol,
    required this.hint,
  });
  final String label;
  final TextEditingController controller;
  final String symbol;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          Text(label, style: orbitLabelStyle),
          const Spacer(),
          Text(symbol,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              )),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: IntrinsicWidth(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                cursorColor: AppColors.accent,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: const TextStyle(
                    color: AppColors.inkFaint,
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A group-card row with a label and a − N + stepper on the right.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });
  final String label;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Text(label, style: orbitLabelStyle),
          const Spacer(),
          _btn(Icons.remove_rounded, value > 1, () {
            HapticFeedback.selectionClick();
            onChanged(value - 1);
          }),
          SizedBox(
            width: 62,
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
          _btn(Icons.add_rounded, value < 600, () {
            HapticFeedback.selectionClick();
            onChanged(value + 1);
          }),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon,
            size: 18, color: enabled ? AppColors.accent : AppColors.inkFaint),
      ),
    );
  }
}

// ── How-it-pays-back picker sheet ────────────────────────────────────────────

class _PayoutSheet extends StatelessWidget {
  const _PayoutSheet({required this.selected});
  final PayoutMethod selected;

  IconData _icon(PayoutMethod p) => switch (p) {
        PayoutMethod.lumpSum => Icons.payments_rounded,
        PayoutMethod.monthlyPension => Icons.calendar_month_rounded,
        PayoutMethod.annualPayout => Icons.event_repeat_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How it pays back',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 14),
              for (final p in PayoutMethod.values) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(p),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: p == selected
                          ? AppColors.accent.withValues(alpha: 0.14)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: p == selected
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_icon(p), size: 22, color: AppColors.accent),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.label,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  )),
                              const SizedBox(height: 2),
                              Text(p.blurb,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.inkSoft,
                                  )),
                            ],
                          ),
                        ),
                        if (p == selected)
                          const Icon(Icons.check_circle_rounded,
                              size: 20, color: AppColors.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── The compact "deal" strip ─────────────────────────────────────────────────

/// Shows the trade at a glance: total paid in vs. return, and the net gain —
/// computed live. Only the rows we can compute are shown, so a half-filled form
/// still reads cleanly.
class _DealStrip extends StatelessWidget {
  const _DealStrip({required this.task, required this.cycle});

  final Task task;
  final RepeatCadence cycle;

  static const _accent = AppColors.accent;

  String _money(double v) {
    final sym = currencyOf(task.currency).symbol;
    final grouped =
        formatAmount(v.abs().round().toString(), currencyOf(task.currency).grouping);
    return '${v < 0 ? '-' : ''}$sym$grouped';
  }

  @override
  Widget build(BuildContext context) {
    final paid = task.totalPaidIn;
    final ret = task.returnAmount;
    final gain = task.netGain;

    if (paid == null && ret == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: const [
            Icon(Icons.insights_rounded, size: 18, color: AppColors.inkFaint),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fill in the premium and return to see the net of this deal.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.3, color: AppColors.inkSoft),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.14),
            _accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (paid != null)
                Expanded(
                    child: _miniStat('You pay in', _money(paid))),
              if (ret != null)
                Expanded(child: _miniStat('You get back', _money(ret))),
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

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            )),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

// ── Document attach ──────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.file,
    required this.hasExisting,
    required this.onPick,
    required this.onClear,
  });

  final PlatformFile? file;
  final bool hasExisting;
  final VoidCallback onPick;
  final VoidCallback onClear;

  static const _accent = AppColors.accent;

  bool get _isPdf => (file?.extension ?? '').toLowerCase() == 'pdf';

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload_file_rounded, size: 26, color: _accent),
              const SizedBox(height: 6),
              Text(
                hasExisting ? 'Replace the document' : 'Attach the policy',
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              const Text('PDF or photo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft)),
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
              color: _accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: _accent,
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
                      color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Attached · tap the icon on Home to view',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _accent),
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
