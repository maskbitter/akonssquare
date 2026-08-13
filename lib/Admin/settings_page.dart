import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:akonssquare/Common/ui_helper.dart';

class SettingsPage extends StatefulWidget {
  final bool showOnlyTheme;
  const SettingsPage({super.key, this.showOnlyTheme = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isProcessing = false;
  String? _activeAction;
  double _progress = 0.0;
  String _selectedRoleForVisibility = 'admin';

  String _getBackupFileName(num version) {
    DateTime now = DateTime.now();
    String d = now.day.toString().padLeft(2, '0');
    String m = now.month.toString().padLeft(2, '0');
    String y = now.year.toString();
    String h = now.hour.toString().padLeft(2, '0');
    String min = now.minute.toString().padLeft(2, '0');
    String s = now.second.toString().padLeft(2, '0');
    String vStr = version is int ? "${version}.0" : version.toString();
    return "akonssquare_v_${vStr}_${d}${m}${y}_${h}${min}${s}.json";
  }

  Future<void> _handleBackup(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    setState(() { _isProcessing = true; _activeAction = 'backup'; _progress = 0.0; });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String actor = prefs.getString('username') ?? "Unknown";
      Map<String, dynamic> data = await _dbService.exportDatabase(actor, onProgress: (p) => setState(() => _progress = p));
      String jsonStr = await compute(jsonEncode, data);
      final directory = await getTemporaryDirectory();
      String fileName = _getBackupFileName(data['dbVersion'] ?? 0);
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path)], text: 'Database Backup v${data['dbVersion']}');
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Backup Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally { if (mounted) setState(() { _isProcessing = false; _activeAction = null; }); }
  }

  Future<void> _handleLocalSave(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String actor = prefs.getString('username') ?? "Unknown";
      setState(() { _isProcessing = true; _activeAction = 'localSave'; _progress = 0.0; });
      Map<String, dynamic> data = await _dbService.exportDatabase(actor, onProgress: (p) => setState(() => _progress = p));
      String jsonStr = await compute(jsonEncode, data);
      String fileName = _getBackupFileName(data['dbVersion'] ?? 0);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
      String? result = await FilePicker.saveFile(fileName: fileName, bytes: bytes, type: FileType.custom, allowedExtensions: ['json']);
      if (context.mounted && result != null) DatabaseService.showToast(context, "Backup saved: $fileName");
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Local Save Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally { if (mounted) setState(() { _isProcessing = false; _activeAction = null; }); }
  }

  Future<void> _handleRestore(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (_isProcessing) return;
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.single.path == null) return;
      
      setState(() { _isProcessing = true; _activeAction = 'restore'; _progress = 0.0; });
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      Map<String, dynamic> importData = await compute(_parseJson, content);
      num backupVersion = importData['dbVersion'] ?? 1.0;
      double serverVersion = await _dbService.getDBVersion();
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String role = prefs.getString('userRole') ?? 'admin';
      String actor = prefs.getString('username') ?? "Unknown";
      
      bool proceed = false;
      if (role == 'superadmin') {
        if (backupVersion > serverVersion) proceed = await _showConfirmDialog(context, "Restore New Data?", "This will overwrite all data with v$backupVersion.");
        else if (backupVersion == serverVersion) proceed = await _showConfirmDialog(context, "Re-upload Version?", "This backup matches the current server.");
        else {
          bool first = await _showConfirmDialog(context, "WARNING: Older Version", "This backup is OLDER than current. Restore anyway?");
          if (first) proceed = await _showConfirmDialog(context, "Final Verification", "Downgrade server data?");
        }
      } else {
        if (backupVersion > serverVersion) proceed = await _showConfirmDialog(context, "Restore Data?", "Update server data to v$backupVersion?");
        else if (backupVersion == serverVersion) {
          if (context.mounted) _showInfoDialog(context, "Already Restored", "The database is already at version $serverVersion.");
          setState(() { _isProcessing = false; _activeAction = null; }); return;
        } else {
          if (context.mounted) _showInfoDialog(context, "Update Denied", "Higher version required.");
          setState(() { _isProcessing = false; _activeAction = null; }); return;
        }
      }
      
      if (proceed && context.mounted) {
        // Create rollback snapshot before starting destructive operation
        await _dbService.createRollbackSnapshot(actor);
        await _dbService.setServerStatus('uploading', progress: 0.0);
        await _dbService.importDatabase(importData, actor, onProgress: (p) => setState(() => _progress = p));
        // Clear snapshot on success
        await _dbService.clearRollbackSnapshot();
        await _dbService.setServerStatus('completed');
        if (context.mounted) DatabaseService.showToast(context, "Database Restored Successfully!", backgroundColor: Colors.green);
      }
    } catch (e) {
       if (context.mounted) DatabaseService.showToast(context, "Restore Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally { if (mounted) setState(() { _isProcessing = false; _activeAction = null; }); }
  }

  static Map<String, dynamic> _parseJson(String jsonStr) => jsonDecode(jsonStr);

  Future<void> _handleWipe(BuildContext context) async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();
    try {
      DocumentSnapshot backupInfo = await FirebaseFirestore.instance.collection('app_config').doc('database_info').get();
      bool hasBackup = backupInfo.exists && (backupInfo.data() as Map).containsKey('lastBackupAt');
      bool proceed = false;
      if (!hasBackup) {
        bool backupNow = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Center(child: Text("Backup Required!", style: TextStyle(fontWeight: FontWeight.bold))),
            content: const Text("It is recommended to backup before wiping.", textAlign: TextAlign.center),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx, false), 
                    child: const Text("Cancel")
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true), 
                    child: const Text("Backup Now")
                  ),
                ],
              ),
            ],
          ),
        ) ?? false;
        if (backupNow) { if (context.mounted) await _handleBackup(context); }
        return;
      }
      bool confirm1 = await _showConfirmDialog(context, "Initial Confirmation", "Delete ALL data?");
      if (confirm1) proceed = await _showConfirmDialog(context, "FINAL WARNING", "Erase all records. PROCEED?");
      
      if (proceed && context.mounted) {
        setState(() { _isProcessing = true; _activeAction = 'wipe'; _progress = 1.0; });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String actor = prefs.getString('username') ?? "Unknown";
        
        // Create rollback snapshot
        await _dbService.createRollbackSnapshot(actor);
        await _dbService.setServerStatus('wiping', progress: 1.0);
        await _dbService.wipeDatabase(actor, onProgress: (p) => setState(() => _progress = p));
        // Clear snapshot on success
        await _dbService.clearRollbackSnapshot();
        await _dbService.setServerStatus('wipe_completed');
        if (context.mounted) DatabaseService.showToast(context, "Server Wiped Successfully!", backgroundColor: Theme.of(context).colorScheme.error);
      }
    } catch (e) {
      if (context.mounted) DatabaseService.showToast(context, "Wipe Error: $e", backgroundColor: Theme.of(context).colorScheme.error);
    } finally { if (mounted) setState(() { _isProcessing = false; _activeAction = null; }); }
  }

  void _showInfoDialog(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error, 
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("OK")
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ), 
                onPressed: () => Navigator.pop(ctx, false), 
                child: const Text("Cancel")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary, 
                  foregroundColor: ThemeManager.outlineBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ), 
                onPressed: () => Navigator.pop(ctx, true), 
                child: const Text("Proceed")
              ),
            ],
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildVisibilitySwitch(String title, bool value, Function(bool) onChanged, {bool isSub = false, IconData? icon}) {
    return SwitchListTile(
      secondary: icon != null ? Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20) : null,
      title: Text(title, style: isSub ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.bodyLarge),
      value: value,
      dense: true,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: (val) { HapticFeedback.selectionClick(); onChanged(val); },
    );
  }

  Widget _buildSubVisibilityRadio(String title, bool isVisible, Function(bool) onChanged, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: InkWell(
        onTap: () => onChanged(!isVisible),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              if (icon != null) Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
              if (icon != null) const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.secondary))),
              Radio<bool>(
                value: true,
                groupValue: isVisible,
                visualDensity: VisualDensity.compact,
                activeColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.secondary,
                onChanged: (v) => onChanged(true),
              ),
              Radio<bool>(
                value: false,
                groupValue: isVisible,
                visualDensity: VisualDensity.compact,
                activeColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.red : Theme.of(context).colorScheme.error,
                onChanged: (v) => onChanged(false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showOnlyTheme) {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              _buildThemeSection(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Visibility
            _buildSettingsCard(
              context,
              icon: Icons.security_outlined,
              title: "Dashboard Visibility Control",
              subtitle: "Control what sections are visible to different roles",
              color: ThemeManager.getCardContainerColor(1),
              accentColor: ThemeManager.getCardColor(1),
              children: [
                // Nested System Config at the top
                StreamBuilder<DocumentSnapshot>(
                  stream: _dbService.getAppConfigStream(),
                  builder: (context, snapshot) {
                    bool isEnabled = snapshot.data?.exists == true ? snapshot.data!['isPopupEnabled'] ?? true : true;
                    return Card(
                      elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 3,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.transparent : ThemeManager.getCardContainerColor(5, isSubCard: true),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: ThemeManager.appThemeNotifier.value == "Outline Theme" ? BorderSide(color: ThemeManager.getCardColor(5, isSubCard: true), width: 1.5) : BorderSide.none,
                      ),
                      child: ExpansionTile(
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
                        leading: Icon(Icons.settings_suggest_outlined, color: ThemeManager.getCardColor(5, isSubCard: true)),
                        iconColor: ThemeManager.getCardColor(5, isSubCard: true),
                        collapsedIconColor: ThemeManager.getCardColor(5, isSubCard: true),
                        title: Text("System Configuration", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: ThemeManager.getCardOnContainerColor(5, isSubCard: true))),
                        subtitle: Text("System behavior & Experience", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThemeManager.getCardOnContainerColor(5, isSubCard: true).withValues(alpha: 0.7))),
                        children: [
                          _buildVisibilitySwitch("Enable Update Notifications", isEnabled, (val) => _dbService.updatePopupStatus(val)),
                          FutureBuilder<SharedPreferences>(
                            future: SharedPreferences.getInstance(),
                            builder: (context, ps) {
                              bool h = ps.data?.getBool('isHapticEnabled') ?? true;
                              return _buildVisibilitySwitch("Haptic Pulse Feedback", h, (v) async { (await SharedPreferences.getInstance()).setBool('isHapticEnabled', v); if(v) DatabaseService.vibrate(); setState((){}); }, icon: Icons.vibration_outlined);
                            }
                          ),
                        ],
                      ),
                    );
                  }
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.person_search_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text("Role:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedRoleForVisibility,
                      items: const [DropdownMenuItem(value: 'admin', child: Text("Admin")), DropdownMenuItem(value: 'operator', child: Text("Operator")), DropdownMenuItem(value: 'viewer', child: Text("Viewer"))],
                      onChanged: (val) { if (val != null) setState(() => _selectedRoleForVisibility = val); },
                    ),
                  ]),
                ),
                const Divider(height: 1),
                StreamBuilder<DocumentSnapshot>(
                  stream: _dbService.getDashboardVisibilityStream(_selectedRoleForVisibility),
                  builder: (context, snapshot) {
                    Map<String, bool> s = {
                      'showAccounts': true, 
                      'showElectricity': true, 
                      'showMainVsSub': true, 
                      'showMainVsGovt': true, 
                      'showCategory': true,
                      'showTotalOccupied': true,
                      'showTotalVacant': true,
                    };
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>;
                      (data['settings'] ?? {}).forEach((k, v) => s[k] = v as bool);
                    }
                    return Column(children: [
                      Card(
                        elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.transparent : ThemeManager.getCardContainerColor(6, isSubCard: true),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: ThemeManager.appThemeNotifier.value == "Outline Theme" ? BorderSide(color: ThemeManager.getCardColor(6, isSubCard: true), width: 1.5) : BorderSide.none,
                        ),
                        child: _buildVisibilitySwitch("Show Accounts Section", s['showAccounts']!, (val) { s['showAccounts'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.account_balance_wallet_outlined),
                      ),
                      
                      // Electricity Nested
                      Card(
                        elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.transparent : ThemeManager.getCardContainerColor(7, isSubCard: true),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: ThemeManager.appThemeNotifier.value == "Outline Theme" ? BorderSide(color: ThemeManager.getCardColor(7, isSubCard: true), width: 1.5) : BorderSide.none,
                        ),
                        child: Column(
                          children: [
                            _buildVisibilitySwitch("Show Electricity Section", s['showElectricity']!, (val) { s['showElectricity'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.electric_bolt_outlined),
                            if (s['showElectricity']!) ...[
                              _buildSubVisibilityRadio("Main vs Sub-Meter", s['showMainVsSub']!, (val) { s['showMainVsSub'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.compare_arrows),
                              _buildSubVisibilityRadio("Main vs Govt. Bill", s['showMainVsGovt']!, (val) { s['showMainVsGovt'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.receipt_long),
                              const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      ),

                      // Category Nested
                      Card(
                        elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.transparent : ThemeManager.getCardContainerColor(8, isSubCard: true),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: ThemeManager.appThemeNotifier.value == "Outline Theme" ? BorderSide(color: ThemeManager.getCardColor(8, isSubCard: true), width: 1.5) : BorderSide.none,
                        ),
                        child: Column(
                          children: [
                            _buildVisibilitySwitch("Show Category Section", s['showCategory']!, (val) { s['showCategory'] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.category_outlined),
                            if (s['showCategory']!) ...[
                              _buildSubVisibilityRadio("Total Occupied", s['showTotalOccupied']!, (v){ s['showTotalOccupied'] = v; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.door_front_door_outlined),
                              _buildSubVisibilityRadio("Total Vacant", s['showTotalVacant']!, (v){ s['showTotalVacant'] = v; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.meeting_room_outlined),
                              StreamBuilder<QuerySnapshot>(
                                stream: _dbService.getCategoriesStream(),
                                builder: (context, catSnap) {
                                  if (!catSnap.hasData) return const SizedBox.shrink();
                                  return Column(children: catSnap.data!.docs.map((doc) {
                                    String catName = (doc.data() as Map)['categoryName'] ?? '';
                                    String key = "cat_${doc.id}";
                                    bool isVisible = s[key] ?? true;
                                    return _buildSubVisibilityRadio(catName, isVisible, (val) { s[key] = val; _dbService.updateDashboardVisibility(_selectedRoleForVisibility, s); }, icon: Icons.label_outline);
                                  }).toList());
                                },
                              ),
                              const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      ),
                    ]);
                  }
                ),
              ],
            ),

            // 3. Data Management
            _buildSettingsCard(
              context,
              icon: Icons.storage_outlined,
              title: "Data Management",
              subtitle: "Backup and restore database records",
              color: ThemeManager.getCardContainerColor(2),
              accentColor: ThemeManager.getCardColor(2),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    AppDialogActions(
                      actions: [
                        AppButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: ThemeManager.outlineBackground), 
                          onPressed: _isProcessing ? null : () => _handleBackup(context), 
                          icon: (_isProcessing && _activeAction == 'backup') 
                            ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
                            : const Icon(Icons.cloud_upload_outlined), 
                          child: const Text("Backup")
                        ),
                        AppButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: ThemeManager.outlineBackground), 
                          onPressed: _isProcessing ? null : () => _handleRestore(context), 
                          icon: (_isProcessing && _activeAction == 'restore') 
                            ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
                            : const Icon(Icons.cloud_download_outlined), 
                          child: const Text("Restore")
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppDialogActions(
                      actions: [
                        AppButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: ThemeManager.outlineBackground), 
                          onPressed: _isProcessing ? null : () => _handleLocalSave(context), 
                          icon: (_isProcessing && _activeAction == 'localSave') 
                            ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
                            : const Icon(Icons.save_alt), 
                          child: const Text("Save Locally")
                        ),
                      ],
                    ),
                    if (_isProcessing) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: _progress, backgroundColor: Theme.of(context).colorScheme.outlineVariant, color: Theme.of(context).colorScheme.primary, minHeight: 6),
                      const SizedBox(height: 4),
                      Text("${(_progress * 100).toStringAsFixed(1)}%", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      "Backup generates a JSON file. Use Restore to upload a previous backup. Versioning ensures safety.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, snapshot) {
                        if (snapshot.data?.getString('userRole') == 'superadmin') {
                          return Padding(padding: const EdgeInsets.only(top: 16), child: Column(children: [
                            const Divider(),
                            AppDialogActions(
                              actions: [
                                AppButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: ThemeManager.outlineBackground), 
                                  onPressed: _isProcessing ? null : () => _handleWipe(context), 
                                  icon: (_isProcessing && _activeAction == 'wipe') 
                                    ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
                                    : const Icon(Icons.delete_forever), 
                                  child: const Text("Wipe All Data")
                                ),
                              ],
                            ),
                          ]));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ]),
                ),
              ],
            ),

            // 4. Account Management
            _buildSettingsCard(
              context,
              icon: Icons.manage_accounts_outlined,
              title: "Account Management",
              subtitle: "Create and manage system access",
              color: ThemeManager.getCardContainerColor(3),
              accentColor: ThemeManager.getCardColor(3),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    AppDialogActions(
                      actions: [
                        AppButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: ThemeManager.outlineBackground), onPressed: _isProcessing ? null : () => _showUserDialog(context), icon: const Icon(Icons.person_add_alt_1_outlined), child: const Text("Add New Account")),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildUsersListRow(),
                  ]),
                ),
              ],
            ),

            // 5. Theme
            _buildThemeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection() {
    return _buildSettingsCard(
      context,
      icon: Icons.palette_outlined,
      title: "Theme & Appearance",
      subtitle: "Customize look and feel of your app",
      color: ThemeManager.getCardContainerColor(4),
      accentColor: ThemeManager.getCardColor(4),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppDialogActions(
                actions: [
                  AppButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: ThemeManager.outlineBackground), onPressed: _isProcessing ? null : () => _showThemeSelectionDialog(context), icon: const Icon(Icons.color_lens_outlined), child: const Text("Change App Theme")),
                ],
              ),
              const SizedBox(height: 16),
              // Font Selection Dropdown
              ValueListenableBuilder<String>(
                valueListenable: ThemeManager.appFontNotifier,
                builder: (context, currentFont, child) {
                  return DropdownButtonFormField<String>(
                    value: currentFont,
                    decoration: const InputDecoration(
                      labelText: "App Font Family",
                      prefixIcon: Icon(Icons.font_download_outlined),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ThemeManager.supportedFonts.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ThemeManager.setFont(val);
                        DatabaseService.showToast(context, "Font changed to $val");
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required Color accentColor, required List<Widget> children}) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Card(
      elevation: isOutline ? 0 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isOutline ? Colors.transparent : color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: isOutline ? BorderSide(color: accentColor, width: 1.5) : BorderSide.none
      ),
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        leading: Icon(icon, color: accentColor),
        iconColor: accentColor,
        collapsedIconColor: accentColor,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: isOutline ? Colors.black : accentColor, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isOutline ? Colors.black : null)),
        children: children,
      ),
    );
  }

  Widget _buildUsersListRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var users = snapshot.data!.docs.toList();
        users.sort((a, b) => ((a.data() as Map)['username'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['username'] ?? '').toString().toLowerCase()));
        
        return Column(children: users.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String role = (data['role'] ?? 'viewer').toString().toLowerCase();
          
          Color roleColor = Theme.of(context).colorScheme.surface;
          int colorIdx = 0;
          if (role == 'admin') colorIdx = 3; // Index 3 for admin (Error/Red)
          else if (role == 'operator') colorIdx = 1; // Index 1 for operator (Secondary/Cyan)
          else colorIdx = 4; // Index 4 for viewer (Surface/Neutral)

          roleColor = ThemeManager.getCardContainerColor(colorIdx, isSubCard: true);
          final accent = ThemeManager.getCardColor(colorIdx, isSubCard: true);
          bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";

          return Card(
            elevation: isOutline ? 0 : 2,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: isOutline ? Colors.transparent : roleColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: isOutline ? BorderSide(color: accent, width: 1.5) : BorderSide.none
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(role == 'admin' ? Icons.security : role == 'operator' ? Icons.build_circle : Icons.visibility, size: 20, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['username'] ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(colorIdx, isSubCard: true))),
                        Text(role.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Text(data['password'] ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(colorIdx, isSubCard: true).withValues(alpha: 0.7))),
                  const SizedBox(width: 8),
                  IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: accent), onPressed: () => _showUserDialog(context, docId: doc.id, currentData: data)),
                  IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error), onPressed: () => _confirmRemove(doc.id, data['username'])),
                ],
              ),
            ),
          );
        }).toList());
      },
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    String local = ThemeManager.appThemeNotifier.value;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setST) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text("Select Theme", style: Theme.of(context).textTheme.titleLarge)),
        content: DropdownButton<String>(
          value: local, isExpanded: true, items: ["Editor Choice", "Random Color Theme", "Black & White Theme", "Outline Theme"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) { if (val != null) setST(() => local = val); },
        ),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ), 
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary, 
                  foregroundColor: ThemeManager.outlineBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ), 
                onPressed: () async {
                  await ThemeManager.setTheme(local);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (local == "Outline Theme" && context.mounted) {
                    _showOutlineColorPickerDialog(context);
                  }
                }, 
                child: const Text("Apply")
              ),
            ],
          ),
        ],
      );
    }));
  }

  void _showOutlineColorPickerDialog(BuildContext context) {
    Color selected = ThemeManager.appOutlineBgNotifier.value;
    final List<Color> presets = [
      const Color(0xFFFAF9F6), // Off-white
      Colors.white,
      const Color(0xFFF5F5F5), // Light Gray
      const Color(0xFFFFFDD0), // Cream
      const Color(0xFFFDF5E6), // Old Lace
      const Color(0xFFE6E6FA), // Lavender Mist
      const Color(0xFFF0FFF0), // Honeydew
      const Color(0xFFF0F8FF), // Alice Blue
      const Color(0xFFFFF5EE), // Shell
      const Color(0xFFF0FFFF), // Azure
      const Color(0xFFF5FFFA), // Mint Cream
      const Color(0xFFFFFFF0), // Ivory
      const Color(0xFFFFFAF0), // Floral White
      const Color(0xFFFFF0F5), // Lavender Blush
      const Color(0xFFFFE4E1), // Misty Rose
      const Color(0xFFFAF0E6), // Linen
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Text("Background Customizer", style: TextStyle(fontWeight: FontWeight.bold))),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select a background color:", textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presets.map((c) => GestureDetector(
                  onTap: () async {
                    setST(() {
                      selected = c;
                    });
                    await ThemeManager.setOutlineBgColor(c);
                  },
                  child: Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected.value == c.value ? Colors.black : Colors.grey, width: selected.value == c.value ? 3 : 1),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary, 
                    foregroundColor: Theme.of(context).colorScheme.onPrimary
                  ),
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("Done")
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, {String? docId, Map<String, dynamic>? currentData}) {
    final uC = TextEditingController(text: currentData?['username'] ?? '');
    final pC = TextEditingController(text: currentData?['password'] ?? '');
    String role = currentData?['role'] ?? 'operator';
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setST) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text(docId == null ? "Add Account" : "Edit Account", style: Theme.of(context).textTheme.titleLarge)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: uC, 
            decoration: const InputDecoration(
              labelText: "Username",
              hintText: "Enter account username",
              prefixIcon: Icon(Icons.person_outline),
            ), 
            onChanged: (v) => setST((){})
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pC, 
            decoration: const InputDecoration(
              labelText: "Password",
              hintText: "Enter account password",
              prefixIcon: Icon(Icons.lock_outline),
            ), 
            onChanged: (v) => setST((){})
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: role, 
            decoration: const InputDecoration(
              labelText: "Role",
              prefixIcon: Icon(Icons.security_outlined),
            ), 
            items: const [DropdownMenuItem(value: 'admin', child: Text("Admin")), DropdownMenuItem(value: 'operator', child: Text("Operator")), DropdownMenuItem(value: 'viewer', child: Text("Viewer"))], 
            onChanged: (v) => setST(() => role = v!)
          ),
        ]),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ), 
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary, 
                  foregroundColor: ThemeManager.outlineBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ), 
                onPressed: (uC.text == (currentData?['username'] ?? '') && pC.text == (currentData?['password'] ?? '') && role == (currentData?['role'] ?? 'operator')) ? null : () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await _dbService.saveUser(uC.text, pC.text, role, prefs.getString('username') ?? '', docId: docId);
                  if (ctx.mounted) Navigator.pop(ctx);
                }, 
                child: const Text("Save")
              ),
            ],
          ),
        ],
      );
    }));
  }

  void _confirmRemove(String docId, String username) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Remove Account?"), content: Text("Are you sure you want to remove user '$username'?"),
      actions: [
        AppDialogActions(
          actions: [
            AppButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("Cancel")
            ),
            AppButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await _dbService.removeUser(docId, prefs.getString('username') ?? '');
                if (mounted) Navigator.pop(ctx);
              }, 
              child: const Text("Remove")
            ),
          ],
        ),
      ],
    ));
  }
}
