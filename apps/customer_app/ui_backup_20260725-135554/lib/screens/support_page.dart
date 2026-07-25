import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

final ApiService _api = ApiService();

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});
  @override State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  List _tickets = [];
  bool _loadTickets = true;

  @override void initState() { super.initState(); _fetch(); }
  @override void dispose() { _subjectCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    try {
      final r = await _api.getSupportTickets();
      if (r["success"] && mounted) setState(() { _tickets = r["data"] ?? []; _loadTickets = false; });
      else if (mounted) setState(() => _loadTickets = false);
    } catch (_) { if (mounted) setState(() => _loadTickets = false); }
  }

  Future<void> _create() async {
    if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill both fields")));
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await _api.createSupportTicket(_subjectCtrl.text, _descCtrl.text);
      if (r["success"]) {
        _subjectCtrl.clear(); _descCtrl.clear(); _fetch();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket created")));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _prio(String p) => p == "urgent" ? AppColors.danger : (p == "high" ? AppColors.warning : AppColors.primary);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Help & Support")),
    body: _loadTickets
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
          VybeFadeIn(child: VybeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const VybeIconBox(icon: Icons.support_agent_rounded, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Raise a ticket", style: AppText.h3.copyWith(fontSize: 15.5)),
                const SizedBox(height: 2),
                Text("We usually reply within a few hours", style: AppText.label.copyWith(fontSize: 11.5)),
              ])),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _subjectCtrl, decoration: const InputDecoration(hintText: "Subject")),
            const SizedBox(height: 10),
            TextField(controller: _descCtrl, maxLines: 4, decoration: const InputDecoration(hintText: "Describe your issue")),
            const SizedBox(height: 14),
            VybeButton(label: "Submit ticket", loading: _loading, onPressed: _create, height: 47),
          ]))),
          const SizedBox(height: 24),
          Text("MY TICKETS", style: AppText.tiny),
          const SizedBox(height: 9),
          if (_tickets.isEmpty)
            VybeCard(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Column(children: [
                Icon(Icons.inbox_rounded, size: 30, color: AppColors.muted.withOpacity(0.6)),
                const SizedBox(height: 10),
                Text("No tickets yet", style: AppText.body.copyWith(fontSize: 13)),
              ])),
            ))
          else
            ...List.generate(_tickets.length, (i) {
              final t = _tickets[i];
              final prio = (t["priority"] ?? "medium").toString();
              final color = _prio(prio);
              return Padding(padding: const EdgeInsets.only(bottom: 10), child: VybeFadeIn(
                delayMs: (i * 50).clamp(0, 300),
                child: VybeCard(padding: const EdgeInsets.all(14), child: Row(children: [
                  VybeIconBox(icon: prio == "urgent" ? Icons.priority_high_rounded : Icons.confirmation_number_rounded, color: color, size: 38),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t["subject"] ?? "", style: AppText.bodyStrong.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text((t["status"] ?? "open").toString(), style: AppText.label.copyWith(fontSize: 11.5)),
                  ])),
                  VybeBadge(text: prio, color: color),
                ])),
              ));
            }),
        ]),
  );
}
