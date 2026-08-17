import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akons_square/Admin/settings_page.dart';
import 'package:akons_square/main.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:akons_square/Common/build_config.dart';
import 'package:akons_square/Common/update_guard.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/ui_helper.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final DatabaseService _dbService = DatabaseService();
  String _appName = "";

  @override
  void initState() {
    super.initState();
    _loadAppName();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRollback());
  }

  Future<void> _loadAppName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appName = packageInfo.appName;
      });
    }
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
        content: const Text("A previous database operation was interrupted. Rollback to safe state?"),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _dbService.clearRollbackSnapshot();
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
                onPressed: () {
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

    _dbService.restoreFromRollback("SuperAdmin", onProgress: (p) {
      progressNotifier.value = p;
    }).then((_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DatabaseService.showToast(context, "Rollback Successful!");
    }).catchError((e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DatabaseService.showToast(context, "Rollback Failed: $e", backgroundColor: Colors.red);
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primary,
        foregroundColor: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
        elevation: isOutline ? 0 : 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appName.isEmpty ? "Loading..." : _appName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "System",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary),
                ),
                Text(
                  " | ", 
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black.withValues(alpha: 0.5) : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                ),
                Text(
                  "Super Admin(Master Access Mode)",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, 
                  ),
                ),
              ],
            ),
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
                        color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
                        secondaryColor: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
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
      body: Column(
        children: [
          _buildPermissionManagerSection(),
          const Divider(height: 1),
          const Expanded(child: SettingsPage()),
        ],
      ),
    );
  }

  Widget _buildPermissionManagerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text("Admin Permission Control", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              var admins = snapshot.data!.docs;
              if (admins.isEmpty) return const Text("No Admin accounts found.");

              return SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: admins.length,
                  itemBuilder: (context, index) {
                    var data = admins[index].data() as Map<String, dynamic>;
                    String username = data['username'] ?? 'Admin';
                    Map<String, dynamic> perms = data['permissions'] ?? {
                      'canSeeSecurityLogs': false,
                      'canControlVisibility': false,
                      'canManageData': false,
                      'canManageAccounts': false,
                    };

                    return Card(
                      margin: const EdgeInsets.only(right: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 12, child: Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 10))),
                                const SizedBox(width: 8),
                                Expanded(child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const Divider(),
                            Expanded(
                              child: GridView.count(
                                crossAxisCount: 2,
                                childAspectRatio: 4,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                children: [
                                  _buildPermToggle(admins[index].id, "Logs", perms['canSeeSecurityLogs'] ?? false, 'canSeeSecurityLogs', perms),
                                  _buildPermToggle(admins[index].id, "Visibility", perms['canControlVisibility'] ?? false, 'canControlVisibility', perms),
                                  _buildPermToggle(admins[index].id, "Data", perms['canManageData'] ?? false, 'canManageData', perms),
                                  _buildPermToggle(admins[index].id, "Accounts", perms['canManageAccounts'] ?? false, 'canManageAccounts', perms),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermToggle(String docId, String label, bool value, String key, Map<String, dynamic> currentPerms) {
    return InkWell(
      onTap: () async {
        Map<String, bool> newPerms = Map<String, bool>.from(currentPerms.map((k, v) => MapEntry(k, v as bool)));
        newPerms[key] = !value;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await _dbService.updateUserPermissions(docId, newPerms, prefs.getString('username') ?? 'SuperAdmin');
        DatabaseService.vibrate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: value ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(value ? Icons.check_circle : Icons.circle_outlined, size: 12, color: value ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: value ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
