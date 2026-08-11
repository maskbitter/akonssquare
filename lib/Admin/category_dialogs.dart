import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akonssquare/Common/database_service.dart';
import 'package:flutter/services.dart';
import 'package:akonssquare/Common/theme_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:akonssquare/Common/ui_helper.dart';

class CategoryDialogs {
  static final DatabaseService _dbService = DatabaseService();

  static void _showValidationWarning(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error), 
              const SizedBox(width: 8), 
              Text("Required", style: Theme.of(context).textTheme.titleLarge)
            ]
          )
        ),
        content: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("OK")
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void showConfirmDialog({
    required BuildContext context, 
    required String title, 
    required String content, 
    required VoidCallback onConfirm,
    String confirmText = "Remove",
    Color? confirmColor,
  }) {
    final effectiveConfirmColor = confirmColor ?? Theme.of(context).colorScheme.error;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.delete_forever_outlined, color: effectiveConfirmColor, size: 40),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(content, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveConfirmColor, 
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () { Navigator.pop(ctx); onConfirm(); }, 
                child: Text(confirmText, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary))
              ),
            ],
          ),
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
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("New Category", style: Theme.of(context).textTheme.titleLarge)),
          content: TextField(
            controller: controller, 
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: (val) => setDialogState(() {}),
            decoration: const InputDecoration(
              labelText: "Category Name",
              hintText: "e.g. Apartment, Shop",
              prefixIcon: Icon(Icons.category_outlined),
            )
          ),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isLoading || controller.text.trim().isEmpty) ? null : () async {
                    String name = controller.text.trim(); if (name.isEmpty) return;
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await _dbService.addCategory(name, prefs.getString('username') ?? "Admin");
                    if (context.mounted) Navigator.pop(ctx);
                  }, 
                  child: isLoading ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)) : const Text("Save")
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  static void showAddServiceDialog(BuildContext context) {
    final nameController = TextEditingController(); 
    final amountController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Text("Manage Services", style: Theme.of(context).textTheme.titleLarge)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    TextField(
                      controller: nameController, 
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: (val) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: "New Service Name", 
                        hintText: "e.g. Water, Security",
                        prefixIcon: Icon(Icons.miscellaneous_services_outlined),
                        isDense: true
                      )
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController, 
                      keyboardType: TextInputType.number, 
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: (val) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: "Price (BDT)", 
                        hintText: "Enter amount",
                        prefixIcon: Icon(Icons.payments_outlined),
                        prefixText: "৳ ", 
                        isDense: true
                      )
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary, 
                        foregroundColor: Theme.of(context).colorScheme.onTertiary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (isLoading || nameController.text.trim().isEmpty || amountController.text.trim().isEmpty) ? null : () async {
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
                      child: Text(isLoading ? "Saving..." : "Add Service")
                    ),
                    const Divider(height: 32),
                    Text("Existing Services", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: _dbService.getServicesStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        var docs = snapshot.data!.docs.toList();
                        docs.sort((a, b) => ((a.data() as Map)['serviceName'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['serviceName'] ?? '').toString().toLowerCase()));
                        
                        if (docs.isEmpty) return Text("No services found.", style: Theme.of(context).textTheme.bodySmall);
                        
                        return Column(
                          children: docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            String sName = data['serviceName'] ?? 'Unknown';
                            double amt = (data['amount'] ?? 0).toDouble();

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerLow, 
                                borderRadius: BorderRadius.circular(8), 
                                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sName, style: Theme.of(context).textTheme.titleSmall),
                                        Text("৳${amt.toStringAsFixed(0)}", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
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
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text("Close")
                  ),
                ],
              ),
            ],
          );
        }
      ),
    );
  }

  static void showAddSubItemDialog({required BuildContext context, required String categoryId, required String categoryName}) {
    final subItemController = TextEditingController(); 
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("Add Unit to $categoryName", style: Theme.of(context).textTheme.titleLarge)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: subItemController, 
              style: Theme.of(context).textTheme.bodyLarge,
              onChanged: (val) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: "$categoryName No",
                hintText: "e.g. 101, A-1",
                prefixIcon: const Icon(Icons.meeting_room_outlined),
              )
            ),
          ])),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isLoading || subItemController.text.trim().isEmpty) ? null : () async {
                    String name = subItemController.text.trim(); if (name.isEmpty) return;
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await _dbService.addSubItem(categoryId, name, prefs.getString('username') ?? "Admin");
                    if (context.mounted) Navigator.pop(ctx);
                  }, 
                  child: isLoading ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary)) : const Text("Add")
                ),
              ],
            ),
          ],
        );
      }),
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
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(child: Text("Add Main Meter", style: Theme.of(context).textTheme.titleLarge)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: meterType,
                  decoration: const InputDecoration(
                    labelText: "Meter Type",
                    prefixIcon: Icon(Icons.merge_type_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: "Residential", child: Text("Residential")),
                    DropdownMenuItem(value: "Commercial", child: Text("Commercial")),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => meterType = v); },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: meterNoController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: (val) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: "Meter Number",
                    hintText: "Enter main meter no",
                    prefixIcon: Icon(Icons.speed_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: (isLoading || meterNoController.text.trim().isEmpty) ? null : () async {
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
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary))
                      : const Text("Add"),
                  ),
                ],
              ),
            ],
          );
        }
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
                Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text("Update Main Meter: ${data['meterNo']}", style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadOnlyRow(context, "Meter Type", data['meterType']),
                  _buildReadOnlyRow(context, "Meter No", data['meterNo']),
                  _buildReadOnlyRow(context, "Last Reading", lastReading.toStringAsFixed(1)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: presentReadingController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: "New Present Reading", 
                      hintText: "Enter reading",
                      prefixIcon: Icon(Icons.speed),
                      isDense: true
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("Govt. Bill Details", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  ),
                  _buildReadOnlyRow(context, "Last Govt. Bill Reading", lastGovtReading.toStringAsFixed(1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: govtReadingController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: "New Govt. Bill Reading", 
                      hintText: "Enter govt reading",
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      isDense: true
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      labelText: "Govt. Bill Amount", 
                      hintText: "Enter bill amount",
                      prefixIcon: Icon(Icons.payments_outlined),
                      prefixText: "৳ ", 
                      isDense: true
                    ),
                  ),
                  _buildReadOnlyRow(context, "Govt. Bill Unit", govtBillUnit.toStringAsFixed(1)),
                  _buildReadOnlyRow(context, "Last Month Unit Rate", "৳${lastMonthRate.toStringAsFixed(2)}"),
                  _buildReadOnlyRow(context, "This Month Unit Rate", "৳${thisMonthRate.toStringAsFixed(2)}"),
                  _buildReadOnlyRow(context, "Govt. Due/Adv Units", govtDueAdv.toStringAsFixed(1)),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("Detailed Statistics (Calculated)", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  ),
                  _buildReadOnlyRow(context, "Main Meter Used Unit", mainUsed.toStringAsFixed(1)),
                  
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
                          _buildReadOnlyRow(context, "Total Sub-meter Units", totalSubUnits.toStringAsFixed(1)),
                          _buildReadOnlyRow(context, "Balance Units (Main-Sub)", balance.toStringAsFixed(1), valueColor: balance > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: (isLoading || 
                                (presentReadingController.text == data['presentReading'].toString() &&
                                 govtReadingController.text == data['govtBillReading'].toString() &&
                                 amountController.text == data['govtBillAmount'].toString())) ? null : () async {
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
                            title: Text("Sync Main Meter?", style: Theme.of(context).textTheme.titleLarge),
                            content: Text("Previous reading was $prevSavedMain. Should this be set as the 'Last Reading' for this month?", style: Theme.of(context).textTheme.bodyMedium),
                            actions: [
                              AppDialogActions(
                                actions: [
                                  AppButton(
                                    onPressed: () => Navigator.pop(c, false), 
                                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                    child: const Text("No")
                                  ),
                                  AppButton(
                                    onPressed: () => Navigator.pop(c, true), 
                                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary),
                                    child: const Text("Yes")
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ) ?? false;
                      }

                      if (prevSavedGovt > 0 && govt != prevSavedGovt) {
                        syncGovt = await showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text("Sync Govt. Reading?", style: Theme.of(context).textTheme.titleLarge),
                            content: Text("Previous Govt. reading was $prevSavedGovt. Should this be set as the 'Last Govt. Reading' for this month?", style: Theme.of(context).textTheme.bodyMedium),
                            actions: [
                              AppDialogActions(
                                actions: [
                                  AppButton(
                                    onPressed: () => Navigator.pop(c, false), 
                                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                    child: const Text("No")
                                  ),
                                  AppButton(
                                    onPressed: () => Navigator.pop(c, true), 
                                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary),
                                    child: const Text("Yes")
                                  ),
                                ],
                              ),
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
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary))
                      : const Text("Update"),
                  ),
                ],
              ),
            ],
          );
        }
      ),
    );
  }

  static Widget _buildReadOnlyRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: valueColor)),
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
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(child: Text("Add Sub Meter", style: Theme.of(context).textTheme.titleLarge)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: _dbService.getMainMetersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  var meters = snapshot.data!.docs.toList();
                  meters.sort((a, b) => ((a.data() as Map)['meterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['meterNo'] ?? '').toString().toLowerCase()));
                  
                  return DropdownButtonFormField<String>(
                    value: selectedMainMeter,
                    decoration: const InputDecoration(
                      labelText: "Select Main Meter",
                      prefixIcon: Icon(Icons.speed_outlined),
                    ),
                    items: meters.map((doc) => DropdownMenuItem(value: doc['meterNo'].toString(), child: Text("Meter: ${doc['meterNo']}", style: Theme.of(context).textTheme.bodyMedium))).toList(),
                    onChanged: (v) => setDialogState(() => selectedMainMeter = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subMeterNoController,
                style: Theme.of(context).textTheme.bodyLarge,
                onChanged: (val) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: "Sub Meter Number",
                  hintText: "Enter sub meter no",
                  prefixIcon: Icon(Icons.av_timer_outlined),
                ),
              ),
            ],
          ),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    backgroundColor: Theme.of(context).colorScheme.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isLoading || subMeterNoController.text.trim().isEmpty || selectedMainMeter == null) ? null : () async {
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
                    : const Text("Add"),
                ),
              ],
            ),
          ],
        );
        }
      ),
    );
  }

  static void showElectricityDialog({required BuildContext context, required String subItemId, required String subItemName, Map<String, dynamic>? existingData, bool isOperator = false}) {
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
        builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
            Icon(Icons.electric_bolt, color: context.electric, size: 40),
              const SizedBox(height: 12),
              Text("Electricity - assigned submeter", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              Text("Update for $subItemName", style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existingData?['updatedAt'] != null)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Last updated: ${DatabaseService.formatDuration(existingData?['updatedAt'] as Timestamp?)} ago", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary))),
                      ],
                    ),
                  ),
                StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getSubMetersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    var allSubMeters = snapshot.data!.docs.toList();
                    allSubMeters.sort((a, b) => ((a.data() as Map)['subMeterNo'] ?? '').toString().toLowerCase().compareTo(((b.data() as Map)['subMeterNo'] ?? '').toString().toLowerCase()));
                    
                    var available = allSubMeters.where((doc) {
                      bool isAssigned = doc['isAssigned'] ?? false;
                      bool isCurrent = doc['subMeterNo'] == selectedSubMeter;
                      return !isAssigned || isCurrent;
                    }).toList();

                    // Safety check: Ensure selected value exists in items
                    String? dropdownValue = selectedSubMeter;
                    if (dropdownValue != null && !available.any((d) => d['subMeterNo'] == dropdownValue)) {
                      dropdownValue = null;
                    }

                    return DropdownButtonFormField<String>(
                      value: dropdownValue,
                      decoration: const InputDecoration(labelText: "Sub-meter No", isDense: true),
                      items: available.map((doc) => DropdownMenuItem(value: doc['subMeterNo'].toString(), child: Text("Sub-meter: ${doc['subMeterNo']} (Main: ${doc['mainMeterNo']})", style: Theme.of(context).textTheme.bodyMedium))).toList(),
                      onChanged: isOperator ? null : (v) => setDialogState(() {
                        selectedSubMeter = v;
                        var match = available.firstWhere((d) => d['subMeterNo'] == v);
                        selectedMainMeter = match['mainMeterNo']?.toString();
                        lastReadingController.text = (match['presentReading'] ?? 0).toString();
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildReadOnlyRow(context, "Last Reading (Previous)", lastReadingController.text),
                const SizedBox(height: 12),
                TextField(
                  controller: presentReadingController, 
                  keyboardType: TextInputType.number, 
                  onChanged: (val) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: "New Present Reading", 
                    hintText: "Enter current reading",
                    prefixIcon: Icon(Icons.electric_bolt_outlined),
                    isDense: true
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController, 
                  keyboardType: TextInputType.number, 
                  onChanged: (val) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: "Price (per unit) BDT", 
                    hintText: "Enter unit rate",
                    prefixIcon: Icon(Icons.price_change_outlined),
                    prefixText: "৳ ", 
                    isDense: true
                  )
                ),
              ],
            ),
          ),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    backgroundColor: Theme.of(context).colorScheme.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: (isLoading || 
                              (presentReadingController.text.trim().isEmpty && priceController.text == (existingData?['pricePerUnit'] ?? 10).toString()) ||
                              (presentReadingController.text == (existingData?['presentReading'] ?? 0).toString() && priceController.text == (existingData?['pricePerUnit'] ?? 10).toString()) ||
                              (selectedSubMeter == existingData?['subMeterNo'] && presentReadingController.text.trim().isEmpty && priceController.text == (existingData?['pricePerUnit'] ?? 10).toString())
                              ) ? null : () async {
                    double last = double.tryParse(lastReadingController.text) ?? 0; 
                    double pres = double.tryParse(presentReadingController.text) ?? last;
                    if (pres < last) { _showValidationWarning(context, "Reading cannot be lower than previous."); return; }
                    if (selectedMainMeter == null || selectedSubMeter == null) { _showValidationWarning(context, "Please select both Main and Sub meters."); return; }
                    
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String actor = prefs.getString('username') ?? "Admin";

                    if (existingData?['subMeterNo'] != null && existingData?['subMeterNo'] != selectedSubMeter) {
                      await _dbService.setSubMeterAssignment(existingData?['subMeterNo'], false);
                    }
                    await _dbService.setSubMeterAssignment(selectedSubMeter!, true);

                    // Only update presentReading, lastReading remains same until payment
                    await _dbService.updateSubItemElectricity(subItemId, {
                      'mainMeterNo': selectedMainMeter,
                      'subMeterNo': selectedSubMeter,
                      'lastReading': (existingData?['lastReading'] ?? last).toDouble(),
                      'presentReading': pres,
                      'pricePerUnit': double.tryParse(priceController.text) ?? 10,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'isStopped': false,
                    }, actor);

                    if (context.mounted) Navigator.pop(ctx);
                  }, 
                  child: Text(isLoading ? "Updating..." : "Update", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ],
            ),
          ],
        );
        }
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
          title: Center(child: Text("Payment: $subItemName", style: Theme.of(context).textTheme.titleLarge)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Text("Select month for this payment", style: Theme.of(context).textTheme.bodySmall),
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
                _buildRow(context, "$mainCategoryName Rent:", "৳${houseRentTotal.toStringAsFixed(1)}"),
                const SizedBox(height: 4),
                _buildRow(context, "Electric Bill:", "৳${electricityBill.toStringAsFixed(1)}"),
                const Divider(height: 24),
                _buildRow(context, "Total:", "৳${(houseRentTotal + electricityBill).toStringAsFixed(1)}", isBold: true),
                const SizedBox(height: 12),
                if (!isFuture) ...[
                   TextField(
                    controller: noteController, 
                    onChanged: (val) => setDialogState(() => wordCount = _getWordCount(val)),
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: "Notes", 
                      hintText: "Add payment notes",
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      isDense: true,
                      counterText: "$wordCount / 100 words",
                      counterStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: wordCount > 100 ? Theme.of(context).colorScheme.error : null),
                    ),
                  ),
                ] else
                   Text("Future payments cannot be recorded.", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),

                // --- HISTORY SECTION ---
                FutureBuilder<QuerySnapshot>(
                  future: _dbService.getPaymentRecords(subItemId, monthYear),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          const Divider(),
                          Text("Payment History", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 8),
                          ...snapshot.data!.docs.asMap().entries.map((entry) {
                            var hData = entry.value.data() as Map<String, dynamic>;
                            int idx = entry.key + 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text("$idx. Paid by: ${hData['TenantName'] ?? TenantName}", style: Theme.of(context).textTheme.titleSmall),
                                  Text("Time: ${_formatTimestamp(hData['paidAt'] as Timestamp?)}", style: Theme.of(context).textTheme.bodySmall),
                                  if ((hData['paymentNotes'] ?? '').toString().isNotEmpty)
                                    Text("Note: ${hData['paymentNotes']}", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
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
            AppDialogActions(
              actions: [
                if (isFuture) 
                  AppButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onError, 
                        backgroundColor: Theme.of(context).colorScheme.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx), 
                      child: const Text("Cancel")
                  )
                else ...[
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text("Cancel")
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        'services': services, 
                        'paymentNotes': note, 
                        'paidAt': FieldValue.serverTimestamp()
                      }, actor);
                      
                      if (electricityDetails != null) {
                        double last = (electricityDetails['lastReading'] ?? 0).toDouble();
                        double pres = (electricityDetails['presentReading'] ?? 0).toDouble();
                        double used = pres - last;
                        String? meterNo = electricityDetails['mainMeterNo'];
                        String? subMeterNo = electricityDetails['subMeterNo'];

                        await _dbService.updateSubItemElectricity(subItemId, {
                          ...electricityDetails, 
                          'lastReading': pres, 
                          'updatedAt': FieldValue.serverTimestamp()
                        }, actor);

                        if (subMeterNo != null) {
                          await _dbService.syncSubMeterReading(subMeterNo, pres, actor);
                        }

                        if (meterNo != null && used > 0) {
                          await _dbService.incrementMainMeterPaidUnits(meterNo, used);
                        }
                      }
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        DatabaseService.showToast(context, "Payment Recorded!");
                      }
                    }, 
                    child: isLoading 
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary))
                      : const Text("Confirm")
                  ),
                ],
              ],
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
         builder: (context, setDialogState) {
           return AlertDialog(
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             title: Center(child: Text("Services: $categoryName", style: Theme.of(context).textTheme.titleLarge)),
           content: SizedBox(
             width: double.maxFinite,
             child: StreamBuilder<QuerySnapshot>(
               stream: _dbService.getServicesStream(),
               builder: (context, snapshot) {
                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                 var docs = snapshot.data!.docs;
                 if (docs.isEmpty) return Center(child: Text("No global services found.", style: Theme.of(context).textTheme.bodyMedium));

                 return ListView.builder(
                   shrinkWrap: true,
                   itemCount: docs.length,
                   itemBuilder: (context, i) {
                     var data = docs[i].data() as Map<String, dynamic>;
                     String sName = data['serviceName'] ?? '';
                     num amount = data['amount'] ?? 0;
                     bool isChecked = currentAssigned.any((element) => element['name'] == sName);

                     return CheckboxListTile(
                       title: Text(sName, style: Theme.of(context).textTheme.bodyLarge),
                       subtitle: Text("Price: ৳$amount", style: Theme.of(context).textTheme.bodySmall),
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
             AppDialogActions(
               actions: [
                 AppButton(
                   style: ElevatedButton.styleFrom(
                     foregroundColor: Theme.of(context).colorScheme.onError,
                     backgroundColor: Theme.of(context).colorScheme.error,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     elevation: 0,
                   ),
                   onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 AppButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Theme.of(context).colorScheme.tertiary,
                     foregroundColor: Theme.of(context).colorScheme.onTertiary,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   onPressed: (isLoading || setEquals(currentAssigned.map((e) => e['name']).toSet(), dynamicAssignedServices.map((e) => (e is Map) ? e['name'] : e.toString()).toSet())) ? null : () async {
                   setDialogState(() => isLoading = true);
                   SharedPreferences prefs = await SharedPreferences.getInstance();
                   await _dbService.updateCategoryServices(categoryId, currentAssigned, prefs.getString('username') ?? "Admin");
                   if (context.mounted) Navigator.pop(ctx);
                 }, child: isLoading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Apply")),
               ],
             ),
           ],
         );
       },
     ),
    );
  }

  static void showEditSubItemDetailsDialog({required BuildContext context, required String subItemId, required String currentName, required String currentTenantName, required String currentNidNumber, required String currentNotes}) {
    final subItemController = TextEditingController(text: currentName); 
    final tenantController = TextEditingController(text: currentTenantName == "No Name" ? "" : currentTenantName);
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
            title: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text("Edit unit details", style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ), 
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  _buildCenteredField(context, subItemController, "Sub-item Name / Number", onChanged: (v) => setDialogState((){})),
                  const SizedBox(height: 12),
                  _buildCenteredField(context, tenantController, "Tenant Name (Optional)", onChanged: (v) => setDialogState((){})),
                  const SizedBox(height: 12),
                  _buildCenteredField(context, nidController, "Tenant NID Number", onChanged: (v) => setDialogState((){})),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController, 
                    style: Theme.of(context).textTheme.bodyLarge,
                    onChanged: (val) => setDialogState(() => wordCount = _getWordCount(val)),
                    decoration: InputDecoration(
                      labelText: "Notes (Max 100 words)", 
                      hintText: "Enter tenant or unit notes",
                      prefixIcon: const Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                      counterText: "$wordCount / 100 words",
                      counterStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: wordCount > 100 ? Theme.of(context).colorScheme.error : null),
                    ), 
                    maxLines: 3
                  ),
                ]
              ),
            ), 
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text("Cancel")
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (isLoading || wordCount > 100 || 
                                (subItemController.text == currentName &&
                                 tenantController.text == (currentTenantName == "No Name" ? "" : currentTenantName) &&
                                 nidController.text == (currentNidNumber == "No Number" ? "" : currentNidNumber) &&
                                 notesController.text == currentNotes)) ? null : () async {
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
                      : const Text("Update")
                  ),
                ],
              ),
            ]
          );
        },
      ),
    );
  }

  static Widget _buildCenteredField(BuildContext context, TextEditingController controller, String label, {ValueChanged<String>? onChanged}) {
    IconData icon;
    String hint;
    if (label.toLowerCase().contains("tenant")) {
      icon = Icons.person_outline;
      hint = "Enter tenant name";
    } else if (label.toLowerCase().contains("nid")) {
      icon = Icons.badge_outlined;
      hint = "Enter NID number";
    } else {
      icon = Icons.edit_note_outlined;
      hint = "Enter information";
    }

    return TextField(
      controller: controller, 
      style: Theme.of(context).textTheme.bodyLarge,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }

  static void showSubItemStatusDialog({required BuildContext context, required String subItemId, required String subItemName, required String currentStatus, required String currentTenant, required String currentNid, Map<String, dynamic>? electricityDetails}) {
    if (currentStatus == 'Vacant') {
      final tenantController = TextEditingController();
      final nidController = TextEditingController();
      bool isLoading = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Icon(Icons.person_add_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
                const SizedBox(height: 12),
                Text("Set $subItemName to Occupied", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Enter tenant details to proceed", style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(
                  controller: tenantController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: (val) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: "Tenant Name", 
                    hintText: "Enter full name",
                    prefixIcon: Icon(Icons.person_outline),
                    isDense: true
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nidController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: (val) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: "NID Number", 
                    hintText: "Enter NID (for password)",
                    prefixIcon: Icon(Icons.badge_outlined),
                    isDense: true
                  ),
                ),
              ],
            ),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (isLoading || tenantController.text.trim().isEmpty || nidController.text.trim().isEmpty) ? null : () async {
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
                      : const Text("Proceed"),
                  ),
                ],
              ),
            ],
          );
          }
        ),
      );
    } else {
      double eBillAmount = 0;
      double units = 0;
      if (electricityDetails != null && electricityDetails['isStopped'] != true) {
        double last = ((electricityDetails['lastReading'] ?? 0) as num).toDouble();
        double pres = ((electricityDetails['presentReading'] ?? 0) as num).toDouble();
        double rate = ((electricityDetails['pricePerUnit'] ?? 0) as num).toDouble();
        units = pres - last;
        if (units > 0) eBillAmount = units * rate;
      }

      if (eBillAmount > 0) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              children: [
                Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 48),
                const SizedBox(height: 12),
                Text("Pending Bill Alert!", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.error)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "This unit has a pending electricity bill of ৳${eBillAmount.toStringAsFixed(1)} (${units.toStringAsFixed(1)} units).",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to set $subItemName to Vacant? Renter info will be cleared.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, 
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx), 
                    child: const Text("Cancel")
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await _dbService.updateSubItemStatus(subItemId, 'Vacant', prefs.getString('username') ?? "Admin");
                    },
                    child: const Text("Proceed"),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        showConfirmDialog(
          context: context, 
          title: "Set to Vacant?", 
          content: "Are you sure you want to set $subItemName to Vacant? Renter info will be cleared.", 
          confirmText: "Proceed",
          confirmColor: Theme.of(context).colorScheme.error,
          onConfirm: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await _dbService.updateSubItemStatus(subItemId, 'Vacant', prefs.getString('username') ?? "Admin");
          }
        );
      }
    }
  }

  static void showSubItemServiceSettingsDialog({required BuildContext context, required String subItemId, required String subItemName, required List categoryServices, required List excludedServices}) {
    bool isLoading = false;
    List<String> currentExcluded = List<String>.from(excludedServices);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Center(child: Text("Manage Services: $subItemName", style: Theme.of(context).textTheme.titleLarge)),
          content: SizedBox(
            width: double.maxFinite,
            child: categoryServices.isEmpty 
              ? Center(child: Text("No category services defined.", style: Theme.of(context).textTheme.bodyMedium))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: categoryServices.length,
                  itemBuilder: (context, i) {
                    var service = categoryServices[i];
                    String sName = (service is Map) ? service['name'] : service.toString();
                    num amount = (service is Map) ? (service['amount'] ?? 0) : 0;
                    bool isApplied = !currentExcluded.contains(sName);

                    return CheckboxListTile(
                      title: Text(sName, style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text(
                        isApplied ? "applied (৳$amount)" : "Unassigned for this sub-item",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isApplied ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.onSurfaceVariant),
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
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onError, 
                    backgroundColor: Theme.of(context).colorScheme.error,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text("Cancel")
                ),
                AppButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isLoading || setEquals(currentExcluded.toSet(), excludedServices.toSet())) ? null : () async {
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
                    : const Text("Update")
                ),
              ],
            ),
          ],
        );
        }
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
              Icon(Icons.wifi_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
              const SizedBox(height: 12),
              Text("Edit 'Wifi Bill' for '$subItemName'", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Service: Wifi Bill", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () { if (quantity > 1) setDialogState(() => quantity--); },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(8)),
                    child: Text("$quantity", style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.tertiary),
                    onPressed: () => setDialogState(() => quantity++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: "Wifi cost per device", 
                  hintText: "Enter amount",
                  prefixIcon: Icon(Icons.price_change_outlined),
                  prefixText: "৳ "
                ),
                onChanged: (val) {
                  double? p = double.tryParse(val);
                  if (p != null) setDialogState(() => unitPrice = p);
                },
                controller: TextEditingController(text: unitPrice.toStringAsFixed(0))..selection = TextSelection.fromPosition(TextSelection.fromPosition(TextPosition(offset: unitPrice.toStringAsFixed(0).length)).extent),
              ),
              const SizedBox(height: 16),
              Text("Total Wifi Bill: ৳${total.toStringAsFixed(0)}", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
            ],
          ),
            actions: [
              AppDialogActions(
                actions: [
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  AppButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.tertiary,
                      foregroundColor: Theme.of(context).colorScheme.onTertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: (isLoading || 
                                (quantity == (serviceMap['deviceQuantity'] ?? 1).toInt() && 
                                 unitPrice == (serviceMap['wifiCost'] ?? serviceMap['amount'] ?? 0).toDouble())) ? null : () async {
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
                    child: isLoading 
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary))
                      : const Text("Update"),
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
    final nameController = TextEditingController(text: serviceMap['name']); 
    final amountController = TextEditingController(text: serviceMap['amount'].toString());
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
        title: const Center(child: Text("Edit Service")), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(
                labelText: "Name",
                hintText: "Enter service name",
                prefixIcon: Icon(Icons.edit_outlined),
              ), 
              onChanged: (v) => setDialogState((){})
            ), 
            const SizedBox(height: 12),
            TextField(
              controller: amountController, 
              decoration: const InputDecoration(
                labelText: "Amount",
                hintText: "Enter amount",
                prefixIcon: Icon(Icons.payments_outlined),
                prefixText: "৳ "
              ), 
              onChanged: (v) => setDialogState((){})
            )
          ]
        ), 
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary, 
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (nameController.text == serviceMap['name'] && amountController.text == serviceMap['amount'].toString()) ? null : () async {
                  List updated = overriddenServices.map((s) => Map<String, dynamic>.from(s)).toList();
                  updated.removeWhere((s) => s['originalName'] == serviceMap['originalName']);
                  updated.add({'originalName': serviceMap['originalName'], 'name': nameController.text.trim(), 'amount': double.tryParse(amountController.text) ?? 0});
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await _dbService.updateSubItemOverriddenServices(subItemId, updated, prefs.getString('username') ?? "Admin");
                  if (context.mounted) Navigator.pop(ctx);
                }, 
                child: const Text("Save")
              ),
            ],
          ),
        ]
      );
    }));
  }

  static int _getWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static Widget _buildRow(BuildContext context, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), 
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Theme.of(context).colorScheme.primary : null))
        ]
      )
    );
  }
}
