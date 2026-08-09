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

  @override
  void initState() {
    super.initState();
    _fetchAppName();
  }

  Future<void> _fetchAppName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appName = packageInfo.appName;
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
        title: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AutomationGuidePage()));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_appName, style: Theme.of(context).textTheme.titleMedium),
              Text("Viewer Mode", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ],
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
      body: const UpdateGuard(child: AdminHome(isReadOnly: true)),
    );
  }
}
