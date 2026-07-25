import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class RegisterDocsScreen extends StatefulWidget {
  const RegisterDocsScreen({super.key});
  @override State<RegisterDocsScreen> createState() => _RegisterDocsScreenState();
}

class _RegisterDocsScreenState extends State<RegisterDocsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  Map<String, XFile?> _docs = {'aadhaar_front': null, 'aadhaar_back': null, 'selfie': null, 'rc': null, 'insurance': null};
  final _bankNameCtrl = TextEditingController();
  final _acctHolderCtrl = TextEditingController();
  final _acctNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  @override void dispose() { _bankNameCtrl.dispose(); _acctHolderCtrl.dispose(); _acctNumCtrl.dispose(); _ifscCtrl.dispose(); super.dispose(); }

  String _label(String k) {
    switch (k) {
      case 'aadhaar_front': return 'Aadhaar (Front)';
      case 'aadhaar_back': return 'Aadhaar (Back)';
      case 'selfie': return 'Live photo';
      case 'rc': return 'Vehicle RC';
      case 'insurance': return 'Insurance';
      default: return k;
    }
  }

  String _hint(String k) {
    switch (k) {
      case 'aadhaar_front': return 'Required';
      case 'selfie': return 'Required';
      default: return 'Optional';
    }
  }

  IconData _icon(String k) {
    switch (k) {
      case 'aadhaar_front': return Icons.badge_rounded;
      case 'aadhaar_back': return Icons.badge_outlined;
      case 'selfie': return Icons.camera_alt_rounded;
      case 'rc': return Icons.directions_car_rounded;
      case 'insurance': return Icons.verified_user_rounded;
      default: return Icons.upload_file_rounded;
    }
  }

  Future<void> _pickImage(String key) async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (x != null) setState(() => _docs[key] = x);
  }

  Future<String> _imageToBase64(XFile file) async {
    final bytes = await File(file.path).readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : ext == 'gif' ? 'image/gif' : 'image/jpeg';
    return 'data:$mime;base64,' + base64Encode(bytes);
  }

  Future<void> _submit() async {
    if (_docs['aadhaar_front'] == null || _docs['selfie'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload at least Aadhaar Front and a live photo')));
      return;
    }
    if (_bankNameCtrl.text.isEmpty || _acctHolderCtrl.text.isEmpty || _acctNumCtrl.text.isEmpty || _ifscCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all bank details')));
      return;
    }
    setState(() => _loading = true);
    try {
      for (final e in _docs.entries) {
        if (e.value != null) {
          try {
            final base64 = await _imageToBase64(e.value!);
            await ApiService.post('/drivers/documents', {
              'document_type': e.key,
              'document_url': e.key,
              'document_data': base64,
            });
          } catch (_) {}
        }
      }
      try {
        await ApiService.updateProfile({
          'bank_name': _bankNameCtrl.text,
          'account_holder': _acctHolderCtrl.text,
          'account_number': _acctNumCtrl.text,
          'ifsc_code': _ifscCtrl.text,
        });
      } catch (_) {}
      if (mounted) Navigator.pushReplacementNamed(context, '/terms');
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _docs.values.where((v) => v != null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Documents & Bank')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
        VybeFadeIn(child: Row(children: [
          Expanded(child: _Step(n: '1', label: 'Details', done: true)),
          Expanded(child: _Step(n: '2', label: 'Docs', active: true)),
          Expanded(child: _Step(n: '3', label: 'Terms')),
          Expanded(child: _Step(n: '4', label: 'Payment')),
        ])),
        const SizedBox(height: 22),
        Row(children: [
          Text('DOCUMENTS', style: AppText.tiny),
          const Spacer(),
          Text('$done of 5 uploaded', style: AppText.label.copyWith(fontSize: 11.5)),
        ]),
        const SizedBox(height: 9),
        VybeFadeIn(delayMs: 60, child: VybeCard(padding: EdgeInsets.zero, child: Column(
          children: _docs.keys.map((k) {
            final uploaded = _docs[k] != null;
            final isLast = k == _docs.keys.last;
            return Column(children: [
              Material(color: Colors.transparent, child: InkWell(
                onTap: () => _pickImage(k),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  child: Row(children: [
                    VybeIconBox(icon: _icon(k), color: uploaded ? AppColors.success : AppColors.primary, size: 38),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_label(k), style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(uploaded ? 'Photo captured' : _hint(k), style: AppText.label.copyWith(
                        fontSize: 11.5, color: uploaded ? AppColors.success : AppColors.muted)),
                    ])),
                    Icon(uploaded ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                      color: uploaded ? AppColors.success : AppColors.muted, size: 20),
                  ]),
                ),
              )),
              if (!isLast) const Divider(height: 1, indent: 62),
            ]);
          }).toList(),
        ))),
        const SizedBox(height: 22),
        Text('BANK ACCOUNT', style: AppText.tiny),
        const SizedBox(height: 9),
        VybeFadeIn(delayMs: 120, child: VybeCard(child: Column(children: [
          Text('Your ride earnings are paid into this account.', style: AppText.body.copyWith(fontSize: 12.5)),
          const SizedBox(height: 14),
          TextField(controller: _bankNameCtrl, decoration: const InputDecoration(hintText: 'Bank name')),
          const SizedBox(height: 10),
          TextField(controller: _acctHolderCtrl, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Account holder name')),
          const SizedBox(height: 10),
          TextField(controller: _acctNumCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Account number')),
          const SizedBox(height: 10),
          TextField(controller: _ifscCtrl, textCapitalization: TextCapitalization.characters,
            style: AppText.bodyStrong.copyWith(fontSize: 14, letterSpacing: 1.1),
            decoration: const InputDecoration(hintText: 'IFSC code')),
        ]))),
        const SizedBox(height: 22),
        VybeButton(label: 'Continue to terms', loading: _loading, onPressed: _submit),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final String n; final String label; final bool active; final bool done;
  const _Step({required this.n, required this.label, this.active = false, this.done = false});
  @override
  Widget build(BuildContext context) {
    final Color bg = done ? AppColors.success : (active ? AppColors.primary : AppColors.canvas);
    final Color fg = (done || active) ? Colors.white : AppColors.muted;
    return Column(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9),
          border: (done || active) ? null : Border.all(color: AppColors.line)),
        child: Center(child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : Text(n, style: AppText.tiny.copyWith(fontSize: 11, color: fg))),
      ),
      const SizedBox(height: 5),
      Text(label, style: AppText.label.copyWith(fontSize: 10.5,
        color: active ? AppColors.primary : (done ? AppColors.success : AppColors.muted))),
    ]);
  }
}
