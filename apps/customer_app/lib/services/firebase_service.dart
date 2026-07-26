import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'api_service.dart';

/// Handles a push that arrives while the app is terminated or backgrounded.
/// Must be a top-level function or Flutter cannot find it.
@pragma('vm:entry-point')
Future<void> vybeBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('VYBE-PUSH background: ' + (message.notification?.title ?? '(no title)'));
}

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(vybeBackgroundHandler);

    // Android 13+ will not deliver anything until the user grants this.
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    print('VYBE-PUSH permission: ' + settings.authorizationStatus.toString());

    // Show a heads-up banner even when the app is in the foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    final token = await _messaging.getToken();
    print('VYBE-PUSH token: ' + (token ?? 'NULL'));

    if (token != null) {
      try {
        await ApiService().updateFCMToken(token);
        print('VYBE-PUSH token registered with backend');
      } catch (e) {
        print('VYBE-PUSH register error: ' + e.toString());
      }
    }

    _messaging.onTokenRefresh.listen((newToken) {
      print('VYBE-PUSH token refreshed');
      try { ApiService().updateFCMToken(newToken); } catch (e) {}
    });

    FirebaseMessaging.onMessage.listen((message) {
      print('VYBE-PUSH foreground: ' + (message.notification?.title ?? '') +
            ' - ' + (message.notification?.body ?? ''));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('VYBE-PUSH tapped: ' + (message.notification?.title ?? ''));
    });
  }

  /// Re-registers the FCM token after a successful login, when the auth
  /// token finally exists and the backend can associate the device.
  static Future<void> registerTokenAfterLogin() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await ApiService().updateFCMToken(token);
        print('VYBE-PUSH token registered after login');
      }
    } catch (e) {
      print('VYBE-PUSH post-login register error: ' + e.toString());
    }
  }
}
