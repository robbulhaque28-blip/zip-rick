import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'ride_detail_page.dart';

final ApiService _api = ApiService();

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});
  @override State<RideHistoryPage> createState() => _RideHistoryPageState();
}
class _RideHistoryPageState extends State<RideHistoryPage> {
  List _rides = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { 
      final r = await _api.getRideHistory(); 
      if (r["success"]) { 
        final d = r["data"]; 
        final rides = d["rides"] ?? d["rows"] ?? [];
        setState(() { _rides = rides is List ? rides : []; _loading = false; }); 
      } else { setState(() => _loading = false); }
    } catch (e) { setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("My Rides")),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _rides.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.directions_car, size: 40, color: Color(0xFF6C63FF))),
            const SizedBox(height: 16), const Text("No rides yet", style: TextStyle(fontSize: 16)),
          ]))
        : RefreshIndicator(onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: _rides.length, itemBuilder: (ctx, i) {
            final r = _rides[i]; final status = r["status"] ?? ""; final fare = r["total_fare"]?.toString() ?? "0";
            final date = r["created_at"] ?? ""; String dateStr = "";
            try { final dt = DateTime.parse(date); dateStr = "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}"; } catch (_) { dateStr = date; }
            return Card(margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: (status == "completed" ? const Color(0xFF4CAF50) : const Color(0xFFFFA726)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(status == "completed" ? Icons.check_circle_rounded : Icons.pending_rounded, color: status == "completed" ? const Color(0xFF4CAF50) : const Color(0xFFFFA726))),
                title: Text("Ride #${r["ride_number"] ?? ""}", style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                trailing: Text("₹$fare", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6C63FF))),
                onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailPage(ride: r))); },
              ));
          })),
  );
}
