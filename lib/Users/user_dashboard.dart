import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
import 'package:akonssquare/Common/automation_guide.dart';
import 'package:akonssquare/Common/build_config.dart';
import 'package:akonssquare/Common/ui_helper.dart';
import 'package:akonssquare/Users/user_report_page.dart';
import 'package:akonssquare/main.dart';
import 'dart:async';

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
  String _username = "User";
  String _tenantName = "";
  StreamSubscription? _userSessionSubscription;

  @override
  void initState() {
    super.initState();
    _loadAppData();
    _startSessionListener();
  }

  @override
  void dispose() {
    _userSessionSubscription?.cancel();
    super.dispose();
  }

  void _startSessionListener() {
    String subId = widget.subItemId;
    if (subId.isEmpty) return;

    _userSessionSubscription = FirebaseFirestore.instance
        .collection('sub_items')
        .doc(subId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        _handleLogout();
        return;
      }
      
      var data = snapshot.data() as Map<String, dynamic>;
      
      // Check for Vacant status
      String tenant = data['TenantName'] ?? '';
      String status = data['status'] ?? (tenant.isNotEmpty && tenant != 'No Name' ? 'Occupied' : 'Vacant');
      if (status == 'Vacant') {
        _handleLogout();
        return;
      }

      // Check for Session ID (requires async prefs)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? currentSessionId = prefs.getString('sessionId');
      String? serverSessionId = data['currentSessionId'];
      if (currentSessionId != null && serverSessionId != null && serverSessionId != currentSessionId) {
        _handleLogout();
      }
    }, onError: (e) {
      debugPrint("Listener Error: $e");
      _handleLogout();
    });
  }

  Future<void> _loadAppData() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    
    String catName = "Unknown";
    String uName = "User";
    String tName = "";
    if (widget.categoryId.isNotEmpty) {
      try {
        DocumentSnapshot catDoc = await _dbService.getCategoryById(widget.categoryId);
        if (catDoc.exists) {
          catName = (catDoc.data() as Map?)?['categoryName'] ?? 'Unknown';
        }
        
        DocumentSnapshot subDoc = await FirebaseFirestore.instance.collection('sub_items').doc(widget.subItemId).get();
        if (subDoc.exists) {
          var data = subDoc.data() as Map?;
          uName = data?['subItemName'] ?? 'User';
          tName = data?['TenantName'] ?? '';
        }
      } catch (e) {
        debugPrint("Error loading data: $e");
      }
    }
    
    if (mounted) {
      setState(() {
        _appName = packageInfo.appName;
        _categoryName = catName;
        _username = uName;
        _tenantName = tName;
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
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Cancel")
                ),
                AppButton(
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
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? subItemId = prefs.getString('subItemId');
      if (subItemId != null) {
        // Try updating session, but don't wait if it fails (e.g. doc deleted)
        DatabaseService().updateUserSession('sub_items', subItemId, null).catchError((e) => null);
      }
      await prefs.clear();
    } catch (e) {
      debugPrint("Logout Error: $e");
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              if (icon != null) const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.2)),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, height: 1.2)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sub_items').doc(widget.subItemId).snapshots(),
      builder: (context, snapshot) {
        // Aggressive Existence Check for Auto-Logout
        if (snapshot.hasData && (!snapshot.data!.exists || (snapshot.data!.data() as Map?)?['status'] == 'Vacant')) {
           WidgetsBinding.instance.addPostFrameCallback((_) => _handleLogout());
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final List<Widget> pages = [
          _buildMainDashboard(snapshot.data),
          UserReportPage(subItemId: widget.subItemId),
        ];

        return Theme(
          data: ThemeManager.getThemeByName("Normal Theme"),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AutomationGuidePage()));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _appName.isEmpty ? "Loading..." : _appName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentIndex == 0 ? "Home" : "History",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                          ),
                          Text(
                            " | ", 
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                          ),
                          Text(
                            _tenantName.isEmpty ? _username.toUpperCase() : "${_username.toUpperCase()}($_tenantName)",
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary, 
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                InkWell(
                  onTap: _showLogoutConfirmationDialog,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _dbService.getAppConfigStream(),
                    builder: (context, configSnap) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: _dbService.getDatabaseInfoStream(),
                        builder: (context, dbInfoSnap) {
                          return FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, pSnap) {
                              String local = pSnap.hasData ? "${pSnap.data!.version}+${pSnap.data!.buildNumber}" : "...";
                              String? remote = configSnap.data?.exists == true ? configSnap.data!['requiredVersion'] : null;
                              String dbVersion = "...";
                              String bnText = "BN$buildNumber";
                              if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                                var data = dbInfoSnap.data!.data() as Map<String, dynamic>?;
                                dbVersion = (data?['dbVersion'] ?? 26.0).toDouble().toStringAsFixed(1);
                                int firestoreBN = data?['buildNumber']?.toInt() ?? 0;
                                if (firestoreBN > buildNumber) bnText = "BN$firestoreBN";
                              }
                              
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("${local}_$bnText", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 9)),
                                  if (remote != null && remote != local)
                                    Text("Latest: $remote", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 8)),
                                  Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 18),
                                  Text("DB V-$dbVersion", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 9)),
                                ],
                              );
                            }
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
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
                BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: "History"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainDashboard(DocumentSnapshot? snapshot) {
    if (snapshot == null || !snapshot.exists) {
      return const Center(child: CircularProgressIndicator());
    }

    var subData = snapshot.data() as Map<String, dynamic>?;
    if (subData == null) return const Center(child: Text("Data not found."));

    String subName = subData['subItemName'] ?? 'Unnamed';
    String TenantName = subData['TenantName'] ?? '';
    String nidNumber = subData['nidNumber'] ?? '';
    String notes = subData['notes'] ?? '';
    DateTime? createdAt = (subData['createdAt'] as Timestamp?)?.toDate();

    if (widget.categoryId.isEmpty) {
       return const Center(child: Text("Category info missing. Please contact admin."));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _dbService.getCategoryStream(widget.categoryId),
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

        // --- PAYMENT CHECK FOR CURRENT MONTH ---
        List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        DateTime nowTime = DateTime.now();
        String currentMonthYear = "${months[nowTime.month - 1]}-${nowTime.year.toString().substring(2)}";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('billing_history')
              .where('subItemId', isEqualTo: widget.subItemId)
              .where('monthYear', isEqualTo: currentMonthYear)
              .snapshots(),
          builder: (context, paySnap) {
            bool isPaidThisMonth = paySnap.hasData && paySnap.data!.docs.isNotEmpty;
            
            // Keep the totalBill (Fixed + Elec Usage). 
            // Electricity resets to 0 on payment, so total will show fixed services.
            double displayTotal = totalBill;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- MODERN HEADER CARD ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), letterSpacing: 1.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subName,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                              child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (TenantName.isNotEmpty) ...[
                          Text(
                            "Tenant: $TenantName",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (nidNumber.isNotEmpty)
                          Text(
                            "NID: $nidNumber",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                          ),
                      ],
                    ),
                  ),

                  // --- OUTSTANDING BILL SECTION ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isPaidThisMonth ? Icons.check_circle : Icons.pending_actions, color: isPaidThisMonth ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error, size: 20),
                            const SizedBox(width: 8),
                            Text(isPaidThisMonth ? "MONTHLY BILL (PAID)" : "CURRENT OUTSTANDING", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "৳${displayTotal.toStringAsFixed(2)}",
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: isPaidThisMonth ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        if (createdAt != null)
                          Text(isPaidThisMonth ? "Current month paid: $currentMonthYear" : "Active since: ${DatabaseService.formatMonthYear(createdAt)}", style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),

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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("UNPAID MONTHS", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: pendingMonths.map((m) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              m, 
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  );
                }
              ),

              if (notes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text("ADMIN NOTES", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(notes, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))),
                    ],
                  ),
                ),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text("BILL BREAKDOWN", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),

              if (ed != null && !isElectricStopped)
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    iconColor: context.electric,
                    collapsedIconColor: context.electric,
                    leading: CircleAvatar(
                      backgroundColor: context.electric.withValues(alpha: 0.1),
                      child: Icon(Icons.electric_bolt, color: context.electric, size: 20),
                    ),
                    title: Text("Electricity Bill", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text("Usage: ${((ed['presentReading'] ?? 0) as num) - ((ed['lastReading'] ?? 0) as num)} units", style: Theme.of(context).textTheme.bodySmall),
                    trailing: Text("৳${electricityBill.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _buildInfoRow("Meter Number", ed['subMeterNo'] ?? 'N/A', icon: Icons.numbers),
                      _buildInfoRow("Last Units", (ed['lastReading'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', icon: Icons.history),
                      _buildInfoRow("Present Units", (ed['presentReading'] as num?)?.toDouble().toStringAsFixed(1) ?? '0.0', icon: Icons.speed),
                      _buildInfoRow("Used Units", (((ed['presentReading'] ?? 0) as num) - ((ed['lastReading'] ?? 0) as num)).toStringAsFixed(1), icon: Icons.bolt, isBold: true),
                      _buildInfoRow("Price per Unit", "৳${(ed['pricePerUnit'] as num?)?.toDouble().toStringAsFixed(2)}", icon: Icons.payments_outlined),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

              ...activeServices.map((s) {
                bool isWifi = s['name'].toString().toLowerCase().contains("wifi");
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: (isWifi ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary).withValues(alpha: 0.1),
                      child: Icon(isWifi ? Icons.wifi : Icons.check_circle_outline, color: isWifi ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary, size: 20),
                    ),
                    title: Text(
                      isWifi ? "${s['name']} (x${s['deviceQuantity'] ?? 1})" : s['name'],
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: isWifi ? Text("৳${s['wifiCost'] ?? 0} per device", style: Theme.of(context).textTheme.bodySmall) : null,
                    trailing: Text("৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  ),
                );
              }),

              if (activeServices.isEmpty && (ed == null || isElectricStopped))
                Center(child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text("No active charges found for this period.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                )),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
