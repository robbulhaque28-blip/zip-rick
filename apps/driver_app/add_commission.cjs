const fs = require('fs');
let c = fs.readFileSync('lib/main.dart', 'utf8');

// Add commission variables
c = c.replace('bool _isOnline = false;', 'double _commissionDue = 0;\n  double _totalEarnings = 0;\n  bool _commissionLoading = false;\n  bool _isOnline = false;');

// Add commission check before going online
c = c.replace('onTap: () => setState(() => _isOnline = !_isOnline),', 'onTap: () {\n              if (!_isOnline) {\n                _checkCommissionBeforeOnline();\n              } else {\n                setState(() => _isOnline = false);\n              }\n            },');

// Add functions before _simulateRideRequest
c = c.replace('void _simulateRideRequest() async {', oid _checkCommissionBeforeOnline() async {
    try {
      setState(() => _commissionLoading = true);
      final res = await http.get(Uri.parse(baseUrl + "/drivers/commission/due"), headers: { "Authorization": "Bearer " + (_authToken ?? "") });
      final data = jsonDecode(res.body);
      setState(() => _commissionLoading = false);
      if (data["success"] && data["data"] != null) {
        final due = (data["data"]["commission_due"] ?? 0).toDouble();
        final earnings = (data["data"]["total_earnings"] ?? 0).toDouble();
        setState(() { _commissionDue = due; _totalEarnings = earnings; });
        if (due > 0) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Commission Due", style: TextStyle(color: Colors.red)),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Please pay your pending commission to go online."),
                const SizedBox(height: 16),
                Text("Due: Rs " + due.toStringAsFixed(0), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                Text("Earnings: Rs " + earnings.toStringAsFixed(0), style: TextStyle(color: Colors.grey[600])),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(onPressed: () { Navigator.pop(ctx); _showCommissionPayment(); }, child: const Text("Pay Now")),
              ],
            ),
          );
          return;
        }
      }
      setState(() => _isOnline = true);
    } catch (e) {
      setState(() => { _commissionLoading = false; _isOnline = true; });
    }
  }

  void _showCommissionPayment() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Pay Commission", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text("Pending Commission", style: TextStyle(color: Colors.grey)),
          Text("Rs " + _commissionDue.toStringAsFixed(0), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
          Text("Earnings: Rs " + _totalEarnings.toStringAsFixed(0), style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
            onPressed: _commissionLoading ? null : () async {
              try {
                setState(() => _commissionLoading = true);
                final res = await http.post(Uri.parse(baseUrl + "/drivers/commission/pay"), headers: { "Authorization": "Bearer " + (_authToken ?? ""), "Content-Type": "application/json" }, body: jsonEncode({"amount": _commissionDue}));
                final data = jsonDecode(res.body);
                setState(() => _commissionLoading = false);
                if (data["success"]) {
                  setState(() => _commissionDue = 0);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commission paid! You can go online.")));
                }
              } catch (e) {
                setState(() => _commissionLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment failed")));
              }
            },
            child: _commissionLoading ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text("Pay Now"),
          )),
        ]),
      ),
    );
  }

  void _simulateRideRequest() async {);

// Add commission section in earnings tab
c = c.replace('Card(child: ListTile(leading: const Icon(Icons.history), title: const Text("Ride History"), trailing: const Icon(Icons.chevron_right))),',
  'Card(child: ListTile(leading: const Icon(Icons.history), title: const Text("Ride History"), trailing: const Icon(Icons.chevron_right))),\n          const SizedBox(height: 8),\n          Card(\n            child: ListTile(\n              leading: Icon(_commissionDue > 0 ? Icons.payment : Icons.check_circle, color: _commissionDue > 0 ? Colors.red : Colors.green),\n              title: const Text("Pay Commission"),\n              subtitle: Text("Due: Rs " + _commissionDue.toStringAsFixed(0)),\n              trailing: ElevatedButton(\n                onPressed: _commissionDue > 0 ? () { _showCommissionPayment(); } : null,\n                style: ElevatedButton.styleFrom(backgroundColor: _commissionDue > 0 ? Colors.red : Colors.green),\n                child: Text(_commissionDue > 0 ? "Pay Now" : "Cleared", style: const TextStyle(color: Colors.white)),\n              ),\n            ),\n          ),');

fs.writeFileSync('lib/main.dart', c, 'utf8');
console.log('Commission system added!');