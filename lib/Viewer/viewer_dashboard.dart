import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/admin_home.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/update_guard.dart';
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
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text("Viewer Mode", style: TextStyle(fontSize: 11, color: Colors.blue)),
          ],
        ),
        actions: [
          InkWell(
            onTap: () {
               showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Center(child: Text("Logout", style: TextStyle(fontWeight: FontWeight.bold))),
                  content: const Text("Are you sure you want to logout from viewer mode?", textAlign: TextAlign.center),
                  actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  actions: [
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                          onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
      body: const UpdateGuard(child: AdminHome(isReadOnly: true)),
    );
  }
}
