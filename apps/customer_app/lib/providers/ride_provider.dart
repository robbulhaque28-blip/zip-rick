import 'package:flutter/material.dart';

class RideProvider extends ChangeNotifier {
  int _activeRideCount = 0;

  int get activeRideCount => _activeRideCount;

  void setActiveRideCount(int count) {
    _activeRideCount = count;
    notifyListeners();
  }
}
