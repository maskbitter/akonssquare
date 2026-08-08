import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/category_page.dart';
import 'package:akonssquare/Admin/admin_home.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
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
  StreamSubscription? _userSessionSubscription;
  StreamSubscription? _dbVersionSubscription;
  final PageController _pageController = PageController();
  double? _lastDBVersion;

  @override
  void initState() {
    super.initState();
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
    _dbVersionSubscription = DatabaseService().getDatabaseInfoStream().listen((snap) {
      if (snap.exists) {
        double currentVer = snap['dbVersion']?.toDouble() ?? 1.0;
        if (_lastDBVersion != null && currentVer != _lastDBVersion) {
          DatabaseService.showToast(context, "System Data Updated (V$currentVer)", backgroundColor: Colors.teal);
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
          title: const Center(child: Text("Logout Confirmation", style: TextStyle(fontWeight: FontWeight.bold))),
          content: const Text("Are you sure you want to logout?", textAlign: TextAlign.center),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  onPressed: () => Navigator.pop(context), child: const Text("Cancel"))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    final List<String> titles = ["Home", "Manage"];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Operator Panel",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                Text(
                  titles[_currentIndex],
                  style: const TextStyle(fontSize: 11, color: Colors.teal),
                ),
                const Text(" | ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  widget.username.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: _showLogoutConfirmationDialog,
            child: StreamBuilder<DocumentSnapshot>(
              stream: DatabaseService().getAppConfigStream(),
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
                        Text(local, style: TextStyle(fontSize: 8, color: Colors.blueGrey.shade600, fontWeight: FontWeight.bold)),
                        if (remote != null && remote != local)
                          Text(remote, style: const TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: "Manage"),
        ],
      ),
    );
  }
}
