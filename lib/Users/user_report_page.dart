import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserReportPage extends StatelessWidget {
  final String subItemId;

  const UserReportPage({super.key, required this.subItemId});

  String _formatDuration(DateTime? start) {
    if (start == null) return "Unknown";
    Duration diff = DateTime.now().difference(start);
    int years = diff.inDays ~/ 365;
    int months = (diff.inDays % 365) ~/ 30;
    int days = (diff.inDays % 365) % 30;

    List<String> parts = [];
    if (years > 0) parts.add("$years years");
    if (months > 0) parts.add("$months months");
    if (days > 0) parts.add("$days days");
    
    return parts.isEmpty ? "Joined today" : parts.join(", ");
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    DateTime dt = timestamp.toDate();
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    List services = data['services'] ?? [];
    Map<String, dynamic>? ed = data['electricityDetails'];
    double houseRentTotal = (data['houseRentTotal'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text("Details for ${data['monthYear']}", textAlign: TextAlign.center)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (data['TenantName'] != null && data['TenantName'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text("Tenant: ${data['TenantName']}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent, fontSize: 16)),
                  ),
                if (data['nidNumber'] != null && data['nidNumber'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("NID: ${data['nidNumber']}", style: const TextStyle(fontSize: 16, color: Colors.blueAccent)),
                  ),
                if (data['paymentNotes'] != null && data['paymentNotes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("Note: ${data['paymentNotes']}", style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text("Rent & Services", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...services.map((s) {
                  String name = s['name'] ?? 'Service';
                  String? subtitle;
                  
                  if (name.toLowerCase().contains("wifi")) {
                    int qty = s['deviceQuantity'] ?? 1;
                    num total = s['amount'] ?? 0;
                    // Dynamically calculate cost if missing, otherwise use stored cost
                    num costPerDevice = s['wifiCost'] ?? (qty > 0 ? (total / qty) : total);
                    
                    name = "$name (Devices: $qty)";
                    subtitle = "৳${costPerDevice.toStringAsFixed(2)} (per Device)";
                  }

                  return _buildDetailRow(
                    name,
                    "৳${s['amount']}",
                    subtitle: subtitle,
                  );
                }),
                const Divider(),
                _buildDetailRow(
                  "Subtotal (Rent & Services)",
                  "৳$houseRentTotal",
                ),
                const Divider(),
                if (ed != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                    child: Text("Electricity Details", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _buildDetailRow("Meter No:", ed['mainSubMeterNo'] ?? 'N/A'),
                  _buildDetailRow("Reading:", "${ed['lastReading']} -> ${ed['presentReading']}"),
                  _buildDetailRow("Units Used:", "${(ed['presentReading'] ?? 0) - (ed['lastReading'] ?? 0)}"),
                  _buildDetailRow("Price/Unit:", "৳${ed['pricePerUnit']}"),
                  const Divider(),
                  _buildDetailRow(
                    "Electricity Total",
                    "৳${data['electricityBill']}",
                    valueColor: Colors.teal,
                    isBold: true,
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grand Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      Text("৳${data['totalAmount']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: BorderSide(color: Colors.grey.shade300)),
              onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? subtitle, Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.blue, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sub_items').doc(subItemId).snapshots(),
      builder: (context, subSnapshot) {
        if (!subSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        var subData = subSnapshot.data!.data() as Map<String, dynamic>?;
        if (subData == null) return const Center(child: Text("Data not found"));

        DateTime? createdAt = (subData['createdAt'] as Timestamp?)?.toDate();
        String subName = subData['subItemName'] ?? 'Unnamed';

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                children: [
                  Text(
                    subName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  const Text("Subscription Info", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  Text("Using Since: ${createdAt != null ? "${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}" : 'N/A'}", style: const TextStyle(fontSize: 12)),
                  Text("Duration: ${_formatDuration(createdAt)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('billing_history')
                    .where('subItemId', isEqualTo: subItemId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                  
                  var docs = snapshot.data!.docs;
                  
                  // Sort in memory to avoid needing a composite index in Firestore
                  docs.sort((a, b) {
                    Timestamp t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                    Timestamp t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                    return t2.compareTo(t1); // Descending
                  });

                  // Limit to last 2 records
                  var displayDocs = docs.take(2).toList();

                  if (displayDocs.isEmpty) {
                    return const Center(child: Text("No record of paid rent found.", style: TextStyle(color: Colors.grey)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: displayDocs.length,
                    itemBuilder: (context, index) {
                      var data = displayDocs[index].data() as Map<String, dynamic>;
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showDetailsDialog(context, data),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.blueGrey.shade100,
                                      child: Text("${index + 1}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    Text(data['monthYear'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "PAID (${_formatDateTime(data['paidAt'] as Timestamp?)})", 
                                        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  ],
                                ),
                                if (data['TenantName'] != null && data['TenantName'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "Tenant: ${data['TenantName']} ${data['nidNumber'] != null ? '(NID: ${data['nidNumber']})' : ''}",
                                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    _buildSummaryItem("Rent/Services", "৳${data['houseRentTotal']}", Colors.blueGrey),
                                    _buildSummaryItem("Electricity", "৳${data['electricityBill']}", Colors.teal),
                                    _buildSummaryItem("Total Paid", "৳${data['totalAmount']}", Colors.indigo, isBold: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, {bool isBold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
