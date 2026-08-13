import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/admin_home.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
import 'package:akonssquare/Common/automation_guide.dart';
import 'package:akonssquare/Common/build_config.dart';
import 'package:akonssquare/Common/ui_helper.dart';
import 'package:akonssquare/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ViewerDashboard extends StatefulWidget {
  const ViewerDashboard({super.key});

  @override
  State<ViewerDashboard> createState() => _ViewerDashboardState();
}

class _ViewerDashboardState extends State<ViewerDashboard> {
  String _appName = "";
  String _username = "Viewer";
  StreamSubscription? _userSessionSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAppData();
    _startSessionListener();
  }

  @override
  void dispose() {
    _userSessionSubscription?.cancel();
    super.dispose();
  }

  void _startSessionListener() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userDocId = prefs.getString('userDocId');
    String? currentSessionId = prefs.getString('sessionId');

    if (userDocId == null || userDocId.isEmpty) return;

    _userSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        // User deleted or DB wiped
        _handleLogout();
      } else {
      }
    }, onError: (e) {
      _handleLogout();
    });
  }

  Future<void> _fetchAppData() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _appName = packageInfo.appName;
      _username = prefs.getString('username') ?? "Viewer";
    });
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      "Home",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                    Text(
                      " | ", 
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                    Text(
                      "Viewer",
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
            onTap: () {
               showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Center(child: Text("Logout", style: Theme.of(context).textTheme.titleLarge)),
                  content: Text("Are you sure you want to logout from viewer mode?", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
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
                          onPressed: () => Navigator.pop(ctx), 
                          child: const Text("Cancel")
                        ),
                        AppButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error, 
                            foregroundColor: Theme.of(context).colorScheme.onPrimary
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleLogout();
                          },
                          child: const Text("Logout"),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            child: StreamBuilder<DocumentSnapshot>(
              stream: DatabaseService().getAppConfigStream(),
              builder: (context, configSnap) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: DatabaseService().getDatabaseInfoStream(),
                    builder: (context, dbInfoSnap) {
                      String local = appVersion; // Instant update from build_config.dart
                      String? remote = configSnap.data?.exists == true ? configSnap.data!['requiredVersion'] : null;
                      String dbVersion = "...";
                      if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                        var data = dbInfoSnap.data!.data() as Map<String, dynamic>?;
                        dbVersion = (data?['dbVersion'] ?? 26.0).toDouble().toStringAsFixed(1);
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
                      );
                    }
                );
              }
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: const UpdateGuard(child: AdminHome(isReadOnly: true)),
    );
  }
}
