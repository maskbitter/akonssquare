import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/admin_home.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
import 'package:akonssquare/Common/automation_guide.dart';
import 'package:akonssquare/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewerDashboard extends StatefulWidget {
  const ViewerDashboard({super.key});

  @override
  State<ViewerDashboard> createState() => _ViewerDashboardState();
}

class _ViewerDashboardState extends State<ViewerDashboard> {
  String _appName = "";
  String _username = "Viewer";

  @override
  void initState() {
    super.initState();
    _fetchAppData();
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userDocId = prefs.getString('userDocId');
    if (userDocId != null) {
      await DatabaseService().updateUserSession('users', userDocId, null);
    }
    await prefs.clear();
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
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error, 
                            side: BorderSide(color: Theme.of(context).colorScheme.error)
                          ),
                          onPressed: () => Navigator.pop(ctx), 
                          child: const Text("Cancel")
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
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
                    return FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, pSnap) {
                        String local = pSnap.hasData ? "${pSnap.data!.version}+${pSnap.data!.buildNumber}" : "...";
                        String? remote = configSnap.data?.exists == true ? configSnap.data!['requiredVersion'] : null;
                        String dbVersion = "...";
                        if (dbInfoSnap.hasData && dbInfoSnap.data!.exists) {
                          dbVersion = (dbInfoSnap.data!['dbVersion'] ?? 26.0).toStringAsFixed(1);
                        }
                        
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(local, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, fontWeight: FontWeight.bold)),
                            if (remote != null && remote != local)
                              Text("Latest: $remote", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontSize: 8)),
                            Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 18),
                            Text("DB V-$dbVersion", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
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
      body: const UpdateGuard(child: AdminHome(isReadOnly: true)),
    );
  }
}
