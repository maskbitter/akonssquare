import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/update_guard.dart';
import 'package:akons_square/Common/build_config.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:akons_square/Users/user_report_page.dart';
import 'package:akons_square/main.dart';
import 'package:akons_square/Common/share_helper.dart';
import 'package:akons_square/Admin/category_dialogs.dart';
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
      
      // Check for Vacant status (Strict)
      String status = data['status'] ?? 'Vacant';
      if (status == 'Vacant') {
        _handleLogout();
        return;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? ThemeManager.outlineBackground 
                      : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.5) 
                      : null,
                ),
                child: Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 40),
              ),
              const SizedBox(height: 16),
              Text("Logout Confirmation", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            child: Text("Are you sure you want to logout?", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ),
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
                  child: const Text("Cancel")),
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

  void _showFullScreenImage(BuildContext context, String imageUrl, String title) {
    AppImageHelper.showInteractiveImage(context, url: imageUrl, title: title);
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

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: false,
            title: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: GestureDetector(
                onTap: null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _appName.isEmpty ? "Loading..." : _appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentIndex == 0 ? "Home" : "History",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary),
                        ),
                        Text(
                          " | ", 
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                        ),
                        Text(
                          _tenantName.isEmpty ? _username.toUpperCase() : "${_username.toUpperCase()}($_tenantName)",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.secondary, 
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.share_outlined, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null),
                onPressed: () => ShareHelper.shareApp(context),
                tooltip: "Share App",
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: _dbService.getAppConfigStream(),
                builder: (context, configSnap) {
                  return StreamBuilder<DocumentSnapshot>(
                    stream: _dbService.getDatabaseInfoStream(),
                    builder: (context, dbInfoSnap) {
                      String local = appVersion; // Instant update from build_config.dart
                      final configData = configSnap.data?.data() as Map<String, dynamic>?;
                      String? remote = configData?['requiredVersion'];
                      String dbVersion = "...";
                      if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                        var data = dbInfoSnap.data!.data() as Map<String, dynamic>?;
                        dbVersion = (data?['dbVersion'] ?? DatabaseService.defaultDbVersion).toDouble().toStringAsFixed(1);
                      }
                      
                      bool isOutdated = false;
                      if (remote != null && remote != local) {
                        try {
                          List<String> localParts = local.split('+');
                          List<String> serverParts = remote.split('+');
                          int localMain = int.tryParse(localParts[0].replaceAll('.', '')) ?? 0;
                          int serverMain = int.tryParse(serverParts[0].replaceAll('.', '')) ?? 0;
                          if (serverMain > localMain) {
                            isOutdated = true;
                          } else if (serverMain == localMain && serverParts.length > 1 && localParts.length > 1) {
                            int localBuild = int.tryParse(localParts[1]) ?? 0;
                            int serverBuild = int.tryParse(serverParts[1]) ?? 0;
                            if (serverBuild > localBuild) isOutdated = true;
                          }
                        } catch (e) { isOutdated = remote != local; }
                      }
                      
                      return InkWell(
                        onTap: () {
                          if (isOutdated) {
                            String dUrl = configData?['downloadUrl'] ?? "";
                            showUpdateLogoutDialog(
                              context: context, 
                              remoteVersion: remote ?? "Unknown", 
                              downloadUrl: dUrl, 
                              onLogout: _handleLogout
                            );
                          } else {
                            _showLogoutConfirmationDialog();
                          }
                        },
                        child: AppVersionInfo(
                          version: local,
                          dbVersion: dbVersion,
                          latestVersion: remote,
                          isOutdated: isOutdated,
                          color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary,
                          secondaryColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary,
                          showLogoutIcon: true,
                        ),
                      );
                    }
                  );
                }
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
        List macAddresses = subData['macAddresses'] ?? [];
        List manualDues = subData['manualDues'] ?? [];
        
        List<Map<String, dynamic>> activeServices = [];
        for (var service in assignedServices) {
          String originalName = (service is Map) ? (service['name'] ?? '') : service.toString();
          if (originalName.isEmpty || excludedServices.contains(originalName)) continue;
          
          var matches = overriddenServices.where(
            (element) => element is Map && element['originalName'] == originalName,
          );
          var overrideMatch = matches.isEmpty ? null : matches.first;

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
        String currentMonthYearStr = DatabaseService.formatMonthYear(DateTime.now());
        List filteredManualDues = manualDues.where((m) => (m is Map && m['monthYear'] == currentMonthYearStr)).toList();
        double mDuesSum = filteredManualDues.fold(0.0, (acc, d) => acc + (d['amount'] as num).toDouble());

        // --- BILLING HISTORY FETCH (CONSOLIDATED) ---
        List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        DateTime nowTime = DateTime.now();
        DateTime prevMonth = DateTime(nowTime.year, nowTime.month - 1);
        String prevMonthYear = "${months[prevMonth.month - 1]}-${prevMonth.year.toString().substring(2)}";
        String currentMonthYear = "${months[nowTime.month - 1]}-${nowTime.year.toString().substring(2)}";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('billing_history')
              .where('subItemId', isEqualTo: widget.subItemId)
              .snapshots(),
          builder: (context, historySnapshot) {
            if (!historySnapshot.hasData) return const Center(child: CircularProgressIndicator());

            var historyDocs = historySnapshot.data!.docs;
            
            // Helper to parse Month-Year for sorting
            DateTime parseMY(String my) {
              List<String> parts = my.split('-');
              if (parts.length < 2) return DateTime(2000);
              int mIdx = months.indexWhere((m) => m.toLowerCase() == parts[0].trim().toLowerCase());
              int m = mIdx == -1 ? 1 : mIdx + 1;
              int y = 2000 + (int.tryParse(parts[1]) ?? 0);
              return DateTime(y, m);
            }

            String lastPaidMonth = "None";
            if (historyDocs.isNotEmpty) {
              var sortedPaid = historyDocs
                  .where((doc) => (doc.data() as Map)['status'] != 'Due')
                  .map((doc) => (doc.data() as Map)['monthYear'].toString()).toList();
              if (sortedPaid.isNotEmpty) {
                sortedPaid.sort((a, b) => parseMY(b).compareTo(parseMY(a)));
                lastPaidMonth = sortedPaid.first;
              }
            }

            List<String> paidMonths = historyDocs
                .where((doc) => (doc.data() as Map)['status'] == 'Paid')
                .map((doc) => doc['monthYear'].toString().trim().toLowerCase()).toList();
            
            List<String> dueMonthsFromHistory = historyDocs
                .where((doc) => (doc.data() as Map)['status'] == 'Due')
                .map((doc) => doc['monthYear'].toString().trim().toLowerCase()).toList();

            bool isPrevPaid = paidMonths.contains(prevMonthYear.toLowerCase());
            
            List<String> pendingMonths = []; 
            // Add all Due months from history
            List<String> rawHistoryDueMonths = historyDocs
                .where((doc) => (doc.data() as Map)['status'] == 'Due')
                .map((doc) => doc['monthYear'].toString())
                .toList();
            
            pendingMonths.addAll(rawHistoryDueMonths);
            
            // Sort pending months chronologically
            pendingMonths.sort((a, b) => parseMY(a).compareTo(parseMY(b)));

            // Total Outstanding: Sum of recorded Dues + Current Estimated Month + Missing Months (Arrears)
            double totalOutstanding = 0;
            Set<String> processedMonths = {};
            
            // 1. Sum recorded dues
            for (var doc in historyDocs) {
              var data = doc.data() as Map;
              String my = data['monthYear'].toString().trim().toLowerCase();
              if (data['status'] == 'Due') {
                totalOutstanding += (data['totalAmount'] as num).toDouble();
              }
              processedMonths.add(my);
            }

            // 2. Add current month if it's not already paid/recorded
            if (!processedMonths.contains(currentMonthYear.toLowerCase())) {
               double currentMonthEstimate = servicesSum + electricityBill + mDuesSum;
               totalOutstanding += currentMonthEstimate;
               processedMonths.add(currentMonthYear.toLowerCase());
            }

            // 3. Add missing months (Arrears)
            Timestamp? occupiedAt = subData['occupiedAt'] as Timestamp?;
            if (occupiedAt != null) {
              DateTime current = DateTime(occupiedAt.toDate().year, occupiedAt.toDate().month);
              DateTime limit = DateTime(nowTime.year, nowTime.month);
              while (current.isBefore(limit)) {
                String mYear = "${months[current.month - 1]}-${current.year.toString().substring(2)}";
                if (!processedMonths.contains(mYear.toLowerCase())) {
                   totalOutstanding += servicesSum;
                   if (!pendingMonths.contains(mYear)) pendingMonths.add(mYear);
                }
                current = DateTime(current.year, current.month + 1);
              }
            }
            
            pendingMonths.sort((a, b) => parseMY(a).compareTo(parseMY(b)));

            void showUnpaidDetails(String month) {
              try {
                String targetMonth = month.trim().toLowerCase();
                
                // Helper to parse Month-Year safely
                DateTime? tryParseMY(String my) {
                  try {
                    List<String> parts = my.split('-');
                    if (parts.length < 2) return null;
                    int m = months.indexOf(parts[0]) + 1;
                    if (m < 1) return null;
                    int y = 2000 + (int.tryParse(parts[1]) ?? 0);
                    return DateTime(y, m);
                  } catch (e) {
                    return null;
                  }
                }

                DateTime? targetDateTime = tryParseMY(month);

                // Try to find a recorded Due doc
                var matchingDocs = historyDocs.where(
                  (doc) {
                    var data = doc.data() as Map;
                    String mYear = (data['monthYear'] ?? '').toString().trim().toLowerCase();
                    if (mYear == targetMonth && data['status'] == 'Due') return true;
                    
                    if (targetDateTime != null) {
                      DateTime? docDateTime = tryParseMY(mYear);
                      return docDateTime != null && docDateTime.isAtSameMomentAs(targetDateTime) && data['status'] == 'Due';
                    }
                    return false;
                  },
                );

                var recordedDoc = matchingDocs.isNotEmpty ? matchingDocs.first : null;

                if (recordedDoc != null) {
                  UserReportPage.showDetailsDialog(context, {
                    ...recordedDoc.data() as Map<String, dynamic>,
                    'docId': recordedDoc.id,
                  });
                }
              } catch (e, stack) {
                debugPrint("ERROR in showUnpaidDetails: $e\n$stack");
                DatabaseService.showToast(context, "Error: $e", backgroundColor: Colors.red);
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- MODERN HEADER CARD (Updated Layout) ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : null,
                      gradient: ThemeManager.appThemeNotifier.value == "Outline Theme" ? null : LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                      boxShadow: ThemeManager.appThemeNotifier.value == "Outline Theme" ? null : [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: subData['profilePictureUrl'] != null ? () => _showFullScreenImage(context, subData['profilePictureUrl'], "Profile Picture") : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              backgroundImage: subData['profilePictureUrl'] != null ? NetworkImage(subData['profilePictureUrl']) : null,
                              child: subData['profilePictureUrl'] == null ? Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)) : null,
                            ),
                          ),
                        ),
                        // Line 1: Category Name
                        Text(
                          _categoryName.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7), letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        // Line 2: Unit Name (Tenant Name)
                        Text(
                          TenantName.isNotEmpty ? "$subName ($TenantName)" : subName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900),
                        ),
                        // Line 3: NID Number
                        if (nidNumber.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "NID: $nidNumber",
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                              ),
                              if (subData['nidPictureUrl'] != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showFullScreenImage(context, subData['nidPictureUrl'], "NID Picture"),
                                  child: Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 16),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // --- OUTSTANDING BILL SECTION ---
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                      boxShadow: ThemeManager.appThemeNotifier.value == "Outline Theme" ? null : [
                        BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          if (pendingMonths.isNotEmpty) {
                            showUnpaidDetails(pendingMonths.first);
                          } else {
                            showUnpaidDetails(currentMonthYear);
                          }
                        },
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(pendingMonths.isEmpty ? Icons.check_circle : Icons.pending_actions, color: pendingMonths.isEmpty ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error, size: 20),
                                const SizedBox(width: 8),
                                Text(pendingMonths.isEmpty ? "MONTHLY BILL (PAID)" : "CURRENT OUTSTANDING", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "৳${totalOutstanding.toStringAsFixed(2)}",
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: pendingMonths.isEmpty ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text("Last Paid: $lastPaidMonth", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                            if (pendingMonths.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  Text("Due: ", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                                  ...pendingMonths.asMap().entries.map((entry) {
                                    int idx = entry.key;
                                    String m = entry.value;
                                    return InkWell(
                                      onTap: () => showUnpaidDetails(m),
                                      child: Text(
                                        "$m${idx < pendingMonths.length - 1 ? ", " : ""}",
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.error,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // (REMOVED OLD PENDING MONTHS SECTION FROM HERE)

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
                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(notes, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null))),
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
                  elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: ThemeManager.appThemeNotifier.value == "Outline Theme" ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
                  ),
                  child: ExpansionTile(
                    backgroundColor: ThemeManager.outlineBackground,
                    collapsedBackgroundColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : null,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                    dense: true,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    iconColor: context.electric,
                    collapsedIconColor: context.electric,
                    leading: CircleAvatar(
                      backgroundColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : context.electric.withValues(alpha: 0.1),
                      child: Container(
                        decoration: ThemeManager.appThemeNotifier.value == "Outline Theme" ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)) : null,
                        child: Icon(Icons.electric_bolt, color: context.electric, size: 20)
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Electricity Bill", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                        Text("৳${electricityBill.toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                    subtitle: Text("Usage: ${((ed['presentReading'] ?? 0) as num) - ((ed['lastReading'] ?? 0) as num)} units", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
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
                String name = s['name'] ?? 'Unnamed';
                bool isWifi = name.toLowerCase().contains("wifi");
                bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
                return GestureDetector(
                  onTap: (isWifi && macAddresses.isNotEmpty) ? () => CategoryDialogs.showUserMacDetailsDialog(
                    context: context, 
                    subItemName: subName, 
                    macAddresses: macAddresses, 
                    wifiService: s
                  ) : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                      boxShadow: isOutline ? [] : [
                        BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: isWifi && macAddresses.isNotEmpty
                      ? Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            childrenPadding: const EdgeInsets.only(left: 56, bottom: 8),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            iconColor: Theme.of(context).colorScheme.primary,
                            collapsedIconColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        child: Container(
                                          decoration: isOutline ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)) : null,
                                          child: Icon(Icons.wifi, color: Theme.of(context).colorScheme.primary, size: 16)
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "$name (৳${s['wifiCost'] ?? 0} / device) (x${s['deviceQuantity'] ?? 1})",
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text("৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              ],
                            ),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "MAC Addresses:\n${macAddresses.asMap().entries.map((e) {
                                    var val = e.value;
                                    String sn = (val is Map && val['sn'] != null && val['sn'].toString().isNotEmpty) ? val['sn'].toString() : (e.key + 1).toString();
                                    String mac = val is Map ? val['mac'] : val.toString();
                                    return "$sn) $mac";
                                  }).join('\n')}", 
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary, fontFamily: 'monospace', fontSize: 9)
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          title: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isOutline ? ThemeManager.outlineBackground : (isWifi ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary).withValues(alpha: 0.1),
                                child: Container(
                                  decoration: isOutline ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)) : null,
                                  child: Icon(isWifi ? Icons.wifi : Icons.check_circle_outline, color: isWifi ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary, size: 16)
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isWifi 
                                      ? "$name (৳${s['wifiCost'] ?? 0} / device) (x${s['deviceQuantity'] ?? 1})" 
                                      : name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null),
                                ),
                              ),
                            ],
                          ),
                        trailing: Text("৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      ),
                  ),
                );
              }),

              if (manualDues.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("ADJUST DUES/ADVANCES", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                ...manualDues.map((d) {
                  double amt = (d['amount'] as num).toDouble();
                  bool isAdv = amt < 0;
                  bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
                  Color itemColor = isAdv ? Colors.green : Theme.of(context).colorScheme.error;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutline ? ThemeManager.outlineBackground : itemColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: itemColor.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: itemColor.withValues(alpha: 0.1),
                        child: Icon(isAdv ? Icons.account_balance_wallet_outlined : Icons.money_off, color: itemColor, size: 20),
                      ),
                      title: Text(
                        "${d['reason']}${isAdv ? ' (Adv)' : ''}",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null),
                      ),
                      subtitle: Text("Added: ${d['date']?.toString().split('T')[0] ?? ''}", style: Theme.of(context).textTheme.bodySmall),
                      trailing: Text("৳${amt.abs().toStringAsFixed(2)}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: itemColor)),
                    ),
                  );
                }),
              ],

              if (activeServices.isEmpty && (ed == null || isElectricStopped) && manualDues.isEmpty)
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
