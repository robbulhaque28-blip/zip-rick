import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'referral_page.dart';

final ApiService _api = ApiService();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  Map? _profile; bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await _api.getProfile(); if (r["success"]) setState(() { _profile = r["data"]; _loading = false; }); } catch (_) { setState(() => _loading = false); }
  }

  void _editName() {
    final ctrl = TextEditingController(text: _profile?["user"]?["full_name"] ?? "");
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Edit Name"), content: TextField(controller: ctrl, decoration: InputDecoration(labelText: "Full Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          try { await _api.updateProfile(ctrl.text.trim()); _load(); if (ctx.mounted) Navigator.pop(ctx); } catch (_) {}
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Save")),
      ],
    ));
  }

  Future<void> _logout() async {
    await _api.clearToken();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("Profile"), actions: [
    IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout),
  ]),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(24), children: [
        Center(child: Column(children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF6C63FF))),
          const SizedBox(height: 12),
          GestureDetector(onTap: _editName, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_profile?["user"]?["full_name"] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
            const SizedBox(width: 8), const Icon(Icons.edit, size: 18, color: Color(0xFF6C63FF)),
          ])),
          Text(_profile?["user"]?["phone"] ?? "", style: const TextStyle(color: Color(0xFF9CA3AF))),
        ])),
        const SizedBox(height: 32),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(children: [
            ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.star_rounded, color: Colors.amber)),
              title: const Text("Rating"), trailing: Text("${_profile?["customer"]?["rating"] ?? "0.0"} / 5", style: const TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_car_rounded, color: Color(0xFF6C63FF))),
              title: const Text("Total Rides"), trailing: Text("${_profile?["customer"]?["total_rides"] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.card_giftcard_rounded, color: Colors.purple)),
              title: const Text("Refer & Earn"), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralPage()))),
          ])),
        const SizedBox(height: 16),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
          child: Column(children: [
            ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_rounded, color: Colors.green)),
              title: const Text("Edit Name"), trailing: const Icon(Icons.chevron_right), onTap: _editName),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.logout_rounded, color: Colors.red)),
              title: const Text("Logout"), trailing: const Icon(Icons.chevron_right), onTap: _logout),
          ])),
      ]));
}
