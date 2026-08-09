import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart'; 

import 'package:akonssquare/main.dart';
import 'package:akonssquare/Admin/category_page.dart';
import 'package:akonssquare/Admin/admin_home.dart';
import 'package:akonssquare/Admin/settings_page.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
import 'package:akonssquare/Common/automation_guide.dart';
import 'dart:async';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final DatabaseService _dbService = DatabaseService();
  int _currentIndex = 0; 
  int _categoryInitialSubTab = 0; 
  String _username = "User";
  String _appName = ""; 
  StreamSubscription? _userSessionSubscription;
  StreamSubscription? _dbVersionSubscription;
  final PageController _pageController = PageController();
  double? _lastDBVersion;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndAppName();
    _startSessionListener();
    _startDBVersionListener();
  }

  @override
  void dispose() {
    _userSessionSubscription?.cancel();
    _dbVersionSubscription?.cancel();
    super.dispose();
  }

  void _startDBVersionListener() {
    _dbVersionSubscription = _dbService.getDatabaseInfoStream().listen((snap) {
      if (snap.exists) {
        double currentVer = snap['dbVersion']?.toDouble() ?? 1.0;
        if (_lastDBVersion != null && currentVer != _lastDBVersion) {
          // Version changed (Restore happened)
          DatabaseService.showToast(context, "System Data Updated (V$currentVer)");
          setState(() {}); // Trigger rebuild
        }
        _lastDBVersion = currentVer;
      }
    });
  }

  void _startSessionListener() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? currentUsername = prefs.getString('username');
    String? currentPassword = prefs.getString('savedPassword');

    if (currentUsername == null) return;

    // Listen to the specific user document
    _userSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: currentUsername)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        // User deleted
        _handleLogout();
      } else {
        var userData = snapshot.docs.first.data();
        if (userData['password'] != currentPassword) {
          // Password changed
          _handleLogout();
        }
      }
    });
  }

  Future<void> _loadUserDataAndAppName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String savedUsername = prefs.getString('username') ?? "User";

    setState(() {
      _appName = packageInfo.appName;
      _username = savedUsername;
    });

    String todayStr = DateTime.now().toIso8601String().split('T')[0];
    String? lastShownDate = prefs.getString('last_welcome_date');

    if (lastShownDate != todayStr) {
      await prefs.setString('last_welcome_date', todayStr);
      if (mounted) {
        DatabaseService.showToast(context, "${_username.toUpperCase()} logged in successfully!");
      }
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
                    child: const Text("Cancel"),
                  ),
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
    final List<String> titles = ["Home", "Category Manager", "Settings"];
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
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
                        titles[_currentIndex],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                      Text(
                        " | ", 
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                      Text(
                        _username.toUpperCase(),
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
        body: UpdateGuard(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              AdminHome(
                onCategoryTap: (index) {
                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  setState(() {
                    _categoryInitialSubTab = index;
                  });
                },
                onElectricityTap: () {
                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  setState(() {
                    _categoryInitialSubTab = 2;
                  });
                },
              ),
              CategoryPage(
                key: ValueKey(_categoryInitialSubTab),
                initialSubTabIndex: _categoryInitialSubTab
              ),
              const SettingsPage(),
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
            BottomNavigationBarItem(icon: Icon(Icons.category_outlined), activeIcon: Icon(Icons.category), label: "Category"),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: "Settings"),
          ],
        ),
      ),
    );
  }
}
