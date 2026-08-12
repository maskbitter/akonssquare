import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Admin/category_dialogs.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:akonssquare/Common/ui_helper.dart';

class CategoryPage extends StatefulWidget {
  final int initialSubTabIndex;
  final bool isOperator;
  const CategoryPage({super.key, this.initialSubTabIndex = 0, this.isOperator = false});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final DatabaseService _dbService = DatabaseService();
  String? _selectedFilterCategoryId;
  late DateTime _selectedDate;

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
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: accentColor, child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20)),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: accentColor)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: accentColor.withOpacity(0.7))),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: accentColor),
      ),
    );
  }

  void _showMeterChoiceMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
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
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialSubTabIndex,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
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
                TabBarView(
                  children: [
                    _buildCategoryManagerTab(status: 'Occupied'),
                    _buildCategoryManagerTab(status: 'Vacant'),
                    _buildMainMeterTab(),
                  ],
                ),
                if (!widget.isOperator)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      onPressed: () => _showAddActionMenu(context),
                      icon: const Icon(Icons.add),
                      label: const Text("Add / Manage"),
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getCategoriesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    var categories = snapshot.data!.docs.toList();
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
                    color: Theme.of(context).colorScheme.surface,
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
          child: StreamBuilder<QuerySnapshot>(
            stream: _dbService.getCategoriesStream(),
            builder: (context, categorySnapshot) {
              if (!categorySnapshot.hasData) return const Center(child: CircularProgressIndicator());
              var categoryDocs = categorySnapshot.data!.docs.toList();
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

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: categoryDocs.length,
                itemBuilder: (context, i) {
                  var catDoc = categoryDocs[i];
                  var catData = catDoc.data() as Map<String, dynamic>;
                  String catId = catDoc.id;
                  String catName = catData['categoryName'] ?? 'Unnamed';
                  List assignedServices = catData['assignedServices'] ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: _dbService.getSubItemsStream(catId),
                    builder: (context, subSnapshot) {
                      if (!subSnapshot.hasData) return const LinearProgressIndicator();
                      var subDocs = subSnapshot.data!.docs.where((doc) {
                        var d = doc.data() as Map<String, dynamic>;
                        String tenant = d['TenantName'] ?? '';
                        String s = d['status'] ?? (tenant.isNotEmpty && tenant != 'No Name' ? 'Occupied' : 'Vacant');
                        return s == status;
                      }).toList();

                      subDocs.sort((a, b) => ((a.data() as Map)['subItemName'] ?? '').compareTo((b.data() as Map)['subItemName'] ?? ''));

                      double catTotal = 0;
                      for (var doc in subDocs) {
                        var d = doc.data() as Map<String, dynamic>;
                        var ed = d['electricityDetails'];
                        double eBillVal = 0;
                        if (ed != null && ed['isStopped'] != true) {
                          eBillVal = (((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble()) * ((ed['pricePerUnit'] ?? 0) as num).toDouble();
                        }
                        List active = DatabaseService.getEffectiveServices(categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? [], overriddenServices: d['overriddenServices'] ?? []);
                        catTotal += (active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble()) + eBillVal);
                      }

                      bool hasElectric = subDocs.any((doc) => (doc.data() as Map<String, dynamic>)['electricityDetails'] != null);
                      
                      final Color accentColor = ThemeManager.getCardColor(i);
                      final Color bgColor = ThemeManager.getCardContainerColor(i);
                      final Color onBgColor = ThemeManager.getCardOnContainerColor(i);

                      return Card(
                        elevation: 2,
                        color: bgColor,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16), 
                          side: BorderSide.none,
                        ),
                        child: ExpansionTile(
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
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
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
                                      "${subDocs.length} units | Assigned services",
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: onBgColor.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (hasElectric) Icon(Icons.electric_bolt, color: context.electric, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        "৳${catTotal.toStringAsFixed(2)}",
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
                          children: [
                            const Divider(height: 1),
                            ...subDocs.asMap().entries.map((entry) {
                              var subDoc = entry.value;
                              var d = subDoc.data() as Map<String, dynamic>;
                              String subId = subDoc.id;
                              String subName = d['subItemName'] ?? 'Unnamed';
                              String tenant = d['TenantName'] ?? 'No Name';
                              var ed = d['electricityDetails'];
                              List overridden = d['overriddenServices'] ?? [];
                              List active = DatabaseService.getEffectiveServices(categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? [], overriddenServices: overridden);
                              double eBillAmount = 0;
                              if (ed != null && ed['isStopped'] != true) eBillAmount = (((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble()) * ((ed['pricePerUnit'] ?? 0) as num).toDouble();
                              double total = active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble()) + eBillAmount;

                              // Use nested index for sub-item coloring to make them different from category
                              int itemIndex = i + entry.key + 1;
                              final Color itemAccentColor = ThemeManager.getCardColor(itemIndex, isSubCard: true);
                              final Color itemBgColor = ThemeManager.getCardContainerColor(itemIndex, isSubCard: true);
                              final Color itemOnBgColor = ThemeManager.getCardOnContainerColor(itemIndex, isSubCard: true);

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
                                    color: itemBgColor,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12), 
                                      side: BorderSide.none,
                                    ),
                                    child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                                    iconColor: itemAccentColor,
                                    collapsedIconColor: itemAccentColor,
                                    title: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Icon(Icons.meeting_room_outlined, color: itemAccentColor, size: 24),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(4)),
                                                    child: Text(subName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: itemAccentColor)),
                                                  ),
                                                  const Spacer(),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: Icon(Icons.edit_outlined, size: 18, color: itemOnBgColor.withValues(alpha: 0.7)),
                                                    onPressed: () => CategoryDialogs.showEditSubItemDetailsDialog(
                                                      context: context, 
                                                      subItemId: subId, 
                                                      currentName: subName, 
                                                      currentTenantName: tenant, 
                                                      currentNidNumber: d['nidNumber'] ?? 'No Number', 
                                                      currentNotes: d['notes'] ?? ''
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  PopupMenuButton<String>(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: Icon(Icons.more_vert, size: 24, color: itemOnBgColor.withValues(alpha: 0.7)),
                                                    onSelected: (val) async {
                                                      if (val == 'electric') CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator);
                                                      if (val == 'stop') {
                                                        bool isStopping = ed?['isStopped'] != true;
                                                        if (isStopping) {
                                                          double last = (ed?['lastReading'] ?? 0).toDouble();
                                                          double pres = (ed?['presentReading'] ?? 0).toDouble();
                                                          if (pres > last) {
                                                            CategoryDialogs.showConfirmDialog(
                                                              context: context,
                                                              title: "Confirm Stop Electric",
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
                                                      } else if (val == 'services') {
                                                        CategoryDialogs.showSubItemServiceSettingsDialog(context: context, subItemId: subId, subItemName: subName, categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? []);
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
                                                      PopupMenuItem(
                                                        value: ed == null ? 'electric' : 'stop', 
                                                        child: ListTile(
                                                          leading: Icon(Icons.electric_bolt, color: ed == null ? Theme.of(context).colorScheme.outline : context.electric, size: 20),
                                                          title: Text(ed == null ? "Add Electric" : (ed['isStopped'] == true ? "Resume Electric" : "Stop Electric")), 
                                                          dense: true
                                                        )
                                                      ),
                                                      const PopupMenuItem(value: 'services', child: ListTile(leading: Icon(Icons.settings_suggest_outlined, size: 20), title: Text("Manage Services"), dense: true)),
                                                      if (!widget.isOperator)
                                                        PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20), title: Text("Remove Unit", style: TextStyle(color: Theme.of(context).colorScheme.error)), dense: true)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text("Status: Vacant", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: itemOnBgColor.withValues(alpha: 0.8))),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  if (ed != null) Icon(Icons.electric_bolt, color: context.electric, size: 20),
                                                  Text("৳${total.toStringAsFixed(2)}", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: itemOnBgColor)),
                                                ],
                                              ),
                                            ],
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
                                                  "Electric Bills", 
                                                  "Used: ${(ed['presentReading'] - ed['lastReading']).toStringAsFixed(1)} units | Meter: ${ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A'}\nLast Update: ${DatabaseService.formatDuration(ed['updatedAt'] as Timestamp?)} ago", 
                                                  Icons.electric_bolt, 
                                                  amount: eBillAmount, 
                                                  color: context.electric,
                                                  trailing: IconButton(
                                                    icon: Icon(Icons.electric_bolt, color: context.electric, size: 22), 
                                                    onPressed: () => CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator)
                                                  )
                                                ),

                                              ...active.map((s) => _buildServiceRow(subId, subName, s, overridden)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('billing_history').where('subItemId', isEqualTo: subId).where('monthYear', isEqualTo: _selectedMonthStr).snapshots(),
                                builder: (context, paySnap) {
                                  bool isPaid = paySnap.hasData && paySnap.data!.docs.isNotEmpty;
                                  
                                  // Always show the current calculated total (Usage-based Elec + Fixed Services)
                                  // After payment, eBillAmount is naturally 0 because of reading reset.
                                  double displayTotal = total; 

                                  bool isOccupied = status == 'Occupied';

                                  return InkWell(
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
                                      color: isPaid ? Theme.of(context).colorScheme.tertiaryContainer : itemBgColor,
                                      elevation: 2,
                                        shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide.none,
                                      ),
                                      child: ExpansionTile(
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
                                              Icon(
                                                isOccupied ? (isPaid ? Icons.check_circle : Icons.door_front_door_outlined) : Icons.meeting_room_outlined,
                                                color: isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemAccentColor) : Theme.of(context).colorScheme.error,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  subName,
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w900, 
                                                    color: isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemAccentColor) : Theme.of(context).colorScheme.error, 
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
                                                  currentNotes: d['notes'] ?? ''
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
                                                    onPressed: () => CategoryDialogs.showMarkAsPaidDialog(context: context, subItemId: subId, subItemName: subName, TenantName: tenant, nidNumber: d['nidNumber'] ?? '', houseRentTotal: total - eBillAmount, electricityBill: eBillAmount, services: active.cast<Map<String, dynamic>>(), electricityDetails: ed, mainCategoryName: catName)
                                                  ),
                                                ),
                                              const SizedBox(width: 6),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(Icons.more_vert, size: 22, color: itemOnBgColor.withValues(alpha: 0.7)),
                                                onSelected: (val) async {
                                                  if (val == 'electric') CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator);
                                                  if (val == 'stop') {
                                                    bool isStopping = ed?['isStopped'] != true;
                                                    if (isStopping) {
                                                      double last = (ed?['lastReading'] ?? 0).toDouble();
                                                      double pres = (ed?['presentReading'] ?? 0).toDouble();
                                                      if (pres > last) {
                                                        CategoryDialogs.showConfirmDialog(
                                                          context: context,
                                                          title: "Confirm Stop Electric",
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
                                                  } else if (val == 'services') {
                                                     CategoryDialogs.showSubItemServiceSettingsDialog(context: context, subItemId: subId, subItemName: subName, categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? []);
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
                                                  PopupMenuItem(
                                                    value: ed == null ? 'electric' : 'stop', 
                                                    child: ListTile(
                                                      leading: Icon(Icons.electric_bolt, color: ed == null ? Theme.of(context).colorScheme.outline : context.electric, size: 20),
                                                      title: Text(ed == null ? "Add Electric" : (ed['isStopped'] == true ? "Resume Electric" : "Stop Electric")), 
                                                      dense: true
                                                    )
                                                  ),
                                                  const PopupMenuItem(value: 'services', child: ListTile(leading: Icon(Icons.settings_suggest_outlined, size: 20), title: Text("Manage Services"), dense: true)),
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
                                                "৳${displayTotal.toStringAsFixed(2)}",
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w900, 
                                                  color: isPaid ? Theme.of(context).colorScheme.tertiary : itemOnBgColor, 
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 30, top: 1),
                                            child: Text(
                                              isOccupied 
                                                ? (isPaid ? "Payment Clear • $_selectedMonthStr" : "${active.length} Services | Due") 
                                                : "Ready for new tenant",
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: isOccupied ? (isPaid ? Theme.of(context).colorScheme.tertiary : itemOnBgColor.withValues(alpha: 0.8)) : itemOnBgColor.withValues(alpha: 0.8), 
                                              ),
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
                                                  "Electric Bills", 
                                                  "Used: ${(ed['presentReading'] - ed['lastReading']).toStringAsFixed(1)} units | Meter: ${ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A'}\nLast Update: ${DatabaseService.formatDuration(ed['updatedAt'] as Timestamp?)} ago", 
                                                  Icons.electric_bolt, 
                                                  amount: eBillAmount, 
                                                  color: context.electric,
                                                  trailing: IconButton(
                                                    icon: Icon(Icons.electric_bolt, color: context.electric, size: 22), 
                                                    onPressed: () => CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed, isOperator: widget.isOperator)
                                                  )
                                                ),

                                              ...active.map((s) => _buildServiceRow(subId, subName, s, overridden)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                },
                              );
                            }).toList(),
                            const SizedBox(height: 12),
                            Center(
                              child: AppButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  elevation: 0,
                                ),
                                onPressed: () => CategoryDialogs.showAddSubItemDialog(context: context, categoryId: catId, categoryName: catName),
                                child: Text("Add New $catName", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
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

  Widget _buildSectionBox(String title, String content, IconData icon, {double? amount, Color? color, Widget? trailing}) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow, 
        borderRadius: BorderRadius.circular(12), 
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
            child: Text(content, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(String subId, String subName, Map<String, dynamic> s, List overridden) {
    bool isOverridden = s['isOverridden'] == true;
    String name = s['name'];
    bool isWifi = name.toLowerCase().contains("wifi");
    int? devices = isWifi ? (s['deviceQuantity'] as num?)?.toInt() : null;
    double? unitPrice = isWifi ? (s['wifiCost'] as num?)?.toDouble() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          Icon(isWifi ? Icons.wifi : Icons.check_circle_outline, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWifi && devices != null ? "$name (x$devices)" : name, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.2)
                ),
                if (isWifi && unitPrice != null)
                  Text("৳${unitPrice.toStringAsFixed(0)} / device", style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.2)),
                if (isOverridden && !isWifi) Text("Customized", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.secondary, fontStyle: FontStyle.italic, height: 1.2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text("৳${s['amount'].toStringAsFixed(1)}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, height: 1.2)),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              if (isWifi) {
                CategoryDialogs.showWifiServiceEditDialog(context: context, subItemId: subId, subItemName: subName, serviceMap: s, overriddenServices: overridden);
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
      ),
    );
  }

  Widget _buildMainMeterTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getMainMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var meters = snapshot.data!.docs.toList();
        meters.sort((a, b) => ((a.data() as Map)['meterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['meterNo'] ?? '').toString().toLowerCase()));
        
        var resMeters = meters.where((d) => (d.data() as Map)['meterType'] == 'Residential').toList();
        var comMeters = meters.where((d) => (d.data() as Map)['meterType'] == 'Commercial').toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            Card(
              elevation: 2,
              color: Theme.of(context).colorScheme.primaryContainer,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), 
                side: BorderSide.none,
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.onPrimary, 
                  child: Icon(Icons.settings_input_component, color: Theme.of(context).colorScheme.primary, size: 20)
                ),
                title: Text(
                  "Main Meters List", 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                ),
                subtitle: Text("${meters.length} total meters found", style: Theme.of(context).textTheme.bodySmall),
                children: [
                  _buildMeterExpandableSection(
                    "Residential Meter", 
                    resMeters, 
                    Icons.home_outlined, 
                    Theme.of(context).colorScheme.primary,
                    bgColor: Theme.of(context).colorScheme.tertiaryContainer,
                    accentColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  _buildMeterExpandableSection(
                    "Commercial Meter", 
                    comMeters, 
                    Icons.business_outlined, 
                    Theme.of(context).colorScheme.secondary,
                    bgColor: Theme.of(context).colorScheme.secondaryContainer,
                    accentColor: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
            _buildSubMeterExpandableSection(),
          ],
        );
      },
    );
  }

  Widget _buildMeterExpandableSection(String title, List<QueryDocumentSnapshot> meters, IconData icon, Color color, {Color? bgColor, Color? accentColor}) {
    bool isOp = widget.isOperator;
    final headerTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;
    final effectiveBgColor = bgColor ?? Theme.of(context).colorScheme.surface;
    final effectiveAccentColor = accentColor ?? color;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: effectiveBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide.none,
      ),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: effectiveAccentColor, child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20)),
        title: Text(
          title, 
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: effectiveAccentColor)
        ),
        subtitle: Text("${meters.length} meters found", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: effectiveAccentColor.withOpacity(0.7))),
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
                        color: effectiveAccentColor,
                      ),
                      children: [
                        "#", "Meter Number", "Last Readings", "Present Readings", "Govt. Last\n Bill Readings", "Govt. New\nBill Readings", "Govt. Bill\nAmounts", "Govt. Bill\nUnits", "Last Month\nUnit Rate", "This Month\nUnit Rate", "Govt.\nDue/Adv Units", "Main Meter\nUsed Units", "Sub Units", "Balance", "Action"
                      ].map((h) => Padding(
                        padding: const EdgeInsets.all(12), 
                        child: Center(child: Text(h, textAlign: TextAlign.center, style: headerTextStyle))
                      )).toList().sublist(0, isOp ? 14 : 15),
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
                      double thisRate = (data['unitRate'] ?? 0).toDouble();
                      double govtDueAdv = newGovt - pres;
                      double totalSubPaid = (data['totalSubPaidUnits'] ?? 0).toDouble();
                      double balance = mainUsed - totalSubPaid;

                      Widget wrapCell(Widget child) {
                        return InkWell(
                          onTap: () => CategoryDialogs.showUpdateMainMeterDialog(context: context, data: data, docId: mDoc.id),
                          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Center(child: child)),
                        );
                      }

                      return TableRow(
                        decoration: BoxDecoration(color: idx % 2 == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent),
                        children: [
                          wrapCell(Text("${idx + 1}", style: dataStyle)),
                          wrapCell(Text(meterNo, style: dataStyle?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))),
                          wrapCell(Text(last.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(pres.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(lastGovt.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(newGovt.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(govtAmt.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(govtUnit.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(lastRate.toStringAsFixed(1), style: dataStyle)),
                          wrapCell(Text(thisRate.toStringAsFixed(1), style: dataStyle)),
                          wrapCell(Text(govtDueAdv.toStringAsFixed(0), style: dataStyle?.copyWith(color: govtDueAdv.abs() > 5 ? Theme.of(context).colorScheme.secondary : null, fontWeight: govtDueAdv.abs() > 5 ? FontWeight.bold : null))),
                          wrapCell(Text(mainUsed.toStringAsFixed(0), style: dataStyle?.copyWith(fontWeight: FontWeight.bold))),
                          wrapCell(Text(totalSubPaid.toStringAsFixed(0), style: dataStyle)),
                          wrapCell(Text(balance.toStringAsFixed(0), style: dataStyle?.copyWith(color: balance > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold))),
                          if (!isOp)
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                                onPressed: () => CategoryDialogs.showConfirmDialog(
                                  context: context, 
                                  title: "Remove Meter?", 
                                  content: "Are you sure you want to remove meter '$meterNo'?", 
                                  onConfirm: () async {
                                    SharedPreferences prefs = await SharedPreferences.getInstance();
                                    await _dbService.removeMainMeter(mDoc.id, prefs.getString('username') ?? "Admin");
                                  }
                                ),
                              ),
                            ),
                        ].sublist(0, isOp ? 14 : 15),
                      );
                    }).toList(),
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
    final headerTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSecondary, fontWeight: FontWeight.bold);
    final dataStyle = Theme.of(context).textTheme.bodyMedium;

    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getSubMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var subMeters = snapshot.data!.docs.toList();
        subMeters.sort((a, b) => ((a.data() as Map)['subMeterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['subMeterNo'] ?? '').toString().toLowerCase()));

        return Card(
          elevation: 2,
          color: Theme.of(context).colorScheme.secondaryContainer,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: BorderSide.none,
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.onSecondary, 
              child: Icon(Icons.cable, color: Theme.of(context).colorScheme.secondary, size: 20)
            ),
            title: Text(
              "Sub-Meters List", 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.secondary)
            ),
            subtitle: Text("${subMeters.length} sub-meters registered", style: Theme.of(context).textTheme.bodySmall),
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
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          children: [
                            "#", "Sub-Meter", "Main-Meter", "Last", "Present", "Used", "Action"
                          ].map((h) => Padding(
                            padding: const EdgeInsets.all(12), 
                            child: Center(child: Text(h, textAlign: TextAlign.center, style: headerTextStyle))
                          )).toList().sublist(0, isOp ? 6 : 7),
                        ),
                        ...subMeters.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var sDoc = entry.value;
                          var sData = sDoc.data() as Map<String, dynamic>;
                          double last = (sData['lastReading'] ?? 0).toDouble();
                          double pres = (sData['presentReading'] ?? last).toDouble();

                          return TableRow(
                            decoration: BoxDecoration(color: idx % 2 == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent),
                            children: [
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text("${idx + 1}", style: dataStyle))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(sData['subMeterNo'] ?? '', style: dataStyle?.copyWith(fontWeight: FontWeight.bold)))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(sData['mainMeterNo'] ?? '', style: dataStyle))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(last.toStringAsFixed(0), style: dataStyle))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text(pres.toStringAsFixed(0), style: dataStyle))),
                              Padding(padding: const EdgeInsets.all(12), child: Center(child: Text((pres - last).toStringAsFixed(0), style: dataStyle?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)))),
                              if (!isOp)
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: IconButton(
                                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
                                    onPressed: () => CategoryDialogs.showConfirmDialog(
                                      context: context, 
                                      title: "Remove Sub-Meter?", 
                                      content: "Are you sure you want to remove '${sData['subMeterNo']}'?", 
                                      onConfirm: () async {
                                        SharedPreferences prefs = await SharedPreferences.getInstance();
                                        await _dbService.removeSubMeter(sDoc.id, prefs.getString('username') ?? "Admin");
                                      }
                                    ),
                                  ),
                                ),
                            ].sublist(0, isOp ? 6 : 7),
                          );
                        }).toList(),
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

  Widget _buildMeterStat(String label, double val, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(val.toStringAsFixed(1), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
      ],
    );
  }
}
