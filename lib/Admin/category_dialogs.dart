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
            Icon(Icons.warning_amber_rounded, color: confirmColor, size: 40),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(content, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, 
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold))
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () { Navigator.pop(ctx); onConfirm(); }, 
                child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold))
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
    final nameController = TextEditingController(); final amountController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Text("Manage Services", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Service Name", border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: amountController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", prefixText: "৳ ", border: OutlineInputBorder())),
        ]),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: isLoading ? null : () async {
              String name = nameController.text.trim(); double amt = double.tryParse(amountController.text) ?? 0;
              if (name.isEmpty) return;
              setDialogState(() => isLoading = true);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await _dbService.addService(name, amt, prefs.getString('username') ?? "Admin");
              if (context.mounted) Navigator.pop(ctx);
            }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Save"))),
          ]),
        ],
      )),
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
          TextField(controller: subItemController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Unit Name", border: OutlineInputBorder())),
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

  static void showMainMeterDialog({required BuildContext context, Map<String, dynamic>? existingData, String? docId}) {
    final bool isEditing = existingData != null;
    final meterNoController = TextEditingController(text: existingData?['meterNo'] ?? '');
    final lastReadingController = TextEditingController(text: (existingData?['presentReading'] ?? 0).toString());
    final presentReadingController = TextEditingController();
    final govtReadingController = TextEditingController(text: (existingData?['govtBillReading'] ?? 0).toString());
    final amountController = TextEditingController(text: (existingData?['govtBillAmount'] ?? 0).toString());
    String meterType = existingData?['meterType'] ?? 'Residential';
    bool isLoading = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Center(child: Text(isEditing ? "Edit Meter" : "Add Meter", style: const TextStyle(fontWeight: FontWeight.bold))),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: meterType, items: const [DropdownMenuItem(value: "Residential", child: Text("Residential")), DropdownMenuItem(value: "Commercial", child: Text("Commercial"))], onChanged: (v) { if (v != null) setDialogState(() => meterType = v); }, decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: meterNoController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Meter No", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: lastReadingController, decoration: const InputDecoration(labelText: "Last Reading", border: OutlineInputBorder()), enabled: false),
        const SizedBox(height: 12),
        TextField(controller: presentReadingController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Present Reading", border: OutlineInputBorder())),
        const Divider(height: 32),
        TextField(controller: govtReadingController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Govt Bill Reading", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: amountController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Bill Amount", prefixText: "৳ ", border: OutlineInputBorder())),
      ])),
      actions: [
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: isLoading ? null : () async {
            setDialogState(() => isLoading = true);
            double last = double.tryParse(lastReadingController.text) ?? 0; double pres = double.tryParse(presentReadingController.text) ?? last;
            double govt = double.tryParse(govtReadingController.text) ?? 0; double amt = double.tryParse(amountController.text) ?? 0;
            Map<String, dynamic> data = {'meterNo': meterNoController.text.trim(), 'meterType': meterType, 'lastReading': last, 'presentReading': pres, 'govtBillReading': govt, 'govtBillAmount': amt, 'unitRate': (govt - (existingData?['lastGovtReading'] ?? 0)) > 0 ? amt / (govt - (existingData?['lastGovtReading'] ?? 0)) : 0};
            SharedPreferences prefs = await SharedPreferences.getInstance(); String actor = prefs.getString('username') ?? "Admin";
            if (isEditing) await _dbService.updateMainMeter(docId!, data, actor); else await _dbService.addMainMeter(data, actor);
            if (context.mounted) Navigator.pop(ctx);
          }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Save"))),
        ]),
      ],
    )));
  }

  static void showElectricityDialog({required BuildContext context, required String subItemId, required String subItemName, Map<String, dynamic>? existingData}) {
    final subMeterController = TextEditingController(text: existingData?['mainSubMeterNo'] ?? '');
    final lastReadingController = TextEditingController(text: (existingData?['presentReading'] ?? 0).toString());
    final presentReadingController = TextEditingController();
    final priceController = TextEditingController(text: (existingData?['pricePerUnit'] ?? 10).toString());
    bool isLoading = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.flash_on, color: Colors.amber), const SizedBox(width: 8), Text("Electric: $subItemName", style: const TextStyle(fontWeight: FontWeight.bold))])),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: subMeterController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: "Meter Number", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: lastReadingController, decoration: const InputDecoration(labelText: "Last Reading", border: OutlineInputBorder()), enabled: false),
        const SizedBox(height: 12),
        TextField(controller: presentReadingController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "New Reading", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: priceController, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Unit Price", prefixText: "৳ ", border: OutlineInputBorder())),
      ])),
      actions: [
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: isLoading ? null : () async {
            double last = double.tryParse(lastReadingController.text) ?? 0; double pres = double.tryParse(presentReadingController.text) ?? last;
            if (pres < last) { _showValidationWarning(context, "Reading cannot be lower than previous."); return; }
            setDialogState(() => isLoading = true);
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await _dbService.updateSubItemElectricity(subItemId, {'mainSubMeterNo': subMeterController.text.trim(), 'lastReading': last, 'presentReading': pres, 'pricePerUnit': double.tryParse(priceController.text) ?? 10, 'updatedAt': FieldValue.serverTimestamp()}, prefs.getString('username') ?? "Admin");
            if (context.mounted) Navigator.pop(ctx);
          }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Update"))),
        ]),
      ],
    )));
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
    String target = currentStatus == 'Occupied' ? 'Vacant' : 'Occupied';
    showConfirmDialog(
      context: context, 
      title: "Change Status", 
      content: "Set $subItemName to $target?", 
      confirmText: "Proceed",
      confirmColor: Colors.orange,
      onConfirm: () async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await _dbService.updateSubItemStatus(subItemId, target, prefs.getString('username') ?? "Admin");
      }
    );
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
