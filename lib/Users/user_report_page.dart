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
        title: Center(child: Text("Details for ${data['monthYear']}", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
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
                    child: Text("Tenant: ${data['TenantName']}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                if (data['nidNumber'] != null && data['nidNumber'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("NID: ${data['nidNumber']}", style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (data['paymentNotes'] != null && data['paymentNotes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("Note: ${data['paymentNotes']}", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text("Rent & Services", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
                    child: Text("Electricity Details", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
                    valueColor: context.electric,
                    isBold: true,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Grand Total", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      Text("৳${data['totalAmount']}", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
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
    return Theme(
      data: ThemeManager.getThemeByName("Normal Theme"),
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
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      subName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text("PAYMENT HISTORY", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildHeaderSummary(context, "Joined", createdAt != null ? "${createdAt.day}-${createdAt.month}-${createdAt.year}" : 'N/A'),
                        Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
                        _buildHeaderSummary(context, "Total Duration", _formatDuration(createdAt)),
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
                      return Center(child: Text("No record of paid rent found.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: ThemeManager.getCardContainerColor(index + 2, alpha: 0.5, isSubCard: true),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.1)),
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
                                          color: ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.calendar_month_outlined, color: ThemeManager.getCardColor(index + 2, isSubCard: true), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['monthYear'] ?? 'N/A',
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                            ),
                                            Text("Payment received", style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: Text("PAID", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w900)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCompactSummary(context, "Rent", "৳${data['houseRentTotal']}", Theme.of(context).colorScheme.onSurface),
                                        Container(width: 1, height: 20, color: Theme.of(context).colorScheme.outlineVariant),
                                        _buildCompactSummary(context, "Electric", "৳${data['electricityBill']}", context.electric),
                                        Container(width: 1, height: 20, color: Theme.of(context).colorScheme.outlineVariant),
                                        _buildCompactSummary(context, "Total", "৳${data['totalAmount']}", ThemeManager.getCardColor(index + 2, isSubCard: true), isBold: true),
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

  Widget _buildHeaderSummary(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCompactSummary(BuildContext context, String label, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
