import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'api_service.dart';

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await Firebase.initializeApp();

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    if (token != null) {
      try {
        final api = ApiService();
        await api.updateFCMToken(token);
      } catch (e) {
        print('FCM register error: $e');
      }
    }

    _messaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      try {
        ApiService().updateFCMToken(newToken);
      } catch (e) {}
    });

    FirebaseMessaging.onMessage.listen((message) {
      print('Push: ${message.notification?.title} - ${message.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('Push tapped: ${message.notification?.title}');
    });
  }
}