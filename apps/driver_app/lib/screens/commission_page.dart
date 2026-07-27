import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

/// Pay the platform's commission.
///
/// Fares are collected in cash, so the driver is holding money that belongs to
/// Vybe. They transfer it by UPI or bank transfer outside the app, then report
/// it here. An admin confirms receipt before the balance clears.
class CommissionPage extends StatefulWidget {
  const CommissionPage({super.key});

  @override
  State<CommissionPage> createState() => _CommissionPageState();
}

class _CommissionPageState extends State<CommissionPage> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  double _due = 0;
  double _paid = 0;
  double _rate = 10;
  double _threshold = 20;
  bool _isBlocked = false;
  Map<String, dynamic>? _pending;
  Map<String, dynamic> _payout = {};
  List<dynamic> _history = [];

  final _refCtrl = TextEditingController();
  String _method = 'upi';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiService.getCommissionDue();
      final d = r['data'] ?? {};
      List<dynamic> hist = [];
      try {
        final h = await ApiService.getCommissionPayments();
        hist = (h['data']?['payments'] as List?) ?? [];
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _due = _toD(d['commission_due']);
        _paid = _toD(d['total_commission_paid']);
        _rate = _toD(d['commission_rate'], fallback: 10);
        _threshold = _toD(d['block_threshold'], fallback: 20);
        _isBlocked = d['is_blocked'] == true;
        _pending = d['pending_payment'] as Map<String, dynamic>?;
        _payout = (d['payout'] as Map<String, dynamic>?) ?? {};
        _history = hist;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double _toD(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    return double.tryParse(v.toString()) ?? fallback;
  }

  void _copy(String label, String value) {
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiService.submitCommissionPayment(
        amount: _due,
        method: _method,
        reference: _refCtrl.text.trim(),
      );
      if (!mounted) return;
      _refCtrl.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Submitted. Your dues clear once we confirm the payment.'),
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm payment', style: AppText.h3),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Have you already sent Rs ${_due.toStringAsFixed(0)} to Vybe?',
              style: AppText.body.copyWith(fontSize: 13.5)),
          const SizedBox(height: 10),
          Text('Only submit after the money has actually been transferred. We will verify it before your dues clear.',
              style: AppText.label.copyWith(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not yet')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _submit(); },
            child: const Text('Yes, I paid'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text('Commission', style: AppText.h3)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  if (_error != null) ...[
                    VybeCard(child: Text(_error!, style: AppText.body.copyWith(color: AppColors.danger))),
                    const SizedBox(height: 14),
                  ],
                  _dueCard(),
                  const SizedBox(height: 14),
                  if (_pending != null) _pendingCard()
                  else if (_due > 0) ...[
                    _payoutCard(),
                    const SizedBox(height: 14),
                    _submitCard(),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Payment history', style: AppText.h3.copyWith(fontSize: 15)),
                    const SizedBox(height: 10),
                    ..._history.map(_historyTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _dueCard() {
    final clear = _due <= 0;
    final color = clear
        ? AppColors.success
        : (_isBlocked ? AppColors.danger : AppColors.warning);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
            child: Icon(clear ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(clear ? 'All clear' : 'Commission due', style: AppText.label.copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            Text('Rs ${_due.toStringAsFixed(0)}',
                style: AppText.h1.copyWith(fontSize: 26, color: color)),
          ])),
        ]),
        if (_isBlocked) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.10), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              const Icon(Icons.block_rounded, size: 17, color: AppColors.danger),
              const SizedBox(width: 9),
              Expanded(child: Text(
                'You cannot go online until this is paid.',
                style: AppText.bodyStrong.copyWith(fontSize: 12.5, color: AppColors.danger),
              )),
            ]),
          ),
        ] else if (!clear) ...[
          const SizedBox(height: 12),
          Text(
            'You can keep working. Going online is blocked once you owe Rs ${_threshold.toStringAsFixed(0)} or more.',
            style: AppText.label.copyWith(fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _stat('Rate', '${_rate.toStringAsFixed(0)}%')),
          Expanded(child: _stat('Paid so far', 'Rs ${_paid.toStringAsFixed(0)}')),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label.copyWith(fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(value, style: AppText.bodyStrong.copyWith(fontSize: 14)),
        ],
      );

  Widget _pendingCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.09),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.warning.withOpacity(0.28)),
        ),
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 21),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Awaiting confirmation', style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
            const SizedBox(height: 3),
            Text(
              'You reported Rs ${_toD(_pending!['amount']).toStringAsFixed(0)}. '
              'We will clear your dues once the payment is verified.',
              style: AppText.label.copyWith(fontSize: 12),
            ),
          ])),
        ]),
      );

  Widget _payoutCard() {
    final upi = (_payout['upi_id'] ?? '').toString();
    final accName = (_payout['bank_account_name'] ?? '').toString();
    final accNo = (_payout['bank_account_number'] ?? '').toString();
    final ifsc = (_payout['bank_ifsc'] ?? '').toString();
    final hasAny = upi.isNotEmpty || accNo.isNotEmpty;

    return VybeCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pay to', style: AppText.h3.copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text('Send the amount using any UPI app or bank transfer.',
            style: AppText.label.copyWith(fontSize: 12)),
        const SizedBox(height: 14),
        if (!hasAny)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text(
              'Payment details have not been set up yet. Please contact support for where to send the money.',
              style: AppText.body.copyWith(fontSize: 12.5),
            ),
          ),
        if (upi.isNotEmpty) _payRow('UPI ID', upi),
        if (accName.isNotEmpty) _payRow('Account name', accName),
        if (accNo.isNotEmpty) _payRow('Account number', accNo),
        if (ifsc.isNotEmpty) _payRow('IFSC', ifsc),
      ]),
    );
  }

  Widget _payRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.label.copyWith(fontSize: 11.5)),
            const SizedBox(height: 1),
            Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
          ])),
          IconButton(
            onPressed: () => _copy(label, value),
            icon: const Icon(Icons.copy_rounded, size: 17, color: AppColors.primary),
            visualDensity: VisualDensity.compact,
          ),
        ]),
      );

  Widget _submitCard() => VybeCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('After you pay', style: AppText.h3.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text('Tell us how you sent it so we can match the payment.',
              style: AppText.label.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            _methodChip('upi', 'UPI'),
            const SizedBox(width: 8),
            _methodChip('bank_transfer', 'Bank'),
            const SizedBox(width: 8),
            _methodChip('cash', 'Cash'),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference / UTR number (optional)',
              hintText: 'e.g. 402312345678',
            ),
          ),
          const SizedBox(height: 16),
          VybeButton(
            label: 'I have paid Rs ${_due.toStringAsFixed(0)}',
            icon: Icons.check_rounded,
            loading: _submitting,
            onPressed: _submitting ? null : _confirmSubmit,
          ),
        ]),
      );

  Widget _methodChip(String value, String label) {
    final selected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.10) : AppColors.canvas,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppText.bodyStrong.copyWith(
                fontSize: 13,
                color: selected ? AppColors.primary : AppColors.body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyTile(dynamic p) {
    final m = p as Map<String, dynamic>;
    final status = (m['status'] ?? '').toString();
    Color c = AppColors.warning;
    IconData ic = Icons.hourglass_top_rounded;
    if (status == 'confirmed') { c = AppColors.success; ic = Icons.check_circle_rounded; }
    if (status == 'rejected') { c = AppColors.danger; ic = Icons.cancel_rounded; }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          Icon(ic, color: c, size: 19),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rs ${_toD(m['amount']).toStringAsFixed(0)}',
                style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              status == 'rejected' && (m['rejection_reason'] ?? '').toString().isNotEmpty
                  ? m['rejection_reason'].toString()
                  : status,
              style: AppText.label.copyWith(fontSize: 11.5, color: c),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
        ]),
      ),
    );
  }
}
