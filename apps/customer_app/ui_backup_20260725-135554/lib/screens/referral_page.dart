import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

final ApiService _api = ApiService();

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});
  @override State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  String? _code;
  int _points = 0, _totalReferrals = 0;
  bool _loading = true, _applying = false;
  final _referCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _referCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await _api.getReferralStats();
      if (r["success"] && mounted) {
        setState(() {
          _code = r["data"]["referral_code"];
          _points = r["data"]["loyalty_points"] ?? 0;
          _totalReferrals = r["data"]["total_referrals"] ?? 0;
          _loading = false;
        });
      } else if (mounted) { setState(() => _loading = false); }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _invite() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: "Join Vybe! Use my referral code $_code to get 10% off your first ride."));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite message copied")));
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied")));
  }

  Future<void> _apply() async {
    if (_referCtrl.text.isEmpty) return;
    setState(() => _applying = true);
    try {
      final r = await _api.applyReferral(_referCtrl.text.trim());
      if (r["success"]) {
        _referCtrl.clear(); _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral applied")));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["error"]?["message"] ?? "Could not apply code")));
      }
    } catch (_) {}
    if (mounted) setState(() => _applying = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Refer & Earn")),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
          VybeFadeIn(child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(children: [
              Text("YOUR REFERRAL CODE", style: AppText.tiny.copyWith(color: Colors.white.withOpacity(0.7))),
              const SizedBox(height: 13),
              GestureDetector(onTap: _copyCode, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_code ?? "—", style: AppText.h2.copyWith(color: Colors.white, letterSpacing: 3, fontSize: 22)),
                  const SizedBox(width: 11),
                  Icon(Icons.copy_rounded, size: 16, color: Colors.white.withOpacity(0.8)),
                ]),
              )),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Column(children: [
                  Text("$_points", style: AppText.h2.copyWith(color: Colors.white, fontSize: 21)),
                  const SizedBox(height: 2),
                  Text("Points", style: AppText.label.copyWith(color: Colors.white.withOpacity(0.72), fontSize: 11.5)),
                ])),
                Container(width: 1, height: 32, color: Colors.white.withOpacity(0.18)),
                Expanded(child: Column(children: [
                  Text("$_totalReferrals", style: AppText.h2.copyWith(color: Colors.white, fontSize: 21)),
                  const SizedBox(height: 2),
                  Text("Referred", style: AppText.label.copyWith(color: Colors.white.withOpacity(0.72), fontSize: 11.5)),
                ])),
              ]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 46, child: ElevatedButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.ios_share_rounded, size: 17),
                label: Text("Invite friends", style: AppText.button.copyWith(color: AppColors.primary)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
              )),
            ]),
          )),
          const SizedBox(height: 22),
          Text("HAVE A CODE?", style: AppText.tiny),
          const SizedBox(height: 9),
          VybeFadeIn(delayMs: 80, child: VybeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Enter a friend's code to get 10% off your next ride.", style: AppText.body.copyWith(fontSize: 13)),
            const SizedBox(height: 13),
            Row(children: [
              Expanded(child: TextField(
                controller: _referCtrl,
                textCapitalization: TextCapitalization.characters,
                style: AppText.bodyStrong.copyWith(letterSpacing: 1.4),
                decoration: const InputDecoration(hintText: "Enter code"),
              )),
              const SizedBox(width: 10),
              SizedBox(height: 50, width: 96, child: ElevatedButton(
                onPressed: _applying ? null : _apply,
                child: _applying
                  ? const SizedBox(height: 17, width: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text("Apply", style: AppText.button.copyWith(color: Colors.white)),
              )),
            ]),
          ]))),
          const SizedBox(height: 22),
          Text("HOW IT WORKS", style: AppText.tiny),
          const SizedBox(height: 9),
          VybeFadeIn(delayMs: 140, child: VybeCard(child: Column(children: const [
            _Step(n: "1", text: "Share your code with friends"),
            SizedBox(height: 14),
            _Step(n: "2", text: "They get 10% off their first ride"),
            SizedBox(height: 14),
            _Step(n: "3", text: "You earn points when they ride"),
          ]))),
        ]),
  );
}

class _Step extends StatelessWidget {
  final String n; final String text;
  const _Step({required this.n, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 25, height: 25,
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(n, style: AppText.tiny.copyWith(color: AppColors.primary, fontSize: 11.5))),
    ),
    const SizedBox(width: 12),
    Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13))),
  ]);
}
