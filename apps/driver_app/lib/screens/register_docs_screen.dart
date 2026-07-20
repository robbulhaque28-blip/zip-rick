import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

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

  String _label(String k) {
    switch (k) {
      case 'aadhaar_front': return 'Aadhaar Card (Front)';
      case 'aadhaar_back': return 'Aadhaar Card (Back)';
      case 'selfie': return 'Live Passport Photo';
      case 'rc': return 'Vehicle RC';
      case 'insurance': return 'Vehicle Insurance';
      default: return k;
    }
  }
  IconData _icon(String k) {
    switch (k) {
      case 'aadhaar_front': return Icons.badge;
      case 'aadhaar_back': return Icons.badge;
      case 'selfie': return Icons.camera_alt;
      case 'rc': return Icons.directions_car;
      case 'insurance': return Icons.verified;
      default: return Icons.upload_file;
    }
  }

  Future<void> _pickImage(String key) async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (x != null) setState(() => _docs[key] = x);
  }

  Future<void> _submit() async {
    if (_docs['aadhaar_front'] == null || _docs['selfie'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload at least Aadhaar Front + Selfie')));
      return;
    }
    if (_bankNameCtrl.text.isEmpty || _acctHolderCtrl.text.isEmpty || _acctNumCtrl.text.isEmpty || _ifscCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all bank details')));
      return;
    }
    setState(() => _loading = true);
    try {
      for (final e in _docs.entries) {
        if (e.value != null) {
          try { await ApiService.post('/drivers/documents', {'document_type': e.key, 'document_url': e.value!.path}); } catch (_) {}
        }
      }
      try { await ApiService.updateProfile({'bank_name': _bankNameCtrl.text, 'account_holder': _acctHolderCtrl.text, 'account_number': _acctNumCtrl.text, 'ifsc_code': _ifscCtrl.text}); } catch (_) {}
      if (mounted) Navigator.pushReplacementNamed(context, '/terms');
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.toString().replaceFirst("Exception: ", "")}')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload Docs & Bank')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: const Text('Step 2 of 4', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold))),
      const SizedBox(height: 16),
      const Text('Documents', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 16),
      ..._docs.keys.map((k) => Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon(k), color: const Color(0xFF6C63FF))),
          title: Text(_label(k), style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(_docs[k] != null ? 'Done' : 'Tap to take photo', style: const TextStyle(fontSize: 12)),
          trailing: Icon(_docs[k] != null ? Icons.check_circle : Icons.upload_file, color: _docs[k] != null ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF)),
          onTap: () => _pickImage(k),
        ))),
      const SizedBox(height: 24),
      const Text('Bank Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 12),
      TextField(controller: _bankNameCtrl, decoration: InputDecoration(labelText: 'Bank Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      TextField(controller: _acctHolderCtrl, decoration: InputDecoration(labelText: 'Account Holder Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      TextField(controller: _acctNumCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Account Number *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      TextField(controller: _ifscCtrl, decoration: InputDecoration(labelText: 'IFSC Code *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Next: Terms & Conditions', style: TextStyle(fontSize: 16)))),
    ])));
  @override void dispose() { _bankNameCtrl.dispose(); _acctHolderCtrl.dispose(); _acctNumCtrl.dispose(); _ifscCtrl.dispose(); super.dispose(); }
}
