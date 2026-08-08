import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
import 'package:akonssquare/Users/user_report_page.dart';
import 'package:akonssquare/main.dart';

class UserDashboard extends StatefulWidget {
  final String subItemId;
  final String categoryId;

  const UserDashboard({super.key, required this.subItemId, required this.categoryId});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final DatabaseService _dbService = DatabaseService();
  int _currentIndex = 0;
  String _appName = "";
  String _categoryName = "";

  @override
  void initState() {
    super.initState();
    _loadAppData();
  }

  Future<void> _loadAppData() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    
    String catName = "Unknown";
    if (widget.categoryId.isNotEmpty) {
      try {
        DocumentSnapshot catDoc = await _dbService.getCategoryById(widget.categoryId);
        if (catDoc.exists) {
          catName = (catDoc.data() as Map?)?['categoryName'] ?? 'Unknown';
        }
      } catch (e) {
        debugPrint("Error loading category name: $e");
      }
    }
    
    if (mounted) {
      setState(() {
        _appName = packageInfo.appName;
        _categoryName = catName;
      });
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("Logout Confirmation", style: Theme.of(context).textTheme.titleLarge)),
          content: Text("Are you sure you want to logout?", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error, 
                      side: BorderSide(color: Theme.of(context).colorScheme.error)
                    ),
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Cancel")
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error, 
                      foregroundColor: Theme.of(context).colorScheme.onPrimary
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                    child: const Text("Logout"),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? subItemId = prefs.getString('subItemId');
    if (subItemId != null) {
      await DatabaseService().updateUserSession('sub_items', subItemId, null);
    }
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              if (icon != null) const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildMainDashboard(),
      UserReportPage(subItemId: widget.subItemId),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text(_appName.isEmpty ? "Loading..." : _appName, style: Theme.of(context).textTheme.titleMedium),
        centerTitle: true,
        actions: [
          InkWell(
            onTap: _showLogoutConfirmationDialog,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _dbService.getAppConfigStream(),
              builder: (context, snapshot) {
                return FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, pSnap) {
                    String local = pSnap.hasData ? "${pSnap.data!.version}+${pSnap.data!.buildNumber}" : "...";
                    String? remote = snapshot.data?.exists == true ? snapshot.data!['requiredVersion'] : null;
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 20),
                        Text(local, style: Theme.of(context).textTheme.labelSmall),
                        if (remote != null && remote != local)
                          Text(remote, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                      ],
                    );
                  }
                );
              }
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: UpdateGuard(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: "History"),
        ],
      ),
    );
  }

  Widget _buildMainDashboard() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('sub_items').doc(widget.subItemId).snapshots(),
        builder: (context, subSnapshot) {
          if (!subSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var subData = subSnapshot.data!.data() as Map<String, dynamic>?;
          if (subData == null) return const Center(child: Text("Data not found."));

          String subName = subData['subItemName'] ?? 'Unnamed';
          String TenantName = subData['TenantName'] ?? '';
          String nidNumber = subData['nidNumber'] ?? '';
          String notes = subData['notes'] ?? '';
          DateTime? createdAt = (subData['createdAt'] as Timestamp?)?.toDate();

          String durationText = "N/A";
          if (createdAt != null) {
            Duration diff = DateTime.now().difference(createdAt);
            int years = diff.inDays ~/ 365;
            int months = (diff.inDays % 365) ~/ 30;
            if (years > 0) {
              durationText = "$years year${years > 1 ? 's' : ''}${months > 0 ? ' $months month${months > 1 ? 's' : ''}' : ''}";
            } else {
              durationText = "$months month${months > 1 ? 's' : ''}";
              if (months == 0) durationText = "${diff.inDays} days";
            }
          }
          
          if (widget.categoryId.isEmpty) {
             return const Center(child: Text("Category info missing. Please contact admin."));
          }

          return FutureBuilder<DocumentSnapshot>(
            future: _dbService.getCategoryById(widget.categoryId),
            builder: (context, catSnapshot) {
              if (!catSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var catData = catSnapshot.data!.data() as Map<String, dynamic>?;
              List assignedServices = catData?['assignedServices'] ?? [];

              var ed = subData['electricityDetails'];
              double electricityBill = 0;
              bool isElectricStopped = ed?['isStopped'] == true;

              if (ed != null && !isElectricStopped) {
                double last = (ed['lastReading'] as num?)?.toDouble() ?? 0;
                double present = (ed['presentReading'] as num?)?.toDouble() ?? 0;
                double rate = (ed['pricePerUnit'] as num?)?.toDouble() ?? 0;
                electricityBill = (present - last) * rate;
              }

              List excludedServices = subData['excludedServices'] ?? [];
              List overriddenServices = subData['overriddenServices'] ?? [];
              
              List<Map<String, dynamic>> activeServices = [];
              for (var service in assignedServices) {
                String originalName = (service is Map) ? (service['name'] ?? '') : service.toString();
                if (originalName.isEmpty || excludedServices.contains(originalName)) continue;
                
                var overrideMatch = overriddenServices.firstWhere(
                  (element) => element is Map && element['originalName'] == originalName,
                  orElse: () => null,
                );

                if (overrideMatch != null) {
                  activeServices.add({
                    'name': overrideMatch['name'] ?? originalName,
                    'amount': overrideMatch['amount'] ?? 0,
                    'deviceQuantity': overrideMatch['deviceQuantity'],
                    'wifiCost': overrideMatch['wifiCost'],
                  });
                } else {
                  Map<String, dynamic> serviceData = {
                    'name': originalName,
                    'amount': (service is Map) ? (service['amount'] ?? 0) : 0,
                  };

                  if (originalName.toLowerCase().contains("wifi")) {
                    serviceData['deviceQuantity'] = 1;
                    serviceData['wifiCost'] = serviceData['amount'];
                  }

                  activeServices.add(serviceData);
                }
              }

              double servicesSum = activeServices.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());
              double totalBill = servicesSum + electricityBill;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                        child: Column(
                          children: [
                            Text(_categoryName, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: TenantName.isNotEmpty 
                                  ? MainAxisAlignment.spaceBetween 
                                  : MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    subName, 
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: -0.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (TenantName.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Chip(
                                      label: Text(
                                        TenantName, 
                                        style: Theme.of(context).textTheme.labelSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ), 
                                      backgroundColor: Theme.of(context).colorScheme.surface,
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (nidNumber.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("NID: $nidNumber", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ),
                            if (createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("Using for: $durationText", style: Theme.of(context).textTheme.labelSmall),
                              ),
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  "Total Outstanding: ৳${totalBill.toStringAsFixed(2)}",
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('billing_history').where('subItemId', isEqualTo: widget.subItemId).snapshots(),
                      builder: (context, historySnapshot) {
                        if (!historySnapshot.hasData) return const SizedBox.shrink();
                        
                        List<String> paidMonths = historySnapshot.data!.docs.map((doc) => (doc.data() as Map)['monthYear'].toString()).toList();
                        List<String> pendingMonths = [];
                        
                        if (createdAt != null) {
                          DateTime now = DateTime.now();
                          DateTime current = DateTime(createdAt.year, createdAt.month);
                          List<String> monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                          
                          while (current.isBefore(now) || (current.year == now.year && current.month == now.month)) {
                            String mYear = "${monthNames[current.month - 1]}-${current.year.toString().substring(2)}";
                            if (!paidMonths.contains(mYear)) {
                              pendingMonths.add(mYear);
                            }
                            current = DateTime(current.year, current.month + 1);
                          }
                        }
                        
                        if (pendingMonths.isEmpty) return const SizedBox.shrink();
                        
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Text(
                                "Pending:", 
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error)
                              ),
                              ...pendingMonths.map((m) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.2)),
                                ),
                                child: Text(
                                  m, 
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error)
                                ),
                              )),
                            ],
                          ),
                        );
                      }
                    ),

                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text("Notes", style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 1,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.note_alt_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                          title: Text(notes, style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text("Bill Details", style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (ed != null && !isElectricStopped)
                      Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: const Icon(Icons.electric_bolt, color: Colors.amber, size: 22),
                          title: Text("Electricity Bill", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "Used: ${((ed['presentReading'] ?? 0) as num) - ((ed['lastReading'] ?? 0) as num)} units",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Text(
                            "৳${electricityBill.toStringAsFixed(2)}",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                          ),
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 6),
                            _buildInfoRow("Main Meter No:", ed['mainMeterNo'] ?? 'N/A', icon: Icons.settings_input_component),
                            _buildInfoRow("Sub-Meter No:", ed['subMeterNo'] ?? 'N/A', icon: Icons.numbers),
                            _buildInfoRow("Last Readings:", "${(ed['lastReading'] as num?)?.toDouble().toStringAsFixed(2)}", icon: Icons.history),
                            _buildInfoRow("Present Readings:", "${(ed['presentReading'] as num?)?.toDouble().toStringAsFixed(2)}", icon: Icons.visibility),
                            _buildInfoRow("Used Units:", (((ed['presentReading'] ?? 0) as num) - ((ed['lastReading'] ?? 0) as num)).toStringAsFixed(2), isBold: true, icon: Icons.electric_bolt),
                            _buildInfoRow("Price per Unit:", "৳${(ed['pricePerUnit'] as num?)?.toDouble().toStringAsFixed(2)}", icon: Icons.payments_outlined),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ...activeServices.map((s) {
                      String? wifiSubtitle;
                      if (s['name'].toString().toLowerCase().contains("wifi") && s['deviceQuantity'] != null) {
                        wifiSubtitle = "৳${s['wifiCost'] ?? 200} (per Device)";
                      }

                      return _buildDetailCard(
                        icon: Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.secondary,
                        title: s['name'].toString().toLowerCase().contains("wifi") 
                            ? "${s['name']} (Devices: ${s['deviceQuantity'] ?? 1})" 
                            : s['name'],
                        amount: (s['amount'] as num).toDouble(),
                        subtitle: wifiSubtitle,
                      );
                    }),
                    if (activeServices.isEmpty && (ed == null || isElectricStopped))
                      Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text("No active charges for this month.", style: Theme.of(context).textTheme.bodySmall),
                      )),
                  ],
                ),
              );
            },
          );
        },
      );
  }

  Widget _buildDetailCard({required IconData icon, required Color color, required String title, required double amount, String? subtitle, VoidCallback? onTap}) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, color: color, size: 20),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle, style: Theme.of(context).textTheme.labelSmall) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("৳${amount.toStringAsFixed(2)}", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            if (onTap != null) Icon(Icons.chevron_right, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
