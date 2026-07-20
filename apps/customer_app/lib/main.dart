import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "services/api_service.dart";
import "screens/splash_screen.dart";
import "screens/welcome_screen.dart";
import "screens/login_screen.dart";
import "screens/register_screen.dart";
import "screens/main_screen.dart";
import "screens/support_page.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const ZipRickApp());
}

class ZipRickApp extends StatelessWidget {
  const ZipRickApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: "Zip-Rick", debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6C63FF),
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2937),
      ),
    ),
    initialRoute: "/",
    onGenerateRoute: (s) {
      switch (s.name) {
        case "/": return MaterialPageRoute(builder: (_) => const SplashScreen());
        case "/welcome": return MaterialPageRoute(builder: (_) => const WelcomeScreen());
        case "/login": return MaterialPageRoute(builder: (_) => const LoginScreen());
        case "/register": return MaterialPageRoute(builder: (_) => const RegisterScreen());
        case "/home": return MaterialPageRoute(builder: (_) => const MainScreen());
        case "/support": return MaterialPageRoute(builder: (_) => const SupportPage());
        default: return MaterialPageRoute(builder: (_) => const SplashScreen());
      }
    },
  );
}
