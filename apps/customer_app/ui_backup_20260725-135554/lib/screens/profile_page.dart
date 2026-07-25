import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'referral_page.dart';

final ApiService _api = ApiService();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map? _profile;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _api.getProfile();
      if (r["success"] && mounted) setState(() { _profile = r["data"]; _loading = false; });
      else if (mounted) setState(() => _loading = false);
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _editName() {
    final ctrl = TextEditingController(text: _profile?["user"]?["full_name"] ?? "");
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Edit name"),
      content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: "Full name")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          try { await _api.updateProfile(ctrl.text.trim()); _load(); if (ctx.mounted) Navigator.pop(ctx); } catch (_) {}
        }, child: const Text("Save")),
      ],
    ));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Log out?"),
      content: Text("You'll need to sign in again to book rides.", style: AppText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text("Log out")),
      ],
    ));
    if (ok != true) return;
    await _api.clearToken();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?["user"]?["full_name"] ?? "User";
    final phone = _profile?["user"]?["phone"] ?? "";
    final rating = "${_profile?["customer"]?["rating"] ?? "0.0"}";
    final rides = "${_profile?["customer"]?["total_rides"] ?? 0}";
    final initial = name.toString().trim().isEmpty ? "U" : name.toString().trim()[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
              VybeFadeIn(child: VybeCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
                    child: Center(child: Text(initial, style: AppText.h2.copyWith(color: Colors.white, fontSize: 23))),
                  ),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(phone, style: AppText.label),
                  ])),
                  IconButton(
                    onPressed: _editName,
                    icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.primary),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft),
                  ),
                ]),
              )),
              const SizedBox(height: 13),
              VybeFadeIn(delayMs: 60, child: Row(children: [
                Expanded(child: _Stat(icon: Icons.star_rounded, value: rating, label: "Rating", color: AppColors.warning)),
                const SizedBox(width: 11),
                Expanded(child: _Stat(icon: Icons.route_rounded, value: rides, label: "Total rides", color: AppColors.primary)),
              ])),
              const SizedBox(height: 22),
              Text("ACCOUNT", style: AppText.tiny),
              const SizedBox(height: 9),
              VybeFadeIn(delayMs: 120, child: VybeCard(padding: EdgeInsets.zero, child: Column(children: [
                _Row(icon: Icons.card_giftcard_rounded, color: AppColors.accent, title: "Refer & earn",
                  subtitle: "Invite friends, get rewards",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralPage()))),
                const Divider(height: 1, indent: 62),
                _Row(icon: Icons.headset_mic_rounded, color: AppColors.primary, title: "Help & support",
                  subtitle: "Raise a ticket with our team",
                  onTap: () => Navigator.pushNamed(context, '/support')),
                const Divider(height: 1, indent: 62),
                _Row(icon: Icons.person_outline_rounded, color: AppColors.body, title: "Edit name",
                  subtitle: "Change how your name appears", onTap: _editName),
              ]))),
              const SizedBox(height: 18),
              VybeFadeIn(delayMs: 170, child: VybeCard(padding: EdgeInsets.zero, child:
                _Row(icon: Icons.logout_rounded, color: AppColors.danger, title: "Log out",
                  subtitle: "Sign out of this device", onTap: _logout, danger: true),
              )),
              const SizedBox(height: 22),
              Center(child: Text("Vybe · v1.0.0", style: AppText.label.copyWith(fontSize: 11.5))),
            ]),
          ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color color;
  const _Stat({required this.icon, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => VybeCard(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 11),
      Text(value, style: AppText.h2.copyWith(fontSize: 20)),
      const SizedBox(height: 2),
      Text(label, style: AppText.label.copyWith(fontSize: 11.5)),
    ]),
  );
}

class _Row extends StatelessWidget {
  final IconData icon; final Color color; final String title; final String subtitle;
  final VoidCallback onTap; final bool danger;
  const _Row({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(children: [
        VybeIconBox(icon: icon, color: color, size: 36),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.bodyStrong.copyWith(fontSize: 13.5, color: danger ? AppColors.danger : AppColors.ink)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.label.copyWith(fontSize: 11.5)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
      ]),
    )),
  );
}
