import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:flutter/services.dart';

class CategoryDialogs {
  static final DatabaseService _dbService = DatabaseService();

  static void _showValidationWarning(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text("Required")])),
        content: Text(message, textAlign: TextAlign.center),
        actions: [Center(child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")))],
      ),
    );
  }

  static void showConfirmDialog({
    required BuildContext context, 
    required String title, 
    required String content, 
    required VoidCallback onConfirm,
    String confirmText = "Remove",
    Color confirmColor = Colors.red,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.delete_forever_outlined, color: confirmColor, size: 40),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        content: Text(content, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, 
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                label: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor, 
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () { Navigator.pop(ctx); onConfirm(); }, 
                label: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold))
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static void showCreateCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Text("New Category", style: TextStyle(fontWeight: FontWeight.bold))),
        content: TextField(controller: controller, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Category Name", border: OutlineInputBorder())),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: isLoading ? null : () async {
              String name = controller.text.trim(); if (name.isEmpty) return;
              setDialogState(() => isLoading = true);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await _dbService.addCategory(name, prefs.getString('username') ?? "Admin");
              if (context.mounted) Navigator.pop(ctx);
            }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Save"))),
          ]),
        ],
      )),
    );
  }

  static void showAddServiceDialog(BuildContext context) {
    final nameController = TextEditingController(); 
    final amountController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(child: Text("Manage Services", style: TextStyle(fontWeight: FontWeight.bold))),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  TextField(
                    controller: nameController, 
                    textAlign: TextAlign.center, 
                    decoration: const InputDecoration(labelText: "New Service Name", border: OutlineInputBorder(), isDense: true)
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController, 
                    textAlign: TextAlign.center, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: "Price (BDT)", prefixText: "৳ ", border: OutlineInputBorder(), isDense: true)
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    onPressed: isLoading ? null : () async {
                      String name = nameController.text.trim(); 
                      double amt = double.tryParse(amountController.text) ?? 0;
                      if (name.isEmpty) return;
                      setDialogState(() => isLoading = true);
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await _dbService.addService(name, amt, prefs.getString('username') ?? "Admin");
                      nameController.clear();
                      amountController.clear();
                      setDialogState(() => isLoading = false);
                    }, 
                    label: Text(isLoading ? "Saving..." : "Add Service")
                  ),
                  const Divider(height: 32),
                  const Text("Existing Services", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _dbService.getServicesStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      var docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Text("No services found.", style: TextStyle(fontSize: 12, color: Colors.grey));
                      
                      return Column(
                        children: docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String sName = data['serviceName'] ?? 'Unknown';
                          double amt = (data['amount'] ?? 0).toDouble();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text("৳${amt.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => showConfirmDialog(
                                    context: context, 
                                    title: "Delete Service?", 
                                    content: "Remove '$sName' permanently?", 
                                    onConfirm: () async {
                                      SharedPreferences prefs = await SharedPreferences.getInstance();
                                      await _dbService.removeService(doc.id, prefs.getString('username') ?? "Admin");
                                    }
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ],
        ),
      ),
    );
  }

  static void showAddSubItemDialog({required BuildContext context, required String categoryId, required String categoryName}) {
    final subItemController = TextEditingController(); final tenantNameController = TextEditingController();
    final nidController = TextEditingController(); final notesController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(child: Text("Add Unit to $categoryName", style: const TextStyle(fontWeight: FontWeight.bold))),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subItemController, textAlign: TextAlign.center, decoration: InputDecoration(labelText: "$categoryName No", border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: tenantNameController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Tenant Name (Optional)", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: nidController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "NID Number (Optional)", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: notesController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Notes", border: OutlineInputBorder()), maxLines: 2),
        ])),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: isLoading ? null : () async {
              String name = subItemController.text.trim(); if (name.isEmpty) return;
              setDialogState(() => isLoading = true);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await _dbService.addSubItem(categoryId, name, prefs.getString('username') ?? "Admin", TenantName: tenantNameController.text.trim(), nidNumber: nidController.text.trim(), notes: notesController.text.trim());
              if (context.mounted) Navigator.pop(ctx);
            }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Save"))),
          ]),
        ],
      )),
    );
  }

  static void showAddMainMeterDialog(BuildContext context) {
    final meterNoController = TextEditingController();
    String meterType = 'Residential';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(child: Text("Add Main Meter", style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: meterType,
                decoration: const InputDecoration(labelText: "Meter Type", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: "Residential", child: Text("Residential")),
                  DropdownMenuItem(value: "Commercial", child: Text("Commercial")),
                ],
                onChanged: (v) { if (v != null) setDialogState(() => meterType = v); },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: meterNoController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: "Meter Number", border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isLoading ? null : () async {
                    String no = meterNoController.text.trim();
                    if (no.isEmpty) return;
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await _dbService.addMainMeter({
                      'meterNo': no,
                      'meterType': meterType,
                      'lastReading': 0.0,
                      'presentReading': 0.0,
                      'govtBillReading': 0.0,
                      'lastGovtReading': 0.0,
                      'govtBillAmount': 0.0,
                      'unitRate': 0.0,
                      'lastMonthUnitRate': 0.0,
                    }, prefs.getString('username') ?? "Admin");
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: isLoading 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static void showUpdateMainMeterDialog({required BuildContext context, required Map<String, dynamic> data, required String docId}) {
    final presentReadingController = TextEditingController(text: data['presentReading'].toString());
    final govtReadingController = TextEditingController(text: data['govtBillReading'].toString());
    final amountController = TextEditingController(text: data['govtBillAmount'].toString());
    final lastReadingController = TextEditingController(text: (data['lastReading'] ?? 0).toString());
    
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double lastReading = (data['lastReading'] ?? 0).toDouble();
          double lastGovtReading = (data['lastGovtReading'] ?? 0).toDouble();
          double lastMonthRate = (data['lastMonthUnitRate'] ?? 0).toDouble();
          
          double newPresent = double.tryParse(presentReadingController.text) ?? lastReading;
          double newGovtReading = double.tryParse(govtReadingController.text) ?? lastGovtReading;
          double billAmount = double.tryParse(amountController.text) ?? 0;

          // Calculations
          double govtBillUnit = newGovtReading - lastGovtReading;
          double thisMonthRate = govtBillUnit > 0 ? billAmount / govtBillUnit : 0;
          double govtDueAdv = newGovtReading - newPresent;
          double mainUsed = newPresent - lastReading;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.speed, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(child: Text("Update Main Meter: ${data['meterNo']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadOnlyRow("Meter Type", data['meterType']),
                  _buildReadOnlyRow("Meter No", data['meterNo']),
                  _buildReadOnlyRow("Last Reading", lastReading.toStringAsFixed(1)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: presentReadingController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: "New Present Reading", border: OutlineInputBorder(), isDense: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Government Bill Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  _buildReadOnlyRow("Last Govt. Bill Reading", lastGovtReading.toStringAsFixed(1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: govtReadingController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: "New Govt. Bill Reading", border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: "Govt. Bill Amount", prefixText: "৳ ", border: OutlineInputBorder(), isDense: true),
                  ),
                  _buildReadOnlyRow("Govt. Bill Unit", govtBillUnit.toStringAsFixed(1)),
                  _buildReadOnlyRow("Last Month Unit Rate", "৳${lastMonthRate.toStringAsFixed(2)}"),
                  _buildReadOnlyRow("This Month Unit Rate", "৳${thisMonthRate.toStringAsFixed(2)}"),
                  _buildReadOnlyRow("Govt. Due/Adv Units", govtDueAdv.toStringAsFixed(1)),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Detailed Statistics (Calculated)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  _buildReadOnlyRow("Main Meter Used Unit", mainUsed.toStringAsFixed(1)),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: _dbService.getSubItemsByMainMeter(data['meterNo']),
                    builder: (context, subSnap) {
                      double totalSubUnits = 0;
                      if (subSnap.hasData) {
                        for (var doc in subSnap.data!.docs) {
                          var ud = doc.data() as Map<String, dynamic>;
                          var ed = ud['electricityDetails'];
                          if (ed != null && ed['isStopped'] != true) {
                            totalSubUnits += (((ed['presentReading'] ?? 0) as num).toDouble() - ((ed['lastReading'] ?? 0) as num).toDouble());
                          }
                        }
                      }
                      double balance = mainUsed - totalSubUnits;
                      return Column(
                        children: [
                          _buildReadOnlyRow("Total Sub-meter Units", totalSubUnits.toStringAsFixed(1)),
                          _buildReadOnlyRow("Balance Units (Main-Sub)", balance.toStringAsFixed(1), valueColor: balance > 0 ? Colors.red : Colors.green),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
            actions: [
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isLoading ? null : () async {
                      double last = double.tryParse(lastReadingController.text) ?? 0; 
                      double pres = double.tryParse(presentReadingController.text) ?? last;
                      double govt = double.tryParse(govtReadingController.text) ?? 0; 
                      double amt = double.tryParse(amountController.text) ?? 0;
                      
                      double prevSavedMain = (data['presentReading'] ?? 0).toDouble();
                      double prevSavedGovt = (data['govtBillReading'] ?? 0).toDouble();
                      
                      bool syncMain = false;
                      bool syncGovt = false;

                      if (prevSavedMain > 0 && last != prevSavedMain) {
                        syncMain = await showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text("Sync Main Meter?", style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Text("Previous reading was $prevSavedMain. Should this be set as the 'Last Reading' for this month?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No", style: TextStyle(color: Colors.red))),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes", style: TextStyle(color: Colors.green))),
                            ],
                          ),
                        ) ?? false;
                      }

                      if (prevSavedGovt > 0 && govt != prevSavedGovt) {
                        syncGovt = await showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text("Sync Govt. Reading?", style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Text("Previous Govt. reading was $prevSavedGovt. Should this be set as the 'Last Govt. Reading' for this month?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No", style: TextStyle(color: Colors.red))),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes", style: TextStyle(color: Colors.green))),
                            ],
                          ),
                        ) ?? false;
                      }

                      setDialogState(() => isLoading = true);

                      double finalLastMain = syncMain ? prevSavedMain : last;
                      double finalLastGovt = syncGovt ? prevSavedGovt : (data['lastGovtReading'] ?? 0).toDouble();
                      double unitRate = (govt - finalLastGovt) > 0 ? amt / (govt - finalLastGovt) : (data['unitRate'] ?? 10).toDouble();

                      Map<String, dynamic> updateData = {
                        ...data,
                        'lastReading': finalLastMain,
                        'presentReading': pres,
                        'lastGovtReading': finalLastGovt,
                        'govtBillReading': govt,
                        'govtBillAmount': amt,
                        'lastMonthUnitRate': (data['unitRate'] ?? 0).toDouble(),
                        'unitRate': unitRate,
                      };
                      
                      SharedPreferences prefs = await SharedPreferences.getInstance(); 
                      String actor = prefs.getString('username') ?? "Admin";
                      await _dbService.updateMainMeter(docId, updateData, actor);
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: isLoading 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildReadOnlyRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87)),
        ],
      ),
    );
  }

  static void showAddSubMeterDialog(BuildContext context) {
    final subMeterNoController = TextEditingController();
    String? selectedMainMeter;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(child: Text("Add Sub Meter", style: TextStyle(fontWeight: FontWeight.bold))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: _dbService.getMainMetersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  var meters = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: selectedMainMeter,
                    decoration: const InputDecoration(labelText: "Select Main Meter", border: OutlineInputBorder()),
                    items: meters.map((doc) => DropdownMenuItem(value: doc['meterNo'].toString(), child: Text("Meter: ${doc['meterNo']}"))).toList(),
                    onChanged: (v) => setDialogState(() => selectedMainMeter = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subMeterNoController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: "Sub Meter Number", border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : () async {
                    String no = subMeterNoController.text.trim();
                    if (no.isEmpty || selectedMainMeter == null) return;
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await _dbService.addSubMeter({
                      'subMeterNo': no,
                      'mainMeterNo': selectedMainMeter,
                    }, prefs.getString('username') ?? "Admin");
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: isLoading 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static void showElectricityDialog({required BuildContext context, required String subItemId, required String subItemName, Map<String, dynamic>? existingData}) {
    String? selectedMainMeter = existingData?['mainMeterNo'];
    String? selectedSubMeter = existingData?['subMeterNo'];
    final lastReadingController = TextEditingController(text: (existingData?['presentReading'] ?? 0).toString());
    final presentReadingController = TextEditingController();
    final priceController = TextEditingController(text: (existingData?['pricePerUnit'] ?? 10).toString());
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              const Icon(Icons.electric_bolt, color: Colors.amber, size: 40),
              const SizedBox(height: 12),
              const Text("Electricity - assigned submeter", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Update for $subItemName", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existingData?['updatedAt'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Last updated: ${DatabaseService.formatDuration(existingData?['updatedAt'] as Timestamp?)} ago", style: const TextStyle(fontSize: 11, color: Colors.blue))),
                      ],
                    ),
                  ),
                StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getMainMetersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    var meters = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: selectedMainMeter,
                      decoration: const InputDecoration(labelText: "Main Meter", border: OutlineInputBorder(), isDense: true),
                      items: meters.map((doc) => DropdownMenuItem(value: doc['meterNo'].toString(), child: Text("Main Meter: ${doc['meterNo']}"))).toList(),
                      onChanged: (v) => setDialogState(() => selectedMainMeter = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getSubMetersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    var allSubMeters = snapshot.data!.docs;
                    var available = allSubMeters.where((doc) {
                      bool isAssigned = doc['isAssigned'] ?? false;
                      bool isCurrent = doc['subMeterNo'] == selectedSubMeter;
                      return !isAssigned || isCurrent;
                    }).toList();

                    return DropdownButtonFormField<String>(
                      value: selectedSubMeter,
                      decoration: const InputDecoration(labelText: "Sub-meter No", border: OutlineInputBorder(), isDense: true),
                      items: available.map((doc) => DropdownMenuItem(value: doc['subMeterNo'].toString(), child: Text("Sub-meter: ${doc['subMeterNo']}"))).toList(),
                      onChanged: (v) => setDialogState(() {
                        selectedSubMeter = v;
                        var match = available.firstWhere((d) => d['subMeterNo'] == v);
                        lastReadingController.text = (match['presentReading'] ?? 0).toString();
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildReadOnlyRow("Last Reading (Previous)", lastReadingController.text),
                const SizedBox(height: 12),
                TextField(
                  controller: presentReadingController, 
                  textAlign: TextAlign.center, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: "New Present Reading", border: OutlineInputBorder(), isDense: true)
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController, 
                  textAlign: TextAlign.center, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: "Price (per unit) BDT", prefixText: "৳ ", border: OutlineInputBorder(), isDense: true)
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    label: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isLoading ? null : () async {
                      double last = double.tryParse(lastReadingController.text) ?? 0; 
                      double pres = double.tryParse(presentReadingController.text) ?? last;
                      if (pres < last) { _showValidationWarning(context, "Reading cannot be lower than previous."); return; }
                      if (selectedMainMeter == null || selectedSubMeter == null) { _showValidationWarning(context, "Please select both Main and Sub meters."); return; }
                      
                      double prevSavedReading = (existingData?['presentReading'] ?? 0).toDouble();
                      bool shouldSync = false;
                      if (prevSavedReading > 0 && last != prevSavedReading) {
                        shouldSync = await showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text("Sync Reading?", style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Text("The previous month's reading was $prevSavedReading. Should this be set as the 'Last Reading' for this month?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No", style: TextStyle(color: Colors.red))),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes", style: TextStyle(color: Colors.green))),
                            ],
                          ),
                        ) ?? false;
                      }

                      setDialogState(() => isLoading = true);
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      String actor = prefs.getString('username') ?? "Admin";

                      if (existingData?['subMeterNo'] != null && existingData?['subMeterNo'] != selectedSubMeter) {
                        await _dbService.setSubMeterAssignment(existingData?['subMeterNo'], false);
                      }
                      await _dbService.setSubMeterAssignment(selectedSubMeter!, true);

                      double finalLast = shouldSync ? prevSavedReading : last;

                      await _dbService.updateSubItemElectricity(subItemId, {
                        'mainMeterNo': selectedMainMeter,
                        'subMeterNo': selectedSubMeter,
                        'lastReading': finalLast,
                        'presentReading': pres,
                        'pricePerUnit': double.tryParse(priceController.text) ?? 10,
                        'updatedAt': FieldValue.serverTimestamp(),
                        'isStopped': false,
                      }, actor);

                      await _dbService.syncSubMeterReading(selectedSubMeter!, pres, actor);

                      if (context.mounted) Navigator.pop(ctx);
                    }, 
                    label: Text(isLoading ? "Updating..." : "Update", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void showMarkAsPaidDialog({
    required BuildContext context, 
    required String subItemId, 
    required String subItemName, 
    required String TenantName, 
    required String nidNumber, 
    required double houseRentTotal, 
    required double electricityBill, 
    required List<Map<String, dynamic>> services, 
    required Map<String, dynamic>? electricityDetails,
    required String mainCategoryName
  }) {
    final noteController = TextEditingController(); 
    DateTime now = DateTime.now(); 
    DateTime selectedDate = DateTime(now.year, now.month);
    final List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        String monthYear = "${months[selectedDate.month - 1]}-${selectedDate.year.toString().substring(2)}";
        bool isFuture = selectedDate.year > now.year || (selectedDate.year == now.year && selectedDate.month > now.month);
        int wordCount = _getWordCount(noteController.text);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("Payment: $subItemName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                const Text("select month for this payment", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    DropdownButton<int>(
                      value: selectedDate.month, 
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))), 
                      onChanged: (v) { if (v != null) { setDialogState(() => selectedDate = DateTime(selectedDate.year, v)); } }
                    ),
                    const SizedBox(width: 20),
                    DropdownButton<int>(
                      value: selectedDate.year, 
                      items: List.generate(5, (i) => DropdownMenuItem(value: now.year - 2 + i, child: Text("${now.year - 2 + i}"))), 
                      onChanged: (v) { if (v != null) { setDialogState(() => selectedDate = DateTime(v, selectedDate.month)); } }
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildRow("$mainCategoryName rent:", "৳${houseRentTotal.toStringAsFixed(1)}"),
                const SizedBox(height: 4),
                _buildRow("electric bill:", "৳${electricityBill.toStringAsFixed(1)}"),
                const Divider(height: 24),
                _buildRow("Total:", "৳${(houseRentTotal + electricityBill).toStringAsFixed(1)}", isBold: true),
                const SizedBox(height: 12),
                if (!isFuture) ...[
                   TextField(
                    controller: noteController, 
                    textAlign: TextAlign.center, 
                    onChanged: (val) => setDialogState(() => wordCount = _getWordCount(val)),
                    decoration: InputDecoration(
                      labelText: "Notes", 
                      border: const OutlineInputBorder(), 
                      isDense: true,
                      counterText: "$wordCount / 100 words",
                      counterStyle: TextStyle(color: wordCount > 100 ? Colors.red : Colors.blueGrey, fontSize: 10),
                    ),
                  ),
                ] else
                   const Text("future payments cannot be recorded.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),

                // --- HISTORY SECTION ---
                FutureBuilder<QuerySnapshot>(
                  future: _dbService.getPaymentRecords(subItemId, monthYear),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          const Divider(),
                          const Text("Payment History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                          const SizedBox(height: 8),
                          ...snapshot.data!.docs.asMap().entries.map((entry) {
                            var hData = entry.value.data() as Map<String, dynamic>;
                            int idx = entry.key + 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text("$idx. Paid by: ${hData['TenantName'] ?? TenantName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("Time: ${_formatTimestamp(hData['paidAt'] as Timestamp?)}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  if ((hData['paymentNotes'] ?? '').toString().isNotEmpty)
                                    Text("Note: ${hData['paymentNotes']}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ), 
          actions: [
            if (isFuture) 
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red, 
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red, 
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx), 
                      child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (isLoading || wordCount > 100) ? null : () async {
                        setDialogState(() => isLoading = true);
                        SharedPreferences prefs = await SharedPreferences.getInstance(); 
                        String actor = prefs.getString('username') ?? "Unknown";
                        String note = noteController.text.trim().isEmpty ? "In cash" : noteController.text.trim();
                        
                        await _dbService.addBillingRecord({
                          'subItemId': subItemId, 
                          'subItemName': subItemName, 
                          'TenantName': TenantName, 
                          'monthYear': monthYear, 
                          'totalAmount': houseRentTotal + electricityBill, 
                          'services': services, // Added for chart breakdown
                          'paymentNotes': note, 
                          'paidAt': FieldValue.serverTimestamp()
                        }, actor);
                        
                        if (electricityDetails != null) {
                          await _dbService.updateSubItemElectricity(subItemId, {
                            ...electricityDetails, 
                            'lastReading': electricityDetails['presentReading'], 
                            'updatedAt': FieldValue.serverTimestamp()
                          }, actor);
                        }
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          DatabaseService.showToast(context, "Payment Recorded!");
                        }
                      }, 
                    child: isLoading 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold))
                    ),
                  ),
                ]
              ),
          ],
        );
      }),
    );
  }

  static String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    DateTime dt = timestamp.toDate();
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  static void showCategorySettingsDialog({required BuildContext context, required String categoryId, required String categoryName, required List dynamicAssignedServices}) {
     bool isLoading = false;
     List<Map<String, dynamic>> currentAssigned = dynamicAssignedServices.map<Map<String, dynamic>>((s) {
       if (s is Map) return Map<String, dynamic>.from(s);
       return {'name': s.toString(), 'amount': 0};
     }).toList();

     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setDialogState) => AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: Center(child: Text("Services: $categoryName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
           content: SizedBox(
             width: double.maxFinite,
             child: StreamBuilder<QuerySnapshot>(
               stream: _dbService.getServicesStream(),
               builder: (context, snapshot) {
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 var docs = snapshot.data!.docs;
                 if (docs.isEmpty) return const Center(child: Text("No global services found."));

                 return ListView.builder(
                   shrinkWrap: true,
                   itemCount: docs.length,
                   itemBuilder: (context, i) {
                     var data = docs[i].data() as Map<String, dynamic>;
                     String sName = data['serviceName'] ?? '';
                     num amount = data['amount'] ?? 0;
                     bool isChecked = currentAssigned.any((element) => element['name'] == sName);

                     return CheckboxListTile(
                       title: Text(sName),
                       subtitle: Text("Price: ৳$amount"),
                       value: isChecked,
                       onChanged: (bool? value) {
                         setDialogState(() {
                           if (value == true) currentAssigned.add({'name': sName, 'amount': amount});
                           else currentAssigned.removeWhere((element) => element['name'] == sName);
                         });
                       },
                     );
                   },
                 );
               },
             ),
           ),
           actions: [
             Row(children: [
               Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
               const SizedBox(width: 12),
               Expanded(child: ElevatedButton(onPressed: isLoading ? null : () async {
                 setDialogState(() => isLoading = true);
                 SharedPreferences prefs = await SharedPreferences.getInstance();
                 await _dbService.updateCategoryServices(categoryId, currentAssigned, prefs.getString('username') ?? "Admin");
                 if (context.mounted) Navigator.pop(ctx);
               }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Apply"))),
             ]),
           ],
         ),
       ),
     );
  }

  static void showEditSubItemDetailsDialog({required BuildContext context, required String subItemId, required String currentName, required String currentTenantName, required String currentNidNumber, required String currentNotes}) {
    final subItemController = TextEditingController(text: currentName); 
    final tenantController = TextEditingController(text: currentTenantName == "No Tenant" ? "" : currentTenantName);
    final nidController = TextEditingController(text: currentNidNumber == "No Number" ? "" : currentNidNumber); 
    final notesController = TextEditingController(text: currentNotes);
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          int wordCount = _getWordCount(notesController.text);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
            title: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text("Edit sub-item details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ), 
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  _buildCenteredField(subItemController, "Sub-item Name / Number"),
                  const SizedBox(height: 12),
                  _buildCenteredField(tenantController, "Tenant Name (Optional)"),
                  const SizedBox(height: 12),
                  _buildCenteredField(nidController, "Tenant NID Number"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController, 
                    textAlign: TextAlign.center,
                    onChanged: (val) => setDialogState(() => wordCount = _getWordCount(val)),
                    decoration: InputDecoration(
                      labelText: "Notes (Max 100 words)", 
                      border: const OutlineInputBorder(), 
                      alignLabelWithHint: true,
                      counterText: "$wordCount / 100 words",
                      counterStyle: TextStyle(color: wordCount > 100 ? Colors.red : Colors.blueGrey, fontWeight: FontWeight.bold),
                    ), 
                    maxLines: 3
                  ),
                ]
              ),
            ), 
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red, 
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx), 
                      child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: (isLoading || wordCount > 100) ? null : () async {
                        setDialogState(() => isLoading = true);
                        try {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          String actor = prefs.getString('username') ?? "Admin";
                          await _dbService.updateSubItemDetails(subItemId, {
                            'subItemName': subItemController.text.trim(), 
                            'TenantName': tenantController.text.trim(), 
                            'nidNumber': nidController.text.trim(), 
                            'notes': notesController.text.trim()
                          }, actor);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            DatabaseService.showToast(context, "Details Updated!");
                          }
                        } catch (e) {
                           setDialogState(() => isLoading = false);
                        }
                      }, 
                      child: isLoading 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Update", style: TextStyle(fontWeight: FontWeight.bold))
                    ),
                  ),
                ]
              )
            ]
          );
        },
      ),
    );
  }

  static Widget _buildCenteredField(TextEditingController controller, String label) {
    return TextField(
      controller: controller, 
      textAlign: TextAlign.center,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  static void showSubItemStatusDialog({required BuildContext context, required String subItemId, required String subItemName, required String currentStatus, required String currentTenant, required String currentNid}) {
    if (currentStatus == 'Vacant') {
      final tenantController = TextEditingController();
      final nidController = TextEditingController();
      bool isLoading = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                const Icon(Icons.person_add_outlined, color: Colors.green, size: 40),
                const SizedBox(height: 12),
                Text("Set $subItemName to Occupied", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter tenant details to proceed", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(
                  controller: tenantController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "Tenant Name", border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nidController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "NID Number", border: OutlineInputBorder(), isDense: true),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isLoading ? null : () async {
                        String name = tenantController.text.trim();
                        String nid = nidController.text.trim();
                        if (name.isEmpty || nid.isEmpty) {
                          _showValidationWarning(context, "Please provide both Tenant Name and NID Number.");
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await _dbService.updateSubItemStatus(
                          subItemId, 
                          'Occupied', 
                          prefs.getString('username') ?? "Admin",
                          TenantName: name,
                          nidNumber: nid,
                        );
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: isLoading 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Proceed", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      showConfirmDialog(
        context: context, 
        title: "Set to Vacant?", 
        content: "Are you sure you want to set $subItemName to Vacant? Renter info will be cleared.", 
        confirmText: "Proceed",
        confirmColor: Colors.orange,
        onConfirm: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await _dbService.updateSubItemStatus(subItemId, 'Vacant', prefs.getString('username') ?? "Admin");
        }
      );
    }
  }

  static void showSubItemServiceSettingsDialog({required BuildContext context, required String subItemId, required String subItemName, required List categoryServices, required List excludedServices}) {
    bool isLoading = false;
    List<String> currentExcluded = List<String>.from(excludedServices);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("Manage Services: $subItemName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          content: SizedBox(
            width: double.maxFinite,
            child: categoryServices.isEmpty 
              ? const Center(child: Text("No category services defined."))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: categoryServices.length,
                  itemBuilder: (context, i) {
                    var service = categoryServices[i];
                    String sName = (service is Map) ? service['name'] : service.toString();
                    num amount = (service is Map) ? (service['amount'] ?? 0) : 0;
                    bool isApplied = !currentExcluded.contains(sName);

                    return CheckboxListTile(
                      title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isApplied ? "applied (৳$amount)" : "Unassigned for this sub-item",
                        style: TextStyle(color: isApplied ? Colors.green : Colors.blueGrey, fontSize: 12),
                      ),
                      value: isApplied,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == false) currentExcluded.add(sName);
                          else currentExcluded.remove(sName);
                        });
                      },
                    );
                  },
                ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, 
                    side: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading ? null : () async {
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await _dbService.updateSubItemExcludedServices(subItemId, currentExcluded, prefs.getString('username') ?? "Admin");
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      DatabaseService.showToast(context, "Services Updated!");
                    }
                  }, 
                  child: isLoading 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Update", style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  static void showWifiServiceEditDialog({required BuildContext context, required String subItemId, required String subItemName, required Map<String, dynamic> serviceMap, required List overriddenServices}) {
    int quantity = (serviceMap['deviceQuantity'] ?? 1).toInt();
    double unitPrice = (serviceMap['wifiCost'] ?? serviceMap['amount'] ?? 0).toDouble();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double total = quantity * unitPrice;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                const Icon(Icons.wifi, color: Colors.blueAccent, size: 40),
                const SizedBox(height: 12),
                Text("Edit 'Wifi Bill' for '$subItemName'", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Service: Wifi Bill", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () { if (quantity > 1) setDialogState(() => quantity--); },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: Text("$quantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () => setDialogState(() => quantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: "Wifi cost per device", prefixText: "৳ ", border: OutlineInputBorder()),
                  onChanged: (val) {
                    double? p = double.tryParse(val);
                    if (p != null) setDialogState(() => unitPrice = p);
                  },
                  controller: TextEditingController(text: unitPrice.toStringAsFixed(0))..selection = TextSelection.fromPosition(TextSelection.fromPosition(TextPosition(offset: unitPrice.toStringAsFixed(0).length)).extent),
                ),
                const SizedBox(height: 16),
                Text("Total Wifi Bill: ৳${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.indigo)),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      label: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: isLoading ? null : () async {
                        setDialogState(() => isLoading = true);
                        List updated = overriddenServices.map((s) => Map<String, dynamic>.from(s)).toList();
                        updated.removeWhere((s) => s['originalName'] == serviceMap['originalName']);
                        updated.add({
                          'originalName': serviceMap['originalName'], 
                          'name': serviceMap['name'], 
                          'amount': quantity * unitPrice,
                          'deviceQuantity': quantity,
                          'wifiCost': unitPrice,
                        });
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await _dbService.updateSubItemOverriddenServices(subItemId, updated, prefs.getString('username') ?? "Admin");
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      label: isLoading 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static void showEditSubItemServiceDialog({required BuildContext context, required String subItemId, required String subItemName, required Map<String, dynamic> serviceMap, required List overriddenServices}) {
    final nameController = TextEditingController(text: serviceMap['name']); final amountController = TextEditingController(text: serviceMap['amount'].toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Center(child: Text("Edit Service")), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")), TextField(controller: amountController, decoration: const InputDecoration(labelText: "Amount"))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), TextButton(onPressed: () async {
      List updated = overriddenServices.map((s) => Map<String, dynamic>.from(s)).toList();
      updated.removeWhere((s) => s['originalName'] == serviceMap['originalName']);
      updated.add({'originalName': serviceMap['originalName'], 'name': nameController.text.trim(), 'amount': double.tryParse(amountController.text) ?? 0});
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await _dbService.updateSubItemOverriddenServices(subItemId, updated, prefs.getString('username') ?? "Admin");
      if (context.mounted) Navigator.pop(ctx);
    }, child: const Text("Save"))]));
  }

  static int _getWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 15)), Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.indigo : Colors.black87, fontSize: 15))]));
  }
}
