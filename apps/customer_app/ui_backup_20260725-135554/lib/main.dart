import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "services/api_service.dart";
import "services/firebase_service.dart";
import "theme/app_theme.dart";
import "screens/splash_screen.dart";
import "screens/welcome_screen.dart";
import "screens/login_screen.dart";
import "screens/register_screen.dart";
import "screens/main_screen.dart";
import "screens/support_page.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  try {
    await FirebaseService.initialize();
  } catch (e) {
    print('Firebase init error (non-fatal): $e');
  }
  runApp(const VybeApp());
}

class VybeApp extends StatelessWidget {
  const VybeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "Vybe",
    debugShowCheckedModeBanner: false,
    theme: buildVybeTheme(),
    initialRoute: "/",
    onGenerateRoute: (s) {
      switch (s.name) {
        case "/": return _route(const SplashScreen());
        case "/welcome": return _route(const WelcomeScreen());
        case "/login": return _route(const LoginScreen());
        case "/register": return _route(const RegisterScreen());
        case "/home": return _route(const MainScreen());
        case "/support": return _route(const SupportPage());
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
