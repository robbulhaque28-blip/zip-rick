import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  Future<void> _fetch() async { try { final r = await _api.getSupportTickets(); if (r["success"]) setState(() { _tickets = r["data"] ?? []; _loadTickets = false; }); } catch (_) { setState(() => _loadTickets = false); } }

  Future<void> _create() async {
    if (_subjectCtrl.text.isEmpty || _descCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await _api.createSupportTicket(_subjectCtrl.text, _descCtrl.text);
      if (r["success"]) { _subjectCtrl.clear(); _descCtrl.clear(); _fetch(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket created!"))); }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Support")),
    body: _loadTickets ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Create Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 12),
          TextField(controller: _subjectCtrl, decoration: InputDecoration(labelText: "Subject", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 8), TextField(controller: _descCtrl, decoration: InputDecoration(labelText: "Describe your issue", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), maxLines: 3),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _create, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Submit"))),
        ])),
      const SizedBox(height: 24),
      const Text("My Tickets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 12),
      if (_tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text("No tickets", style: TextStyle(color: Color(0xFF9CA3AF)))))
      else ..._tickets.map((t) => Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: (t["priority"] == "urgent" ? Colors.red : const Color(0xFF6C63FF)).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(t["priority"] == "urgent" ? Icons.warning_rounded : Icons.support_agent_rounded, color: t["priority"] == "urgent" ? Colors.red : const Color(0xFF6C63FF))),
          title: Text(t["subject"] ?? "", style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(t["status"] ?? "open", style: const TextStyle(fontSize: 12)),
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (t["priority"] == "urgent" ? Colors.red : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(t["priority"] ?? "medium", style: TextStyle(fontSize: 11, color: t["priority"] == "urgent" ? Colors.red : Colors.blue)))),
      )),
    ]));
}
