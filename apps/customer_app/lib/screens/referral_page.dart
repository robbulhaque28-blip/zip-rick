import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

final ApiService _api = ApiService();

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});
  @override State<ReferralPage> createState() => _ReferralPageState();
}
class _ReferralPageState extends State<ReferralPage> {
  String? _code; int _points = 0, _totalReferrals = 0; bool _loading = true, _applying = false;
  final _referCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _referCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await _api.getReferralStats();
      if (r["success"]) setState(() { _code = r["data"]["referral_code"]; _points = r["data"]["loyalty_points"] ?? 0; _totalReferrals = r["data"]["total_referrals"] ?? 0; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _invite() { if (_code == null) return; Clipboard.setData(ClipboardData(text: "Join Zip-Rick! Use my code: $_code")); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"))); }

  Future<void> _apply() async {
    if (_referCtrl.text.isEmpty) return;
    setState(() => _applying = true);
    try { final r = await _api.applyReferral(_referCtrl.text.trim()); if (r["success"]) { _referCtrl.clear(); _load(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral applied!"))); } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Failed"))); } } catch (_) {}
    setState(() => _applying = false);
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Refer & Earn")),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(24), children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)]), borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.card_giftcard_rounded, size: 60, color: Colors.white), const SizedBox(height: 12),
          const Text("Your Code", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 8),
          Text(_code ?? "", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [Text("$_points", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const Text("Points", style: TextStyle(color: Colors.white70))]),
            Column(children: [Text("$_totalReferrals", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const Text("Referred", style: TextStyle(color: Colors.white70))]),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _invite, icon: const Icon(Icons.share_rounded), label: const Text("Invite Friends"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ])),
      const SizedBox(height: 24),
      const Text("Have a code?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))), const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _referCtrl, decoration: InputDecoration(labelText: "Enter code", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: _applying ? null : _apply, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24)),
          child: _applying ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Apply")),
      ]),
    ]));
}
