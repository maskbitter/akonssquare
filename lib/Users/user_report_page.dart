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
        title: Center(child: Text("Details for ${data['monthYear']}", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
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
                    child: Text("Tenant: ${data['TenantName']}", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  ),
                if (data['nidNumber'] != null && data['nidNumber'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("NID: ${data['nidNumber']}", style: Theme.of(context).textTheme.bodyLarge),
                  ),
                if (data['paymentNotes'] != null && data['paymentNotes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("Note: ${data['paymentNotes']}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text("Rent & Services", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text("Electricity Details", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
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
                    valueColor: Theme.of(context).colorScheme.secondary,
                    isBold: true,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Grand Total", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      Text("৳${data['totalAmount']}", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
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
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
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
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (subtitle != null)
                  Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              ),
              child: Column(
                children: [
                  Text(
                    subName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text("Subscription Info", style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  _buildSummaryItem("Using Since", createdAt != null ? "${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year}" : 'N/A', Theme.of(context).colorScheme.onSurface),
                  const SizedBox(height: 4),
                  _buildSummaryItem("Total Duration", _formatDuration(createdAt), Theme.of(context).colorScheme.primary, isBold: true),
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
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: Theme.of(context).textTheme.bodyMedium));
                  
                  var docs = snapshot.data!.docs;
                  docs.sort((a, b) {
                    Timestamp t1 = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                    Timestamp t2 = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                    return t2.compareTo(t1); 
                  });

                  var displayDocs = docs.take(3).toList();

                  if (displayDocs.isEmpty) {
                    return Center(child: Text("No record of paid rent found.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: displayDocs.length,
                    itemBuilder: (context, index) {
                      var data = displayDocs[index].data() as Map<String, dynamic>;
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
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
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Text("${index + 1}", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                                    ),
                                    Text(data['monthYear'] ?? 'N/A', style: Theme.of(context).textTheme.titleMedium),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Text(
                                        "PAID", 
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.green.shade800)
                                      ),
                                    ),
                                  ],
                                ),
                                if (data['TenantName'] != null && data['TenantName'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "Tenant: ${data['TenantName']} ${data['nidNumber'] != null ? '(NID: ${data['nidNumber']})' : ''}",
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    _buildSummaryItem("Rent/Services", "৳${data['houseRentTotal']}", Theme.of(context).colorScheme.onSurface),
                                    _buildSummaryItem("Electricity", "৳${data['electricityBill']}", Theme.of(context).colorScheme.secondary),
                                    _buildSummaryItem("Total Paid", "৳${data['totalAmount']}", Theme.of(context).colorScheme.primary, isBold: true),
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
    return Builder(
      builder: (context) {
        return Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
