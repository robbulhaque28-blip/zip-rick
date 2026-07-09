import 'package:flutter/material.dart';

class PaymentProvider extends ChangeNotifier {
  bool _isPaying = false;

  bool get isPaying => _isPaying;

  void setPaying(bool value) {
    _isPaying = value;
    notifyListeners();
  }
}
