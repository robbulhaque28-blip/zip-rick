import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'ride_detail_page.dart';

final ApiService _api = ApiService();

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});
  @override State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  List _rides = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await _api.getRideHistory();
      if (r["success"]) {
        final d = r["data"];
        final rides = d["rides"] ?? d["rows"] ?? [];
        if (mounted) setState(() { _rides = rides is List ? rides : []; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case "completed": return AppColors.success;
      case "cancelled": return AppColors.danger;
      case "started":
      case "driver_assigned":
      case "driver_arrived": return AppColors.primary;
      default: return AppColors.warning;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case "completed": return Icons.check_circle_rounded;
      case "cancelled": return Icons.cancel_rounded;
      case "started": return Icons.navigation_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String _pretty(String s) => s.replaceAll("_", " ");

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("My Rides")),
    body: _loading
      ? const VybeListSkeleton()
      : _rides.isEmpty
        ? VybeEmpty(
            icon: Icons.receipt_long_rounded,
            title: "No rides yet",
            subtitle: "Once you book your first ride,\nit will show up here.",
          )
        : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (ctx, i) {
                final r = _rides[i];
                final status = (r["status"] ?? "").toString();
                final fare = r["total_fare"]?.toString() ?? "0";
                final color = _statusColor(status);
                String dateStr = "";
                try {
                  final dt = DateTime.parse(r["created_at"] ?? "");
                  const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
                  final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
                  final ap = dt.hour >= 12 ? "PM" : "AM";
                  dateStr = "${dt.day} ${months[dt.month - 1]}, $h:${dt.minute.toString().padLeft(2, '0')} $ap";
                } catch (_) { dateStr = (r["created_at"] ?? "").toString(); }

                return VybeFadeIn(
                  delayMs: (i * 45).clamp(0, 350),
                  child: VybeCard(
                    padding: const EdgeInsets.all(15),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailPage(ride: r))),
                    child: Column(children: [
                      Row(children: [
                        VybeIconBox(icon: _statusIcon(status), color: color, size: 42),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("#${r["ride_number"] ?? ""}", style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                          const SizedBox(height: 3),
                          Text(dateStr, style: AppText.label.copyWith(fontSize: 11.5)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text("₹$fare", style: AppText.price.copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                          VybeBadge(text: _pretty(status), color: color),
                        ]),
                      ]),
                      if ((r["pickup_address"] ?? "").toString().isNotEmpty) ...[
                        const SizedBox(height: 13),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Expanded(child: Text("${r["pickup_address"]}", style: AppText.body.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 7),
                        Row(children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(1.5))),
                          const SizedBox(width: 10),
                          Expanded(child: Text("${r["drop_address"] ?? ""}", style: AppText.body.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
  );
}
