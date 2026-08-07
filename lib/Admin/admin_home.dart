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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Accounts",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
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
                  _buildCategorySection(),
                
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
              children: const [
                Icon(Icons.electric_bolt_outlined, size: 20, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text(
                  "Electricity",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
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

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
          child: Row(
            children: const [
              Icon(Icons.category_outlined, size: 20, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text(
                "Category",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.8),
              ),
            ],
          ),
        ),
        _buildCategoryOverviewCard(),
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
                      color: Colors.blue.shade900,
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
                                    const Icon(Icons.analytics_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$_selectedMonthStr Total Revenue",
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
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
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
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
                                _buildInteractiveStat("Received", receivedTotal, Colors.greenAccent, Icons.check_circle_outline,
                                    () => _showBillingDetailsPopup(context, receivedSnapshot.data!.docs, occupiedSnapshot.data!.docs, initialTab: 0)),
                                Container(width: 1, height: 24, color: Colors.white24),
                                _buildInteractiveStat("Due", dueTotal, Colors.orangeAccent, Icons.pending_actions,
                                    () => _showBillingDetailsPopup(context, receivedSnapshot.data!.docs, occupiedSnapshot.data!.docs, initialTab: 1)),
                              ],
                            ),
                            const Divider(color: Colors.white12, height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInteractiveStat("Rent", rentTotal, Colors.lightBlueAccent, Icons.home_work_outlined,
                                    () => _showRentUtilityPopup(context, receivedSnapshot.data!.docs, isRent: true)),
                                Container(width: 1, height: 24, color: Colors.white24),
                                _buildInteractiveStat("Utility", utilityTotal, Colors.yellowAccent, Icons.settings_suggest_outlined,
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
          color: active ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildPieChart(double received, double due) {
    double total = received + due;
    if (total == 0) return const Center(child: Text("No Data", style: TextStyle(color: Colors.white54, fontSize: 10)));
    
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 20,
        sections: [
          PieChartSectionData(
            color: Colors.greenAccent,
            value: received,
            title: '${((received/total)*100).toStringAsFixed(0)}%',
            radius: 35,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
          PieChartSectionData(
            color: Colors.orangeAccent,
            value: due,
            title: '${((due/total)*100).toStringAsFixed(0)}%',
            radius: 30,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
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
            getTooltipColor: (_) => Colors.indigo.shade900,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(rod.toY.toInt().toString(), const TextStyle(color: Colors.white, fontSize: 10));
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
          _makeGroupData(0, v1, Colors.lightBlueAccent),
          _makeGroupData(1, v2, Colors.yellowAccent),
          _makeGroupData(2, v3, Colors.orangeAccent),
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
            color: Colors.black12,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerHeader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 140,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildCategoryOverviewCard() {
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
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_customize_outlined, size: 20, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text(
                    "Units Overview (Category Wise)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                "$totalDocs Total Units Registered in System",
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            // Overall Summary Row (Static Cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubOverviewCard(
                      title: "Total Occupied",
                      count: occupiedCount,
                      color: Colors.green,
                      icon: Icons.door_front_door_outlined,
                      onTap: () {
                        DatabaseService.vibrate();
                        widget.onCategoryTap?.call(0);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSubOverviewCard(
                      title: "Total Vacant",
                      count: vacantCount,
                      color: Colors.red,
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
            StreamBuilder<QuerySnapshot>(
              stream: _dbService.getCategoriesStream(),
              builder: (context, catSnap) {
                if (!catSnap.hasData) return const SizedBox.shrink();
                var categories = catSnap.data!.docs;
                
                return Column(
                  children: categories.map((catDoc) {
                    return _buildCategorySolidCard(catDoc);
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySolidCard(QueryDocumentSnapshot catDoc) {
    String catId = catDoc.id;
    String catName = (catDoc.data() as Map)['categoryName'] ?? 'Unnamed';
    
    // Assign decent solid colors based on index
    final List<MaterialColor> colors = [Colors.indigo, Colors.teal, Colors.deepPurple, Colors.brown, Colors.cyan];
    final MaterialColor baseColor = colors[catId.hashCode % colors.length];

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
            if (status == 'Occupied') {
              occupied++;
            } else {
              vacant++;
            }
          }
        }

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: baseColor.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: baseColor.shade200, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: baseColor,
                  child: const Icon(Icons.category_outlined, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    catName.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: baseColor.shade800, letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildNestedStatItem("Total", total, Colors.blueGrey),
                const SizedBox(width: 12),
                _buildNestedStatItem("Occupied", occupied, Colors.green, onTap: () {
                  DatabaseService.vibrate();
                  widget.onCategoryTap?.call(0);
                }),
                const SizedBox(width: 12),
                _buildNestedStatItem("Vacant", vacant, Colors.red, onTap: () {
                  DatabaseService.vibrate();
                  widget.onCategoryTap?.call(1);
                }),
              ],
            ),
          ),
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
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSubOverviewCard({required String title, required int count, required Color color, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      color: Colors.white,
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
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: color),
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
              Icon(icon, size: 10, color: Colors.white70),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          Text(
            "৳${amount.toStringAsFixed(0)}",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildElectricitySummary(BuildContext context, {bool showMainVsSub = true, bool showMainVsGovt = true}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getMainMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildShimmerList(); 
        var mainMeters = snapshot.data!.docs;

        if (mainMeters.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("No Main Meters found.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        return InkWell(
          onTap: widget.isReadOnly ? null : widget.onElectricityTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMainVsSub) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.balance, size: 16, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text(
                        "Main Meter Vs Sub Meter",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
                _buildMainVsSubTable(mainMeters),
              ],
              if (showMainVsGovt) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, size: 16, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text(
                        "Main Meter Vs Govt. Bill",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
                _buildMainVsGovtTable(mainMeters),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainVsSubTable(List<QueryDocumentSnapshot> mainMeters) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.indigo.shade200, width: 1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            alignment: Alignment.center,
            width: MediaQuery.of(context).size.width > 500 ? null : MediaQuery.of(context).size.width - 24,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
                  children: [
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("#", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Meter\nNumber", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Main Meter\nUsed Units", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Total Sub-Meter\nUnits", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("This Month\nUnit Rate", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Balance\nUnits", textAlign: TextAlign.center, style: textStyle))),
                  ],
                ),
                ...List.generate(mainMeters.length, (index) {
                  var doc = mainMeters[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String meterNo = data['meterNo'] ?? 'N/A';
                  double last = (data['lastReading'] as num?)?.toDouble() ?? 0;
                  double present = (data['presentReading'] ?? last).toDouble();
                  double mainUsed = present - last;
                  double totalSubPaid = (data['totalSubPaidUnits'] ?? 0).toDouble();
                  double unitRate = (data['unitRate'] as num?)?.toDouble() ?? 0;
                  final rowColor = index % 2 == 0 ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.transparent;
                  double balance = mainUsed - totalSubPaid;

                  return TableRow(
                    decoration: BoxDecoration(color: index % 2 == 0 ? Colors.white.withOpacity(0.5) : Colors.transparent),
                    children: [
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("${index + 1}", textAlign: TextAlign.center, style: dataStyle))),
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(meterNo, textAlign: TextAlign.center, style: textStyle, overflow: TextOverflow.ellipsis))),
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(mainUsed.toStringAsFixed(1), textAlign: TextAlign.center, style: dataStyle))),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Text(totalSubPaid.toStringAsFixed(1), textAlign: TextAlign.center, style: dataStyle),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("৳${unitRate.toStringAsFixed(2)}", textAlign: TextAlign.center, style: dataStyle))),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            balance.toStringAsFixed(1),
                            textAlign: TextAlign.center,
                            style: (dataStyle ?? const TextStyle()).copyWith(
                              color: balance > 0 ? Colors.red : Colors.green,
                              fontWeight: balance > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainVsGovtTable(List<QueryDocumentSnapshot> mainMeters) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.teal.shade200, width: 1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            alignment: Alignment.center,
            width: MediaQuery.of(context).size.width > 500 ? null : MediaQuery.of(context).size.width - 24,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
                  children: [
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("#", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Meter\nNumber", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Main Meter\nReadings", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Govt. Bill\nReadings", textAlign: TextAlign.center, style: textStyle))),
                    Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("Balance\nUnits", textAlign: TextAlign.center, style: textStyle))),
                  ],
                ),
                ...List.generate(mainMeters.length, (index) {
                  var doc = mainMeters[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String meterNo = data['meterNo'] ?? 'N/A';
                  double present = (data['presentReading'] as num?)?.toDouble() ?? 0;
                  double govtPresent = (data['govtBillReading'] as num?)?.toDouble() ?? 0;
                  double balance = govtPresent - present;
                  bool isAlert = balance < -5 || balance > 100;

                  return TableRow(
                    decoration: BoxDecoration(color: index % 2 == 0 ? Colors.white.withOpacity(0.5) : Colors.transparent),
                    children: [
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("${index + 1}", textAlign: TextAlign.center, style: dataStyle))),
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(meterNo, textAlign: TextAlign.center, style: textStyle, overflow: TextOverflow.ellipsis))),
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(present.toStringAsFixed(1), textAlign: TextAlign.center, style: dataStyle))),
                      Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(govtPresent.toStringAsFixed(1), textAlign: TextAlign.center, style: dataStyle))),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            balance.toStringAsFixed(1),
                            textAlign: TextAlign.center,
                            style: (dataStyle ?? const TextStyle()).copyWith(
                              color: isAlert ? Colors.red : Colors.green,
                              fontWeight: isAlert ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(3, (index) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: DefaultTabController(
            length: 2,
            initialIndex: initialTab,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        "$_selectedMonthStr Revenue Details",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: Colors.blue.shade900,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue.shade900,
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isRent ? Icons.home_work_outlined : Icons.settings_suggest_outlined, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      "$_selectedMonthStr ${isRent ? 'Rent' : 'Utility'} Details",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              categoryName = catSnap.data?['categoryName'] ?? 'Unknown';
                              String tName = data['TenantName'] ?? snap.data!['TenantName'] ?? 'No Name';
                              
                              return _buildBillingTile(
                                index: index,
                                title: "$resolvedSubName ($tName)",
                                subtitle: categoryName,
                                amount: amountToShow,
                                color: isRent ? Colors.lightBlue : Colors.orangeAccent.shade700,
                                icon: isRent ? Icons.home_work : Icons.settings_suggest,
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
                          color: isRent ? Colors.lightBlue : Colors.orangeAccent.shade700,
                          icon: isRent ? Icons.home_work : Icons.settings_suggest,
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
                  categoryName = catSnap.data?['categoryName'] ?? 'Unknown';
                  String tName = data['TenantName'] ?? snap.data!['TenantName'] ?? 'No Name';

                  return _buildBillingTile(
                    index: index,
                    title: "$resolvedSubName ($tName)",
                    subtitle: categoryName,
                    amount: (data['totalAmount'] as num).toDouble(),
                    color: Colors.green,
                    icon: Icons.check_circle,
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
              color: Colors.green,
              icon: Icons.check_circle,
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
            String categoryName = catSnap.data?['categoryName'] ?? 'Loading...';
            String tName = data['TenantName'] ?? 'No Name'; // Capital T
            return FutureBuilder<double>(
              future: _calculateSingleDue(doc),
              builder: (context, amountSnap) {
                double amount = amountSnap.data ?? 0;
                return _buildBillingTile(
                  index: index,
                  title: "${data['subItemName']} ($tName)",
                  subtitle: categoryName,
                  amount: amount,
                  color: Colors.orange,
                  icon: Icons.pending,
                  onTap: () async {
                    // For Due items, we need to build a virtual billing record
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
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.teal.shade50,
      Colors.pink.shade50,
      Colors.amber.shade50,
      Colors.cyan.shade50,
    ];
    Color itemColor = pastelColors[index % pastelColors.length];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      color: itemColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.1), width: 1)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
            if (paidBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text("Paid by: $paidBy", style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
              ),
            if (paidAt != null)
              Text("Paid at: ${DatabaseService.formatFullDateTime(paidAt)}", style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
            if (notes != null && notes.isNotEmpty)
              Text("Note: $notes", style: const TextStyle(fontSize: 9, color: Colors.brown, fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "৳${amount.toStringAsFixed(2)}",
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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
            Text(subName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo)),
            Text("$tenantName | $catName", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
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
                      const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      const Text("Electricity Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow("Meter No:", data['electricityDetails']['subMeterNo'] ?? 'N/A'),
                  _buildDetailRow("Reading:", "${data['electricityDetails']['lastReading']} -> ${data['electricityDetails']['presentReading']}"),
                  _buildDetailRow("Unit Rate:", "৳${(data['electricityDetails']['pricePerUnit'] as num?)?.toDouble().toStringAsFixed(2)}"),
                  _buildDetailRow("Bill Amount:", "৳${(data['electricityBill'] as num?)?.toDouble().toStringAsFixed(2)}", isBold: true, color: Colors.teal),
                  const Divider(height: 24),
                ],
                if (displayServices.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.list_alt, color: Colors.indigo, size: 16),
                      const SizedBox(width: 8),
                      Text(mode == 'rent' ? "Rent Info" : "Services Info", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...displayServices.map((s) {
                    String name = s['name'] ?? 'Service';
                    if (name.toLowerCase().contains('wifi') && s['deviceQuantity'] != null) {
                      name = "$name (Devices: ${s['deviceQuantity']})";
                    }
                    return _buildDetailRow(name, "৳${(s['amount'] as num).toDouble().toStringAsFixed(2)}");
                  }),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50, 
                    borderRadius: BorderRadius.circular(12), 
                    border: Border.all(color: Colors.indigo.shade200)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      Text("৳${displayTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.indigo)),
                    ],
                  ),
                ),
                if (data['paidBy'] != null || data['paidAt'] != null || (data['paymentNotes'] ?? '').toString().isNotEmpty) ...[
                  const Divider(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blueGrey, size: 16),
                      const SizedBox(width: 8),
                      const Text("Payment Meta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (data['paidBy'] != null) _buildDetailRow("Collected by:", data['paidBy']),
                  if (data['paidAt'] != null) _buildDetailRow("Time:", DatabaseService.formatFullDateTime(data['paidAt'])),
                  if ((data['paymentNotes'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.brown.shade100),
                        ),
                        child: Text(
                          "Note: ${data['paymentNotes']}", 
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.brown)
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
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context), 
              label: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
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
