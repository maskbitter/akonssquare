import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/category_page.dart';
import 'package:akonssquare/Admin/admin_home.dart';
import 'package:akonssquare/Admin/settings_page.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
import 'package:akonssquare/Common/automation_guide.dart';
import 'package:akonssquare/Common/build_config.dart';
import 'package:akonssquare/main.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:akonssquare/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';

class OperatorDashboard extends StatefulWidget {
  final String username;
  const OperatorDashboard({super.key, required this.username});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  int _currentIndex = 0;
  int _categoryInitialSubTab = 0;
  String _appName = "";
  StreamSubscription? _userSessionSubscription;
  StreamSubscription? _dbVersionSubscription;
  final PageController _pageController = PageController();
  double? _lastDBVersion;

  @override
  void initState() {
    super.initState();
    _loadAppName();
    _startSessionListener();
    _startDBVersionListener();
  }

  Future<void> _loadAppName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appName = packageInfo.appName;
      });
    }
  }

  @override
  void dispose() {
    _userSessionSubscription?.cancel();
    _dbVersionSubscription?.cancel();
    super.dispose();
  }

  void _startDBVersionListener() {
    _dbVersionSubscription = DatabaseService().getDatabaseInfoStream().listen((snap) {
      if (snap.exists) {
        double currentVer = snap['dbVersion']?.toDouble() ?? 1.0;
        if (_lastDBVersion != null && currentVer != _lastDBVersion) {
          DatabaseService.showToast(context, "System Data Updated (V$currentVer)");
          setState(() {}); 
        }
        _lastDBVersion = currentVer;
      }
    });
  }

  void _startSessionListener() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentPassword = prefs.getString('savedPassword');

    // Listen to the specific user document
    _userSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: widget.username)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        _handleLogout();
      } else {
        var userData = snapshot.docs.first.data();
        if (userData['password'] != currentPassword) {
          _handleLogout();
        }
      }
    });
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
    String? userDocId = prefs.getString('userDocId');
    if (userDocId != null) {
      await DatabaseService().updateUserSession('users', userDocId, null);
    }
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = ["Home", "Manage", "Settings"];

    return Scaffold(
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
                      titles[_currentIndex],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                    Text(
                      " | ", 
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                    Text(
                      "Operator",
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
                stream: DatabaseService().getAppConfigStream(),
                builder: (context, configSnap) {
                  return StreamBuilder<DocumentSnapshot>(
                    stream: DatabaseService().getDatabaseInfoStream(),
                    builder: (context, dbInfoSnap) {
                      return FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, pSnap) {
                          String local = pSnap.hasData ? "${pSnap.data!.version}+${pSnap.data!.buildNumber}" : "...";
                          String? remote = configSnap.data?.exists == true ? configSnap.data!['requiredVersion'] : null;
                          String dbVersion = "...";
                          String bnText = "BN-$buildNumber";
                          if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                            dbVersion = (dbInfoSnap.data!['dbVersion'] ?? 26.0).toStringAsFixed(1);
                            int firestoreBN = dbInfoSnap.data!['buildNumber']?.toInt() ?? 0;
                            if (firestoreBN > buildNumber) bnText = "BN-$firestoreBN";
                          }
                          
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(local, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, fontWeight: FontWeight.bold)),
                              if (remote != null && remote != local)
                                Text("Latest: $remote", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontSize: 8)),
                              Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 18),
                              Text("DB V-$dbVersion/$bnText", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
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
        body: UpdateGuard(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              // 1. Home Tab (Same as Admin Home)
              AdminHome(
                onCategoryTap: (index) {
                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  setState(() {
                    _categoryInitialSubTab = index; // index 0 for Occupied, 1 for Vacant
                  });
                },
                onElectricityTap: () {
                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  setState(() {
                    _categoryInitialSubTab = 2; // Main Meters
                  });
                },
              ),
              // 2. Manage Tab (Same as Category Manager, with restrictions)
              CategoryPage(
                key: ValueKey(_categoryInitialSubTab),
                initialSubTabIndex: _categoryInitialSubTab,
                isOperator: true,
              ),
              const SettingsPage(showOnlyTheme: true),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 1) {
              setState(() {
                _categoryInitialSubTab = 0; // Default to Occupied
              });
            }
            _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_outlined), activeIcon: Icon(Icons.manage_accounts), label: "Manage"),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: "Settings"),
          ],
        ),
      );
  }
}
