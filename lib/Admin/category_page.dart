import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akonssquare/Admin/category_dialogs.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.add, color: Colors.white)), 
                title: const Text("New Category"), 
                subtitle: const Text("Create a new group like 'Shop' or 'Room'", maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () { Navigator.pop(ctx); CategoryDialogs.showCreateCategoryDialog(context); }
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.build_circle_outlined, color: Colors.white)), 
                title: const Text("Manage Services"), 
                subtitle: const Text("Add services like Water, Wifi, or Garbage", maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddServiceDialog(context); }
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.add_chart, color: Colors.white)), 
                title: const Text("Add Main Meter"), 
                subtitle: const Text("Register a main meter for electricity billing", maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddMainMeterDialog(context); }
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.cable, color: Colors.white)), 
                title: const Text("Add Sub Meter"), 
                subtitle: const Text("Register a sub-meter linked to a main meter", maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddSubMeterDialog(context); }
              ),
            ],
          ),
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
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(icon: Icon(Icons.door_front_door, size: 20), text: "Occupied"),
                Tab(icon: Icon(Icons.meeting_room, size: 20), text: "Vacant"),
                Tab(icon: Icon(Icons.electric_bolt, size: 20), text: "Main Meters"),
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
              const Icon(Icons.filter_alt, color: Colors.blue, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getCategoriesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    var categories = snapshot.data!.docs;
                    return DropdownButtonFormField<String?>(
                      value: _selectedFilterCategoryId,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(), labelText: "Category"),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text("All Categories")),
                        ...categories.map((doc) => DropdownMenuItem<String?>(value: doc.id, child: Text((doc.data() as Map)['categoryName'] ?? ''))),
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
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left, size: 18), onPressed: () => _moveMonth(-1), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                      Text(_selectedMonthStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
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

              if (categoryDocs.isEmpty) return const Center(child: Text("No categories found."));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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
                        String s = d['status'] ?? (tenant.isNotEmpty && tenant != 'No Tenant' ? 'Occupied' : 'Vacant');
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

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(catName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 0.5)),
                                        Text("${subDocs.length} units | ${assignedServices.length} assigned services", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                        const SizedBox(height: 4),
                                        Text("Grand Total: ৳${catTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.deepPurple)),
                                      ],
                                    ),
                                  ),
                                  IconButton(icon: const Icon(Icons.settings, color: Colors.blueAccent), onPressed: () => CategoryDialogs.showCategorySettingsDialog(context: context, categoryId: catId, categoryName: catName, dynamicAssignedServices: assignedServices)),
                                  if (!widget.isOperator) 
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent), 
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
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ...subDocs.map((subDoc) {
                              var d = subDoc.data() as Map<String, dynamic>;
                              String subId = subDoc.id;
                              String subName = d['subItemName'] ?? 'Unnamed';
                              String tenant = d['TenantName'] ?? 'No Tenant';
                              var ed = d['electricityDetails'];
                              List overridden = d['overriddenServices'] ?? [];
                              List active = DatabaseService.getEffectiveServices(categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? [], overriddenServices: overridden);
                              double eBillAmount = 0;
                              if (ed != null && ed['isStopped'] != true) eBillAmount = (((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble()) * ((ed['pricePerUnit'] ?? 0) as num).toDouble();
                              double total = active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble()) + eBillAmount;

                              if (status == 'Vacant') {
                                return InkWell(
                                  onLongPress: () => CategoryDialogs.showSubItemStatusDialog(
                                    context: context, 
                                    subItemId: subId, 
                                    subItemName: subName, 
                                    currentStatus: 'Vacant', 
                                    currentTenant: tenant, 
                                    currentNid: d['nidNumber'] ?? ''
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    color: Colors.red.shade50.withOpacity(0.3),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100, width: 0.5)),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.meeting_room_outlined, color: Colors.redAccent, size: 22),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(subName, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 18), overflow: TextOverflow.ellipsis)),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                                            onPressed: () => CategoryDialogs.showEditSubItemDetailsDialog(
                                              context: context, 
                                              subItemId: subId, 
                                              currentName: subName, 
                                              currentTenantName: tenant, 
                                              currentNidNumber: d['nidNumber'] ?? 'No Number', 
                                              currentNotes: d['notes'] ?? ''
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: const Row(
                                        children: [
                                          SizedBox(width: 32),
                                          Text("Status: VACANT", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 24, color: Colors.blueGrey),
                                        onSelected: (val) async {
                                          if (val == 'remove') CategoryDialogs.showConfirmDialog(
                                            context: context, 
                                            title: "Remove '$subName'?", 
                                            content: "Are you sure you want to remove this $subName?", 
                                            onConfirm: () async { 
                                              SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                              await _dbService.removeSubItem(subId, prefs.getString('username') ?? "Admin"); 
                                            }
                                          );
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red, size: 20), title: Text("Remove Unit", style: TextStyle(color: Colors.red)), dense: true)),
                                        ],
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (d['nidNumber'] != null && d['nidNumber'] != 'No Number' && d['nidNumber'].toString().isNotEmpty)
                                                _buildSectionBox("Tenant NID", d['nidNumber'], Icons.badge_outlined, color: Colors.indigo),
                                                
                                              if ((d['notes'] ?? '').toString().isNotEmpty)
                                                _buildSectionBox("Notes", d['notes'], Icons.note_alt_outlined, trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 20), onPressed: () => _dbService.updateSubItemDetails(subId, {'notes': ''}, "Admin"))),
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
                                  double displayTotal = total;
                                  if (isPaid) {
                                    displayTotal = (paySnap.data!.docs.first['totalAmount'] as num).toDouble();
                                  }

                                  return InkWell(
                                    onLongPress: () => CategoryDialogs.showSubItemStatusDialog(
                                      context: context, 
                                      subItemId: subId, 
                                      subItemName: subName, 
                                      currentStatus: 'Occupied', 
                                      currentTenant: tenant, 
                                      currentNid: d['nidNumber'] ?? ''
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      color: isPaid ? Colors.green.shade50.withOpacity(0.5) : (i % 2 == 0 ? Colors.blue.shade50.withOpacity(0.4) : Colors.green.shade50.withOpacity(0.4)),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: isPaid ? const BorderSide(color: Colors.green, width: 0.5) : BorderSide.none
                                      ),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                        title: Row(
                                          children: [
                                            Icon(isPaid ? Icons.check_circle : Icons.door_front_door_outlined, color: isPaid ? Colors.green : Colors.blue, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(child: Text(subName, style: TextStyle(fontWeight: FontWeight.w900, color: isPaid ? Colors.green.shade700 : Colors.blue, fontSize: 18), overflow: TextOverflow.ellipsis)),
                                            Text("৳${displayTotal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: isPaid ? Colors.green.shade700 : Colors.blue, fontSize: 18)),
                                            const SizedBox(width: 8),
                                            if (!isPaid)
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                                                onPressed: () => CategoryDialogs.showEditSubItemDetailsDialog(
                                                  context: context, 
                                                  subItemId: subId, 
                                                  currentName: subName, 
                                                  currentTenantName: tenant, 
                                                  currentNidNumber: d['nidNumber'] ?? 'No Number', 
                                                  currentNotes: d['notes'] ?? ''
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: Row(
                                          children: [
                                            const SizedBox(width: 32),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (tenant != 'No Tenant' && tenant.isNotEmpty) Text(tenant, style: TextStyle(fontSize: 13, color: isPaid ? Colors.green.shade600 : Colors.blueGrey, fontWeight: FontWeight.bold)),
                                                Text(isPaid ? "PAID for $_selectedMonthStr" : "${active.length} active services | DUE", style: TextStyle(fontSize: 11, color: isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if ((d['notes'] ?? '').toString().isNotEmpty) const Icon(Icons.notes, color: Colors.blueGrey, size: 20),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: Icon(isPaid ? Icons.receipt_long : Icons.request_quote_outlined, color: isPaid ? Colors.blue : Colors.orange, size: 24), 
                                              onPressed: () => CategoryDialogs.showMarkAsPaidDialog(context: context, subItemId: subId, subItemName: subName, TenantName: tenant, nidNumber: d['nidNumber'] ?? '', houseRentTotal: total - eBillAmount, electricityBill: eBillAmount, services: active.cast<Map<String, dynamic>>(), electricityDetails: ed, mainCategoryName: catName)
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert, size: 24, color: Colors.blueGrey),
                                              onSelected: (val) async {
                                                if (val == 'electric') CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed);
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
                                                }
                                                if (val == 'services') CategoryDialogs.showSubItemServiceSettingsDialog(context: context, subItemId: subId, subItemName: subName, categoryServices: assignedServices, excludedServices: d['excludedServices'] ?? []);
                                                if (val == 'remove') CategoryDialogs.showConfirmDialog(
                                                  context: context, 
                                                  title: "Remove '$subName'?", 
                                                  content: "Are you sure you want to remove this $subName?", 
                                                  onConfirm: () async { 
                                                    SharedPreferences prefs = await SharedPreferences.getInstance(); 
                                                    await _dbService.removeSubItem(subId, prefs.getString('username') ?? "Admin"); 
                                                  }
                                                );
                                              },
                                              itemBuilder: (ctx) => [
                                                PopupMenuItem(
                                                  value: ed == null ? 'electric' : 'stop', 
                                                  child: ListTile(
                                                    leading: Icon(Icons.flash_on, color: ed == null ? Colors.grey : Colors.amber, size: 20), 
                                                    title: Text(ed == null ? "Add Electric" : (ed['isStopped'] == true ? "Resume Electric" : "Stop Electric")), 
                                                    dense: true
                                                  )
                                                ),
                                                const PopupMenuItem(value: 'services', child: ListTile(leading: Icon(Icons.settings_suggest, size: 20), title: Text("Manage Services"), dense: true)),
                                                const PopupMenuItem(value: 'remove', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red, size: 20), title: Text("Remove Unit", style: TextStyle(color: Colors.red)), dense: true)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (d['nidNumber'] != null && d['nidNumber'] != 'No Number' && d['nidNumber'].toString().isNotEmpty)
                                                  _buildSectionBox("Tenant NID", d['nidNumber'], Icons.badge_outlined, color: Colors.indigo),

                                                if ((d['notes'] ?? '').toString().isNotEmpty)
                                                  _buildSectionBox("Notes", d['notes'], Icons.note_alt_outlined, trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 20), onPressed: () => _dbService.updateSubItemDetails(subId, {'notes': ''}, "Admin"))),
                                                
                                                    if (ed != null && ed['isStopped'] != true)
                                                  _buildSectionBox(
                                                    "Electric Bills", 
                                                    "Used: ${(ed['presentReading'] - ed['lastReading']).toStringAsFixed(1)} units | Meter: ${ed['subMeterNo'] ?? ed['mainSubMeterNo'] ?? 'N/A'}\nLast Update: ${DatabaseService.formatDuration(ed['updatedAt'] as Timestamp?)} ago", 
                                                    Icons.flash_on, 
                                                    amount: eBillAmount, 
                                                    color: Colors.amber,
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.electric_bolt, color: Colors.orange, size: 22), 
                                                      onPressed: () => CategoryDialogs.showElectricityDialog(context: context, subItemId: subId, subItemName: subName, existingData: ed)
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
                              );
                            }).toList(),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => CategoryDialogs.showAddSubItemDialog(context: context, categoryId: catId, categoryName: catName),
                                icon: const Icon(Icons.add_circle_outline, size: 22),
                                label: Text("Add New $catName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
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

  Widget _buildSectionBox(String title, String content, IconData icon, {double? amount, Color color = Colors.blueGrey, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const Spacer(),
              if (amount != null) Text("৳${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(content, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWifi && devices != null ? "$name (Devices: $devices)" : name, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                ),
                if (isWifi && unitPrice != null)
                  Text("(৳${unitPrice.toStringAsFixed(0)} per device)", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                if (isOverridden && !isWifi) const Text("Customized from 'Original'", style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text("৳${s['amount'].toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
            onPressed: () {
              if (isWifi) {
                CategoryDialogs.showWifiServiceEditDialog(context: context, subItemId: subId, subItemName: subName, serviceMap: s, overriddenServices: overridden);
              } else {
                CategoryDialogs.showEditSubItemServiceDialog(context: context, subItemId: subId, subItemName: subName, serviceMap: s, overriddenServices: overridden);
              }
            },
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
        var meters = snapshot.data!.docs;
        var resMeters = meters.where((d) => (d.data() as Map)['meterType'] == 'Residential').toList();
        var comMeters = meters.where((d) => (d.data() as Map)['meterType'] == 'Commercial').toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildMeterExpandableSection("Residential Main Meters", resMeters, Icons.home_outlined, Colors.green),
            const SizedBox(height: 12),
            _buildMeterExpandableSection("Commercial Main Meters", comMeters, Icons.business_outlined, Colors.orange),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            _buildSubMeterExpandableSection(),
          ],
        );
      },
    );
  }

  Widget _buildMeterExpandableSection(String title, List<QueryDocumentSnapshot> meters, IconData icon, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        subtitle: Text("${meters.length} meters found", style: const TextStyle(fontSize: 12)),
        children: [
          if (meters.isEmpty) 
            const Padding(padding: EdgeInsets.all(16), child: Text("No meters registered"))
          else 
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade300),
                child: DataTable(
                  columnSpacing: 12,
                  headingRowColor: WidgetStateProperty.all(color.withOpacity(0.05)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 11),
                  dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                  columns: const [
                    DataColumn(label: Text("#")),
                    DataColumn(label: Text("Meter No")),
                    DataColumn(label: Text("Last\nReading")),
                    DataColumn(label: Text("Present\nReading")),
                    DataColumn(label: Text("Last Govt.\nReading")),
                    DataColumn(label: Text("New Govt.\nReading")),
                    DataColumn(label: Text("Govt. Bill\nAmount")),
                    DataColumn(label: Text("Govt. Bill\nUnit")),
                    DataColumn(label: Text("Last Month\nRate")),
                    DataColumn(label: Text("This Month\nRate")),
                    DataColumn(label: Text("Govt Due/Adv\nUnits")),
                    DataColumn(label: Text("Main Meter\nUsed")),
                    DataColumn(label: Text("Total Sub\nUnits")),
                    DataColumn(label: Text("Balance\nUnits")),
                    DataColumn(label: Text("Actions")),
                  ],
                  rows: meters.asMap().entries.map((entry) {
                    int index = entry.key + 1;
                    var mDoc = entry.value;
                    var data = mDoc.data() as Map<String, dynamic>;
                    String meterNo = data['meterNo'] ?? 'N/A';
                    
                    double last = (data['lastReading'] ?? 0).toDouble();
                    double pres = (data['presentReading'] ?? 0).toDouble();
                    double mainUsed = pres - last;
                    
                    double lastGovt = (data['lastGovtReading'] ?? 0).toDouble();
                    double newGovt = (data['govtBillReading'] ?? 0).toDouble();
                    double govtAmt = (data['govtBillAmount'] ?? 0).toDouble();
                    double govtUnit = newGovt - lastGovt;
                    
                    double lastRate = (data['lastMonthUnitRate'] ?? 0).toDouble();
                    double thisRate = (data['unitRate'] ?? 0).toDouble();
                    
                    double govtDueAdv = newGovt - pres;
                    double totalSubPaid = (data['totalSubPaidUnits'] ?? 0).toDouble();
                    double balance = mainUsed - totalSubPaid;

                    return DataRow(
                      onSelectChanged: (_) => CategoryDialogs.showUpdateMainMeterDialog(context: context, data: data, docId: mDoc.id),
                      cells: [
                        DataCell(Text("$index")),
                        DataCell(Text(meterNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(last.toStringAsFixed(1))),
                        DataCell(Text(pres.toStringAsFixed(1))),
                        DataCell(Text(lastGovt.toStringAsFixed(1))),
                        DataCell(Text(newGovt.toStringAsFixed(1))),
                        DataCell(Text("৳${govtAmt.toStringAsFixed(0)}")),
                        DataCell(Text(govtUnit.toStringAsFixed(1))),
                        DataCell(Text("৳${lastRate.toStringAsFixed(2)}")),
                        DataCell(Text("৳${thisRate.toStringAsFixed(2)}")),
                        DataCell(Text(govtDueAdv.toStringAsFixed(1), style: TextStyle(color: govtDueAdv.abs() > 5 ? Colors.orange : Colors.black87, fontWeight: govtDueAdv.abs() > 5 ? FontWeight.bold : FontWeight.normal))),
                        DataCell(Text(mainUsed.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(totalSubPaid.toStringAsFixed(1))),
                        DataCell(
                          Text(
                            balance.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: balance > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () => CategoryDialogs.showConfirmDialog(
                              context: context, 
                              title: "Remove Meter?", 
                              content: "Are you sure you want to remove meter '$meterNo'?", 
                              onConfirm: () async {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                await _dbService.removeMainMeter(mDoc.id, prefs.getString('username') ?? "Admin");
                              }
                            ),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubMeterExpandableSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getSubMetersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var subMeters = snapshot.data!.docs;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: ExpansionTile(
            leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.cable, color: Colors.white)),
            title: const Text("Sub-Meters List", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            subtitle: Text("${subMeters.length} sub-meters registered", style: const TextStyle(fontSize: 12)),
            children: [
              if (subMeters.isEmpty) 
                const Padding(padding: EdgeInsets.all(16), child: Text("No sub-meters found."))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text("#")),
                      DataColumn(label: Text("Sub-Meter No")),
                      DataColumn(label: Text("Main-Meter No")),
                      DataColumn(label: Text("Last Reading")),
                      DataColumn(label: Text("Present Reading")),
                      DataColumn(label: Text("Used Unit")),
                      DataColumn(label: Text("Actions")),
                    ],
                    rows: subMeters.asMap().entries.map((entry) {
                      int index = entry.key + 1;
                      var sDoc = entry.value;
                      var sData = sDoc.data() as Map<String, dynamic>;
                      double last = (sData['lastReading'] ?? 0).toDouble();
                      double pres = (sData['presentReading'] ?? 0).toDouble();
                      
                      return DataRow(
                        cells: [
                          DataCell(Text("$index")),
                          DataCell(Text(sData['subMeterNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(sData['mainMeterNo'] ?? '')),
                          DataCell(Text(last.toStringAsFixed(1))),
                          DataCell(Text(pres.toStringAsFixed(1))),
                          DataCell(Text((pres - last).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
                        ],
                      );
                    }).toList(),
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
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
        Text(val.toStringAsFixed(1), style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
      ],
    );
  }
}
