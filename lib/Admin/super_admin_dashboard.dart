import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Admin/settings_page.dart';
import 'package:akonssquare/main.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("System Recovery", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
            Text("Master Access Mode", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => _handleLogout(context),
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
                              Text(local, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 9)),
                              if (remote != null && remote != local)
                                Text("Latest: $remote", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 8)),
                              Icon(Icons.power_settings_new, color: Theme.of(context).colorScheme.error, size: 18),
                              Text("DB V-$dbVersion", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 9)),
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
      body: const SettingsPage(),
    );
  }
}
