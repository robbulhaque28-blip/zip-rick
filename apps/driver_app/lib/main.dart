import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_docs_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/home_screen.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF5A52D5);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const bg = Color(0xFFF5F6FA);
  static const textLight = Color(0xFF9E9E9E);
  static const textDark = Color(0xFF1F2937);
}

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const VybeDriverApp()); }

class VybeDriverApp extends StatelessWidget {
  const VybeDriverApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Vybe Driver', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary, scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Colors.white, foregroundColor: AppColors.textDark)),
    initialRoute: '/', routes: {
      '/': (ctx) => const SplashScreen(),
      '/login': (ctx) => const LoginScreen(),
      '/register-docs': (ctx) => const RegisterDocsScreen(),
      '/terms': (ctx) => const TermsScreen(),
      '/payment': (ctx) => const PaymentScreen(),
      '/home': (ctx) => const DriverHomeScreen(),
    },
  );
}
