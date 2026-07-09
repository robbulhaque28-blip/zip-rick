import 'package:flutter/material.dart';

class LocationProvider extends ChangeNotifier {
  String _currentAddress = 'Current location';

  String get currentAddress => _currentAddress;

  void setCurrentAddress(String value) {
    _currentAddress = value;
    notifyListeners();
  }
}
