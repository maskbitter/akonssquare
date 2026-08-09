import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Common/theme_manager.dart';
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

    return Theme(
      data: ThemeManager.getThemeByName("Default Theme"),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: Text(_appName.isEmpty ? "Loading..." : _appName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          const Icon(Icons.logout, color: Colors.red, size: 20),
                          Text(local, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          if (remote != null && remote != local)
                            Text(remote, style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
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
          selectedItemColor: Colors.indigo.shade800,
          unselectedItemColor: Colors.grey,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: "History"),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- MODERN HEADER CARD ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade800,
                            Colors.indigo.shade500,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _categoryName.toUpperCase(),
                                    style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                                  ),
                                ],
                              ),
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.person_outline, color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (TenantName.isNotEmpty) ...[
                            Text(
                              "Tenant: $TenantName",
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (nidNumber.isNotEmpty)
                            Text(
                              "NID: $nidNumber",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- OUTSTANDING BILL SECTION ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.pending_actions, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text("CURRENT OUTSTANDING", style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "৳${totalBill.toStringAsFixed(2)}",
                            style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.w900, fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          if (createdAt != null)
                            Text("Active since: ${DatabaseService.formatMonthYear(createdAt)}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- PENDING MONTHS ---
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
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("UNPAID MONTHS", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: pendingMonths.map((m) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                                  ),
                                  child: Text(
                                    m, 
                                    style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        );
                      }
                    ),

                    if (notes.isNotEmpty) ...[
                      const Text("ADMIN NOTES", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.indigo, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(notes, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    const Text("BILL BREAKDOWN", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 12),

                    if (ed != null && !isElectricStopped)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.withOpacity(0.1),
                            child: const Icon(Icons.electric_bolt, color: Colors.amber, size: 20),
                          ),
                          title: const Text("Electricity Bill", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text("Usage: ${((ed['presentReading'] ?? 0) as num) - ((ed['lastReading'] ?? 0) as num)} units", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: Text("৳${electricityBill.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            _buildInfoRow("Meter Number", ed['subMeterNo'] ?? 'N/A', icon: Icons.numbers),
                            _buildInfoRow("Reading Range", "${(ed['lastReading'] as num?)?.toDouble().toStringAsFixed(1)} ➜ ${(ed['presentReading'] as num?)?.toDouble().toStringAsFixed(1)}", icon: Icons.sync_alt),
                            _buildInfoRow("Price per Unit", "৳${(ed['pricePerUnit'] as num?)?.toDouble().toStringAsFixed(2)}", icon: Icons.payments_outlined),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                    ...activeServices.map((s) {
                      bool isWifi = s['name'].toString().toLowerCase().contains("wifi");
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isWifi ? Colors.blue : Colors.teal).withOpacity(0.1),
                            child: Icon(isWifi ? Icons.wifi : Icons.check_circle_outline, color: isWifi ? Colors.blue : Colors.teal, size: 20),
                          ),
                          title: Text(
                            isWifi ? "${s['name']} (x${s['deviceQuantity'] ?? 1})" : s['name'],
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: isWifi ? Text("৳${s['wifiCost'] ?? 0} per device", style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
                          trailing: Text("৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ),
                      );
                    }),

                    if (activeServices.isEmpty && (ed == null || isElectricStopped))
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text("No active charges found for this period.", style: TextStyle(color: Colors.grey, fontSize: 13)),
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
