import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:akons_square/Common/data_repository.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:akons_square/Common/app_animations.dart';
import 'package:akons_square/Common/share_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DatabaseService _dbService = DatabaseService();
  final DataRepository _repository = DataRepository();
  
  // Filter States
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedStatus; // Paid, Due, Advance
  String? _selectedMainMeter;
  String? _selectedSubMeter;
  String _searchQuery = "";
  String _dateMode = "Monthly"; // Monthly, Yearly, Custom
  int _selectedYear = DateTime.now().year;
  DateTimeRange? _customDateRange;
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  String get _selectedMonthStr => DatabaseService.formatMonthYear(_selectedDate);

  void _showFilterSheet(bool isOutline) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: isOutline ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            Text("Advanced Filters", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            // Status Filter
            Text("Payment Status", style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ["All", "Paid", "Due"].map((s) {
                bool isSelected = (_selectedStatus ?? "All") == s;
                return ChoiceChip(
                  label: Text(s),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _selectedStatus = (s == "All" ? null : s));
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            
            // Category Filter
            Text("Main Category", style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<QueryDocumentSnapshot>>(
              valueListenable: _repository.categories,
              builder: (context, categories, _) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text("All"),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) { setState(() => _selectedCategoryId = null); Navigator.pop(ctx); },
                    ),
                    ...categories.map((c) {
                      String name = (c.data() as Map)['categoryName'] ?? 'Unit';
                      return ChoiceChip(
                        label: Text(name),
                        selected: _selectedCategoryId == c.id,
                        onSelected: (_) { setState(() => _selectedCategoryId = c.id); Navigator.pop(ctx); },
                      );
                    }),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            
            // Meter Filters
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<List<QueryDocumentSnapshot>>(
                    valueListenable: _repository.mainMeters,
                    builder: (context, meters, _) {
                      return _buildDropdown<String?>(
                        value: _selectedMainMeter,
                        hint: "Main Meter",
                        items: [
                          const DropdownMenuItem(value: null, child: Text("All Main")),
                          ...meters.map((m) => DropdownMenuItem(value: (m.data() as Map)['meterNo'], child: Text((m.data() as Map)['meterNo'] ?? ''))),
                        ],
                        onChanged: (v) { setState(() => _selectedMainMeter = v); Navigator.pop(ctx); },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<List<QueryDocumentSnapshot>>(
                    valueListenable: _repository.subMeters,
                    builder: (context, meters, _) {
                      return _buildDropdown<String?>(
                        value: _selectedSubMeter,
                        hint: "Sub-Meter",
                        items: [
                          const DropdownMenuItem(value: null, child: Text("All Sub")),
                          ...meters.map((m) => DropdownMenuItem(value: (m.data() as Map)['subMeterNo'], child: Text((m.data() as Map)['subMeterNo'] ?? ''))),
                        ],
                        onChanged: (v) { setState(() => _selectedSubMeter = v); Navigator.pop(ctx); },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = null;
                    _selectedCategoryId = null;
                    _selectedMainMeter = null;
                    _selectedSubMeter = null;
                    _dateMode = "Monthly";
                    _selectedDate = DateTime.now();
                    _customDateRange = null;
                    _searchController.clear();
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer, foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text("Reset All Filters"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareReportSummary(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return;
    
    double total = records.fold(0.0, (sum, r) => sum + r['total']);
    int paid = records.where((r) => r['status'] == 'Paid').length;
    int due = records.length - paid;

    String summary = "*AkonsSquare Report Summary (${_dateMode == "Yearly" ? _selectedYear : _selectedMonthStr})*\n"
        "----------------------------------\n"
        "Total Records: ${records.length}\n"
        "Paid: $paid | Due: $due\n"
        "Grand Total: ৳${total.toStringAsFixed(2)}\n\n"
        "Preview:\n";

    for (var i = 0; i < (records.length > 5 ? 5 : records.length); i++) {
      var r = records[i];
      summary += "• ${r['unitName']} (${r['tenantName']}): ৳${r['total'].toStringAsFixed(2)} [${r['status']}]\n";
    }

    if (records.length > 5) summary += "...and ${records.length - 5} more records.\n";
    
    summary += "\nGenerated on: ${DateFormat('dd-MMM-yyyy HH:mm').format(DateTime.now())}";
    
    Share.share(summary);
  }

  @override
  Widget build(BuildContext context) {
    final bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";

    return Scaffold(
      backgroundColor: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _buildSearchAndFilterHeader(isOutline),
          Expanded(child: _buildReportTable(isOutline)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(bool isOutline) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search NID, Tenant, Unit...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: isOutline ? const BorderSide() : BorderSide.none),
                    filled: !isOutline,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showFilterSheet(isOutline),
                icon: Badge(
                  isLabelVisible: _selectedStatus != null || _selectedCategoryId != null,
                  child: const Icon(Icons.filter_list_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_dateMode == "Monthly")
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, size: 14), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1))),
                    Text(_selectedMonthStr, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 14), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1))),
                  ],
                )
              else if (_dateMode == "Yearly")
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, size: 14), onPressed: () => setState(() => _selectedYear--)),
                    Text("Year: $_selectedYear", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 14), onPressed: () => setState(() => _selectedYear++)),
                  ],
                )
              else
                InkWell(
                  onTap: _pickCustomDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _customDateRange == null 
                            ? "Select Date Range" 
                            : "${DateFormat('dd/MM/yy').format(_customDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_customDateRange!.end)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              
              Row(
                children: [
                  _buildModeChip("Monthly"),
                  _buildModeChip("Yearly"),
                  _buildModeChip("Custom"),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode) {
    bool isSelected = _dateMode == mode;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => setState(() => _dateMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
          ),
          child: Text(mode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
        ),
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );
    if (range != null) setState(() => _customDateRange = range);
  }

  Widget _buildReportTable(bool isOutline) {
    Query query = _dbService.getBillingHistoryCollection();
    
    // Server side filtering where possible
    if (_dateMode == "Monthly") {
      query = query.where('monthYear', isEqualTo: _selectedMonthStr);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
          valueListenable: _repository.subItems,
          builder: (context, subItemsList, _) {
            return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
              valueListenable: _repository.categories,
              builder: (context, categoriesList, _) {
                
                // DATA JOINING & FILTERING
                var rawRecords = snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String subId = data['subItemId'] ?? '';
                  
                  var subItem = subItemsList.where((i) => i.id == subId).firstOrNull;
                  var subItemData = subItem?.data() as Map<String, dynamic>?;
                  
                  String catId = data['categoryId'] ?? subItemData?['categoryId'] ?? '';
                  var category = categoriesList.where((c) => c.id == catId).firstOrNull;
                  String catName = (category?.data() as Map?)?['categoryName'] ?? 'N/A';
                  
                  String tenantNid = (data['nidNumber'] ?? subItemData?['nidNumber'] ?? 'N/A').toString();
                  String tenantName = data['TenantName'] ?? subItemData?['TenantName'] ?? 'N/A';
                  String unitName = data['subItemName'] ?? subItemData?['subItemName'] ?? 'N/A';
                  
                  var ed = data['electricityDetails'] ?? {};
                  double eBill = DatabaseService.parseNum(data['electricityBill']).toDouble();
                  String sm = (ed['subMeterNo'] ?? '').toString();
                  String mm = (ed['mainMeterNo'] ?? '').toString();
                  
                  List services = data['services'] is List ? data['services'] : [];
                  double rent = 0;
                  double others = 0;
                  for (var s in services) {
                    if (s is Map) {
                      String sName = s['name'].toString().toLowerCase();
                      double sAmt = DatabaseService.parseNum(s['amount']).toDouble();
                      if (sName.contains('rent')) rent += sAmt;
                      else others += sAmt;
                    }
                  }
                  
                  List manualDues = data['manualDues'] is List ? data['manualDues'] : [];
                  double adj = manualDues.fold(0.0, (sum, m) => sum + DatabaseService.parseNum(m is Map ? m['amount'] : 0).toDouble());

                  Timestamp? recordDate = data['paidAt'] ?? data['createdAt'];

                  return {
                    'monthYear': data['monthYear'] ?? _selectedMonthStr,
                    'catName': catName,
                    'catId': catId,
                    'unitName': unitName,
                    'tenantName': tenantName,
                    'nid': tenantNid,
                    'rent': rent,
                    'services': others,
                    'electricity': eBill,
                    'adj': adj,
                    'total': DatabaseService.parseNum(data['totalAmount']).toDouble(),
                    'status': data['status'] ?? 'N/A',
                    'paidBy': data['paidBy'] ?? 'System',
                    'date': recordDate,
                    'sm': sm,
                    'mm': mm,
                    'searchString': "${tenantName} ${tenantNid} ${unitName} ${catName} ${sm} ${mm}".toLowerCase(),
                  };
                }).toList();

                // CLIENT SIDE FILTERING
                var records = rawRecords;

                if (_dateMode == "Yearly") {
                  records = records.where((r) => r['monthYear'].toString().contains(_selectedYear.toString())).toList();
                } else if (_dateMode == "Custom" && _customDateRange != null) {
                  records = records.where((r) {
                    if (r['date'] == null) return false;
                    DateTime d = (r['date'] as Timestamp).toDate();
                    return d.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) && 
                           d.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
                  }).toList();
                }
                
                if (_selectedCategoryId != null) {
                  records = records.where((r) => r['catId'] == _selectedCategoryId).toList();
                }
                if (_selectedStatus != null) {
                  records = records.where((r) => r['status'] == _selectedStatus).toList();
                }
                if (_selectedMainMeter != null) {
                  records = records.where((r) => r['mm'] == _selectedMainMeter).toList();
                }
                if (_selectedSubMeter != null) {
                  records = records.where((r) => r['sm'] == _selectedSubMeter).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  records = records.where((r) => r['searchString'].toString().contains(_searchQuery)).toList();
                }

                records.sort((a, b) {
                  if (a['date'] == null || b['date'] == null) return 0;
                  return b['date'].compareTo(a['date']);
                });

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text("No matching records found for this period.", style: TextStyle(fontStyle: FontStyle.italic)),
                        if (_searchQuery.isNotEmpty) Text("Searching for: '$_searchQuery'", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${records.length} Records Found", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text("Grand Total: ৳${records.fold(0.0, (sum, r) => sum + r['total']).toStringAsFixed(2)}", style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _shareReportSummary(records),
                            icon: const Icon(Icons.share_outlined, size: 20, color: Colors.blue),
                            tooltip: "Share Summary",
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalScroll,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildReportTableWidget(context, records, isOutline),
                          ),
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

  Widget _buildReportTableWidget(BuildContext context, List<Map<String, dynamic>> records, bool isOutline) {
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white);
    final dataStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: Theme.of(context).dividerColor.withOpacity(0.2), width: 0.5, borderRadius: BorderRadius.circular(8)),
      children: [
        // Header Row
        TableRow(
          decoration: BoxDecoration(color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary),
          children: [
            "#", "Month", "Main Cat", "Unit", "Tenant Name", "NID", "Rent", "Services", "Electric", "Adj/Due", "Total", "Status", "Paid By", "Date"
          ].map((h) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(child: Text(h, style: headerStyle)),
          )).toList(),
        ),
        // Data Rows
        ...records.asMap().entries.map((entry) {
          int index = entry.key;
          var r = entry.value;
          bool isPaid = r['status'] == 'Paid';
          Color statusColor = isPaid ? Colors.green : Colors.red;

          return TableRow(
            decoration: BoxDecoration(color: index % 2 == 0 ? Colors.transparent : (isOutline ? Colors.black12 : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1))),
            children: [
              _cell("${index + 1}", dataStyle),
              _cell(r['monthYear'], dataStyle),
              _cell(r['catName'], dataStyle, bold: true),
              _cell(r['unitName'], dataStyle, bold: true),
              _cell(r['tenantName'], dataStyle),
              _cell(r['nid'], dataStyle),
              _cell("৳${r['rent'].toStringAsFixed(2)}", dataStyle),
              _cell("৳${r['services'].toStringAsFixed(2)}", dataStyle),
              _cell("৳${r['electricity'].toStringAsFixed(2)}", dataStyle),
              _cell("৳${r['adj'].toStringAsFixed(2)}", dataStyle, color: r['adj'] > 0 ? Colors.red : null),
              _cell("৳${r['total'].toStringAsFixed(2)}", dataStyle, bold: true, color: Theme.of(context).colorScheme.primary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(r['status'], style: dataStyle?.copyWith(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9)),
                  ),
                ),
              ),
              _cell(r['paidBy'], dataStyle),
              _cell(DatabaseService.formatFullDateTime(r['date'] as Timestamp?), dataStyle),
            ],
          );
        }),
      ],
    );
  }

  Widget _cell(String text, TextStyle? style, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Text(
          text, 
          textAlign: TextAlign.center,
          style: style?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? style.color),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
