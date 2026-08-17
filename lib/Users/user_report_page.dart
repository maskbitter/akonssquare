import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/ui_helper.dart';

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

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    List services = data['services'] ?? [];
    Map<String, dynamic>? ed = data['electricityDetails'];
    double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    double electricityBill = (data['electricityBill'] as num?)?.toDouble() ?? 0;
    
    double rentAmount = 0;
    List<Map<String, dynamic>> otherServices = [];
    for (var s in services) {
      if (s['name'].toString().toLowerCase().contains('rent')) {
        rentAmount += (s['amount'] as num?)?.toDouble() ?? 0;
      } else {
        otherServices.add(Map<String, dynamic>.from(s));
      }
    }
    double rentAndServicesSubtotal = rentAmount + otherServices.fold(0.0, (sum, s) => sum + (s['amount'] as num).toDouble());

    String paidTime = "N/A";
    if (data['paidAt'] != null) {
      paidTime = DatabaseService.formatFullDateTime(data['paidAt'] as Timestamp);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isOutline ? ThemeManager.outlineBackground : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isOutline ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
        ),
        title: Column(
          children: [
            Text("Payment: ${data['monthYear'] ?? ''}", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null)),
            const SizedBox(height: 4),
            Text("${data['subItemName'] ?? 'Unit'} (${data['TenantName'] ?? 'No Name'})", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary)),
            const Divider(height: 24),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(context, "Payment Time:", paidTime, isBold: true),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text("Rent & Services", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDetailRow(context, "House Rent", "৳${rentAmount.toStringAsFixed(2)}"),
                ...otherServices.map((s) {
                  String name = s['name'] ?? 'Service';
                  return _buildDetailRow(context, name, "৳${(s['amount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}");
                }),
                const Divider(),
                _buildDetailRow(
                  context,
                  "Subtotal (Rent & Services)",
                  "৳${rentAndServicesSubtotal.toStringAsFixed(2)}",
                  isBold: true,
                ),

                if (ed != null || electricityBill > 0) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isOutline ? Theme.of(context).colorScheme.primary : context.electric.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.electric_bolt, color: context.electric, size: 20),
                            const SizedBox(width: 8),
                            Text("Electricity Breakdown", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : context.electric)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (ed != null) ...[
                          _buildDetailRow(context, "Meter No:", ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A'),
                          _buildDetailRow(context, "Last Units:", "${ed['lastReading'] ?? 0}"),
                          _buildDetailRow(context, "Present Units:", "${ed['presentReading'] ?? 0}"),
                          _buildDetailRow(context, "Used Units:", "${(ed['presentReading'] ?? 0) - (ed['lastReading'] ?? 0)}", isBold: true),
                          _buildDetailRow(context, "Price per Unit:", "৳${ed['pricePerUnit'] ?? 0}"),
                        ] else ...[
                           const Center(child: Text("(Detailed readings not available)", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic))),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Electric Bill", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null)),
                            Text("৳${electricityBill.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: context.electric)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Grand Total", 
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isOutline ? Colors.black : Colors.white, 
                            fontWeight: FontWeight.bold
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("৳${totalAmount.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isOutline ? Colors.black : Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if ((data['paymentNotes'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text("Note: ${data['paymentNotes']}", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: isOutline ? Colors.black : null)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.error,
                  foregroundColor: isOutline ? Colors.black : Colors.white,
                  side: isOutline ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Close")
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {String? subtitle, Color? valueColor, bool isBold = false}) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
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
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onSurfaceVariant)),
                if (subtitle != null)
                  Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isOutline ? Colors.black : valueColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('sub_items').doc(subItemId).snapshots(),
        builder: (context, subSnapshot) {
          if (!subSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          var subData = subSnapshot.data!.data() as Map<String, dynamic>?;
          if (subData == null) return const Center(child: Text("Data not found"));

          DateTime? createdAt = (subData['createdAt'] as Timestamp?)?.toDate();
          String subName = subData['subItemName'] ?? 'Unnamed';
          String currentTenant = subData['TenantName'] ?? '';

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isOutline ? ThemeManager.outlineBackground : null,
                  gradient: isOutline ? null : LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                  boxShadow: isOutline ? null : [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      currentTenant.isNotEmpty ? "$subName ($currentTenant)" : subName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text("PAYMENT HISTORY", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildHeaderSummary(context, "Joined", createdAt != null ? "${createdAt.day}-${createdAt.month}-${createdAt.year}" : 'N/A'),
                        Container(width: 1, height: 30, color: isOutline ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        
                        // Extract Rent, Electricity and calculate Utility
                        List services = data['services'] ?? [];
                        double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
                        double electricityBill = (data['electricityBill'] as num?)?.toDouble() ?? 0;
                        
                        double rentAmount = 0;
                        for (var s in services) {
                          if (s['name'].toString().toLowerCase().contains('rent')) {
                            rentAmount += (s['amount'] as num?)?.toDouble() ?? 0;
                          }
                        }
                        
                        double utilityAmount = totalAmount - rentAmount - electricityBill;
                        if (utilityAmount < 0) utilityAmount = 0;

                        String paidTime = "N/A";
                        if (data['paidAt'] != null) {
                          paidTime = DatabaseService.formatFullDateTime(data['paidAt'] as Timestamp);
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardContainerColor(index + 2, alpha: 0.5, isSubCard: true),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isOutline ? null : [
                              BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: isOutline ? Theme.of(context).colorScheme.primary : ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.1), width: isOutline ? 1.5 : 1),
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
                                          color: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
                                        ),
                                        child: Icon(Icons.calendar_month_outlined, color: isOutline ? Theme.of(context).colorScheme.primary : ThemeManager.getCardColor(index + 2, isSubCard: true), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${data['monthYear'] ?? 'N/A'} - ${data['TenantName'] ?? 'No Name'}",
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: isOutline ? Colors.black : null),
                                            ),
                                            Text("Paid on: $paidTime", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: isOutline ? Colors.black : null)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(30),
                                              border: isOutline ? Border.all(color: Colors.green, width: 1.5) : null,
                                            ),
                                            child: Text("PAID", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.green : Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w900)),
                                          ),
                                          if ((data['paymentNotes'] ?? '').toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                data['paymentNotes'],
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8, fontStyle: FontStyle.italic, color: isOutline ? Colors.black : Theme.of(context).colorScheme.onSurfaceVariant),
                                                textAlign: TextAlign.right,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(16),
                                      border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCompactSummary(context, "Rent", "৳${rentAmount.toStringAsFixed(0)}", isOutline ? Colors.black : Theme.of(context).colorScheme.onSurface),
                                        Container(width: 1, height: 20, color: Theme.of(context).colorScheme.outlineVariant),
                                        InkWell(
                                          onTap: () {
                                            DatabaseService.vibrate();
                                            _showDetailsDialog(context, data);
                                          },
                                          child: _buildCompactSummary(context, "Electricity Bills", "৳${electricityBill.toStringAsFixed(0)}", isOutline ? Colors.black : context.electric),
                                        ),
                                        Container(width: 1, height: 20, color: Theme.of(context).colorScheme.outlineVariant),
                                        _buildCompactSummary(context, "Utility", "৳${utilityAmount.toStringAsFixed(0)}", isOutline ? Colors.black : Theme.of(context).colorScheme.secondary),
                                        Container(width: 1, height: 20, color: Theme.of(context).colorScheme.outlineVariant),
                                        _buildCompactSummary(context, "Total", "৳${totalAmount.toStringAsFixed(0)}", isOutline ? Colors.black : ThemeManager.getCardColor(index + 2, isSubCard: true), isBold: true),
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
      );
  }

  Widget _buildHeaderSummary(BuildContext context, String label, String value) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900)),
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
