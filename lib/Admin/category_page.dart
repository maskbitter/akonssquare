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
              ListTile(leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.add, color: Colors.white)), title: const Text("New Category"), onTap: () { Navigator.pop(ctx); CategoryDialogs.showCreateCategoryDialog(context); }),
              const Divider(),
              ListTile(leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.build_circle_outlined, color: Colors.white)), title: const Text("Manage Services"), onTap: () { Navigator.pop(ctx); CategoryDialogs.showAddServiceDialog(context); }),
              const Divider(),
              ListTile(leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.add_chart, color: Colors.white)), title: const Text("Add Main Meter"), onTap: () { Navigator.pop(ctx); CategoryDialogs.showMainMeterDialog(context: context); }),
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
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.filter_alt, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text("Filter Category:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getCategoriesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    var categories = snapshot.data!.docs;
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedFilterCategoryId,
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                      hint: const Text("All"),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text("All")),
                        ...categories.map((doc) => DropdownMenuItem<String?>(value: doc.id, child: Text((doc.data() as Map)['categoryName'] ?? ''))),
                      ],
                      onChanged: (val) => setState(() => _selectedFilterCategoryId = val),
                    );
                  },
                ),
              ),
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
                                        title: "Remove Category?", 
                                        content: "Remove '$catName'?", 
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

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                color: i % 2 == 0 ? Colors.blue.shade50.withOpacity(0.4) : Colors.green.shade50.withOpacity(0.4),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                                  title: Row(
                                    children: [
                                      const Icon(Icons.door_front_door_outlined, color: Colors.blue, size: 22),
                                      const SizedBox(width: 10),
                                      Text(subName, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 18)),
                                      const Spacer(),
                                      Text("৳${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 18)),
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
                                          if (tenant != 'No Tenant' && tenant.isNotEmpty) Text(tenant, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                          Text("${active.length} active services", style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
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
                                        icon: const Icon(Icons.request_quote_outlined, color: Colors.green, size: 24), 
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
                                          if ((d['notes'] ?? '').toString().isNotEmpty)
                                            _buildSectionBox("Notes", d['notes'], Icons.note_alt_outlined, trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 20), onPressed: () => _dbService.updateSubItemDetails(subId, {'notes': ''}, "Admin"))),
                                          
                                          if (ed != null && ed['isStopped'] != true)
                                            _buildSectionBox("Electric Bills", "Used: ${(ed['presentReading'] - ed['lastReading']).toStringAsFixed(1)} units | Meter: ${ed['mainSubMeterNo'] ?? 'N/A'}\nLast Update: ${DatabaseService.formatDuration(ed['updatedAt'] as Timestamp?)} ago", Icons.flash_on, amount: eBillAmount, color: Colors.amber),

                                          ...active.map((s) => _buildServiceRow(subId, subName, s, overridden)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (isOverridden) const Text("Customized from 'Original'", style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Text("৳${s['amount'].toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
            onPressed: () => CategoryDialogs.showEditSubItemServiceDialog(context: context, subItemId: subId, subItemName: subName, serviceMap: s, overriddenServices: overridden),
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
            _buildMeterExpandableSection("Residential Meters", resMeters, Icons.home_outlined, Colors.green),
            const SizedBox(height: 12),
            _buildMeterExpandableSection("Commercial Meters", comMeters, Icons.business_outlined, Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildMeterExpandableSection(String title, List<QueryDocumentSnapshot> meters, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        subtitle: Text("${meters.length} meters found", style: const TextStyle(fontSize: 12)),
        children: [
          if (meters.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("No meters registered"))
          else SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text("#")),
                    DataColumn(label: Text("Meter No")),
                    DataColumn(label: Text("Last")),
                    DataColumn(label: Text("Present")),
                    DataColumn(label: Text("Used")),
                    DataColumn(label: Text("Action")),
                  ],
                  rows: meters.asMap().entries.map((e) {
                    var data = e.value.data() as Map<String, dynamic>;
                    double last = (data['lastReading'] ?? 0).toDouble();
                    double pres = (data['presentReading'] ?? 0).toDouble();
                    return DataRow(cells: [
                      DataCell(Text("${e.key + 1}")),
                      DataCell(Text(data['meterNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(last.toStringAsFixed(0))),
                      DataCell(Text(pres.toStringAsFixed(0))),
                      DataCell(Text((pres - last).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => CategoryDialogs.showMainMeterDialog(context: context, existingData: data, docId: e.value.id))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
