import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZipRickDriverApp());
}

class ZipRickDriverApp extends StatelessWidget {
  const ZipRickDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zip-Rick Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          primary: const Color(0xFF6C63FF),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/login': (ctx) => const DriverLoginScreen(),
        '/register': (ctx) => const RegistrationScreen(),
        '/home': (ctx) => const DriverHomeScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() { super.initState(); Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacementNamed(context, '/login')); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF6C63FF),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.electric_rickshaw_rounded, size: 120, color: Colors.white),
      const SizedBox(height: 24),
      Text('Zip-Rick Driver', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      const SizedBox(height: 60), const CircularProgressIndicator(color: Colors.white),
    ])),
  );
}

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+91');
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() { _phoneCtrl.dispose(); _otpCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 60),
      const Icon(Icons.electric_rickshaw_rounded, size: 64, color: Color(0xFF6C63FF)),
      const SizedBox(height: 24),
      Text(_otpSent ? 'Verify OTP' : 'Driver Login', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(_otpSent ? 'Enter OTP' : 'Enter your phone to register', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
      const SizedBox(height: 40),
      TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
      if (_otpSent) ...[
        const SizedBox(height: 16),
        TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'OTP', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
      ],
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () { setState(() { if (!_otpSent) _otpSent = true; else Navigator.pushReplacementNamed(context, '/register'); }); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(_otpSent ? 'Verify' : 'Send OTP'),
      ),
    ]))),
  );
}

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registration')),
    body: ListView(padding: const EdgeInsets.all(24), children: const [
      Text('Complete Your Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      SizedBox(height: 24),
      ListTile(leading: Icon(Icons.badge_outlined, color: Color(0xFF6C63FF)), title: Text('Upload Aadhaar Card'), subtitle: Text('Front & Back'), trailing: Icon(Icons.upload_file)),
      Divider(),
      ListTile(leading: Icon(Icons.directions_car, color: Color(0xFF6C63FF)), title: Text('Upload E-Rickshaw RC'), subtitle: Text('Registration Certificate'), trailing: Icon(Icons.upload_file)),
      Divider(),
      ListTile(leading: Icon(Icons.camera_alt, color: Color(0xFF6C63FF)), title: Text('Live Selfie'), trailing: Icon(Icons.camera_alt)),
      Divider(),
      ListTile(leading: Icon(Icons.payments, color: Color(0xFF6C63FF)), title: Text('Pay Registration Fee'), subtitle: Text('\u20B9499 (limited time)'), trailing: Icon(Icons.payment)),
      Divider(),
      SizedBox(height: 24),
      Center(child: Text('Complete all steps above then submit', style: TextStyle(color: Color(0xFF6B7280)))),
      SizedBox(height: 12),
      ElevatedButton(onPressed: null, style: null, child: Text('Submit for Review')),
    ]),
  );
}

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zip-Rick Driver')),
    body: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.toggle_off_outlined, size: 80, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.power_settings_new),
          label: const Text('Go Online'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D9A6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
        ),
        const SizedBox(height: 40),
        Card(margin: const EdgeInsets.symmetric(horizontal: 24), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('Today\'s Earnings', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          const Text('\u20B9 0', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('0 trips completed', style: TextStyle(color: Color(0xFF6B7280))),
        ]))),
      ]),
    ),
    bottomNavigationBar: BottomNavigationBar(items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Earnings'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ]),
  );
}
