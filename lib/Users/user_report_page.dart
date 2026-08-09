import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:akonssquare/Common/database_service.dart';

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
        title: Center(child: Text("Details for ${data['monthYear']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                    child: Text("Tenant: ${data['TenantName']}", style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold)),
                  ),
                if (data['nidNumber'] != null && data['nidNumber'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("NID: ${data['nidNumber']}", style: const TextStyle(fontSize: 14)),
                  ),
                if (data['paymentNotes'] != null && data['paymentNotes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("Note: ${data['paymentNotes']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey), textAlign: TextAlign.center),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 8),
                  child: Text("Rent & Services", style: TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                ...services.map((s) {
                  String name = s['name'] ?? 'Service';
                  String? subtitle;
                  
                  if (name.toLowerCase().contains("wifi")) {
                    int qty = s['deviceQuantity'] ?? 1;
                    num total = s['amount'] ?? 0;
                    num costPerDevice = s['wifiCost'] ?? (qty > 0 ? (total / qty) : total);
                    
                    name = "$name (Devices: $qty)";
                    subtitle = "৳${costPerDevice.toStringAsFixed(2)} (per Device)";
                  }

                  return _buildDetailRow(
                    context,
                    name,
                    "৳${s['amount']}",
                    subtitle: subtitle,
                  );
                }),
                const Divider(),
                _buildDetailRow(
                  context,
                  "Subtotal (Rent & Services)",
                  "৳$houseRentTotal",
                  isBold: true,
                ),
                const Divider(),
                if (ed != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 8),
                    child: Text("Electricity Details", style: TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  _buildDetailRow(context, "Meter No:", ed['mainSubMeterNo'] ?? 'N/A'),
                  _buildDetailRow(context, "Reading:", "${ed['lastReading']} -> ${ed['presentReading']}"),
                  _buildDetailRow(context, "Units Used:", "${(ed['presentReading'] ?? 0) - (ed['lastReading'] ?? 0)}"),
                  _buildDetailRow(context, "Price/Unit:", "৳${ed['pricePerUnit']}"),
                  const Divider(),
                  _buildDetailRow(
                    context,
                    "Electricity Total",
                    "৳${data['electricityBill']}",
                    valueColor: Colors.cyan.shade800,
                    isBold: true,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grand Total", style: TextStyle(color: Colors.indigo, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("৳${data['totalAmount']}", style: TextStyle(color: Colors.indigo.shade900, fontSize: 22, fontWeight: FontWeight.w900)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("OK")
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {String? subtitle, Color? valueColor, bool isBold = false}) {
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
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.indigo, fontStyle: FontStyle.italic)),
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
    return Theme(
      data: ThemeManager.getThemeByName("Default Theme"),
      child: StreamBuilder<DocumentSnapshot>(
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      subName,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    const Text("PAYMENT HISTORY", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildHeaderSummary("Joined", createdAt != null ? "${createdAt.day}-${createdAt.month}-${createdAt.year}" : 'N/A'),
                        Container(width: 1, height: 30, color: Colors.white24),
                        _buildHeaderSummary("Total Duration", _formatDuration(createdAt)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('billing_history')
                      .where('subItemId', isEqualTo: subItemId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    var docs = snapshot.data!.docs;
                    docs.sort((a, b) {
                      Timestamp t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                      Timestamp t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                      return t2.compareTo(t1); 
                    });

                    if (docs.isEmpty) {
                      return const Center(child: Text("No record of paid rent found.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showDetailsDialog(context, data),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.calendar_month_outlined, color: Colors.indigo, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['monthYear'] ?? 'N/A',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                            ),
                                            const Text("Payment received", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: const Text("PAID", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCompactSummary("Rent", "৳${data['houseRentTotal']}", Colors.black87),
                                        Container(width: 1, height: 20, color: Colors.grey.shade200),
                                        _buildCompactSummary("Electric", "৳${data['electricityBill']}", Colors.cyan.shade800),
                                        Container(width: 1, height: 20, color: Colors.grey.shade200),
                                        _buildCompactSummary("Total", "৳${data['totalAmount']}", Colors.indigo, isBold: true),
                                      ],
                                    ),
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
      ),
    );
  }

  Widget _buildHeaderSummary(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCompactSummary(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
