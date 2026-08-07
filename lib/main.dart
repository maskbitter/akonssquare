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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AkonsSquare',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const SplashScreen(),
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
  List<Map<String, dynamic>> _subItems = DatabaseService.cachedSubItems;
  Map<String, dynamic>? _selectedSubItem;

  @override
  void initState() {
    super.initState();
    _fetchAppName();
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
          String status = item['status'] ?? (tenant.isNotEmpty && tenant != 'No Tenant' ? 'Occupied' : 'Vacant');
          return status == 'Occupied';
        }).toList();
        _subItems.sort((a, b) => (a['subItemName'] ?? '').toString().compareTo((b['subItemName'] ?? '').toString()));
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchAppName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() { _appName = packageInfo.appName; });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Text("Login Failed!", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: BorderSide(color: Colors.grey.shade300)),
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
          String tName = _selectedSubItem!['TenantName'] ?? 'No Tenant';
          String unitName = _selectedSubItem!['subItemName'] ?? 'Unit';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(unitName, style: const TextStyle(fontWeight: FontWeight.bold)), Text("($tName)", style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontStyle: FontStyle.italic))])),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Enter last 4 digits of your NID:", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(controller: passController, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder(), counterText: "")),
            ]),
            actions: [
              Row(children: [
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), onPressed: isAuthenticating ? null : () => Navigator.pop(ctx), child: const Text("Cancel"))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.bold)), onPressed: isAuthenticating ? null : () async {
                  String input = passController.text.trim(); String storedNid = (_selectedSubItem!['nidNumber'] ?? '').toString();
                  if (input.isEmpty || input.length != 4) { DatabaseService.showToast(context, "Enter 4 digits!", backgroundColor: Colors.orange); return; }
                  setDialogState(() => isAuthenticating = true);
                  String last4 = storedNid.length >= 4 ? storedNid.substring(storedNid.length - 4) : storedNid;
                  if (input == last4 && storedNid.isNotEmpty && storedNid != "No Number") {
                    String subId = _selectedSubItem!['id']; String catId = _selectedSubItem!['categoryId'] ?? '';
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'user');
                    await prefs.setString('subItemId', subId); await prefs.setString('categoryId', catId);
                    if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserDashboard(subItemId: subId, categoryId: catId))); }
                  } else {
                    if (context.mounted) DatabaseService.showToast(context, "Incorrect password!", backgroundColor: Colors.red);
                    setDialogState(() => isAuthenticating = false);
                  }
                }, child: isAuthenticating ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Verify"))),
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
                    var userData = userQuery.docs.first.data() as Map<String, dynamic>; String role = (userData['role'] ?? 'viewer').toString();
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', role);
                    await prefs.setString('username', u); await prefs.setString('savedPassword', p);
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Text("Master Access", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Enter secret key:", style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          TextField(controller: keyController, obscureText: true, decoration: const InputDecoration(labelText: "Secret Key", border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key_outlined))),
        ]),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async {
              if (keyController.text.trim() == 'superadmin') {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', true); await prefs.setString('userRole', 'superadmin');
                if (mounted) { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard())); }
              } else { if (context.mounted) DatabaseService.showToast(context, "Invalid!", backgroundColor: Colors.red); }
            }, child: const Text("Authorize"))),
          ]),
        ],
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
                GestureDetector(onLongPress: _showMasterKeyDialog, child: Text(_appName.isEmpty ? "AKONS SQUARE" : _appName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade900, letterSpacing: 1.5))),
                const SizedBox(height: 4),
                StreamBuilder<DocumentSnapshot>(
                  stream: DatabaseService().getDatabaseInfoStream(),
                  initialData: null,
                  builder: (context, dbSnap) {
                    String dbVer = DatabaseService.cachedDBVersion?.toString() ?? "..."; 
                    if (dbSnap.hasData && dbSnap.data!.exists) { var v = (dbSnap.data!.data() as Map)['dbVersion'] ?? 0; dbVer = v.toString(); }
                    return Text("DB V-$dbVer", style: TextStyle(fontSize: 10, color: Colors.indigo.shade300, fontWeight: FontWeight.w900));
                  }
                ),
              ]),
            ),
            Expanded(
              child: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Welcome", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedSubItem,
                  decoration: InputDecoration(labelText: "Select User Name", prefixIcon: const Icon(Icons.meeting_room_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: _subItems.map((item) {
                    String displayText = "${item['subItemName'] ?? 'Unnamed'} (${item['TenantName'] ?? ''})";
                    return DropdownMenuItem<Map<String, dynamic>>(value: item, child: Text(displayText));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSubItem = v),
                  hint: const Text("Select User Name"),
                ),
                const SizedBox(height: 25),
                SizedBox(width: 250, height: 50, child: ElevatedButton(
                  onPressed: () { HapticFeedback.mediumImpact(); _loginBasicUser(); },
                  onLongPress: () { HapticFeedback.heavyImpact(); _showHiddenLoginDialog(); },
                  child: const Text("LOGIN"),
                )),
              ]))),
            ),
          ],
        ),
      ),
    );
  }
}
