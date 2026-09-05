import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akons_square/Admin/category_dialogs.dart';

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

  static void showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    debugPrint("DEBUG: showDetailsDialog called with data: $data");
    try {
      bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
      List services = data['services'] is List ? data['services'] : [];
      Map<String, dynamic>? ed = data['electricityDetails'] is Map ? Map<String, dynamic>.from(data['electricityDetails']) : null;
      double totalAmount = DatabaseService.parseNum(data['totalAmount']).toDouble();
      double electricityBill = DatabaseService.parseNum(data['electricityBill']).toDouble();
      
      double rentAmount = 0;
      List<Map<String, dynamic>> otherServices = [];
      for (var s in services) {
        if (s is Map) {
          String sName = (s['name'] ?? '').toString().toLowerCase();
          if (sName.contains('rent')) {
            rentAmount += DatabaseService.parseNum(s['amount']).toDouble();
          } else {
            otherServices.add(Map<String, dynamic>.from(s));
          }
        }
      }
      double rentAndServicesSubtotal = rentAmount + otherServices.fold(0.0, (sum, s) => sum + DatabaseService.parseNum(s['amount']).toDouble());

      String status = data['status'] ?? 'Paid';
      bool isDue = status == 'Due';

      String paidTime = "N/A";
      if (data['paidAt'] != null) {
        paidTime = DatabaseService.formatFullDateTime(data['paidAt']);
      } else if (isDue && data['createdAt'] != null) {
        paidTime = DatabaseService.formatFullDateTime(data['createdAt']);
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isOutline ? ThemeManager.outlineBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: isOutline ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Column(
            children: [
              if (data['profilePictureUrl'] != null)
                GestureDetector(
                  onTap: () => AppImageHelper.showInteractiveImage(context, url: data['profilePictureUrl'], title: "Tenant Profile"),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(data['profilePictureUrl']),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDue ? const Color(0xFFFFEBEB) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDue ? Icons.insert_drive_file : Icons.calendar_month_outlined, 
                    color: isDue ? const Color(0xFFE53935) : Theme.of(context).colorScheme.primary, 
                    size: 36
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                isDue ? "Due: ${data['monthYear']}" : "Payment: ${data['monthYear']}", 
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, 
                  color: isDue ? const Color(0xFFE53935) : null
                )
              ),
              const SizedBox(height: 2),
              Text(
                "${data['subItemName'] ?? 'Unit'} (${data['TenantName'] ?? 'No Name'})", 
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isOutline ? Colors.black : const Color(0xFF757575),
                  fontWeight: FontWeight.w500
                )
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildDetailRow(context, isDue ? "Status:" : "Payment Time:", isDue ? "PENDING (DUE)" : paidTime, isBold: true, valueColor: isDue ? const Color(0xFFE53935) : null),
                  if (isDue) _buildDetailRow(context, "Recorded at:", paidTime, valueColor: const Color(0xFFE53935)),
                  
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.list_alt, color: Color(0xFF8D4F37), size: 18),
                      const SizedBox(width: 8),
                      Text("Rent & Services", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, "House Rent", "৳${rentAmount.toStringAsFixed(2)}"),
                  ...otherServices.map((s) {
                    String name = s['name'] ?? 'Service';
                    return _buildDetailRow(context, name, "৳${(s['amount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}");
                  }),
                  const Padding(
                    padding: EdgeInsets.only(left: 0, right: 0),
                    child: Divider(height: 16),
                  ),
                  _buildDetailRow(
                    context,
                    "Subtotal (Rent & Services)",
                    "৳${rentAndServicesSubtotal.toStringAsFixed(2)}",
                    isBold: true,
                  ),

                  if (ed != null || electricityBill > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7F2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFFE0CC).withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt, color: Color(0xFF5D4037), size: 18),
                              const SizedBox(width: 8),
                              Text("Electricity Breakdown", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (ed != null) ...[
                            _buildDetailRow(context, "Meter No:", (ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A').toString()),
                            _buildDetailRow(context, "Last Units:", "${DatabaseService.parseNum(ed['lastReading'])}"),
                            _buildDetailRow(context, "Present Units:", "${DatabaseService.parseNum(ed['presentReading'])}"),
                            _buildDetailRow(context, "Used Units:", "${DatabaseService.parseNum(ed['presentReading']).toDouble() - DatabaseService.parseNum(ed['lastReading']).toDouble()}", isBold: true),
                            _buildDetailRow(context, "Price per Unit:", "৳${DatabaseService.parseNum(ed['pricePerUnit'])}"),
                          ] else ...[
                             const Center(child: Text("(Detailed readings not available)", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic))),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Electric Bill", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text("৳${electricityBill.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF5D4037))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8D4F37),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Grand Total", 
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        Text("৳${totalAmount.toStringAsFixed(2)}", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  if ((data['paymentNotes'] ?? '').toString().isNotEmpty && !(isDue == false && data['paymentNotes'] == "Marked as Due"))
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
                      child: Text("Note: ${data['paymentNotes']}", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 20),
                  FutureBuilder<SharedPreferences>(
                    future: SharedPreferences.getInstance(),
                    builder: (context, prefsSnap) {
                      final bool isAdmin = prefsSnap.hasData && (prefsSnap.data!.getString('userRole') == 'admin' || prefsSnap.data!.getString('userRole') == 'operator');
                      
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.pop(ctx), 
                              child: const Text("Close", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                            ),
                          ),
                          if (isDue && isAdmin) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 4,
                                ),
                                onPressed: () async {
                                  final String? docId = data['docId'];
                                  if (docId != null) {
                                    // Update existing Due record
                                    String actor = prefsSnap.data!.getString('username') ?? "Admin";
                                    await DatabaseService().updateBillingRecordStatus(docId, 'Paid', actor);
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      DatabaseService.showToast(context, "Marked as Paid!");
                                    }
                                  } else {
                                    // Open Mark as Paid dialog for estimated record
                                    Navigator.pop(ctx);
                                    CategoryDialogs.showMarkAsPaidDialog(
                                      context: context, 
                                      subItemId: data['subItemId'], 
                                      subItemName: data['subItemName'], 
                                      TenantName: data['TenantName'], 
                                      nidNumber: data['nidNumber'] ?? '', 
                                      houseRentTotal: DatabaseService.parseNum(data['houseRentTotal']).toDouble(), 
                                      electricityBill: DatabaseService.parseNum(data['electricityBill']).toDouble(), 
                                      services: (data['services'] as List).cast<Map<String, dynamic>>(), 
                                      electricityDetails: data['electricityDetails'], 
                                      mainCategoryName: data['mainCategoryName'] ?? 'Unknown', 
                                      manualDues: data['manualDues'] ?? []
                                    );
                                  }
                                }, 
                                child: const Text("Mark as Paid", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint("ERROR in showDetailsDialog: $e\n$stack");
      DatabaseService.showToast(context, "Dialog Error: $e", backgroundColor: Colors.red);
    }
  }


  static Widget _buildDetailRow(BuildContext context, String label, String value, {String? subtitle, Color? valueColor, bool isBold = false}) {

    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isOutline ? Colors.black : const Color(0xFF616161), fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isOutline ? Colors.black : (valueColor ?? Colors.black),
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
                        final data = docs[index].data() as Map<String, dynamic>;
                        String status = data['status'] ?? 'Paid';
                        bool isDue = status == 'Due';

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

                        String paidTimeLabel = isDue ? "Recorded on: " : "Paid on: ";
                        String paidTime = "N/A";
                        if (isDue) {
                           paidTime = data['createdAt'] != null ? DatabaseService.formatFullDateTime(data['createdAt'] as Timestamp) : "N/A";
                        } else if (data['paidAt'] != null) {
                          paidTime = DatabaseService.formatFullDateTime(data['paidAt'] as Timestamp);
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardContainerColor(index + 2, alpha: 0.5, isSubCard: true),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isOutline ? null : [
                              BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: isOutline ? (isDue ? Colors.red : Theme.of(context).colorScheme.primary) : (isDue ? Colors.red.withValues(alpha: 0.5) : ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.1)), width: (isDue || isOutline) ? 1.5 : 1),

                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              try {
                                UserReportPage.showDetailsDialog(context, {
                                  ...data,
                                  'docId': docs[index].id,
                                });
                              } catch (e, stack) {
                                debugPrint("ERROR in user_report_page list onTap: $e\n$stack");
                                DatabaseService.showToast(context, "Error: $e", backgroundColor: Colors.red);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      if (data['profilePictureUrl'] != null)
                                        GestureDetector(
                                          onTap: () => AppImageHelper.showInteractiveImage(context, url: data['profilePictureUrl'], title: "Tenant Profile"),
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 10),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.3), width: 1),
                                            ),
                                            child: CircleAvatar(
                                              radius: 18,
                                              backgroundImage: NetworkImage(data['profilePictureUrl']),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          margin: const EdgeInsets.only(right: 10),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardColor(index + 2, isSubCard: true).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            border: isOutline ? Border.all(color: isDue ? Colors.red : Theme.of(context).colorScheme.primary, width: 1) : null,
                                          ),
                                          child: Icon(isDue ? Icons.request_quote_outlined : Icons.calendar_month_outlined, color: isOutline ? (isDue ? Colors.red : Theme.of(context).colorScheme.primary) : ThemeManager.getCardColor(index + 2, isSubCard: true), size: 18),
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${data['monthYear'] ?? 'N/A'} - ${data['TenantName'] ?? 'No Name'}",
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: isOutline ? Colors.black : (isDue ? Colors.red : null)),
                                            ),
                                            Text("$paidTimeLabel$paidTime", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, color: isOutline ? Colors.black : null)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isOutline ? ThemeManager.outlineBackground : (isDue ? Colors.red.withValues(alpha: 0.1) : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(30),
                                              border: isOutline ? Border.all(color: isDue ? Colors.red : Colors.green, width: 1.5) : null,
                                            ),
                                            child: Text(status.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? (isDue ? Colors.red : Colors.green) : (isDue ? Colors.red : Theme.of(context).colorScheme.tertiary), fontWeight: FontWeight.w900)),
                                          ),
                                          if ((data['paymentNotes'] ?? '').toString().isNotEmpty && !(isDue == false && data['paymentNotes'] == "Marked as Due"))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                data['paymentNotes'],
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8, fontStyle: FontStyle.italic, color: isOutline ? (isDue ? Colors.red : Colors.black) : Theme.of(context).colorScheme.onSurfaceVariant),
                                                textAlign: TextAlign.right,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(16),
                                      border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildCompactSummary(context, "Rent", "৳${rentAmount.toStringAsFixed(0)}", isOutline ? Colors.black : Theme.of(context).colorScheme.onSurface),
                                        Container(width: 1, height: 16, color: Theme.of(context).colorScheme.outlineVariant),
                                        InkWell(
                                          onTap: () {
                                            try {
                                              DatabaseService.vibrate();
                                              UserReportPage.showDetailsDialog(context, {
                                              ...data,
                                              'docId': docs[index].id,
                                            });
                                            } catch (e, stack) {
                                              debugPrint("ERROR in user_report_page summary onTap: $e\n$stack");
                                              DatabaseService.showToast(context, "Error: $e", backgroundColor: Colors.red);
                                            }
                                          },
                                          child: _buildCompactSummary(context, "Elec", "৳${electricityBill.toStringAsFixed(0)}", isOutline ? Colors.black : context.electric),
                                        ),
                                        Container(width: 1, height: 16, color: Theme.of(context).colorScheme.outlineVariant),
                                        _buildCompactSummary(context, "Util", "৳${utilityAmount.toStringAsFixed(0)}", isOutline ? Colors.black : Theme.of(context).colorScheme.secondary),
                                        Container(width: 1, height: 16, color: Theme.of(context).colorScheme.outlineVariant),
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
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
