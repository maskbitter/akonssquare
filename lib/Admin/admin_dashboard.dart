import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart'; 

import 'package:akons_square/main.dart';
import 'package:akons_square/Admin/category_page.dart';
import 'package:akons_square/Admin/admin_home.dart';
import 'package:akons_square/Admin/settings_page.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/update_guard.dart';
import 'package:akons_square/Common/automation_guide.dart';
import 'package:akons_square/Common/build_config.dart';
import 'package:akons_square/Common/ui_helper.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRollback());
  }

  Future<void> _checkRollback() async {
    bool hasSnapshot = await _dbService.hasRollbackSnapshot();
    if (!hasSnapshot) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Interrupted Job"),
          ],
        ),
        content: const Text("A previous database operation (Restore/Delete) was interrupted or failed. Would you like to rollback to the safe state or ignore?"),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _dbService.clearRollbackSnapshot();
                  DatabaseService.showToast(context, "Snapshot cleared.");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Ignore"),
              ),
              AppButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  _showRollbackProgressDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Rollback Now"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRollbackProgressDialog() {
    final progressNotifier = ValueNotifier<double>(0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Rolling Back...", textAlign: TextAlign.center),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 10),
                Text("${(value * 100).toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
      ),
    );

    _dbService.restoreFromRollback(_username, onProgress: (p) {
      progressNotifier.value = p;
    }).then((_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DatabaseService.showToast(context, "Rollback Successful!");
    }).catchError((e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DatabaseService.showToast(context, "Rollback Failed: $e", backgroundColor: Colors.red);
    });
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
    String? currentSessionId = prefs.getString('sessionId');

    if (currentUsername == null) return;

    // Listen to the specific user document
    _userSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: currentUsername)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        // User deleted or DB wiped
        _handleLogout();
      } else {
        var userData = snapshot.docs.first.data() as Map<String, dynamic>;
        if (userData['password'] != currentPassword) {
          // Password changed
          _handleLogout();
        }
      }
    }, onError: (e) {
       _handleLogout();
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
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error, 
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
      String? userDocId = prefs.getString('userDocId');
      if (userDocId != null) {
        DatabaseService().updateUserSession('users', userDocId, null).catchError((e) => null);
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

  @override
  Widget build(BuildContext context) {
    final List<String> titles = ["Home", "Manage", "Settings"];
    
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
                        "Admin",
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
                      
                      return AppVersionInfo(
                        version: local,
                        dbVersion: dbVersion,
                        latestVersion: remote,
                        isOutdated: isOutdated,
                        color: Theme.of(context).colorScheme.primary,
                        secondaryColor: Theme.of(context).colorScheme.secondary,
                        showLogoutIcon: true,
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
            BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_outlined), activeIcon: Icon(Icons.manage_accounts), label: "Manage"),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: "Settings"),
          ],
        ),
      ),
    );
  }
}
