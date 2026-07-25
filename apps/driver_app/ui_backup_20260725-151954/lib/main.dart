import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_docs_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  try { await FirebaseService.initialize(); } catch (e) { print('Firebase init error: $e'); }
  runApp(const VybeDriverApp());
}

class VybeDriverApp extends StatelessWidget {
  const VybeDriverApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vybe Driver',
    debugShowCheckedModeBanner: false,
    theme: buildVybeTheme(),
    initialRoute: '/',
    onGenerateRoute: (s) {
      switch (s.name) {
        case '/': return _route(const SplashScreen());
        case '/login': return _route(const LoginScreen());
        case '/register-docs': return _route(const RegisterDocsScreen());
        case '/terms': return _route(const TermsScreen());
        case '/payment': return _route(const PaymentScreen());
        case '/home': return _route(const DriverHomeScreen());
        default: return _route(const SplashScreen());
      }
    },
  );

  PageRouteBuilder _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.025), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 260),
  );
}
