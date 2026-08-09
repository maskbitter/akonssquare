import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Admin/category_dialogs.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      body: SingleChildScrollView(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings['showAccounts']!) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 22, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              "Accounts",
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              onPressed: () => _moveMonth(-1),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            Text(
                              _selectedMonthStr,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
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
      ),
    );
  }

  Widget _buildElectricitySection(Map<String, bool> settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: widget.isReadOnly ? null : widget.onElectricityTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Icon(Icons.electric_bolt_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Electricity",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),
        _buildElectricitySummary(context, 
          showMainVsSub: settings['showMainVsSub'] ?? true, 
          showMainVsGovt: settings['showMainVsGovt'] ?? true),
      ],
    );
  }

  Widget _buildCategorySection(Map<String, bool> settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
          child: Row(
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
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$_selectedMonthStr Total Revenue",
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
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
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onPrimary, letterSpacing: -0.5),
                            ),
                            
                            if (_showPieChart || _showBarChart) 
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
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInteractiveStat("Received", receivedTotal, Theme.of(context).colorScheme.tertiary, Icons.check_circle_outline,
                                    () => _showBillingDetailsPopup(context, receivedSnapshot.data!.docs, occupiedSnapshot.data!.docs, initialTab: 0)),
                                Container(width: 1, height: 24, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2)),
                                _buildInteractiveStat("Due", dueTotal, Theme.of(context).colorScheme.error, Icons.pending_actions,
                                    () => _showBillingDetailsPopup(context, receivedSnapshot.data!.docs, occupiedSnapshot.data!.docs, initialTab: 1)),
                              ],
                            ),
                            Divider(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2), height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInteractiveStat("Rent", rentTotal, Theme.of(context).colorScheme.onPrimary, Icons.home_work_outlined,
                                    () => _showRentUtilityPopup(context, receivedSnapshot.data!.docs, isRent: true)),
                                Container(width: 1, height: 24, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2)),
                                _buildInteractiveStat("Utility", utilityTotal, Theme.of(context).colorScheme.secondary, Icons.settings_suggest_outlined,
                                    () => _showRentUtilityPopup(context, receivedSnapshot.data!.docs, isRent: false)),
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
    return InkWell(
      onTap: () {
        DatabaseService.vibrate();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 18),
      ),
    );
  }

  Widget _buildPieChart(double received, double due) {
    double total = received + due;
    if (total == 0) return Center(child: Text("No Data", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary)));
    
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 20,
        sections: [
          PieChartSectionData(
            color: Theme.of(context).colorScheme.tertiary,
            value: received,
            title: '${((received/total)*100).toStringAsFixed(0)}%',
            radius: 35,
            titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onTertiary, fontWeight: FontWeight.bold),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.2), width: 1),
          ),
          PieChartSectionData(
            color: Theme.of(context).colorScheme.error,
            value: due,
            title: '${((due/total)*100).toStringAsFixed(0)}%',
            radius: 30,
            titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onError, fontWeight: FontWeight.bold),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onError.withOpacity(0.2), width: 1),
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
            getTooltipColor: (_) => Theme.of(context).colorScheme.secondary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(rod.toY.toInt().toString(), Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.white));
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
          _makeGroupData(0, v1, Theme.of(context).colorScheme.onPrimary),
          _makeGroupData(1, v2, Theme.of(context).colorScheme.secondary),
          _makeGroupData(2, v3, Theme.of(context).colorScheme.error),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          borderSide: BorderSide(color: color.withValues(alpha: 0.8), width: 1),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
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
          String status = d['status'] ?? ((d['tenantName'] ?? '').toString().isNotEmpty ? 'Occupied' : 'Vacant');
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
                        color: Theme.of(context).colorScheme.tertiary,
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
                        color: Theme.of(context).colorScheme.error,
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
                  var allCategories = catSnap.data!.docs;
                  
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
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSubOverviewCard({required String title, required int count, required Color color, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.3), width: 1.2)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStat(String label, double amount, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        DatabaseService.vibrate();
        onTap();
      },
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Theme.of(context).colorScheme.onPrimary),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
            ],
          ),
          Text(
            "৳${amount.toStringAsFixed(0)}",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            children: [
              Icon(titleIcon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        Card(
          elevation: 2,
          color: containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor, width: 1)
          ),
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
                  border: TableBorder(
                    verticalInside: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), width: 1),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: accentColor,
                        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), width: 0.5))
                      ),
                      children: headers.map((h) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(child: Text(h, textAlign: TextAlign.center, style: headerTextStyle)),
                      )).toList(),
                    ),
                    ...List.generate(meters.length, (index) {
                      var doc = meters[index];
                      var data = doc.data() as Map<String, dynamic>;
                      var rows = rowBuilder(data, index);
                      
                      return TableRow(
                        decoration: BoxDecoration(
                          color: index % 2 == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent,
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
      ],
    );
  }

  Widget _buildElectricitySummary(BuildContext context, {bool showMainVsSub = true, bool showMainVsGovt = true}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getMainMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildShimmerList(); 
        var mainMeters = snapshot.data!.docs;

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
                containerColor: Theme.of(context).colorScheme.primaryContainer,
                accentColor: Theme.of(context).colorScheme.primary,
                headers: ["#", "Meter\nNumber", "Main Meter\nUsed Units", "Sub-Meter\nTotal Units", "This Month\nUnit Rate", "Balance Units"],
                meters: mainMeters,
                rowBuilder: (data, index) {
                  double last = (data['lastReading'] as num?)?.toDouble() ?? 0;
                  double present = (data['presentReading'] ?? last).toDouble();
                  double mainUsed = present - last;
                  double totalSubPaid = (data['totalSubPaidUnits'] ?? 0).toDouble();
                  double unitRate = (data['unitRate'] as num?)?.toDouble() ?? 0;
                  double balance = mainUsed - totalSubPaid;
                  
                  return [
                    Text("${index + 1}", style: Theme.of(context).textTheme.bodyMedium),
                    Text(data['meterNo'] ?? 'N/A', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(mainUsed.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium),
                    Text(totalSubPaid.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium),
                    Text("৳${unitRate.toStringAsFixed(2)}", style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      balance.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: balance > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
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
                containerColor: Theme.of(context).colorScheme.secondaryContainer,
                accentColor: Theme.of(context).colorScheme.secondary,
                headers: ["#", "Meter\nNumber", "Main Meter\nReadings", "Govt. Bill\nReadings", "Balance Units"],
                meters: mainMeters,
                rowBuilder: (data, index) {
                  double present = (data['presentReading'] as num?)?.toDouble() ?? 0;
                  double govtPresent = (data['govtBillReading'] as num?)?.toDouble() ?? 0;
                  double balance = govtPresent - present;
                  bool isAlert = balance < -5 || balance > 100;

                  return [
                    Text("${index + 1}", style: Theme.of(context).textTheme.bodyMedium),
                    Text(data['meterNo'] ?? 'N/A', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(present.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium),
                    Text(govtPresent.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      balance.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isAlert ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                        fontWeight: isAlert ? FontWeight.bold : FontWeight.normal,
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
    
    // Assign rotating containers based on index to ensure visual difference
    final List<Color> bgColors = [
      Theme.of(context).colorScheme.primaryContainer, 
      Theme.of(context).colorScheme.secondaryContainer, 
      Theme.of(context).colorScheme.tertiaryContainer,
    ];
    final List<Color> accentColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
    ];
    
    int idx = index % bgColors.length;
    final Color bgColor = bgColors[idx];
    final Color accentColor = accentColors[idx];

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
            String status = d['status'] ?? ((d['tenantName'] ?? '').toString().isNotEmpty ? 'Occupied' : 'Vacant');
            if (status == 'Occupied') occupied++; else vacant++;
          }
        }

        return Card(
          elevation: 2,
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor.withOpacity(0.1), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor,
                  child: Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.onTertiary, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    catName.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: accentColor, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildNestedStatItem("Total", total, accentColor),
                const SizedBox(width: 12),
                _buildNestedStatItem("Occupied", occupied, Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                _buildNestedStatItem("Vacant", vacant, Theme.of(context).colorScheme.error),
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
            margin: const EdgeInsets.only(bottom: 12),
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
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
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
                        style: Theme.of(context).textTheme.titleLarge,
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
                    Tab(icon: Icon(Icons.pending_actions), text: "Due"),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
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
                    Icon(isRent ? Icons.home_work_outlined : Icons.settings_suggest_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      "$_selectedMonthStr ${isRent ? 'Rent' : 'Utility'} Details",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
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
                                color: isRent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
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
                          color: isRent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
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
                    color: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.primary,
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

    var dueItems = occupiedDocs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? occupiedAt = data['occupiedAt'] as Timestamp?;
      bool wasOccupiedInOrBeforeSelectedMonth = occupiedAt != null && occupiedAt.toDate().isBefore(monthEnd);
      return wasOccupiedInOrBeforeSelectedMonth && !paidSubIds.contains(doc.id);
    }).toList();

    if (dueItems.isEmpty) return _buildEmptyState("All units have paid for $_selectedMonthStr!");

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
                      color: Theme.of(context).colorScheme.error,
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
    final List<Color> pastelColors = [
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer,
      Theme.of(context).colorScheme.tertiaryContainer,
      Theme.of(context).colorScheme.surfaceContainer,
      Theme.of(context).colorScheme.surfaceContainerHigh,
      Theme.of(context).colorScheme.surfaceContainerHighest,
      Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
      Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.7),
    ];
    Color itemColor = pastelColors[index % pastelColors.length];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: itemColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.15), width: 1)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (paidBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Paid by: $paidBy", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ),
            if (paidAt != null)
              Text("Time: ${DatabaseService.formatFullDateTime(paidAt)}", style: Theme.of(context).textTheme.labelSmall),
            if (notes != null && notes.isNotEmpty)
              Text("Note: $notes", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "৳${amount.toStringAsFixed(2)}",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    
    if (mode == 'rent') {
      displayServices = allServices.where((s) => s['name'].toString().toLowerCase().contains('rent')).toList();
      displayTotal = displayServices.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());
    } else if (mode == 'utility') {
      displayServices = allServices.where((s) => !s['name'].toString().toLowerCase().contains('rent')).toList();
      double elec = (data['electricityBill'] as num?)?.toDouble() ?? 0;
      displayTotal = displayServices.fold(elec, (acc, s) => acc + (s['amount'] as num).toDouble());
      showElec = true;
    } else {
      displayServices = allServices;
      displayTotal = (data['totalAmount'] as num).toDouble();
      showElec = true;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(subName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
            Text("$tenantName | $catName", style: Theme.of(context).textTheme.bodyMedium),
            const Divider(height: 24),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showElec && data['electricityDetails'] != null) ...[
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: Theme.of(context).colorScheme.secondary, size: 16),
                      const SizedBox(width: 8),
                      Text("Electricity Breakdown", style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, "Meter No:", data['electricityDetails']['subMeterNo'] ?? 'N/A'),
                  _buildDetailRow(context, "Reading:", "${data['electricityDetails']['lastReading']} -> ${data['electricityDetails']['presentReading']}"),
                  _buildDetailRow(context, "Unit Rate:", "৳${(data['electricityDetails']['pricePerUnit'] as num?)?.toDouble().toStringAsFixed(2)}"),
                  _buildDetailRow(context, "Bill Amount:", "৳${(data['electricityBill'] as num?)?.toDouble().toStringAsFixed(2)}", isBold: true, color: Theme.of(context).colorScheme.secondary),
                  const Divider(height: 24),
                ],
                if (displayServices.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(mode == 'rent' ? "Rent Info" : "Services Info", style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...displayServices.map((s) {
                    String name = s['name'] ?? 'Service';
                    if (name.toLowerCase().contains('wifi') && s['deviceQuantity'] != null) {
                      name = "$name (Devices: ${s['deviceQuantity']})";
                    }
                    return _buildDetailRow(context, name, "৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}");
                  }),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      Text("৳${displayTotal.toStringAsFixed(2)}", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
                if (data['paidBy'] != null || data['paidAt'] != null || (data['paymentNotes'] ?? '').toString().isNotEmpty) ...[
                  const Divider(height: 32),
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
                      const SizedBox(width: 8),
                      Text("Payment Meta", style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (data['paidBy'] != null) _buildDetailRow(context, "Collected by:", data['paidBy']),
                  if (data['paidAt'] != null) _buildDetailRow(context, "Time:", DatabaseService.formatFullDateTime(data['paidAt'])),
                  if ((data['paymentNotes'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Text(
                          "Note: ${data['paymentNotes']}", 
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
              onPressed: () => Navigator.pop(context), 
              child: const Text("OK")
            ),
          ),
        ],
      ),
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
