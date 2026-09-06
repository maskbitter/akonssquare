import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Admin/category_dialogs.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:akons_square/Common/ui_helper.dart';
import 'package:akons_square/Users/user_report_page.dart';

import 'package:akons_square/Common/data_repository.dart';

class CategoryPage extends StatefulWidget {
  final int initialSubTabIndex;
  final bool isOperator;
  const CategoryPage({super.key, this.initialSubTabIndex = 0, this.isOperator = false});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> with AutomaticKeepAliveClientMixin {
  final DatabaseService _dbService = DatabaseService();
  final DataRepository _repository = DataRepository();
  String? _selectedFilterCategoryId;
  late DateTime _selectedDate;
  bool _isFabVisible = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _selectedMonthStr => DatabaseService.formatMonthYear(_selectedDate);

  void _moveMonth(int delta) {
    DatabaseService.vibrate();
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  void _showAddActionMenu(BuildContext context) {
    DatabaseService.vibrate();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            _buildActionCard(
              context, 
              title: "New Category", 
              subtitle: "Create a new group like 'Shop' or 'Room'", 
              icon: Icons.category_outlined, 
              color: Theme.of(context).colorScheme.primaryContainer,
              accentColor: Theme.of(context).colorScheme.primary,
              onTap: () { Navigator.pop(ctx); CategoryDialogs.showCreateCategoryDialog(context); }
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context, 
              title: "Manage Services", 
              subtitle: "Add global services for categories", 
              icon: Icons.build_circle_outlined, 
              color: Theme.of(context).colorScheme.secondaryContainer,
              accentColor: Theme.of(context).colorScheme.secondary,
              onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddServiceDialog(context); }
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context, 
              title: "Electricity Meters", 
              subtitle: "Add Main or Sub-Meters", 
              icon: Icons.electric_bolt, 
              color: Theme.of(context).colorScheme.tertiaryContainer,
              accentColor: context.electric,
              onTap: () { 
                Navigator.pop(ctx);
                _showMeterChoiceMenu(context);
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required Color accentColor, required VoidCallback onTap}) {
    bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    return Card(
      elevation: isOutline ? 0 : 2,
      margin: EdgeInsets.zero,
      color: isOutline ? Colors.transparent : color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: isOutline ? BorderSide(color: accentColor, width: 1.5) : BorderSide.none
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOutline ? Colors.transparent : accentColor,
            border: isOutline ? Border.all(color: accentColor, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: isOutline ? accentColor : Theme.of(context).colorScheme.onPrimary, size: 20),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : accentColor)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isOutline ? Colors.black : accentColor.withValues(alpha: 0.7))),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isOutline ? Colors.black : accentColor),
      ),
    );
  }

  void _showMeterChoiceMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            _buildActionCard(
              context, 
              title: "Add Main Meter", 
              subtitle: "Register a master electric meter", 
              icon: Icons.add_chart_outlined, 
              color: Theme.of(context).colorScheme.primaryContainer,
              accentColor: Theme.of(context).colorScheme.primary,
              onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddMainMeterDialog(context); }
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context, 
              title: "Add Sub Meter", 
              subtitle: "Register a unit-linked meter", 
              icon: Icons.cable_outlined, 
              color: Theme.of(context).colorScheme.secondaryContainer,
              accentColor: Theme.of(context).colorScheme.secondary,
              onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddSubMeterDialog(context); }
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialSubTabIndex,
      child: Column(
        children: [
          Material(
            color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary,
              unselectedLabelColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black.withValues(alpha: 0.6) : Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Theme.of(context).colorScheme.outlineVariant,
              tabs: const [
                Tab(icon: Icon(Icons.door_front_door_outlined, size: 20), text: "Occupied"),
                Tab(icon: Icon(Icons.meeting_room_outlined, size: 20), text: "Vacant"),
                Tab(icon: Icon(Icons.electric_bolt, size: 20), text: "Meters"),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction == ScrollDirection.idle) {
                      if (!_isFabVisible) setState(() => _isFabVisible = true);
                    } else {
                      if (_isFabVisible) setState(() => _isFabVisible = false);
                    }
                    return true;
                  },
                  child: TabBarView(
                    children: [
                      _buildCategoryManagerTab(status: 'Occupied'),
                      _buildCategoryManagerTab(status: 'Vacant'),
                      _buildMainMeterTab(),
                    ],
                  ),
                ),
                if (!widget.isOperator)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: AnimatedScale(
                      scale: _isFabVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: FloatingActionButton.extended(
                        onPressed: () => _showAddActionMenu(context),
                        icon: const Icon(Icons.add),
                        label: const Text("Add / Manage"),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryManagerTab({required String status}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: ValueListenableBuilder<List<QueryDocumentSnapshot>>(
                  valueListenable: _repository.categories,
                  builder: (context, categoriesList, child) {
                    var categories = categoriesList.toList();
                    categories.sort((a, b) => ((a.data() as Map)['categoryName'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['categoryName'] ?? '').toString().toLowerCase()));
                    
                    return DropdownButtonFormField<String?>(
                      value: _selectedFilterCategoryId,
                      decoration: InputDecoration(
                        isDense: true, 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), 
                        border: InputBorder.none, 
                        labelText: "Category",
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                      ),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text("All Categories", style: Theme.of(context).textTheme.bodyMedium)),
                        ...categories.map((doc) => DropdownMenuItem<String?>(value: doc.id, child: Text((doc.data() as Map)['categoryName'] ?? '', style: Theme.of(context).textTheme.bodyMedium))),
                      ],
                      onChanged: (val) => setState(() => _selectedFilterCategoryId = val),
                    );
                  },
                ),
              ),
              if (status == 'Occupied') ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
                    border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Colors.black, width: 1.5) : null,
                  ),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left, size: 18), onPressed: () => _moveMonth(-1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                      Text(
                        _selectedMonthStr, 
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                      IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: () => _moveMonth(1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<QueryDocumentSnapshot>>(
            valueListenable: _repository.categories,
            builder: (context, allCategories, child) {
              var categoryDocs = allCategories.toList();
              categoryDocs.sort((a, b) => ((a.data() as Map)['categoryName'] ?? '').compareTo((b.data() as Map)['categoryName'] ?? ''));
              if (_selectedFilterCategoryId != null) {
                categoryDocs = categoryDocs.where((doc) => doc.id == _selectedFilterCategoryId).toList();
              }

              if (categoryDocs.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 24),
                        Text(
                          "No Categories Added",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "You haven't created any groups like 'Shop' or 'Flat' yet. Add your first category to start managing units.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        AppDialogActions(
                          actions: [
                            AppButton.icon(
                              onPressed: () => CategoryDialogs.showCreateCategoryDialog(context),
                              icon: const Icon(Icons.add),
                              child: const Text("Create First Category"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text(
                          "Tip: Start by creating a category, then add units (shops/rooms) inside it.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
                valueListenable: _repository.billingHistory,
                builder: (context, billingHistory, child) {
                  Set<String> paidIds = {};
                  Map<String, QueryDocumentSnapshot> historyMap = {};
                  for (var doc in billingHistory) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['monthYear'] == _selectedMonthStr) {
                      String subId = data['subItemId'] ?? '';
                      if (subId.isNotEmpty) historyMap[subId] = doc;
                      if (data['status'] != 'Due') {
                        paidIds.add(subId);
                      }
                    }
                  }


                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                    itemCount: categoryDocs.length,
                    itemBuilder: (context, i) {
                      var catDoc = categoryDocs[i];
                      var catData = catDoc.data() as Map<String, dynamic>;
                      String catId = catDoc.id;
                      String catName = catData['categoryName'] ?? 'Unnamed';
                      List assignedServices = catData['assignedServices'] ?? [];

                      return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
                        valueListenable: _repository.subItems,
                        builder: (context, allSubItems, child) {
                          var subDocs = allSubItems.where((doc) {
                            var d = doc.data() as Map<String, dynamic>;
                            return d['categoryId'] == catId && (d['status'] ?? 'Vacant') == status;
                          }).toList();

                          subDocs.sort((a, b) => ((a.data() as Map)['subItemName'] ?? '').compareTo((b.data() as Map)['subItemName'] ?? ''));

                          // Hide category if no units are occupied in this tab
                          if (status == 'Occupied' && subDocs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                            double _calculateUnitMonthTotal(QueryDocumentSnapshot doc) {
                            var existingRecord = historyMap[doc.id];
                            if (existingRecord != null) {
                               return ((existingRecord.data() as Map)['totalAmount'] as num).toDouble();
                            }
                            var d = doc.data() as Map<String, dynamic>;
                            var ed = d['electricityDetails'];
                            double eBillVal = 0;
                            if (ed != null && ed['isStopped'] != true) {
                              eBillVal = (((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble()) * ((ed['pricePerUnit'] ?? 0) as num).toDouble();
                            }
                            List active = DatabaseService.getEffectiveServices(categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? [], overriddenServices: d['overriddenServices'] ?? []);
                            
                            // Manual dues are now handled by calculateFinancialSummary to ensure all pending ones are counted
                            return (active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble()) + eBillVal);
                          }

                          return Builder(
                            builder: (context) {
                              double catTotalPayable = 0;
                              for (var doc in subDocs) {
                                catTotalPayable += _calculateUnitMonthTotal(doc);
                              }
                              bool hasElectric = subDocs.any((doc) => (doc.data() as Map<String, dynamic>)['electricityDetails'] != null);
                              
                              final Color accentColor = ThemeManager.getCardColor(i);
                              final Color bgColor = ThemeManager.getCardContainerColor(i);
                              final Color onBgColor = ThemeManager.getCardOnContainerColor(i);

                              return Card(
                        elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                        color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : bgColor,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16), 
                          side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                              ? BorderSide(color: accentColor, width: 1.5) 
                              : BorderSide.none,
                        ),
                        child: ExpansionTile(
                          backgroundColor: Colors.transparent,
                          collapsedBackgroundColor: Colors.transparent,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          iconColor: accentColor,
                          collapsedIconColor: accentColor,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.category_outlined, color: accentColor, size: 22),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: onBgColor, width: 1) : null,
                                    ),
                                    child: Text(
                                      catName.toUpperCase(),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900, 
                                        color: onBgColor, 
                                        letterSpacing: 0.5
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                                    onPressed: () => CategoryDialogs.showCategorySettingsDialog(
                                      context: context, 
                                      categoryId: catId, 
                                      categoryName: catName, 
                                      dynamicAssignedServices: assignedServices
                                    ),
                                  ),
                                  if (!widget.isOperator) ...[
                                    const SizedBox(width: 12),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error, size: 20), 
                                      onPressed: () => CategoryDialogs.showConfirmDialog(
                                        context: context, 
                                        title: "Remove '$catName'?", 
                                        content: "Are you sure you want to remove this category?", 
                                        onConfirm: () async { 
                                          SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                          await _dbService.removeCategory(catId, prefs.getString('username') ?? "Admin"); 
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 30),
                                    child: Text(
                                      "${subDocs.length} units | ${assignedServices.length} Services",
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: onBgColor.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Row(
                                        children: [
                                          if (hasElectric) Icon(Icons.electric_bolt, color: context.electric, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Total: ৳${catTotalPayable.toStringAsFixed(0)}",
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w900, 
                                              color: onBgColor
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            ...subDocs.asMap().entries.map((entry) {
                              var subDoc = entry.value;
                              var d = subDoc.data() as Map<String, dynamic>;
                              String subId = subDoc.id;
                              String subName = d['subItemName'] ?? 'Unnamed';
                              String tenant = d['TenantName'] ?? 'No Name';
                              var ed = d['electricityDetails'];
                              var existingRecord = historyMap[subId];
                              double monthTotal = 0;
                              double servicesTotal = 0;
                              double eBillAmount = 0;
                              double mDuesSum = 0;
                              List? historicalServices;

                              if (existingRecord != null) {
                                var hData = existingRecord.data() as Map<String, dynamic>;
                                monthTotal = (hData['totalAmount'] as num).toDouble();
                                servicesTotal = (hData['houseRentTotal'] as num).toDouble();
                                eBillAmount = (hData['electricityBill'] as num).toDouble();
                                mDuesSum = monthTotal - (servicesTotal + eBillAmount);
                                historicalServices = hData['services'];
                              } else {
                                List overridden = d['overriddenServices'] ?? [];
                                List active = DatabaseService.getEffectiveServices(categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? [], overriddenServices: overridden);
                                servicesTotal = active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());
                                if (ed != null && ed['isStopped'] != true) {
                                  eBillAmount = (((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble()) * ((ed['pricePerUnit'] ?? 0) as num).toDouble();
                                }
                                // Manual dues are now accounted for by calculateFinancialSummary
                                monthTotal = servicesTotal + eBillAmount;
                              }

                              bool isPaid = paidIds.contains(subId);
                              bool isOccupied = status == 'Occupied';

                              return Builder(
                                builder: (context) {
                                  double unitMonthBill = monthTotal;
                                  
                                  var summary = _repository.calculateFinancialSummaryLocal(subId, unitMonthBill, _selectedMonthStr);
                                  List pendingMonths = summary['pendingMonths'] ?? [];
                                  List summaryManualDues = d['manualDues'] ?? [];
                                  int arrearsCount = summary['arrearsCount'] ?? 0;
                                  bool hasAdvance = summaryManualDues.any((m) => (m['amount'] as num).toDouble() < -0.1);

                                  int itemIndex = i + entry.key + 1;
                                  final Color itemAccentColor = ThemeManager.getCardColor(itemIndex, isSubCard: true);
                                  final Color itemBgColor = ThemeManager.getCardContainerColor(itemIndex, isSubCard: true);
                                  final Color itemOnBgColor = ThemeManager.getCardOnContainerColor(itemIndex, isSubCard: true);

                              List overridden = d['overriddenServices'] ?? [];
                              List active = historicalServices != null 
                                  ? List<Map<String, dynamic>>.from(historicalServices)
                                  : DatabaseService.getEffectiveServices(categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? [], overriddenServices: overridden);
                              List manualDues = d['manualDues'] ?? [];

                              if (status == 'Vacant') {
                                return InkWell(
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    CategoryDialogs.showSubItemStatusDialog(
                                      context: context, 
                                      subItemId: subId, 
                                      subItemName: subName, 
                                      currentStatus: 'Vacant', 
                                      currentTenant: tenant, 
                                      currentNid: d['nidNumber'] ?? 'No Number',
                                      electricityDetails: ed
                                    );
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : itemBgColor,
                                    elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12), 
                                      side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                                          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                                          : BorderSide.none,
                                    ),
                                    child: ExpansionTile(
                                      backgroundColor: Colors.transparent,
                                      collapsedBackgroundColor: Colors.transparent,
                                      shape: const Border(),
                                      collapsedShape: const Border(),
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      iconColor: itemAccentColor,
                                      collapsedIconColor: itemAccentColor,
                                      title: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.meeting_room_outlined, color: itemAccentColor, size: 22),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
                                                ),
                                                child: Text(
                                                  subName,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w900, 
                                                    color: itemAccentColor, 
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              const SizedBox(width: 6),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(Icons.more_vert, size: 22, color: itemOnBgColor.withValues(alpha: 0.7)),
                                                onSelected: (val) async {
                                                  if (val == 'electric') CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator, initialDate: _selectedDate);
                                                  if (val == 'stop') {
                                                    bool isStopping = ed?['isStopped'] != true;
                                                    if (isStopping) {
                                                      double last = (ed?['lastReading'] ?? 0).toDouble();
                                                      double pres = (ed?['presentReading'] ?? 0).toDouble();
                                                      if (pres > last) {
                                                        CategoryDialogs.showConfirmDialog(
                                                          context: context,
                                                          title: "Confirm Stop Sub-Meter Billing",
                                                          content: "There are unused units (${(pres - last).toStringAsFixed(1)}). Stopping will reset Present Reading to Last Reading. Proceed?",
                                                          onConfirm: () async {
                                                            await _dbService.updateSubItemElectricity(subId, {
                                                              ...ed!,
                                                              'presentReading': last,
                                                              'isStopped': true,
                                                              'updatedAt': FieldValue.serverTimestamp(),
                                                            }, "Admin");
                                                          },
                                                        );
                                                      } else {
                                                        await _dbService.updateSubItemElectricityStatus(subId, true, "Admin");
                                                      }
                                                    } else {
                                                      await _dbService.updateSubItemElectricityStatus(subId, false, "Admin");
                                                    }
                                                  } else if (val == 'remove_electric') {
                                                     CategoryDialogs.showConfirmDialog(
                                                      context: context, 
                                                      title: "Remove Sub-Meter?",
                                                      content: "Are you sure you want to remove the electric meter from this unit? All previous billing history will be preserved, and the current meter reading will be carried forward for future use.", 
                                                      onConfirm: () async { 
                                                        SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                                        await _dbService.removeSubItemElectricity(subId, prefs.getString('username') ?? "Admin"); 
                                                      }
                                                    );
                                                  } else if (val == 'services') {
                                                    CategoryDialogs.showSubItemServiceSettingsDialog(context: context, subItemId: subId, subItemName: subName, categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? []);
                                                  } else if (val == 'dues') {
                                                    CategoryDialogs.showManualDueDialog(context: context, subItemId: subId, subItemName: subName, manualDues: d['manualDues'] ?? [], monthYear: _selectedMonthStr);
                                                  } else if (val == 'remove') {
                                                     CategoryDialogs.showConfirmDialog(
                                                      context: context, 
                                                      title: "Remove '$subName'?", 
                                                      content: "Are you sure you want to remove this $subName?", 
                                                      onConfirm: () async { 
                                                        SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                                        await _dbService.removeSubItem(subId, prefs.getString('username') ?? "Admin"); 
                                                      }
                                                    );
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  if (ed != null || !widget.isOperator)
                                                    PopupMenuItem(
                                                      value: ed == null ? 'electric' : 'stop', 
                                                      child: ListTile(
                                                        leading: Icon(Icons.electric_bolt, color: ed == null ? Theme.of(context).colorScheme.outline : context.electric, size: 20),
                                                        title: Text(ed == null ? "Add Sub-Meter" : (ed['isStopped'] == true ? "Resume Sub-Meter" : "Stop Sub-Meter")), 
                                                        dense: true
                                                      )
                                                    ),
                                                  const PopupMenuItem(value: 'services', child: ListTile(leading: Icon(Icons.settings_suggest_outlined, size: 20), title: Text("Manage Services"), dense: true)),
                                                  if (status == 'Occupied')
                                                    const PopupMenuItem(value: 'dues', child: ListTile(leading: Icon(Icons.money_off, size: 20, color: Colors.red), title: Text("Adjust Dues/Adv"), dense: true)),
                                                  if (ed != null && !widget.isOperator)
                                                    PopupMenuItem(
                                                      value: 'remove_electric', 
                                                      child: ListTile(
                                                        leading: Icon(Icons.electric_bolt, color: Theme.of(context).colorScheme.error, size: 20),
                                                        title: Text("Remove Sub-Meter", style: TextStyle(color: Theme.of(context).colorScheme.error)), 
                                                        dense: true
                                                      )
                                                    ),
                                                  if (!widget.isOperator)
                                                    PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20), title: Text("Remove Unit", style: TextStyle(color: Theme.of(context).colorScheme.error)), dense: true)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(left: 30),
                                                child: Text(
                                                  'Vacant',
                                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (ed != null) Icon(Icons.electric_bolt, color: context.electric, size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                "৳${monthTotal.toStringAsFixed(0)}",
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w900, 
                                                  color: itemOnBgColor, 
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 30, top: 1),
                                            child: Text(
                                              "${active.length} Services | Ready for new tenant",
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: itemOnBgColor.withValues(alpha: 0.8), 
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (d['nidNumber'] != null && d['nidNumber'] != 'No Name' && d['nidNumber'].toString().isNotEmpty)
                                              _buildSectionBox("Tenant NID", d['nidNumber'], Icons.badge_outlined, color: Theme.of(context).colorScheme.primary),
                                              
                                            if ((d['notes'] ?? '').toString().isNotEmpty)
                                              _buildSectionBox("Notes", d['notes'], Icons.note_alt_outlined, trailing: IconButton(
                                                icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error, size: 20), 
                                                onPressed: () => CategoryDialogs.showConfirmDialog(
                                                  context: context,
                                                  title: "Remove Note?",
                                                  content: "Are you sure you want to clear the note for '$subName'?",
                                                  confirmText: "Clear",
                                                  onConfirm: () async {
                                                    SharedPreferences prefs = await SharedPreferences.getInstance();
                                                    await _dbService.updateSubItemDetails(subId, {'notes': ''}, prefs.getString('username') ?? "Admin");
                                                  },
                                                ),
                                              )),
                                            
                                            if (ed != null && ed['isStopped'] != true)
                                                _buildSectionBox(
                                                  "Sub-Meter Bills", 
                                                  "Used: ${(ed['presentReading'] - ed['lastReading']).toStringAsFixed(1)} units | Meter: ${ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A'}\nLast Update: ${DatabaseService.formatFullDateTime(ed['updatedAt'] as Timestamp?)}\n${DatabaseService.formatDuration(ed['updatedAt'] as Timestamp?)}", 
                                                  Icons.electric_bolt, 
                                                  amount: eBillAmount, 
                                                  color: context.electric,
                                                  trailing: IconButton(
                                                    icon: Icon(Icons.edit_note, color: context.electric, size: 22), 
                                                    onPressed: () => CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator, initialDate: _selectedDate)
                                                  )
                                                ),

                                              ...active.map((s) => _buildServiceRow(subId, subName, s, overridden, d['macAddresses'] ?? [])),

                                              if (summaryManualDues.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Text(
                                                  "Additional Dues", 
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.error, 
                                                    fontWeight: FontWeight.bold
                                                  )
                                                ),
                                                const SizedBox(height: 4),
                                                ...summaryManualDues.map((m) {
                                                  double amt = (m['amount'] as num).toDouble();
                                                  bool isAdv = amt < 0;
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow, 
                                                      borderRadius: BorderRadius.circular(12), 
                                                      border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(child: Text(isAdv ? "As An Advance" : m['reason'], style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
                                                        Text("৳${amt.toStringAsFixed(1)}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                              
                              return InkWell(
                                    onTap: () {
                                      String targetMonth = _selectedMonthStr;
                                      var records = historyMap.values.where((doc) => doc['subItemId'] == subId).toList();
                                      var recordedDoc = records.isEmpty ? null : records.first;

                                      Map<String, dynamic> reportData;
                                      if (recordedDoc != null) {
                                        reportData = {
                                          ...recordedDoc.data() as Map<String, dynamic>,
                                          'docId': recordedDoc.id,
                                        };
                                      } else {
                                        reportData = {
                                          'status': 'Due',
                                          'monthYear': targetMonth,
                                          'subItemName': subName,
                                          'TenantName': tenant,
                                          'subItemId': subId,
                                          'profilePictureUrl': d['profilePictureUrl'],
                                          'categoryId': catId,
                                          'mainCategoryName': catName,
                                          'manualDues': d['manualDues'] ?? [],
                                          'nidNumber': d['nidNumber'] ?? '',
                                          'services': active,
                                          'electricityDetails': ed,
                                          'electricityBill': eBillAmount,
                                          'totalAmount': monthTotal,
                                          'houseRentTotal': servicesTotal,
                                          'createdAt': Timestamp.now(),
                                          'paymentNotes': 'Monthly breakdown (Estimated)',
                                        };
                                      }
                                      UserReportPage.showDetailsDialog(context, reportData);
                                    },
                                    onLongPress: () {
                                      HapticFeedback.heavyImpact();
                                      CategoryDialogs.showSubItemStatusDialog(
                                        context: context, 
                                        subItemId: subId, 
                                        subItemName: subName, 
                                        currentStatus: 'Occupied', 
                                        currentTenant: tenant, 
                                        currentNid: d['nidNumber'] ?? 'No Number',
                                        electricityDetails: ed
                                      );
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      color: isPaid 
                                          ? (ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.tertiaryContainer) 
                                          : (ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : itemBgColor),
                                      elevation: ThemeManager.appThemeNotifier.value == "Outline Theme" ? 0 : 2,
                                        shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                                            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                                            : BorderSide.none,
                                      ),
                                      child: ExpansionTile(
                                      backgroundColor: Colors.transparent,
                                      collapsedBackgroundColor: Colors.transparent,
                                      shape: const Border(),
                                      collapsedShape: const Border(),
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      iconColor: isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemAccentColor) : Theme.of(context).colorScheme.error,
                                      collapsedIconColor: isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemAccentColor) : Theme.of(context).colorScheme.error,
                                      title: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (isOccupied)
                                                GestureDetector(
                                                  onTap: d['profilePictureUrl'] != null ? () => _showFullScreenImage(context, d['profilePictureUrl'], "Tenant Profile") : null,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 8),
                                                    child: CircleAvatar(
                                                      radius: 14,
                                                      backgroundImage: d['profilePictureUrl'] != null ? NetworkImage(d['profilePictureUrl']) : null,
                                                      backgroundColor: Theme.of(context).colorScheme.surface,
                                                      child: d['profilePictureUrl'] == null ? const Icon(Icons.person, size: 18, color: Colors.grey) : null,
                                                    ),
                                                  ),
                                                ),
                                              Icon(
                                                isOccupied ? (isPaid ? Icons.check_circle : Icons.door_front_door_outlined) : Icons.meeting_room_outlined,
                                                color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? (isPaid ? Colors.green : (isOccupied ? Colors.black : Colors.red)) : (isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemAccentColor) : Theme.of(context).colorScheme.error),
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                                                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) 
                                                      : null,
                                                ),
                                                child: Text(
                                                  subName,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w900, 
                                                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Colors.black : (isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemAccentColor) : Theme.of(context).colorScheme.error), 
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(Icons.edit_note, size: 22, color: itemOnBgColor.withValues(alpha: 0.7)),
                                                onPressed: () => CategoryDialogs.showEditSubItemDetailsDialog(
                                                  context: context, 
                                                  subItemId: subId, 
                                                  currentName: subName, 
                                                  currentTenantName: tenant, 
                                                  currentNidNumber: d['nidNumber'] ?? 'No Number', 
                                                  currentNotes: d['notes'] ?? '',
                                                  currentProfileUrl: d['profilePictureUrl'],
                                                  currentNidUrl: d['nidPictureUrl'],
                                                ),
                                              ),
                                              if ((d['notes'] ?? '').toString().isNotEmpty)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 6),
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(4)),
                                                  child: Icon(Icons.notes, color: Theme.of(context).colorScheme.tertiary, size: 16),
                                                ),
                                              if (isOccupied)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 6),
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: Icon(isPaid ? Icons.receipt_long : Icons.request_quote_outlined, color: isPaid ? Theme.of(context).colorScheme.tertiary : itemOnBgColor, size: 24), 
                                                    onPressed: () => CategoryDialogs.showMarkAsPaidDialog(
                                                      context: context, 
                                                      subItemId: subId, 
                                                      subItemName: subName, 
                                                      TenantName: tenant, 
                                                      nidNumber: d['nidNumber'] ?? '', 
                                                      houseRentTotal: servicesTotal, 
                                                      electricityBill: eBillAmount, 
                                                      services: active.cast<Map<String, dynamic>>(), 
                                                      electricityDetails: ed, 
                                                      mainCategoryName: catName, 
                                                      manualDues: d['manualDues'] ?? [],
                                                      notes: d['notes'] ?? '',
                                                      profilePictureUrl: d['profilePictureUrl']
                                                    )
                                                  ),
                                                ),
                                              const SizedBox(width: 6),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(Icons.more_vert, size: 22, color: itemOnBgColor.withValues(alpha: 0.7)),
                                                onSelected: (val) async {
                                                  if (val == 'electric') CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator, initialDate: _selectedDate);
                                                  if (val == 'stop') {
                                                    bool isStopping = ed?['isStopped'] != true;
                                                    if (isStopping) {
                                                      double last = (ed?['lastReading'] ?? 0).toDouble();
                                                      double pres = (ed?['presentReading'] ?? 0).toDouble();
                                                      if (pres > last) {
                                                        CategoryDialogs.showConfirmDialog(
                                                          context: context,
                                                          title: "Confirm Stop Sub-Meter Billing",
                                                          content: "There are unused units (${(pres - last).toStringAsFixed(1)}). Stopping will reset Present Reading to Last Reading. Proceed?",
                                                          onConfirm: () async {
                                                            await _dbService.updateSubItemElectricity(subId, {
                                                              ...ed!,
                                                              'presentReading': last,
                                                              'isStopped': true,
                                                              'updatedAt': FieldValue.serverTimestamp(),
                                                            }, "Admin");
                                                          },
                                                        );
                                                      } else {
                                                        await _dbService.updateSubItemElectricityStatus(subId, true, "Admin");
                                                      }
                                                    } else {
                                                      await _dbService.updateSubItemElectricityStatus(subId, false, "Admin");
                                                    }
                                                  } else if (val == 'remove_electric') {
                                                     CategoryDialogs.showConfirmDialog(
                                                      context: context, 
                                                      title: "Remove Sub-Meter?", 
                                                      content: "Are you sure you want to remove the electric meter from this unit? All previous billing history will be preserved, and the current meter reading will be carried forward for future use.", 
                                                      onConfirm: () async { 
                                                        SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                                        await _dbService.removeSubItemElectricity(subId, prefs.getString('username') ?? "Admin"); 
                                                      }
                                                    );
                                                  } else if (val == 'services') {
                                                     CategoryDialogs.showSubItemServiceSettingsDialog(context: context, subItemId: subId, subItemName: subName, categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? []);
                                                  } else if (val == 'dues') {
                                                     CategoryDialogs.showManualDueDialog(context: context, subItemId: subId, subItemName: subName, manualDues: d['manualDues'] ?? [], monthYear: _selectedMonthStr);
                                                  } else if (val == 'remove') {
                                                     CategoryDialogs.showConfirmDialog(
                                                      context: context, 
                                                      title: "Remove '$subName'?", 
                                                      content: "Are you sure you want to remove this $subName?", 
                                                      onConfirm: () async { 
                                                        SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                                        await _dbService.removeSubItem(subId, prefs.getString('username') ?? "Admin"); 
                                                      }
                                                    );
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  if (ed != null || !widget.isOperator)
                                                    PopupMenuItem(
                                                      value: ed == null ? 'electric' : 'stop', 
                                                      child: ListTile(
                                                        leading: Icon(Icons.electric_bolt, color: ed == null ? Theme.of(context).colorScheme.outline : context.electric, size: 20),
                                                        title: Text(ed == null ? "Add Sub-Meter" : (ed['isStopped'] == true ? "Resume Sub-Meter" : "Stop Sub-Meter")), 
                                                        dense: true
                                                      )
                                                    ),
                                                  const PopupMenuItem(value: 'services', child: ListTile(leading: Icon(Icons.settings_suggest_outlined, size: 20), title: Text("Manage Services"), dense: true)),
                                                  if (status == 'Occupied')
                                                    const PopupMenuItem(value: 'dues', child: ListTile(leading: Icon(Icons.money_off, size: 20, color: Colors.red), title: Text("Adjust Dues/Adv"), dense: true)),
                                                  if (ed != null && !widget.isOperator)
                                                    PopupMenuItem(
                                                      value: 'remove_electric', 
                                                      child: ListTile(
                                                        leading: Icon(Icons.electric_bolt, color: Theme.of(context).colorScheme.error, size: 20),
                                                        title: Text("Remove Sub-Meter", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                                        dense: true
                                                      )
                                                    ),
                                                  if (!widget.isOperator)
                                                    PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20), title: Text("Remove Unit", style: TextStyle(color: Theme.of(context).colorScheme.error)), dense: true)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(left: 30),
                                                child: Text(
                                                  isOccupied ? (tenant.isNotEmpty && tenant != 'No Name' ? tenant : 'No Tenant') : 'Vacant',
                                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (ed != null) Icon(Icons.electric_bolt, color: context.electric, size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                "৳${unitMonthBill.toStringAsFixed(0)}",
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w900, 
                                                  color: isPaid ? Theme.of(context).colorScheme.tertiary : itemOnBgColor, 
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 30, top: 1),
                                            child: Builder(
                                              builder: (context) {
                                                String statsText = "";
                                                if (isOccupied) {
                                                  if (isPaid) {
                                                    statsText = "${active.length} Services | Payment Clear";
                                                    if (arrearsCount > 0) statsText = "Arrears Pending | $statsText";
                                                  } else {
                                                    statsText = "${active.length} Services | Due";
                                                    if (arrearsCount > 0) statsText += " + $arrearsCount Months Arrears";
                                                  }
                                                  if (hasAdvance) statsText += " (Advance Applied)";
                                                } else {
                                                  statsText = "${active.length} Services | Ready for new tenant";
                                                }

                                                return Text(
                                                  statsText,
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemOnBgColor.withValues(alpha: 0.8)) : itemOnBgColor.withValues(alpha: 0.8), 
                                                  ),
                                                );
                                              }
                                            ),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (d['nidNumber'] != null && d['nidNumber'] != 'No Name' && d['nidNumber'].toString().isNotEmpty)
                                                _buildSectionBox("Tenant NID", d['nidNumber'], Icons.badge_outlined, color: Theme.of(context).colorScheme.primary),

                                              if (isOccupied && pendingMonths.isNotEmpty)
                                                _buildSectionBox(
                                                  "Due Months (Pending)", 
                                                  "", 
                                                  Icons.history_toggle_off,
                                                  color: Theme.of(context).colorScheme.error,
                                                  customContent: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: pendingMonths.map((m) {
                                                      String mYear = m['monthYear'];
                                                      return InkWell(
                                                        onTap: () {
                                                          Map<String, dynamic> reportData;
                                                          if (m['isHistory']) {
                                                            reportData = m['data'];
                                                          } else {
                                                            reportData = {
                                                              'status': 'Due',
                                                              'monthYear': mYear,
                                                              'subItemName': subName,
                                                              'TenantName': tenant,
                                                              'subItemId': subId,
                                                              'profilePictureUrl': d['profilePictureUrl'],
                                                              'categoryId': catId,
                                                              'mainCategoryName': catName,
                                                              'manualDues': d['manualDues'] ?? [],
                                                              'nidNumber': d['nidNumber'] ?? '',
                                                              'services': active,
                                                              'electricityDetails': ed,
                                                              'electricityBill': eBillAmount,
                                                              'totalAmount': monthTotal,
                                                              'houseRentTotal': servicesTotal,
                                                              'createdAt': Timestamp.now(),
                                                              'paymentNotes': 'Monthly breakdown (Estimated)',
                                                            };
                                                          }
                                                          UserReportPage.showDetailsDialog(context, reportData);
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
                                                          ),
                                                          child: Text(
                                                            mYear,
                                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                              color: Theme.of(context).colorScheme.error,
                                                              fontWeight: FontWeight.bold,
                                                              decoration: TextDecoration.underline,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  )
                                                ),
                                              
                                              if ((d['notes'] ?? '').toString().isNotEmpty)
                                                _buildSectionBox("Notes", d['notes'], Icons.note_alt_outlined, trailing: IconButton(
                                                  icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error, size: 20), 
                                                  onPressed: () => CategoryDialogs.showConfirmDialog(
                                                    context: context,
                                                    title: "Remove Note?",
                                                    content: "Are you sure you want to clear the note for '$subName'?",
                                                    confirmText: "Clear",
                                                    onConfirm: () async {
                                                      SharedPreferences prefs = await SharedPreferences.getInstance();
                                                      await _dbService.updateSubItemDetails(subId, {'notes': ''}, prefs.getString('username') ?? "Admin");
                                                    },
                                                  ),
                                                )),
                                              
                                                  if (ed != null && ed['isStopped'] != true)
                                                _buildSectionBox(
                                                  "Sub-Meter Bills", 
                                                  "Used: ${(ed['presentReading'] - ed['lastReading']).toStringAsFixed(1)} units | Meter: ${ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A'}\nLast Update: ${DatabaseService.formatFullDateTime(ed['updatedAt'] as Timestamp?)}\n${DatabaseService.formatDuration(ed['updatedAt'] as Timestamp?)}", 
                                                  Icons.electric_bolt, 
                                                  amount: (existingRecord != null || isPaid) ? 0.0 : eBillAmount, 
                                                  color: context.electric,
                                                  trailing: IconButton(
                                                    icon: Icon(Icons.edit_note, color: context.electric, size: 22), 
                                                    onPressed: () => CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator, initialDate: _selectedDate)
                                                  )
                                                ),

                                              ...active.map((s) => _buildServiceRow(subId, subName, s, overridden, d['macAddresses'] ?? [])),

                                              if (summaryManualDues.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Text(
                                                  "Additional Dues", 
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.error, 
                                                    fontWeight: FontWeight.bold
                                                  )
                                                ),
                                                const SizedBox(height: 4),
                                                ...summaryManualDues.map((m) {
                                                  double amt = (m['amount'] as num).toDouble();
                                                  bool isAdv = amt < 0;
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow, 
                                                      borderRadius: BorderRadius.circular(12), 
                                                      border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(child: Text(isAdv ? "As An Advance" : m['reason'], style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
                                                        Text("৳${amt.toStringAsFixed(1)}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                },
                              );


                            }),
                            if (status == 'Vacant') ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => CategoryDialogs.showAddSubItemDialog(context: context, categoryId: catId, categoryName: catName),
                                  icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                                  label: Text(
                                    "Add New $catName", 
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBox(String title, String content, IconData icon, {double? amount, Color? color, Widget? trailing, Widget? customContent}) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.surfaceContainerLow, 
        borderRadius: BorderRadius.circular(12), 
        border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              if (amount != null) Text("৳${amount.toStringAsFixed(1)}", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: customContent ?? Text(content, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(String subId, String subName, Map<String, dynamic> s, List overridden, List macAddresses) {
    bool isOverridden = s['isOverridden'] == true;
    String name = s['name'];
    bool isWifi = name.toLowerCase().contains("wifi");
    int? devices = isWifi ? (s['deviceQuantity'] as num?)?.toInt() : null;
    double? unitPrice = isWifi ? (s['wifiCost'] as num?)?.toDouble() : null;
    
    String displayName = isWifi && devices != null 
        ? "$name (৳${unitPrice?.toStringAsFixed(0) ?? '0'} / device) (x$devices)" 
        : name;

    Widget trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("৳${s['amount'].toStringAsFixed(1)}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, height: 1.2)),
        const SizedBox(width: 4),
        InkWell(
          onTap: () {
            if (isWifi) {
              CategoryDialogs.showWifiServiceEditDialog(
                context: context, 
                subItemId: subId, 
                subItemName: subName, 
                serviceMap: s, 
                overriddenServices: overridden,
                macAddresses: macAddresses
              );
            } else {
              CategoryDialogs.showEditSubItemServiceDialog(context: context, subItemId: subId, subItemName: subName, serviceMap: s, overriddenServices: overridden);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.edit_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );

    if (isWifi && macAddresses.isNotEmpty) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.only(left: 34, bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          visualDensity: VisualDensity.compact,
          dense: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.wifi, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayName, 
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.2)
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          iconColor: Theme.of(context).colorScheme.primary,
          collapsedIconColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "MAC Addresses:\n${macAddresses.asMap().entries.map((e) {
                  var val = e.value;
                  String sn = (val is Map && val['sn'] != null && val['sn'].toString().isNotEmpty) ? val['sn'].toString() : (e.key + 1).toString();
                  String mac = val is Map ? val['mac'] : val.toString();
                  return "$sn) $mac";
                }).join('\n')}", 
                style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.primary, fontFamily: 'monospace')
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        children: [
          Icon(isWifi ? Icons.wifi : Icons.check_circle_outline, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.2)
                ),
                if (isOverridden && !isWifi) Text("Customized", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.secondary, fontStyle: FontStyle.italic, height: 1.2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _buildMainMeterTab() {
    return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
      valueListenable: _repository.billingHistory,
      builder: (context, billingHistory, child) {
        Map<String, double> paidUnitsMap = {};
        for (var doc in billingHistory) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['monthYear'] == _selectedMonthStr) {
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

        return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
          valueListenable: _repository.mainMeters,
          builder: (context, metersList, child) {
            final bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
            var meters = metersList.toList();
            meters.sort((a, b) => ((a.data() as Map)['meterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['meterNo'] ?? '').toString().toLowerCase()));
            
            var resMeters = meters.where((d) => (d.data() as Map)['meterType'] == 'Residential').toList();
            var comMeters = meters.where((d) => (d.data() as Map)['meterType'] == 'Commercial').toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text("Stats for:", style: Theme.of(context).textTheme.labelSmall),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left, size: 18), onPressed: () => _moveMonth(-1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                            Text(
                              _selectedMonthStr, 
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                            ),
                            IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: () => _moveMonth(1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  elevation: isOutline ? 0 : 2,
                  color: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardContainerColor(10),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), 
                    side: isOutline ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
                  ),
                  child: ExpansionTile(
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    leading: CircleAvatar(
                      backgroundColor: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardColor(10), 
                      child: Container(
                        decoration: isOutline ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)) : null,
                        child: Icon(Icons.settings_input_component, color: isOutline ? Theme.of(context).colorScheme.primary : Colors.white, size: 20)
                      )
                    ),
                    title: Text(
                      "Main Meters List", 
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(10))
                    ),
                    subtitle: Text("${meters.length} total meters found", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(10).withValues(alpha: 0.7))),
                    children: [
                      _buildMeterExpandableSection(
                        "Residential Meter", 
                        resMeters, 
                        Icons.home_outlined, 
                        Theme.of(context).colorScheme.primary,
                        paidUnitsMap,
                        colorIndex: 11,
                      ),
                      _buildMeterExpandableSection(
                        "Commercial Meter", 
                        comMeters, 
                        Icons.business_outlined, 
                        Theme.of(context).colorScheme.secondary,
                        paidUnitsMap,
                        colorIndex: 12,
                      ),
                    ],
                  ),
                ),
                _buildSubMeterExpandableSection(),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildMeterExpandableSection(String title, List<QueryDocumentSnapshot> meters, IconData icon, Color color, Map<String, double> paidUnitsMap, {int colorIndex = 0}) {
    bool isOp = widget.isOperator;
    final headerTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;
    final bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
    final Color effectiveBgColor = isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardContainerColor(colorIndex, isSubCard: true);
    final Color effectiveAccentColor = isOutline ? Theme.of(context).colorScheme.primary : ThemeManager.getCardColor(colorIndex, isSubCard: true);
    final Color onBgColor = isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(colorIndex, isSubCard: true);

    return Card(
      elevation: isOutline ? 0 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: effectiveBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: isOutline ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
      ),
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        leading: CircleAvatar(
          backgroundColor: isOutline ? ThemeManager.outlineBackground : effectiveAccentColor, 
          child: Container(
            decoration: isOutline ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)) : null,
            child: Icon(icon, color: Colors.white, size: 20)
          )
        ),
        title: Text(
          title, 
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: isOutline ? Colors.black : onBgColor)
        ),
        subtitle: Text("${meters.length} meters found", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isOutline ? Colors.black : onBgColor.withValues(alpha: 0.7))),
        children: [
          if (meters.isEmpty) 
            Padding(
              padding: const EdgeInsets.all(16), 
              child: Text("No meters registered", style: Theme.of(context).textTheme.bodySmall)
            )
          else 
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  border: const TableBorder(
                    verticalInside: BorderSide.none,
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: isOutline ? ThemeManager.outlineBackground : effectiveAccentColor,
                        border: isOutline ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)) : null,
                      ),
                      children: [
                        "#", "Meter Number", "Last Updated", "Last Readings", "Present Readings", "Govt. Last\n Bill Readings", "Govt. New\nBill Readings", "Govt. Bill\nAmounts", "Govt. Bill\nUnits", "Last Month\nUnit Rate", "This Month\nUnit Rate", "Govt.\nDue/Adv Units", "Main Meter\nUsed Units", "Sub-Meter\nUsed Units", "Balance", "Action"
                      ].map((h) => Padding(
                        padding: const EdgeInsets.all(12), 
                        child: Center(child: Text(h, textAlign: TextAlign.center, style: headerTextStyle?.copyWith(color: isOutline ? Colors.black : null)))
                      )).toList().sublist(0, isOp ? 15 : 16),
                    ),
                    ...meters.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var mDoc = entry.value;
                      var data = mDoc.data() as Map<String, dynamic>;
                      String meterNo = data['meterNo'] ?? 'N/A';
                      double last = (data['lastReading'] ?? 0).toDouble();
                      double pres = (data['presentReading'] ?? last).toDouble();
                      double mainUsed = pres - last;
                      double lastGovt = (data['lastGovtReading'] ?? 0).toDouble();
                      double newGovt = (data['govtBillReading'] ?? lastGovt).toDouble();
                      double govtAmt = (data['govtBillAmount'] ?? 0).toDouble();
                      double govtUnit = newGovt - lastGovt;
                      double lastRate = (data['lastMonthUnitRate'] ?? 0).toDouble();
                      
                      // Live calculation for consistency
                      double thisRate = govtUnit > 0 ? (govtAmt / govtUnit) : (data['unitRate'] ?? 0).toDouble();
                      double govtDueAdv = pres - newGovt;
                      
                      String advDueSuffix = "";
                      if (govtDueAdv < 0) advDueSuffix = "(A)";
                      else if (govtDueAdv > 0) advDueSuffix = "(D)";
                      bool isAdvDueRed = govtDueAdv != 0;
                      double totalSubPaid = paidUnitsMap[meterNo] ?? 0;
                      double balance = mainUsed - totalSubPaid;

                      Widget wrapCell(Widget child) {
                        return InkWell(
                          onTap: () => CategoryDialogs.showUpdateMainMeterDialog(context: context, data: data, docId: mDoc.id),
                          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Center(child: child)),
                        );
                      }

                      return TableRow(
                        decoration: BoxDecoration(color: isOutline ? ThemeManager.outlineBackground : (idx % 2 == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent)),
                        children: [
                          wrapCell(Text("${idx + 1}", style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(meterNo, style: dataStyle?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary))),
                          wrapCell(Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(DatabaseService.formatFullDateTime(data['updatedAt'] as Timestamp?), style: dataStyle?.copyWith(fontSize: 10, color: isOutline ? Colors.black : null)),
                              Text(DatabaseService.formatDuration(data['updatedAt'] as Timestamp?), style: dataStyle?.copyWith(fontSize: 9, color: isOutline ? Colors.black54 : Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)),
                            ],
                          )),
                          wrapCell(Text(last.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(pres.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(lastGovt.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(newGovt.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(govtAmt.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(govtUnit.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(lastRate.toStringAsFixed(1), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(thisRate.toStringAsFixed(1), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text("${govtDueAdv.toStringAsFixed(0)}$advDueSuffix", style: dataStyle?.copyWith(color: isAdvDueRed ? Theme.of(context).colorScheme.error : (isOutline ? Colors.black : null), fontWeight: isAdvDueRed ? FontWeight.bold : null))),
                          wrapCell(Text(mainUsed.toStringAsFixed(0), style: dataStyle?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null))),
                          wrapCell(Text(totalSubPaid.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null))),
                          wrapCell(Text(balance.toStringAsFixed(0), style: dataStyle?.copyWith(color: balance > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold))),
                          if (!isOp)
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                                onPressed: () => CategoryDialogs.showDeleteMeterDialog(
                                  context: context, 
                                  type: "MainMeter",
                                  meterNo: meterNo,
                                  onConfirm: () async {
                                    SharedPreferences prefs = await SharedPreferences.getInstance();
                                    await _dbService.removeMainMeter(mDoc.id, prefs.getString('username') ?? "Admin");
                                  }
                                ),
                              ),
                            ),
                        ].sublist(0, isOp ? 15 : 16),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubMeterExpandableSection() {
    bool isOp = widget.isOperator;
    final headerTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;

    return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
      valueListenable: _repository.subMeters,
      builder: (context, subMetersList, child) {
        final bool isOutline = ThemeManager.appThemeNotifier.value == "Outline Theme";
        var subMeters = subMetersList.toList();
        subMeters.sort((a, b) => ((a.data() as Map)['subMeterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['subMeterNo'] ?? '').toString().toLowerCase()));

        return Card(
          elevation: isOutline ? 0 : 2,
          color: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardContainerColor(13),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: isOutline ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
          ),
          child: ExpansionTile(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            leading: CircleAvatar(
              backgroundColor: isOutline ? ThemeManager.outlineBackground : ThemeManager.getCardColor(13), 
              child: Container(
                decoration: isOutline ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1)) : null,
                child: Icon(Icons.cable, color: isOutline ? Theme.of(context).colorScheme.primary : Colors.white, size: 20)
              )
            ),
            title: Text(
              "Sub-Meters List", 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(13))
            ),
            subtitle: Text("${subMeters.length} sub-meters registered", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isOutline ? Colors.black : ThemeManager.getCardOnContainerColor(13).withValues(alpha: 0.7))),
            children: [
              if (subMeters.isEmpty) 
                Padding(
                  padding: const EdgeInsets.all(16), 
                  child: Text("No sub-meters found.", style: Theme.of(context).textTheme.bodySmall)
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: const TableBorder(
                        verticalInside: BorderSide.none,
                      ),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: isOutline ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.secondary,
                            border: isOutline ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)) : null,
                          ),
                          children: [
                            "#", "Sub-Meter", "Last Updated", "Main-Meter", "Last", "Present", "Used", "Action"
                          ].map((h) => Padding(
                            padding: const EdgeInsets.all(12), 
                            child: Center(child: Text(h, textAlign: TextAlign.center, style: headerTextStyle?.copyWith(color: isOutline ? Colors.black : null)))
                          )).toList().sublist(0, isOp ? 7 : 8),
                        ),
                        ...subMeters.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var sDoc = entry.value;
                          var sData = sDoc.data() as Map<String, dynamic>;
                          double last = (sData['lastReading'] ?? 0).toDouble();
                          double pres = (sData['presentReading'] ?? last).toDouble();

                          return TableRow(
                            decoration: BoxDecoration(color: isOutline ? ThemeManager.outlineBackground : (idx % 2 == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent)),
                            children: [
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("${idx + 1}", style: dataStyle?.copyWith(color: isOutline ? Colors.black : null)))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(sData['subMeterNo'] ?? '', style: dataStyle?.copyWith(fontWeight: FontWeight.bold, color: isOutline ? Colors.black : null)))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(DatabaseService.formatFullDateTime(sData['updatedAt'] as Timestamp?), style: dataStyle?.copyWith(fontSize: 10, color: isOutline ? Colors.black : null)),
                                  Text(DatabaseService.formatDuration(sData['updatedAt'] as Timestamp?), style: dataStyle?.copyWith(fontSize: 9, color: isOutline ? Colors.black54 : Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)),
                                ],
                              ))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(sData['mainMeterNo'] ?? '', style: dataStyle?.copyWith(color: isOutline ? Colors.black : null)))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(last.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null)))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(pres.toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : null)))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text((pres - last).toStringAsFixed(0), style: dataStyle?.copyWith(color: isOutline ? Colors.black : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)))),
                              if (!isOp)
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
                                    onPressed: () => CategoryDialogs.showDeleteMeterDialog(
                                      context: context, 
                                      type: "SubMeter",
                                      meterNo: sData['subMeterNo'] ?? 'N/A',
                                      onConfirm: () async {
                                        SharedPreferences prefs = await SharedPreferences.getInstance();
                                        await _dbService.removeSubMeter(sDoc.id, prefs.getString('username') ?? "Admin");
                                      }
                                    ),
                                  ),
                                ),
                            ].sublist(0, isOp ? 7 : 8),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String title) {
    AppImageHelper.showInteractiveImage(context, url: imageUrl, title: title);
  }
}
