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
import 'package:akons_square/Common/share_helper.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  String _appName = "";
  late TabController _tabController;
  final Set<String> _selectedLogIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 1 && _selectedLogIds.isNotEmpty) {
        setState(() => _selectedLogIds.clear());
      }
    });
    _loadAppName();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRollback());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? ThemeManager.outlineBackground 
                    : Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? Border.all(color: Colors.orange, width: 1.5) 
                    : null,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
            ),
            const SizedBox(height: 16),
            const Text("Interrupted Job", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("A previous database operation was interrupted. Rollback to safe state?", textAlign: TextAlign.center),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? ThemeManager.outlineBackground 
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                    : null,
              ),
              child: Icon(Icons.history_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text("Rolling Back...", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LinearProgressIndicator(
                  value: value,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 10,
                ),
                const SizedBox(height: 10),
                Text("${(value * 100).toStringAsFixed(1)}% Complete", style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? ThemeManager.outlineBackground 
                      : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.5) 
                      : null,
                ),
                child: Icon(Icons.logout, color: Theme.of(context).colorScheme.error, size: 40),
              ),
              const SizedBox(height: 16),
              Text("Logout Confirmation", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
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
                    _handleLogout(context);
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
    bool isSelectionMode = _selectedLogIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: isSelectionMode 
            ? (isOutline ? Colors.black : Theme.of(context).colorScheme.surfaceContainerHighest)
            : (isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primary),
        foregroundColor: isSelectionMode
            ? (isOutline ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant)
            : (isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary),
        elevation: isOutline ? 0 : 2,
        leading: isSelectionMode ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selectedLogIds.clear()),
        ) : null,
        title: isSelectionMode ? Text("${_selectedLogIds.length} selected") : Column(
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isOutline ? (isSelectionMode ? Colors.white : Colors.black) : Colors.white,
          labelColor: isOutline ? (isSelectionMode ? Colors.white : Colors.black) : Colors.white,
          unselectedLabelColor: isOutline ? (isSelectionMode ? Colors.white70 : Colors.black54) : Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.admin_panel_settings), text: "Permissions"),
            Tab(icon: Icon(Icons.history), text: "Activity Log"),
            Tab(icon: Icon(Icons.settings), text: "Settings"),
          ],
        ),
        actions: isSelectionMode ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showBatchDeleteConfirm,
            tooltip: "Delete Selected",
          ),
          const SizedBox(width: 8),
        ] : [
          IconButton(
            icon: Icon(Icons.share_outlined, color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary),
            onPressed: () => ShareHelper.shareApp(context),
            tooltip: "Share App",
          ),
          StreamBuilder<DocumentSnapshot>(
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
                  
                  return InkWell(
                    onTap: () {
                      if (isOutdated) {
                        String dUrl = configData?['downloadUrl'] ?? "";
                        showUpdateLogoutDialog(
                          context: context, 
                          remoteVersion: remote ?? "Unknown", 
                          downloadUrl: dUrl, 
                          onLogout: () => _handleLogout(context)
                        );
                      } else {
                        _showLogoutConfirmationDialog();
                      }
                    },
                    child: AppVersionInfo(
                      version: local,
                      dbVersion: dbVersion,
                      latestVersion: remote,
                      isOutdated: isOutdated,
                      color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
                      secondaryColor: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary,
                      showLogoutIcon: true,
                    ),
                  );
                }
              );
            }
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(child: _buildPermissionManagerSection()),
          _buildActivityLogSection(),
          const SettingsPage(),
        ],
      ),
    );
  }

  Widget _buildActivityLogSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getActivityLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        
        var logs = snapshot.data?.docs ?? [];
        if (logs.isEmpty) return const Center(child: Text("No activity logs found."));

        return ListView.builder(
          itemCount: logs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            var doc = logs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildLogTile(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildLogTile(String logId, Map<String, dynamic> data) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    bool isSelected = _selectedLogIds.contains(logId);
    bool isSelectionMode = _selectedLogIds.isNotEmpty;
    
    String actor = data['actor'] ?? 'System';
    String action = data['action'] ?? 'Unknown';
    String details = data['details'] ?? 'No details provided';
    String category = data['category'] ?? 'General';
    Timestamp? ts = data['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isOutline ? 0 : (isSelected ? 4 : 2),
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : (isOutline ? const BorderSide(color: Colors.black, width: 1.5) : BorderSide.none),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () {
          DatabaseService.vibrate();
          setState(() {
            if (isSelected) {
              _selectedLogIds.remove(logId);
            } else {
              _selectedLogIds.add(logId);
            }
          });
        },
        onTap: () {
          if (isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedLogIds.remove(logId);
              } else {
                _selectedLogIds.add(logId);
              }
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (isSelectionMode) ...[
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedLogIds.add(logId);
                              else _selectedLogIds.remove(logId);
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                      ],
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(actor.isNotEmpty ? actor[0].toUpperCase() : 'S', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      ),
                      const SizedBox(width: 8),
                      Text(actor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Text(
                    DatabaseService.formatFullDateTime(ts),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                    child: Text(category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                ],
              ),
              const SizedBox(height: 4),
              Text(details, style: Theme.of(context).textTheme.bodySmall),
              if (!isSelectionMode) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditLogDialog(logId, data),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("Edit", style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showDeleteLogConfirm(logId),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text("Delete", style: TextStyle(fontSize: 12, color: Colors.red)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBatchDeleteConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever, color: Colors.red, size: 40),
            ),
            const SizedBox(height: 16),
            const Text("Bulk Delete", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("Are you sure you want to permanently delete ${_selectedLogIds.length} selected activity records?", textAlign: TextAlign.center),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Cancel"),
              ),
              AppButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  String actor = prefs.getString('username') ?? 'SuperAdmin';
                  List<String> idsToDelete = _selectedLogIds.toList();
                  setState(() => _selectedLogIds.clear());
                  await _dbService.deleteActivityLogsBatch(idsToDelete, actor);
                  if (mounted) DatabaseService.showToast(context, "${idsToDelete.length} logs deleted");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Delete All"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditLogDialog(String logId, Map<String, dynamic> data) {
    final actionCtrl = TextEditingController(text: data['action']);
    final detailsCtrl = TextEditingController(text: data['details']);
    final categoryCtrl = TextEditingController(text: data['category']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Activity Log"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: actionCtrl, decoration: const InputDecoration(labelText: "Action")),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: "Category")),
              TextField(controller: detailsCtrl, decoration: const InputDecoration(labelText: "Details"), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _dbService.updateActivityLog(logId, {
                'action': actionCtrl.text,
                'details': detailsCtrl.text,
                'category': categoryCtrl.text,
              });
              Navigator.pop(ctx);
              DatabaseService.showToast(context, "Log updated");
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showDeleteLogConfirm(String logId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Log?"),
        content: const Text("Are you sure you want to permanently delete this activity record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _dbService.deleteActivityLog(logId);
              Navigator.pop(ctx);
              DatabaseService.showToast(context, "Log deleted");
            },
            child: const Text("Delete"),
          ),
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
          const SizedBox(height: 8),
          Text(
            "Manage access levels for administrative accounts. Click an account to expand permissions.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              var admins = snapshot.data!.docs;
              if (admins.isEmpty) return const Text("No Admin accounts found.");

              return Column(
                children: admins.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String username = data['username'] ?? 'Admin';
                  Map<String, dynamic> perms = data['permissions'] ?? {
                    'canSeeSecurityLogs': false,
                    'canControlVisibility': false,
                    'canManageData': false,
                    'canManageAccounts': false,
                  };

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(username[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Account Permissions", style: Theme.of(context).textTheme.labelSmall),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        const Divider(),
                        _buildPermSwitch(doc.id, "Allow this admin to view and audit system security logs", perms['canSeeSecurityLogs'] ?? false, 'canSeeSecurityLogs', perms),
                        _buildPermSwitch(doc.id, "Allow this admin to control dashboard section visibility for all roles", perms['canControlVisibility'] ?? false, 'canControlVisibility', perms),
                        _buildPermSwitch(doc.id, "Allow this admin to perform critical data management (Backup, Restore, Wipe)", perms['canManageData'] ?? false, 'canManageData', perms),
                        _buildPermSwitch(doc.id, "Allow this admin to create and manage system access accounts", perms['canManageAccounts'] ?? false, 'canManageAccounts', perms),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermSwitch(String docId, String fullSentence, bool value, String key, Map<String, dynamic> currentPerms) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(fullSentence, style: const TextStyle(fontSize: 12)),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (bool newVal) async {
        Map<String, bool> newPerms = Map<String, bool>.from(currentPerms.map((k, v) => MapEntry(k, v as bool)));
        newPerms[key] = newVal;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await _dbService.updateUserPermissions(docId, newPerms, prefs.getString('username') ?? 'SuperAdmin');
        DatabaseService.vibrate();
      },
    );
  }

}
