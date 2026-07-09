import 'package:flutter/material.dart';

class PickupDropWidget extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropController;
  final Function(dynamic) onPickupChanged;
  final Function(dynamic) onDropChanged;
  final VoidCallback onClearDrop;
  final VoidCallback useCurrentLocation;

  const PickupDropWidget({
    super.key,
    required this.pickupController,
    required this.dropController,
    required this.onPickupChanged,
    required this.onDropChanged,
    required this.onClearDrop,
    required this.useCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.green, size: 16),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: pickupController,
                  onChanged: (value) => onPickupChanged(value),
                  decoration: const InputDecoration(
                    hintText: "Pickup Location",
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location, size: 20),
                onPressed: useCurrentLocation,
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 16),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: dropController,
                  onChanged: (value) => onDropChanged(value),
                  decoration: const InputDecoration(
                    hintText: "Where to?",
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: onClearDrop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}