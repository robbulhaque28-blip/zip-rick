const fs = require("fs");
const p = "lib/main.dart";
let c = fs.readFileSync(p, "utf8");

// Fix the bookRide function to show better loading state
c = c.replace(
  'Future<void> _bookRide(String paymentMethod) async {',
  'bool _isBooking = false;\n\n  Future<void> _bookRide(String paymentMethod) async {'
);

c = c.replace(
  'setState(() => _loading = true);\n    try {\n      final res = await api.bookRide(',
  'setState(() => _isBooking = true);\n    try {\n      final res = await api.bookRide('
);

c = c.replace(
  "ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']?['message'] ?? 'Booking failed')));\n      }\n    } catch (e) {}\n    setState(() => _loading = false);\n  }",
  "ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']?['message'] ?? 'Booking failed')));\n      }\n    } catch (e) {}\n    setState(() => _isBooking = false);\n  }"
);

// Update the book buttons to show loading
c = c.replace(
  "ElevatedButton(onPressed: () => _bookRide('cash'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: const Text('Book Cash'))",
  "ElevatedButton(onPressed: _isBooking ? null : () => _bookRide('cash'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), child: _isBooking ? const SizedBox(width:20,height:20,child: CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Booking Cash'))"
);

c = c.replace(
  "ElevatedButton(onPressed: () => _bookRide('upi'), child: const Text('Book UPI'))",
  "ElevatedButton(onPressed: _isBooking ? null : () => _bookRide('upi'), child: _isBooking ? const SizedBox(width:20,height:20,child: CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Booking UPI'))"
);

// Update the tracking page to show "Booking ride" during search and "Driver found" when assigned
c = c.replace(
  "const Text('Status: Searching for nearby driver...', style: TextStyle(color: Colors.orange))",
  "const Text('Booking your ride...', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))"
);

fs.writeFileSync(p, c);
console.log("Updated main.dart");
