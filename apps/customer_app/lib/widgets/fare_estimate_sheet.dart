import 'package:flutter/material.dart';

class FareEstimateSheet extends StatelessWidget {
  final dynamic pickupLocation;
  final dynamic dropLocation;
  final VoidCallback onBookRide;

  const FareEstimateSheet({
    super.key,
    required this.pickupLocation,
    required this.dropLocation,
    required this.onBookRide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Fare Estimate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onBookRide,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Book Ride Now'),
          ),
        ],
      ),
    );
  }
}