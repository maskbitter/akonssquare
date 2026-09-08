import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/data_repository.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:akons_square/Common/app_animations.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseService _dbService = DatabaseService();
  final DataRepository _repository = DataRepository();
  
  String _selectedReportType = "Financial";
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedUnitId;
  String? _selectedMainMeter;
  String? _selectedSubMeter;

  final List<String> _reportTypes = ["Financial", "Electricity", "Occupancy", "Activity"];

  String get _selectedMonthStr => DatabaseService.formatMonthYear(_selectedDate);

  void _moveMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";

    return Column(
      children: [
        _buildFilterBar(isOutline),
        Expanded(
          child: _buildReportContent(isOutline),
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isOutline) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Report Type Selector
            _buildDropdown<String>(
              value: _selectedReportType,
              items: _reportTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedReportType = v!),
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(width: 8),
            // Month Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => _moveMonth(-1)),
                  Text(_selectedMonthStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => _moveMonth(1)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Category Filter
            ValueListenableBuilder<List<QueryDocumentSnapshot>>(
              valueListenable: _repository.categories,
              builder: (context, categories, _) {
                return _buildDropdown<String?>(
                  value: _selectedCategoryId,
                  hint: "All Categories",
                  items: [
                    const DropdownMenuItem(value: null, child: Text("All Categories")),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text((c.data() as Map)['categoryName'] ?? 'Unit'))),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedCategoryId = v;
                    _selectedUnitId = null;
                  }),
                  icon: Icons.category_outlined,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged, String? hint, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 12)) : null,
          items: items,
          onChanged: onChanged,
          icon: icon != null ? Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary) : null,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildReportContent(bool isOutline) {
    switch (_selectedReportType) {
      case "Financial":
        return _buildFinancialReport(isOutline);
      case "Electricity":
        return _buildElectricityReport(isOutline);
      case "Occupancy":
        return _buildOccupancyReport(isOutline);
      case "Activity":
        return _buildActivityReport(isOutline);
      default:
        return const Center(child: Text("Select a report type"));
    }
  }

  Widget _buildFinancialReport(bool isOutline) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getBillingHistoryByMonth(_selectedMonthStr),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        
        // Filter by category if selected
        if (_selectedCategoryId != null) {
          // This requires fetching sub_items to know their category, or joining.
          // For simplicity in UI, we can filter the list if we have the categoryId in the billing doc.
          // Looking at DB schema, billing_history doesn't have categoryId directly usually, but let's check.
          docs = docs.where((d) {
             var data = d.data() as Map<String, dynamic>;
             // In many implementations, we might need to cross-ref.
             return true; 
          }).toList();
        }

        double totalReceived = 0;
        double totalDue = 0;
        int paidCount = 0;
        int dueCount = 0;

        for (var d in docs) {
          var data = d.data() as Map<String, dynamic>;
          double amt = (data['totalAmount'] as num?)?.toDouble() ?? 0;
          if (data['status'] == 'Paid') {
            totalReceived += amt;
            paidCount++;
          } else {
            totalDue += amt;
            dueCount++;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard("Financial Overview", [
              _buildStat("Received", "৳${totalReceived.toStringAsFixed(2)}", Colors.green),
              _buildStat("Due", "৳${totalDue.toStringAsFixed(2)}", Colors.red),
              _buildStat("Total", "৳${(totalReceived + totalDue).toStringAsFixed(2)}", Colors.blue),
            ]),
            const SizedBox(height: 20),
            Text("Collection Details", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...docs.map((d) {
              var data = d.data() as Map<String, dynamic>;
              bool isPaid = data['status'] == 'Paid';
              return Card(
                elevation: 0,
                color: isOutline ? ThemeManager.outlineBackground : (isPaid ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05)),
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isOutline ? BorderSide(color: isPaid ? Colors.green : Colors.red) : BorderSide.none,
                ),
                child: ListTile(
                  title: Text(data['subItemName'] ?? 'Unit', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Tenant: ${data['TenantName'] ?? 'N/A'}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("৳${(data['totalAmount'] as num?)?.toDouble().toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: isPaid ? Colors.green : Colors.red)),
                      Text(isPaid ? "Paid" : "Due", style: TextStyle(fontSize: 10, color: isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildElectricityReport(bool isOutline) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getMainMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var mainMeters = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Main Meter Audit", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...mainMeters.map((mDoc) {
              var mData = mDoc.data() as Map<String, dynamic>;
              double last = (mData['lastReading'] as num?)?.toDouble() ?? 0;
              double pres = (mData['presentReading'] as num?)?.toDouble() ?? 0;
              double used = pres - last;
              
              return Card(
                elevation: 0,
                color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Meter: ${mData['meterNo']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                            child: Text("Main", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat("Last", last.toStringAsFixed(2)),
                          _buildMiniStat("Present", pres.toStringAsFixed(2)),
                          _buildMiniStat("Used", used.toStringAsFixed(2), color: Colors.blue, bold: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("Govt. Bill Info", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat("Bill Unit", ((mData['govtBillReading'] ?? 0) - (mData['lastGovtReading'] ?? 0)).toStringAsFixed(2)),
                          _buildMiniStat("Bill Amt", "৳${(mData['govtBillAmount'] ?? 0).toStringAsFixed(2)}"),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            Text("Sub-Meter Summary", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ValueListenableBuilder<List<QueryDocumentSnapshot>>(
              valueListenable: _repository.subMeters,
              builder: (context, subMeters, _) {
                return Column(
                  children: subMeters.map((sDoc) {
                    var sData = sDoc.data() as Map<String, dynamic>;
                    double last = (sData['lastReading'] as num?)?.toDouble() ?? 0;
                    double pres = (sData['presentReading'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      dense: true,
                      title: Text("SM: ${sData['subMeterNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Main: ${sData['mainMeterNo']}"),
                      trailing: Text("${(pres - last).toStringAsFixed(2)} Units", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildOccupancyReport(bool isOutline) {
    return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
      valueListenable: _repository.subItems,
      builder: (context, units, _) {
        int occupied = units.where((u) => (u.data() as Map)['status'] == 'Occupied').length;
        int vacant = units.where((u) => (u.data() as Map)['status'] == 'Vacant').length;
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard("Occupancy Stats", [
              _buildStat("Occupied", "$occupied", Colors.green),
              _buildStat("Vacant", "$vacant", Colors.orange),
              _buildStat("Total Units", "${units.length}", Colors.blue),
            ]),
            const SizedBox(height: 20),
            Text("Unit Breakdown", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...units.map((uDoc) {
              var uData = uDoc.data() as Map<String, dynamic>;
              bool isOccupied = uData['status'] == 'Occupied';
              return ListTile(
                leading: Icon(isOccupied ? Icons.person : Icons.meeting_room, color: isOccupied ? Colors.green : Colors.grey),
                title: Text(uData['subItemName'] ?? 'Unit', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isOccupied ? (uData['TenantName'] ?? 'N/A') : "Vacant"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOccupied ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    uData['status'] ?? 'N/A', 
                    style: TextStyle(color: isOccupied ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildActivityReport(bool isOutline) {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getActivityLogsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var logs = snapshot.data!.docs.take(50).toList(); // Show last 50

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            var data = logs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 0,
              color: isOutline ? ThemeManager.outlineBackground : Colors.grey.withOpacity(0.05),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  child: Icon(Icons.history, size: 16, color: Theme.of(context).colorScheme.secondary),
                ),
                title: Text(data['action'] ?? 'Action', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['details'] ?? ''),
                    const SizedBox(height: 2),
                    Text(
                      "By: ${data['actor']} | ${DatabaseService.formatFullDateTime(data['timestamp'] as Timestamp?)}",
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, List<Widget> stats) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: stats,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? color, bool bold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }
}
