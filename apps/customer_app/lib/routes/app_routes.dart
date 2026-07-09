import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String booking = '/booking';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case booking:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Booking screen coming soon')),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
