import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Admin/category_dialogs.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/ui_helper.dart';

class AdminHome extends StatefulWidget {
  final Function(int)? onCategoryTap;
  final VoidCallback? onElectricityTap;
  final bool isReadOnly;
  const AdminHome({super.key, this.onCategoryTap, this.onElectricityTap, this.isReadOnly = false});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final DatabaseService _dbService = DatabaseService();
  late DateTime _selectedDate;
  String _userRole = 'operator';
  
  bool _showPieChart = true;
  bool _showBarChart = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('userRole') ?? 'operator';
      });
    }
  }

  String get _selectedMonthStr => DatabaseService.formatMonthYear(_selectedDate);

  void _moveMonth(int delta) {
    DatabaseService.vibrate();
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getCategoriesStream(),
        builder: (context, catSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _dbService.getServicesStream(),
            builder: (context, serviceSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('sub_items').snapshots(),
                builder: (context, subSnap) {
                  if (!catSnap.hasData || !serviceSnap.hasData || !subSnap.hasData) return _buildShimmerHeader();
                  
                  bool hasCategories = catSnap.data!.docs.isNotEmpty;
                  bool hasServices = serviceSnap.data!.docs.isNotEmpty;
                  bool hasSubItems = subSnap.data!.docs.isNotEmpty;

                  if (!hasCategories || !hasServices || !hasSubItems) {
                    return _buildEmptyStateHome(
                      hasCategories: hasCategories,
                      hasServices: hasServices,
                      hasSubItems: hasSubItems,
                    );
                  }

                  return SingleChildScrollView(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _dbService.getDashboardVisibilityStream(_userRole),
                      builder: (context, visSnap) {
                        Map<String, bool> settings = {
                          'showAccounts': true,
                          'showElectricity': true,
                          'showMainVsSub': true,
                          'showMainVsGovt': true,
                          'showCategory': true,
                          'showTotalOccupied': true,
                          'showTotalVacant': true,
                        };

                        if (visSnap.hasData && visSnap.data!.exists) {
                          var data = visSnap.data!.data() as Map<String, dynamic>;
                          var s = data['settings'] ?? {};
                          s.forEach((k, v) => settings[k] = v as bool);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (settings['showAccounts']!) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.account_balance_wallet_outlined, size: 22, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.indigo : Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Accounts",
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold, 
                                            letterSpacing: 0.8,
                                            color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.chevron_left, size: 20, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null),
                                          onPressed: () => _moveMonth(-1),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                        Text(
                                          _selectedMonthStr,
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold, 
                                            color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.chevron_right, size: 20, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null),
                                          onPressed: () => _moveMonth(1),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _buildFinancialHeader(),
                            ],

                            if (settings['showElectricity']!)
                              _buildElectricitySection(settings),

                            if (settings['showCategory']!)
                              _buildCategorySection(settings),
                            
                            const SizedBox(height: 80),
                          ],
                        );
                      }
                    ),
                  );
                }
              );
            }
          );
        }
      ),
    );
  }

  Widget _buildElectricitySection(Map<String, bool> settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.electric_bolt, size: 20, color: context.electric),
                const SizedBox(width: 8),
                Text(
                  "Electricity",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _dbService.getBillingHistoryByMonth(_selectedMonthStr),
          builder: (context, billingSnapshot) {
            Map<String, double> paidUnitsMap = {};
            if (billingSnapshot.hasData) {
              for (var doc in billingSnapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                var ed = data['electricityDetails'];
                if (ed != null) {
                  String? meterNo = ed['mainMeterNo'];
                  if (meterNo != null) {
                    double used = ((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble();
                    if (used > 0) {
                      paidUnitsMap[meterNo] = (paidUnitsMap[meterNo] ?? 0) + used;
                    }
                  }
                }
              }
            }
            return _buildElectricitySummary(context, 
              showMainVsSub: settings['showMainVsSub'] ?? true, 
              showMainVsGovt: settings['showMainVsGovt'] ?? true,
              paidUnitsMap: paidUnitsMap,
            );
          }
        ),
      ],
    );
  }

  Widget _buildCategorySection(Map<String, bool> settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.category_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Category",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),
        _buildCategoryOverviewCard(settings),
      ],
    );
  }

  Widget _buildFinancialHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('billing_history')
          .where('monthYear', isEqualTo: _selectedMonthStr)
          .snapshots(),
      builder: (context, receivedSnapshot) {
        double receivedTotal = 0;
        double rentTotal = 0;
        if (receivedSnapshot.hasData) {
          for (var doc in receivedSnapshot.data!.docs) {
            receivedTotal += (doc['totalAmount'] as num).toDouble();
            var data = doc.data() as Map<String, dynamic>;
            List services = data.containsKey('services') ? data['services'] : [];
            for (var s in services) {
              if (s['name'].toString().toLowerCase().contains('rent')) {
                rentTotal += (s['amount'] as num).toDouble();
              }
            }
          }
        }
        double utilityTotal = receivedTotal - rentTotal;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sub_items')
              .where('status', isEqualTo: 'Occupied')
              .snapshots(),
          builder: (context, occupiedSnapshot) {
            if (!receivedSnapshot.hasData || !occupiedSnapshot.hasData) {
              return _buildShimmerHeader();
            }

            return FutureBuilder<double>(
              future: _calculateDueTotal(occupiedSnapshot.data?.docs ?? [], receivedSnapshot.data!.docs),
              builder: (context, dueSnapshot) {
                double dueTotal = dueSnapshot.data ?? 0;
                double grandTotal = receivedTotal + dueTotal;

                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 1,
                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.analytics_outlined, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.blue : Theme.of(context).colorScheme.onPrimary, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$_selectedMonthStr Total Revenue",
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (ThemeManager.appThemeNotifier.value != "Black & White Theme")
                                  _buildChartToggle(
                                    pieActive: _showPieChart,
                                    barActive: _showBarChart,
                                    onPieToggle: () => setState(() => _showPieChart = !_showPieChart),
                                    onBarToggle: () => setState(() => _showBarChart = !_showBarChart),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "৳${grandTotal.toStringAsFixed(2)}",
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900, 
                                color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.onPrimary, 
                                letterSpacing: -0.5
                              ),
                            ),
                            
                            if (ThemeManager.appThemeNotifier.value != "Black & White Theme" && (_showPieChart || _showBarChart)) 
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    if (_showPieChart)
                                      Expanded(child: SizedBox(height: 80, child: _buildPieChart(receivedTotal, dueTotal))),
                                    if (_showPieChart && _showBarChart) const SizedBox(width: 16),
                                    if (_showBarChart)
                                      Expanded(child: SizedBox(height: 80, child: _buildBarChart(rentTotal, utilityTotal, dueTotal))),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInteractiveStat(
                                    "Received", 
                                    receivedTotal, 
                                    Theme.of(context).colorScheme.onTertiaryContainer, // Enhanced for Default Theme
                                    Theme.of(context).colorScheme.tertiaryContainer,
                                    Icons.check_circle_outline,
                                    () => _showBillingDetailsPopup(context, receivedSnapshot.data!.docs, occupiedSnapshot.data!.docs, initialTab: 0)
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInteractiveStat(
                                    "Due", 
                                    dueTotal, 
                                    Theme.of(context).colorScheme.onErrorContainer, // Enhanced for Default Theme
                                    Theme.of(context).colorScheme.errorContainer,
                                    Icons.pending_actions,
                                    () => _showBillingDetailsPopup(context, receivedSnapshot.data!.docs, occupiedSnapshot.data!.docs, initialTab: 1)
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInteractiveStat(
                                    "Rent", 
                                    rentTotal, 
                                    Theme.of(context).colorScheme.onPrimaryContainer, // Enhanced for Default Theme
                                    Theme.of(context).colorScheme.primaryContainer,
                                    Icons.home_work_outlined,
                                    () => _showRentUtilityPopup(context, receivedSnapshot.data!.docs, isRent: true)
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildInteractiveStat(
                                    "Utility", 
                                    utilityTotal, 
                                    Theme.of(context).colorScheme.onSecondaryContainer, // Enhanced for Default Theme
                                    Theme.of(context).colorScheme.secondaryContainer,
                                    Icons.settings_suggest_outlined,
                                    () => _showRentUtilityPopup(context, receivedSnapshot.data!.docs, isRent: false)
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChartToggle({required bool pieActive, required bool barActive, required VoidCallback onPieToggle, required VoidCallback onBarToggle}) {
    return Row(
      children: [
        _chartIconButton(Icons.pie_chart_outline, pieActive, onPieToggle),
        const SizedBox(width: 8),
        _chartIconButton(Icons.bar_chart_outlined, barActive, onBarToggle),
      ],
    );
  }

  Widget _chartIconButton(IconData icon, bool active, VoidCallback onTap) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return InkWell(
      onTap: () {
        DatabaseService.vibrate();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (active && !isOutline) ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: (active && isOutline) ? Border.all(color: Colors.black, width: 1) : null,
        ),
        child: Icon(icon, color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary, size: 18),
      ),
    );
  }

  Widget _buildPieChart(double received, double due) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    double total = received + due;
    if (total == 0) return Center(child: Text("No Data", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onPrimary)));
    
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 20,
        sections: [
          PieChartSectionData(
            color: isOutline ? Colors.transparent : Colors.greenAccent,
            value: received,
            title: '${((received/total)*100).toStringAsFixed(0)}%',
            radius: 35,
            titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Colors.black87, fontWeight: FontWeight.bold),
            borderSide: isOutline ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
          ),
          PieChartSectionData(
            color: isOutline ? Colors.transparent : Colors.redAccent,
            value: due,
            title: '${((due/total)*100).toStringAsFixed(0)}%',
            radius: 30,
            titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
            borderSide: isOutline ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(double v1, double v2, double v3) {
    double maxVal = [v1, v2, v3].reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.3,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : Theme.of(context).colorScheme.secondary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(rod.toY.toInt().toString(), Theme.of(context).textTheme.labelSmall!.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.onSecondary));
            },
          ),
        ),
        titlesData: const FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, v1, Colors.amberAccent),
          _makeGroupData(1, v2, Colors.cyanAccent),
          _makeGroupData(2, v3, Colors.redAccent),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isOutline ? Colors.transparent : color,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          borderSide: isOutline ? BorderSide(color: color, width: 1.5) : BorderSide.none,
          backDrawRodData: BackgroundBarChartRodData(
            show: !isOutline,
            toY: y,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerHeader() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        height: 140,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildEmptyStateHome({required bool hasCategories, required bool hasServices, required bool hasSubItems}) {
    IconData headerIcon = Icons.dashboard_customize_outlined;
    String headerTitle = "Ready to start managing?";
    String headerSubtitle = "Your dashboard is empty because no categories have been added yet.";

    if (hasCategories && !hasServices) {
      headerIcon = Icons.settings_suggest_outlined;
      headerTitle = "Almost there!";
      headerSubtitle = "You have categories, but no global services are set up. Services are required to calculate bills.";
    } else if (hasCategories && hasServices && !hasSubItems) {
      headerIcon = Icons.add_home_work_outlined;
      headerTitle = "One last step!";
      headerSubtitle = "You have categories and services, but no units (rooms/shops) have been added yet.";
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(headerIcon, size: 80, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 32),
            Text(
              headerTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              headerSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildGuidanceCard(
              title: "Step 1: Add a Category",
              subtitle: "Create groups like 'Shop', 'Room' or 'Flat' to organize your items.",
              icon: Icons.category_outlined,
              color: !hasCategories ? Colors.blue : Colors.grey,
              actionText: !hasCategories ? "Go to Manage Tab" : "Category Added",
              isHighlighted: !hasCategories,
              onAction: () => widget.onCategoryTap?.call(0),
            ),
            const SizedBox(height: 16),
            _buildGuidanceCard(
              title: "Step 2: Setup Services",
              subtitle: "Define monthly charges like Rent, Wifi, or Trash in the Services menu.",
              icon: Icons.settings_suggest_outlined,
              color: hasCategories && !hasServices ? Colors.orange : Colors.grey,
              actionText: hasCategories && !hasServices ? "Open Services Menu" : "Services Ready",
              isHighlighted: hasCategories && !hasServices,
              onAction: () => CategoryDialogs.showAddServiceDialog(context),
            ),
            const SizedBox(height: 16),
            _buildGuidanceCard(
              title: "Step 3: Add Units",
              subtitle: "Add specific shops or rooms to your categories to start billing.",
              icon: Icons.add_business_outlined,
              color: hasCategories && hasServices && !hasSubItems ? Colors.teal : Colors.grey,
              actionText: hasCategories && hasServices && !hasSubItems ? "Go to Manage Tab" : "Units Ready",
              isHighlighted: hasCategories && hasServices && !hasSubItems,
              onAction: () => widget.onCategoryTap?.call(0),
            ),
            const SizedBox(height: 32),
            Text(
              "Welcome! Please complete the configuration steps above.",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.secondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color, 
    required String actionText, 
    required VoidCallback onAction,
    bool isHighlighted = false,
  }) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Card(
      elevation: isHighlighted ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), 
        side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
            ? BorderSide(color: color, width: 1.5) 
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOutline ? Colors.transparent : color.withOpacity(0.1), 
                  child: Icon(icon, color: color, size: 20),
                  foregroundColor: color,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : (isHighlighted ? null : Colors.grey))),
                      Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(isHighlighted ? 1.0 : 0.5))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppDialogActions(
              actions: [
                AppButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighlighted ? color : (ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : Colors.grey.shade300),
                    foregroundColor: isHighlighted ? Colors.white : (ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Colors.grey),
                    side: (ThemeManager.appThemeNotifier.value == "Outline Theme") ? BorderSide(color: isHighlighted ? color : Colors.black, width: 1.5) : null,
                    elevation: isHighlighted ? 2 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(actionText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryOverviewCard(Map<String, bool> settings) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sub_items').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildShimmerHeader();

        int totalDocs = snapshot.data!.docs.length;
        int occupiedCount = 0;
        int vacantCount = 0;

        for (var doc in snapshot.data!.docs) {
          var d = doc.data() as Map<String, dynamic>;
          String status = d['status'] ?? 'Vacant'; // Strict status check
          if (status == 'Occupied') {
            occupiedCount++;
          } else {
            vacantCount++;
          }
        }

        return Column(
          children: [
            const SizedBox(height: 16),
            Center(
              child: Text(
                "Total Units: $totalDocs (In System)",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold, 
                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Overall Summary Row (Static Cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (settings['showTotalOccupied'] ?? true)
                    Expanded(
                      child: _buildSubOverviewCard(
                        title: "Total Occupied",
                        count: occupiedCount,
                        color: ThemeManager.getCardColor(0),
                        icon: Icons.door_front_door_outlined,
                        onTap: () {
                          DatabaseService.vibrate();
                          widget.onCategoryTap?.call(0);
                        },
                      ),
                    ),
                  if ((settings['showTotalOccupied'] ?? true) && (settings['showTotalVacant'] ?? true))
                    const SizedBox(width: 12),
                  if (settings['showTotalVacant'] ?? true)
                    Expanded(
                      child: _buildSubOverviewCard(
                        title: "Total Vacant",
                        count: vacantCount,
                        color: ThemeManager.getCardColor(1),
                        countColor: Colors.red,
                        icon: Icons.meeting_room_outlined,
                        onTap: () {
                          DatabaseService.vibrate();
                          widget.onCategoryTap?.call(1);
                        },
                      ),
                    ),
                ],
              ),
            ),
            // Static Category List
            if (settings['showCategory']!)
              StreamBuilder<QuerySnapshot>(
                stream: _dbService.getCategoriesStream(),
                builder: (context, catSnap) {
                  if (!catSnap.hasData) return const SizedBox.shrink();
                  var allCategories = catSnap.data!.docs.toList();
                  allCategories.sort((a, b) => ((a.data() as Map)['categoryName'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['categoryName'] ?? '').toString().toLowerCase()));
                  
                  // Filter based on individual category visibility settings
                  var visibleCategories = allCategories.where((catDoc) {
                    return settings['cat_${catDoc.id}'] ?? true;
                  }).toList();

                  return Column(
                    children: visibleCategories.asMap().entries.map<Widget>((entry) {
                      return _buildCategorySolidCard(entry.value, entry.key);
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildNestedStatItem(String label, int count, Color color, {VoidCallback? onTap}) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : null)),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900, 
              color: (isOutline && color != Colors.red) ? Colors.black : color
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubOverviewCard({required String title, required int count, required Color color, required IconData icon, required VoidCallback onTap, Color? countColor}) {
    return Card(
      elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
            ? BorderSide(color: color, width: 1.5) 
            : BorderSide.none
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : color)),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900, 
                  color: (ThemeManager.appThemeNotifier.value == "Outline Theme" && countColor != Colors.red) ? Colors.black : (countColor ?? color)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStat(String label, double amount, Color color, Color bgColor, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
      margin: EdgeInsets.zero,
      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
            ? BorderSide(color: color, width: 1.5) 
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          DatabaseService.vibrate();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : color.withValues(alpha: 0.8))),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "৳${amount.toStringAsFixed(0)}",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedMeterTable({
    required String title,
    required List<String> headers,
    required List<QueryDocumentSnapshot> meters,
    required List<Widget> Function(Map<String, dynamic> data, int index) rowBuilder,
    required Color containerColor,
    required Color accentColor,
    required IconData titleIcon,
  }) {
    final headerTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: (ThemeManager.appThemeNotifier.value == "Outline Theme")
                ? BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(titleIcon, size: 18, color: (ThemeManager.appThemeNotifier.value == "Outline Theme") ? Theme.of(context).colorScheme.primary : context.electric),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: (ThemeManager.appThemeNotifier.value == "Outline Theme") ? Colors.black : Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: widget.isReadOnly ? null : () {
            DatabaseService.vibrate();
            widget.onElectricityTap?.call();
          },
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
            color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : containerColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                  ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                  : BorderSide.none,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  alignment: Alignment.center,
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: const TableBorder(
                      verticalInside: BorderSide.none,
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : accentColor,
                          border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)) : null,
                        ),
                        children: headers.map((h) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(child: Text(h, textAlign: TextAlign.center, style: headerTextStyle?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null))),
                        )).toList(),
                      ),
                      ...List.generate(meters.length, (index) {
                        var doc = meters[index];
                        var data = doc.data() as Map<String, dynamic>;
                        var rows = rowBuilder(data, index);
                        
                        return TableRow(
                          decoration: BoxDecoration(
                            color: (ThemeManager.appThemeNotifier.value == "Outline Theme") 
                                ? Colors.white 
                                : (index % 2 == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent),
                          ),
                          children: rows.map((cell) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Center(child: cell),
                          )).toList(),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildElectricitySummary(BuildContext context, {bool showMainVsSub = true, bool showMainVsGovt = true, Map<String, double>? paidUnitsMap}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getMainMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildShimmerList(); 
        var mainMeters = snapshot.data!.docs.toList();
        mainMeters.sort((a, b) => ((a.data() as Map)['meterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['meterNo'] ?? '').toString().toLowerCase()));

        if (mainMeters.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("No Main Meters found.", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          );
        }

        return Column(
          children: [
            if (showMainVsSub)
              _buildUnifiedMeterTable(
                title: "Main Meter Vs Sub Meter",
                titleIcon: Icons.balance,
                containerColor: Theme.of(context).colorScheme.secondaryContainer,
                accentColor: Theme.of(context).colorScheme.secondary,
                headers: ["#", "Meter\nNumber", "Main Meter\nUsed Units", "Sub-Meter\nTotal Units", "This Month\nUnit Rate", "Balance\nUnits"],
                meters: mainMeters,
                rowBuilder: (data, index) {
                  double last = (data['lastReading'] as num?)?.toDouble() ?? 0;
                  double present = (data['presentReading'] ?? last).toDouble();
                  double mainUsed = present - last;
                  String meterNo = data['meterNo'] ?? 'N/A';
                  double totalSubPaid = (paidUnitsMap != null) ? (paidUnitsMap[meterNo] ?? 0) : 0;
                  double unitRate = (data['unitRate'] as num?)?.toDouble() ?? 0;
                  double balance = mainUsed - totalSubPaid;
                  
                  return [
                    Text("${index + 1}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(meterNo, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(mainUsed.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(totalSubPaid.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text("৳${unitRate.toStringAsFixed(2)}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(
                      balance.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: balance > 0 ? Colors.red : (ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ];
                },
              ),
            if (showMainVsGovt)
              _buildUnifiedMeterTable(
                title: "Main Meter Vs Govt. Bill",
                titleIcon: Icons.receipt_long,
                containerColor: Theme.of(context).colorScheme.primaryContainer,
                accentColor: Theme.of(context).colorScheme.primary,
                headers: ["#", "Meter\nNumber", "Main Meter\nReadings", "Govt. Bill\nReadings", "Balance\nUnits"],
                meters: mainMeters,
                rowBuilder: (data, index) {
                  double present = (data['presentReading'] as num?)?.toDouble() ?? 0;
                  double govtPresent = (data['govtBillReading'] as num?)?.toDouble() ?? 0;
                  double balance = present - govtPresent;
                  
                  String suffix = "";
                  if (balance < 0) suffix = "(A)";
                  else if (balance > 0) suffix = "(D)";
                  bool isRed = balance != 0;

                  return [
                    Text("${index + 1}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(data['meterNo'] ?? 'N/A', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(present.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(govtPresent.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : null)),
                    Text(
                      "${balance.toStringAsFixed(1)}$suffix",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isRed ? Colors.red : (ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary),
                        fontWeight: isRed ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ];
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySolidCard(QueryDocumentSnapshot catDoc, int index) {
    String catId = catDoc.id;
    String catName = (catDoc.data() as Map)['categoryName'] ?? 'Unnamed';
    
    final Color accentColor = ThemeManager.getCardColor(index);
    final Color bgColor = ThemeManager.getCardContainerColor(index);

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getSubItemsStream(catId),
      builder: (context, subSnap) {
        int total = 0;
        int occupied = 0;
        int vacant = 0;

        if (subSnap.hasData) {
          total = subSnap.data!.docs.length;
          for (var doc in subSnap.data!.docs) {
            var d = doc.data() as Map<String, dynamic>;
            String status = d['status'] ?? 'Vacant'; // Strict status check
            if (status == 'Occupied') occupied++; else vacant++;
          }
        }

        return Card(
          elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
          color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : bgColor,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                ? BorderSide(color: accentColor, width: 1.5) 
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : accentColor,
                  child: Container(
                    decoration: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentColor, width: 1)) 
                        : null,
                    alignment: Alignment.center,
                    child: Icon(Icons.category_outlined, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? accentColor : Theme.of(context).colorScheme.onTertiary, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    catName.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900, 
                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : ThemeManager.getCardOnContainerColor(index), 
                      letterSpacing: 0.5
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildNestedStatItem("Total", total, ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : ThemeManager.getCardOnContainerColor(index)),
                const SizedBox(width: 12),
                _buildNestedStatItem("Occupied", occupied, Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                _buildNestedStatItem("Vacant", vacant, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(3, (index) => Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20)),
          )),
        ),
      ),
    );
  }

  void _showBillingDetailsPopup(BuildContext context, List<QueryDocumentSnapshot> receivedDocs, List<QueryDocumentSnapshot> occupiedDocs, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isOutline ? Colors.white : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
          ),
          child: DefaultTabController(
            length: 2,
            initialIndex: initialTab,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        "$_selectedMonthStr Revenue Details",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.check_circle_outline), text: "Received"),
                    Tab(icon: Icon(Icons.pending_actions), text: "Due (Occupied)"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildReceivedList(receivedDocs),
                      _buildDueList(occupiedDocs, receivedDocs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRentUtilityPopup(BuildContext context, List<QueryDocumentSnapshot> receivedDocs, {required bool isRent}) {
    final Color themeColor = isRent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isOutline ? Colors.white : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: isOutline ? Border.all(color: themeColor, width: 2) : null,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isRent ? Icons.home_work_outlined : Icons.settings_suggest_outlined, color: themeColor),
                    const SizedBox(width: 8),
                    Text(
                      "$_selectedMonthStr ${isRent ? 'Rent' : 'Utility'} Details",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: themeColor),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: receivedDocs.length,
                  itemBuilder: (context, index) {
                    var data = receivedDocs[index].data() as Map<String, dynamic>;
                    String subId = data['subItemId'];
                    
                    double rent = 0;
                    List services = data.containsKey('services') ? data['services'] : [];
                    for (var s in services) {
                      if (s['name'].toString().toLowerCase().contains('rent')) {
                        rent += (s['amount'] as num).toDouble();
                      }
                    }
                    double amountToShow = isRent ? rent : (data['totalAmount'] as num).toDouble() - rent;

                    if (amountToShow <= 0) return const SizedBox.shrink();

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('sub_items').doc(subId).get(),
                      builder: (context, snap) {
                        String categoryName = "Loading...";
                        String resolvedSubName = data['subItemName'] ?? '...';

                        if (snap.hasData && snap.data!.exists) {
                          if (data['subItemName'] == null) {
                            resolvedSubName = snap.data!['subItemName'] ?? 'Unnamed';
                          }
                          String catId = snap.data!['categoryId'] ?? '';
                          return FutureBuilder<DocumentSnapshot>(
                            future: _dbService.getCategoryById(catId),
                            builder: (context, catSnap) {
                              categoryName = (catSnap.data?.data() as Map?)?['categoryName'] ?? 'Unknown';
                              String tName = data['TenantName'] ?? snap.data!['TenantName'] ?? 'No Name';
                              
                              return _buildBillingTile(
                                index: index,
                                title: "$resolvedSubName ($tName)",
                                subtitle: categoryName,
                                amount: amountToShow,
                                color: themeColor,
                                icon: isRent ? Icons.home_work_outlined : Icons.settings_suggest_outlined,
                                paidBy: data['paidBy'],
                                paidAt: data['paidAt'],
                                notes: data['paymentNotes'],
                                onTap: () => _showItemDetailDialog(context, data, resolvedSubName, tName, categoryName, mode: isRent ? 'rent' : 'utility'),
                              );
                            },
                          );
                        }
                        String tName = data['TenantName'] ?? 'No Name';
                        return _buildBillingTile(
                          index: index,
                          title: "$resolvedSubName ($tName)",
                          subtitle: categoryName,
                          amount: amountToShow,
                          color: themeColor,
                          icon: isRent ? Icons.home_work_outlined : Icons.settings_suggest_outlined,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceivedList(List<QueryDocumentSnapshot> receivedDocs) {
    if (receivedDocs.isEmpty) return _buildEmptyState("No payments received for $_selectedMonthStr.");

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: receivedDocs.length,
      itemBuilder: (context, index) {
        var data = receivedDocs[index].data() as Map<String, dynamic>;
        String subId = data['subItemId'];
        
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('sub_items').doc(subId).get(),
          builder: (context, snap) {
            String categoryName = "Loading...";
            String resolvedSubName = data['subItemName'] ?? '...';

            if (snap.hasData && snap.data!.exists) {
              if (data['subItemName'] == null) {
                resolvedSubName = snap.data!['subItemName'] ?? 'Unnamed';
              }
              String catId = snap.data!['categoryId'] ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: _dbService.getCategoryById(catId),
                builder: (context, catSnap) {
                  categoryName = (catSnap.data?.data() as Map?)?['categoryName'] ?? 'Unknown';
                  String tName = data['TenantName'] ?? snap.data!['TenantName'] ?? 'No Name';

                  return _buildBillingTile(
                    index: index,
                    title: "$resolvedSubName ($tName)",
                    subtitle: categoryName,
                    amount: (data['totalAmount'] as num).toDouble(),
                    color: Theme.of(context).colorScheme.tertiary,
                    icon: Icons.check_circle_outline,
                    paidBy: data['paidBy'],
                    paidAt: data['paidAt'],
                    notes: data['paymentNotes'],
                    onTap: () => _showItemDetailDialog(context, data, resolvedSubName, tName, categoryName, mode: 'all'),
                  );
                },
              );
            }
            String tName = data['TenantName'] ?? 'No Name';
            return _buildBillingTile(
              index: index,
              title: "$resolvedSubName ($tName)",
              subtitle: categoryName,
              amount: (data['totalAmount'] as num).toDouble(),
              color: Theme.of(context).colorScheme.tertiary,
              icon: Icons.check_circle_outline,
            );
          },
        );
      },
    );
  }

  Widget _buildDueList(List<QueryDocumentSnapshot> occupiedDocs, List<QueryDocumentSnapshot> receivedDocs) {
    if (_selectedDate.isAfter(DateTime.now())) return _buildEmptyState("Future bills are not generated yet.");

    List<String> paidSubIds = receivedDocs.map((doc) => doc['subItemId'].toString()).toList();
    DateTime monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

    // Strictly filter by Occupied status per instructions
    var dueItems = occupiedDocs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      String status = data['status'] ?? '';
      Timestamp? occupiedAt = data['occupiedAt'] as Timestamp?;
      bool wasOccupiedInOrBeforeSelectedMonth = occupiedAt != null && occupiedAt.toDate().isBefore(monthEnd);
      return status == 'Occupied' && wasOccupiedInOrBeforeSelectedMonth && !paidSubIds.contains(doc.id);
    }).toList();

    if (dueItems.isEmpty) return _buildEmptyState("All units have paid for $_selectedMonthStr!");

    final Color dueColor = Theme.of(context).colorScheme.error;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dueItems.length,
      itemBuilder: (context, index) {
        var doc = dueItems[index];
        var data = doc.data() as Map<String, dynamic>;
        String catId = data['categoryId'] ?? '';

        return FutureBuilder<DocumentSnapshot>(
          future: _dbService.getCategoryById(catId),
          builder: (context, catSnap) {
            String categoryName = (catSnap.data?.data() as Map?)?['categoryName'] ?? 'Loading...';
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('sub_items').doc(doc.id).get(),
              builder: (context, subSnap) {
                String tName = 'No Name';
                if (subSnap.hasData && subSnap.data!.exists) {
                  tName = subSnap.data!['TenantName'] ?? 'No Name';
                }
                return FutureBuilder<double>(
                  future: _calculateSingleDue(doc),
                  builder: (context, amountSnap) {
                    double amount = amountSnap.data ?? 0;
                    return _buildBillingTile(
                      index: index,
                      title: "${data['subItemName']} ($tName)",
                      subtitle: categoryName,
                      amount: amount,
                      color: dueColor,
                      icon: Icons.pending_actions,
                      onTap: () async {
                        var catDoc = await _dbService.getCategoryById(catId);
                        List catServices = (catDoc.data() as Map<String, dynamic>?)?['assignedServices'] ?? [];
                        List excluded = data['excludedServices'] ?? [];
                        List overridden = data['overriddenServices'] ?? [];
                        List active = DatabaseService.getEffectiveServices(categoryServices: catServices, excludedServices: excluded, overriddenServices: overridden);
                        
                        Map<String, dynamic> virtualData = {
                          'monthYear': _selectedMonthStr,
                          'TenantName': tName,
                          'nidNumber': data['nidNumber'] ?? '',
                          'services': active,
                          'electricityDetails': data['electricityDetails'],
                          'electricityBill': (amount - active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble())),
                          'totalAmount': amount,
                          'houseRentTotal': amount - (amount - active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble())),
                        };
                        if (context.mounted) _showItemDetailDialog(context, virtualData, data['subItemName'] ?? 'Unnamed', tName, categoryName, mode: 'all');
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBillingTile({
    required int index, 
    required String title, 
    required String subtitle, 
    required double amount, 
    required Color color, 
    required IconData icon, 
    VoidCallback? onTap,
    String? paidBy,
    Timestamp? paidAt,
    String? notes,
  }) {
    // Soft-coded, readable background based on theme
    Color itemColor = ThemeManager.getCardContainerColor(index + 7, alpha: 0.8, isSubCard: true);
    // Ensure readable text color by using the contrast/onContainer color from theme
    Color textColor = ThemeManager.getCardOnContainerColor(index + 7, isSubCard: true);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: itemColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
            ? BorderSide(color: color, width: 1.5) 
            : BorderSide.none
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.white : color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 22),
          foregroundColor: color,
        ),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.7), letterSpacing: 0.5)),
            if (paidBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.person_pin_outlined, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text("By: $paidBy", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (paidAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  DatabaseService.formatFullDateTime(paidAt), 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10, 
                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : textColor.withOpacity(0.6)
                  )
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "৳${amount.toStringAsFixed(0)}",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 12, color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showItemDetailDialog(BuildContext context, Map<String, dynamic> data, String subName, String tenantName, String catName, {required String mode}) {
    List allServices = data['services'] ?? [];
    List displayServices = [];
    double displayTotal = 0;
    bool showElec = false;
    Color modeColor = Theme.of(context).colorScheme.primary;
    
    if (mode == 'rent') {
      displayServices = allServices.where((s) => s['name'].toString().toLowerCase().contains('rent')).toList();
      displayTotal = displayServices.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());
      modeColor = Theme.of(context).colorScheme.primary;
    } else if (mode == 'utility') {
      displayServices = allServices.where((s) => !s['name'].toString().toLowerCase().contains('rent')).toList();
      double elec = (data['electricityBill'] as num?)?.toDouble() ?? 0;
      displayTotal = displayServices.fold(elec, (acc, s) => acc + (s['amount'] as num).toDouble());
      showElec = true;
      modeColor = Theme.of(context).colorScheme.secondary;
    } else {
      displayServices = allServices;
      displayTotal = (data['totalAmount'] as num).toDouble();
      showElec = true;
      modeColor = Theme.of(context).colorScheme.tertiary; // Received mode
      if (data['paidAt'] == null) modeColor = Theme.of(context).colorScheme.error; // Due mode
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: modeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(mode.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: modeColor, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(subName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: modeColor, fontWeight: FontWeight.w900)),
            Text("$tenantName | $catName", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            const Divider(height: 32),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showElec && data['electricityBill'] != null && (data['electricityBill'] as num).toDouble() > 0) ...[
                  _buildSectionHeader(context, "Electricity", Icons.electric_bolt, context.electric),
                  const SizedBox(height: 12),
                  if (data['electricityDetails'] != null) ...[
                    _buildDetailRow(context, "Meter No:", data['electricityDetails']['subMeterNo'] ?? 'N/A'),
                    _buildDetailRow(context, "Reading Range:", "${data['electricityDetails']['lastReading']} ➔ ${data['electricityDetails']['presentReading']}"),
                    _buildDetailRow(context, "Unit Rate:", "৳${(data['electricityDetails']['pricePerUnit'] as num?)?.toDouble().toStringAsFixed(2)}"),
                  ],
                  _buildDetailRow(context, "Total Usage Bill:", "৳${(data['electricityBill'] as num?)?.toDouble().toStringAsFixed(2)}", isBold: true, color: context.electric),
                  const Divider(height: 32),
                ],
                if (displayServices.isNotEmpty) ...[
                  _buildSectionHeader(context, mode == 'rent' ? "House Rent" : "Service Charges", mode == 'rent' ? Icons.home_work : Icons.list_alt, modeColor),
                  const SizedBox(height: 12),
                  ...displayServices.map((s) {
                    String name = s['name'] ?? 'Service';
                    if (name.toLowerCase().contains('wifi') && s['deviceQuantity'] != null) {
                      name = "$name (x${s['deviceQuantity']})";
                    }
                    return _buildDetailRow(context, name, "৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}");
                  }),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [modeColor, modeColor.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: modeColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("GRAND TOTAL", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text("৳${displayTotal.toStringAsFixed(2)}", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if (data['paidBy'] != null || data['paidAt'] != null) ...[
                  const Divider(height: 32),
                  _buildSectionHeader(context, "Payment Confirmation", Icons.verified_user_outlined, Colors.blueGrey),
                  const SizedBox(height: 8),
                  if (data['paidBy'] != null) _buildDetailRow(context, "Collected by:", data['paidBy']),
                  if (data['paidAt'] != null) _buildDetailRow(context, "Time:", DatabaseService.formatFullDateTime(data['paidAt'])),
                ],
              ],
            ),
          ),
        ),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: modeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                ),
                onPressed: () => Navigator.pop(context), 
                child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Future<double> _calculateDueTotal(List<QueryDocumentSnapshot> occupied, List<QueryDocumentSnapshot> received) async {
    if (_selectedDate.isAfter(DateTime.now())) return 0;

    List<String> paidIds = received.map((d) => d['subItemId'].toString()).toList();
    double totalDue = 0;
    
    DateTime monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

    for (var doc in occupied) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? occupiedAt = data['occupiedAt'] as Timestamp?;
      
      bool wasOccupiedInOrBeforeSelectedMonth = occupiedAt != null && occupiedAt.toDate().isBefore(monthEnd);

      if (wasOccupiedInOrBeforeSelectedMonth && !paidIds.contains(doc.id)) {
        totalDue += await _calculateSingleDue(doc);
      }
    }
    return totalDue;
  }

  Future<double> _calculateSingleDue(QueryDocumentSnapshot subDoc) async {
    var subData = subDoc.data() as Map<String, dynamic>;
    String catId = subData['categoryId'] ?? '';
    if (catId.isEmpty) return 0;

    DocumentSnapshot catDoc = await _dbService.getCategoryById(catId);
    if (!catDoc.exists) return 0;

    List categoryServices = (catDoc.data() as Map)['assignedServices'] ?? [];
    List excluded = subData['excludedServices'] ?? [];
    List overridden = subData['overriddenServices'] ?? [];

    List<Map<String, dynamic>> active = DatabaseService.getEffectiveServices(
      categoryServices: categoryServices,
      excludedServices: excluded,
      overriddenServices: overridden,
    );

    double servicesSum = active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());
    
    var ed = subData['electricityDetails'];
    double eBill = 0;
    if (ed != null && ed['isStopped'] != true) {
      double last = (ed['lastReading'] as num?)?.toDouble() ?? 0;
      double present = (ed['presentReading'] as num?)?.toDouble() ?? 0;
      double rate = (ed['pricePerUnit'] as num?)?.toDouble() ?? 0;
      eBill = (present - last) * rate;
    }

    return servicesSum + eBill;
  }
}
