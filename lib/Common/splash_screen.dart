import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/main.dart';
import 'package:akonssquare/Admin/admin_dashboard.dart';
import 'package:akonssquare/Users/user_dashboard.dart';
import 'package:akonssquare/Operator/operator_dashboard.dart';
import 'package:akonssquare/Viewer/viewer_dashboard.dart';
import 'package:akonssquare/Admin/super_admin_dashboard.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    _logoController.forward();
    _startPreFetching();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _startPreFetching() async {
    // 1. Minimum delay for animation beauty (2.5 seconds)
    final minDelay = Future.delayed(const Duration(milliseconds: 2500));

    // 2. Data Pre-fetching
    final dataFetch = _fetchInitialData();

    // 3. Wait for both
    await Future.wait([minDelay, dataFetch]);

    // 4. Navigate based on Auth
    if (mounted) {
      _navigateNext();
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      // Fetch App Config
      DocumentSnapshot configSnap = await FirebaseFirestore.instance.collection('app_config').doc('settings').get();
      if (configSnap.exists) {
        DatabaseService.cachedAppConfig = configSnap.data() as Map<String, dynamic>;
      }

      // Fetch DB Version
      DocumentSnapshot dbSnap = await FirebaseFirestore.instance.collection('app_config').doc('database_info').get();
      if (dbSnap.exists) {
        DatabaseService.cachedDBVersion = (dbSnap.data() as Map)['dbVersion']?.toDouble();
      }

      // Fetch Occupied Sub-items for Login Page
      QuerySnapshot subItemsSnap = await FirebaseFirestore.instance.collection('sub_items').get();
      DatabaseService.cachedSubItems = subItemsSnap.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).where((item) {
        String tenant = item['TenantName'] ?? '';
        String status = item['status'] ?? (tenant.isNotEmpty && tenant != 'No Name' ? 'Occupied' : 'Vacant');
        return status == 'Occupied';
      }).toList();
      DatabaseService.cachedSubItems.sort((a, b) => (a['subItemName'] ?? '').toString().compareTo((b['subItemName'] ?? '').toString()));

    } catch (e) {
      debugPrint("Pre-fetching Error: $e");
    }
  }

  Future<void> _navigateNext() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String role = prefs.getString('userRole') ?? 'user';

    if (!mounted) return;

    if (isLoggedIn) {
      if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
      } else if (role == 'operator') {
        String username = prefs.getString('username') ?? "Operator";
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OperatorDashboard(username: username)));
      } else if (role == 'viewer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ViewerDashboard()));
      } else if (role == 'superadmin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperAdminDashboard()));
      } else {
        String subId = prefs.getString('subItemId') ?? "";
        String catId = prefs.getString('categoryId') ?? "";
        if (subId.isEmpty || catId.isEmpty) {
          await prefs.clear();
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          return;
        }
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UserDashboard(subItemId: subId, categoryId: catId)));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF24292E), Color(0xFF0A0C0E)], // Back to cleaner charcoal gradient
            center: Alignment.center,
            radius: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: CustomPaint(
                  size: const Size(80, 80), // Reverted to 120
                  painter: ModernLogoPainter(),
                ),
              ),
            ),
            const SizedBox(height: 50),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    "AKONS SQUARE",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: 5.0,
                      shadows: [
                        Shadow(color: const Color(0xFF00FFC2).withValues(alpha: 0.5), blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "SECURE PROPERTY MANAGEMENT",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF00FFC2).withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                      fontSize: 8,
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

class ModernLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Background Square (Base) - taking ~90% of size area
    final basePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1A1E23), Color(0xFF0A0C0E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.9, h * 0.9), const Radius.circular(24)),
      basePaint,
    );

    // Subtle Outer Glow
    final glowPaint = Paint()
      ..color = const Color(0xFF00FFC2).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.9, h * 0.9), const Radius.circular(24)),
      glowPaint,
    );

    // 2. Logic Grid Squares - taking more area (70% coverage)
    final gridPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FFC2), Color(0xFF00D2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    const double spacing = 0.08; // 8% spacing
    const double sqSize = 0.38;  // 38% size per square

    // Top-Left Square
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.12, w * sqSize, h * sqSize), const Radius.circular(8)),
      gridPaint,
    );
    // Top-Right Square
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * (0.12 + sqSize + spacing), h * 0.12, w * sqSize, h * sqSize), const Radius.circular(8)),
      gridPaint,
    );
    // Bottom-Left Square
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * (0.12 + sqSize + spacing), w * sqSize, h * sqSize), const Radius.circular(8)),
      gridPaint,
    );

    // 3. Active Billing Node (Bottom Right Focus) - Vibrant White/Cyan
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Color(0xFF00FFC2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * (0.12 + sqSize + spacing), h * (0.12 + sqSize + spacing), w * sqSize, h * sqSize), const Radius.circular(8)),
      activePaint,
    );

    // 4. Glossy Reflection Overlay
    final glossPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(w * 0.05, h * 0.05)
      ..lineTo(w * 0.95, h * 0.05)
      ..lineTo(w * 0.05, h * 0.95)
      ..close();
    canvas.drawPath(path, glossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
