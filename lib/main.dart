import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

import 'package:akonssquare/Admin/admin_dashboard.dart';
import 'package:akonssquare/Users/user_dashboard.dart';
import 'package:akonssquare/Operator/operator_dashboard.dart';
import 'package:akonssquare/Viewer/viewer_dashboard.dart';
import 'package:akonssquare/Admin/super_admin_dashboard.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/splash_screen.dart';
import 'package:akonssquare/Common/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize theme
  await ThemeManager.init();

  // Explicitly enable and configure persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeManager.appThemeNotifier,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AkonsSquare',
          theme: ThemeManager.getThemeByName(currentTheme),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String _appName = ""; 
  String _currentVersion = "";
  List<Map<String, dynamic>> _subItems = DatabaseService.cachedSubItems;
  Map<String, dynamic>? _selectedSubItem;

  @override
  void initState() {
    super.initState();
    _fetchAppDetails();
    if (_subItems.isEmpty) {
      _fetchSubItems();
    }
  }

  Future<void> _fetchSubItems() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('sub_items').get();
      setState(() {
        _subItems = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).where((item) {
          String tenant = item['TenantName'] ?? '';
          String status = item['status'] ?? (tenant.isNotEmpty && tenant != 'No Name' ? 'Occupied' : 'Vacant');
          return status == 'Occupied';
        }).toList();
        _subItems.sort((a, b) => (a['subItemName'] ?? '').toString().compareTo((b['subItemName'] ?? '').toString()));
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchAppDetails() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() { 
      _appName = packageInfo.appName; 
      _currentVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text("Login Failed!", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
        content: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface, 
                foregroundColor: Theme.of(context).colorScheme.onSurface, 
                side: BorderSide(color: Theme.of(context).colorScheme.outline)
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loginBasicUser() async {
    if (_selectedSubItem == null) { _showErrorDialog("Please select your name!"); return; }
    final passController = TextEditingController(); bool isAuthenticating = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String tName = _selectedSubItem!['TenantName'] ?? 'No Name';
          String unitName = _selectedSubItem!['subItemName'] ?? 'Unit';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(unitName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text("($tName)", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic))])),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("Enter last 4 digits of your NID:", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),
              TextField(controller: passController, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, style: Theme.of(context).textTheme.bodyLarge, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder(), counterText: "")),
            ]),
            actions: [
              Row(children: [
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, side: BorderSide(color: Theme.of(context).colorScheme.error)), onPressed: isAuthenticating ? null : () => Navigator.pop(ctx), child: const Text("Cancel"))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, textStyle: const TextStyle(fontWeight: FontWeight.bold)), onPressed: isAuthenticating ? null : () async {
                  String input = passController.text.trim(); String storedNid = (_selectedSubItem!['nidNumber'] ?? '').toString();
                  if (input.isEmpty || input.length != 4) { DatabaseService.showToast(context, "Enter 4 digits!", backgroundColor: Theme.of(context).colorScheme.secondary); return; }
                  setDialogState(() => isAuthenticating = true);
                  String last4 = storedNid.length >= 4 ? storedNid.substring(storedNid.length - 4) : storedNid;
                  if (input == last4 && storedNid.isNotEmpty && storedNid != "No Number") {
                    String subId = _selectedSubItem!['id']; String catId = _selectedSubItem!['categoryId'] ?? '';
                    String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                    
                    await DatabaseService().updateUserSession('sub_items', subId, sessionId);

                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'user');
                    await prefs.setString('subItemId', subId); await prefs.setString('categoryId', catId);
                    await prefs.setString('sessionId', sessionId);

                    if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserDashboard(subItemId: subId, categoryId: catId))); }
                  } else {
                    if (context.mounted) DatabaseService.showToast(context, "Incorrect password!", backgroundColor: Theme.of(context).colorScheme.error);
                    setDialogState(() => isAuthenticating = false);
                  }
                }, child: isAuthenticating ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)) : const Text("Verify"))),
              ]),
            ],
          );
        },
      ),
    );
  }

  void _showHiddenLoginDialog() {
    final userController = TextEditingController(); final passController = TextEditingController(); bool isVerifying = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Text("Access Login", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: userController, decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 10),
            TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))),
          ]),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), onPressed: isVerifying ? null : () => Navigator.pop(ctx), child: const Text("Cancel"))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.bold)), onPressed: isVerifying ? null : () async {
                String u = userController.text.trim(); String p = passController.text.trim(); if (u.isEmpty || p.isEmpty) return;
                setDialogState(() => isVerifying = true);
                try {
                  if (u == 'admin' && p == 'admin') {
                     var adminCheck = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').get();
                     if (adminCheck.docs.isEmpty) {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'admin');
                        await prefs.setString('username', u); await prefs.setString('savedPassword', p);
                        if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard())); }
                        return;
                     }
                  }
                  QuerySnapshot userQuery = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: u).where('password', isEqualTo: p).limit(1).get();
                  if (userQuery.docs.isNotEmpty) {
                    var userDoc = userQuery.docs.first;
                    var userData = userDoc.data() as Map<String, dynamic>; String role = (userData['role'] ?? 'viewer').toString();
                    String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                    
                    await DatabaseService().updateUserSession('users', userDoc.id, sessionId);

                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', role);
                    await prefs.setString('username', u); await prefs.setString('savedPassword', p);
                    await prefs.setString('userDocId', userDoc.id);
                    await prefs.setString('sessionId', sessionId);

                    if (mounted) {
                      Navigator.pop(ctx);
                      if (role == 'admin') Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
                      else if (role == 'operator') Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OperatorDashboard(username: u)));
                      else Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ViewerDashboard()));
                    }
                    return;
                  }
                  if (context.mounted) DatabaseService.showToast(context, "Incorrect details!", backgroundColor: Colors.red);
                } catch (e) { /* ignore */ } finally { if (ctx.mounted) setDialogState(() => isVerifying = false); }
              }, child: isVerifying ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Login"))),
            ]),
          ],
        ),
      ),
    );
  }

  void _showMasterKeyDialog() {
    final keyController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Text("Master Access", style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Enter secret key:", style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(controller: keyController, obscureText: true, decoration: const InputDecoration(labelText: "Secret Key", border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key_outlined))),
          ]),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                  ),
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("Cancel")
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary, 
                    foregroundColor: Theme.of(context).colorScheme.onTertiary
                  ), 
                  onPressed: isLoading ? null : () async {
                    if (keyController.text.trim() == 'superadmin') {
                      setDialogState(() => isLoading = true);
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'superadmin');
                      if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard())); }
                    } else { if (context.mounted) DatabaseService.showToast(context, "Invalid!", backgroundColor: Theme.of(context).colorScheme.error); }
                  }, 
                  child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Authorize")
                )
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                GestureDetector(onLongPress: _showMasterKeyDialog, child: Text(_appName.isEmpty ? "AKONS SQUARE" : _appName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.5))),
                const SizedBox(height: 4),
                // Version Info moved here
                StreamBuilder<DocumentSnapshot>(
                  stream: DatabaseService().getAppConfigStream(),
                  builder: (context, snapshot) {
                    String latestVer = "";
                    if (snapshot.hasData && snapshot.data!.exists) {
                      latestVer = (snapshot.data!.data() as Map)['requiredVersion'] ?? "";
                    }
                    
                    String versionText = "V: $_currentVersion";
                    if (latestVer.isNotEmpty && latestVer != _currentVersion) {
                      versionText += " | Latest: $latestVer";
                    }

                    return Text(
                      versionText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    );
                  }
                ),
                const SizedBox(height: 2),
                StreamBuilder<DocumentSnapshot>(
                  stream: DatabaseService().getDatabaseInfoStream(),
                  initialData: null,
                  builder: (context, dbSnap) {
                    String dbVer = DatabaseService.cachedDBVersion?.toString() ?? "..."; 
                    if (dbSnap.hasData && dbSnap.data!.exists) { var v = (dbSnap.data!.data() as Map)['dbVersion'] ?? 0; dbVer = v.toString(); }
                    return Text("DB V-$dbVer", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w900));
                  }
                ),
              ]),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Text("Welcome", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedSubItem,
                          alignment: Alignment.center,
                          isExpanded: true,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            labelText: "Select User Name", 
                            prefixIcon: const Icon(Icons.meeting_room_outlined), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          items: _subItems.map((item) {
                            String displayText = "${item['subItemName'] ?? 'Unnamed'} (${item['TenantName'] ?? ''})";
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: item, 
                              alignment: Alignment.center,
                              child: Center(child: Text(displayText, textAlign: TextAlign.center))
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedSubItem = v),
                          hint: const Center(child: Text("Select User Name")),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, 
                        height: 55, 
                        child: ElevatedButton(
                          onLongPress: () { HapticFeedback.heavyImpact(); _showHiddenLoginDialog(); },
                          onPressed: () { HapticFeedback.mediumImpact(); _loginBasicUser(); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                            foregroundColor: Theme.of(context).colorScheme.onTertiary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Login to dashboard", style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Theme.of(context).colorScheme.onTertiary)),
                        )
                      ),
                    ]
                  )
                )
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Image.asset('assets/images/signature.png', height: 40, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                  const SizedBox(height: 4),
                  Text(
                    "AkonsAutomation by AkonS",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 0.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
