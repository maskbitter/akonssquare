library category_dialogs;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:akons_square/Common/database_service.dart';
import 'package:flutter/services.dart';
import 'package:akons_square/Common/theme_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:akons_square/Common/ui_helper.dart';

part 'dialogs/meter_dialogs.dart';
part 'dialogs/service_billing_dialogs.dart';

class CategoryDialogs {
  const CategoryDialogs();
  static final DatabaseService _dbService = DatabaseService();

  // --- Forwarding Methods for Meter Dialogs ---
  static void showAddMainMeterDialog(BuildContext context) => const CategoryDialogs().showAddMainMeterDialog(context);
  static void showUpdateMainMeterDialog({required BuildContext context, required Map<String, dynamic> data, required String docId}) => 
      const CategoryDialogs().showUpdateMainMeterDialog(context: context, data: data, docId: docId);
  static void showAddSubMeterDialog(BuildContext context) => const CategoryDialogs().showAddSubMeterDialog(context);
  static void showDeleteMeterDialog({required BuildContext context, required String type, required String meterNo, required VoidCallback onConfirm}) => 
      const CategoryDialogs().showDeleteMeterDialog(context: context, type: type, meterNo: meterNo, onConfirm: onConfirm);

  // --- Forwarding Methods for Service & Billing Dialogs ---
  static void showAddServiceDialog(BuildContext context) => const CategoryDialogs().showAddServiceDialog(context);
  static void showEditGlobalServiceDialog({required BuildContext context, required String serviceId, required String currentName, required double currentAmount}) => 
      const CategoryDialogs().showEditGlobalServiceDialog(context: context, serviceId: serviceId, currentName: currentName, currentAmount: currentAmount);
  static void showElectricityDialog({required BuildContext context, required String subItemId, required String subItemName, Map<String, dynamic>? existingData, bool isOperator = false, DateTime? initialDate}) => 
      const CategoryDialogs().showElectricityDialog(context: context, subItemId: subItemId, subItemName: subItemName, existingData: existingData, isOperator: isOperator, initialDate: initialDate);
  static void showMarkAsPaidDialog({required BuildContext context, required String subItemId, required String subItemName, required String TenantName, required String nidNumber, required double houseRentTotal, required double electricityBill, required List<Map<String, dynamic>> services, required Map<String, dynamic>? electricityDetails, required String mainCategoryName, required List manualDues, String? notes}) => 
      const CategoryDialogs().showMarkAsPaidDialog(context: context, subItemId: subItemId, subItemName: subItemName, TenantName: TenantName, nidNumber: nidNumber, houseRentTotal: houseRentTotal, electricityBill: electricityBill, services: services, electricityDetails: electricityDetails, mainCategoryName: mainCategoryName, manualDues: manualDues, notes: notes);
  static void showManualDueDialog({required BuildContext context, required String subItemId, required String subItemName, required List manualDues}) => 
      const CategoryDialogs().showManualDueDialog(context: context, subItemId: subItemId, subItemName: subItemName, manualDues: manualDues);
  static void showWifiServiceEditDialog({required BuildContext context, required String subItemId, required String subItemName, required Map<String, dynamic> serviceMap, required List overriddenServices, required List macAddresses}) => 
      const CategoryDialogs().showWifiServiceEditDialog(context: context, subItemId: subItemId, subItemName: subItemName, serviceMap: serviceMap, overriddenServices: overriddenServices, macAddresses: macAddresses);
  static void showGlobalMacListDialog({required BuildContext context}) => const CategoryDialogs().showGlobalMacListDialog(context: context);
  static void showUserMacDetailsDialog({required BuildContext context, required String subItemName, required List macAddresses, required Map<String, dynamic> wifiService}) => 
      const CategoryDialogs().showUserMacDetailsDialog(context: context, subItemName: subItemName, macAddresses: macAddresses, wifiService: wifiService);
  static void showSubItemServiceSettingsDialog({required BuildContext context, required String subItemId, required String subItemName, required List categoryServices, required List excludedServices}) => 
      const CategoryDialogs().showSubItemServiceSettingsDialog(context: context, subItemId: subItemId, subItemName: subItemName, categoryServices: categoryServices, excludedServices: excludedServices);
  static void showEditSubItemServiceDialog({required BuildContext context, required String subItemId, required String subItemName, required Map<String, dynamic> serviceMap, required List overriddenServices}) => 
      const CategoryDialogs().showEditSubItemServiceDialog(context: context, subItemId: subItemId, subItemName: subItemName, serviceMap: serviceMap, overriddenServices: overriddenServices);
  static void showConfirmDialog({required BuildContext context, required String title, required String content, required VoidCallback onConfirm, String confirmText = "Remove", Color? confirmColor, IconData? icon}) => 
      const CategoryDialogs().showConfirmDialog(context: context, title: title, content: content, onConfirm: onConfirm, confirmText: confirmText, confirmColor: confirmColor, icon: icon);

  // --- Shared Private Helper Methods ---
  static void _showValidationWarning(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? ThemeManager.outlineBackground 
                    : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                    ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.5) 
                    : null,
              ),
              child: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text("Required", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ),
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

  static void _showDuplicateErrorDialog(BuildContext context, String name, String type) {
    String typeLabel = "Item";
    if (type == 'Category') typeLabel = "Category";
    else if (type == 'Unit') typeLabel = "Unit/Room";
    else if (type == 'Service') typeLabel = "Service";
    else if (type.contains('Meter')) typeLabel = "Meter";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThemeManager.appThemeNotifier.value == "Outline Theme" ? ThemeManager.outlineBackground : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: ThemeManager.appThemeNotifier.value == "Outline Theme" ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.5) : null,
              ),
              child: Icon(Icons.copy_all_rounded, color: Theme.of(context).colorScheme.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text("Duplicate Found!", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: "Uh oh! '"),
                    TextSpan(text: name, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const TextSpan(text: "' is already registered in our system."),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Please use a unique name to keep your records organized and error-free.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          AppDialogActions(
            actions: [
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("I'll change it"),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? ThemeManager.outlineBackground 
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                      : null,
                ),
                child: Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
              ),
              const SizedBox(height: 16),
              Text("New Category", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            child: TextField(
              controller: controller, 
              style: Theme.of(context).textTheme.bodyLarge,
              onChanged: (val) => setDialogState(() {}),
              decoration: const InputDecoration(
                labelText: "Category Name",
                hintText: "e.g. Apartment, Shop",
                prefixIcon: Icon(Icons.category_outlined),
              )
            ),
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
                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await _dbService.addCategory(name, prefs.getString('username') ?? "Admin");
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (e.toString().contains("DuplicateFound")) {
                        if (context.mounted) _showDuplicateErrorDialog(context, name, "Category");
                      }
                    }
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

  static void showAddSubItemDialog({required BuildContext context, required String categoryId, required String categoryName}) {
    final subItemController = TextEditingController(); 
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? ThemeManager.outlineBackground 
                      : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                      ? Border.all(color: Theme.of(context).colorScheme.tertiary, width: 1.5) 
                      : null,
                ),
                child: Icon(Icons.meeting_room_outlined, color: Theme.of(context).colorScheme.tertiary, size: 40),
              ),
              const SizedBox(height: 16),
              Text("Add Unit to $categoryName", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
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
                ]
              ),
            ),
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
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isLoading || subItemController.text.trim().isEmpty) ? null : () async {
                    String name = subItemController.text.trim(); if (name.isEmpty) return;
                    setDialogState(() => isLoading = true);
                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await _dbService.addSubItem(categoryId, name, prefs.getString('username') ?? "Admin");
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (e.toString().contains("DuplicateFound")) {
                        if (context.mounted) _showDuplicateErrorDialog(context, name, "Unit");
                      }
                    }
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
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
             title: Column(
               children: [
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                         ? ThemeManager.outlineBackground 
                         : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                     shape: BoxShape.circle,
                     border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                         ? Border.all(color: Theme.of(context).colorScheme.tertiary, width: 1.5) 
                         : null,
                   ),
                   child: Icon(Icons.miscellaneous_services_outlined, color: Theme.of(context).colorScheme.tertiary, size: 40),
                 ),
                 const SizedBox(height: 16),
                 Text("Services: $categoryName", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
               ],
             ),
           content: SizedBox(
             width: MediaQuery.of(context).size.width * 0.95,
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
                 }, child: isLoading ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground)) : const Text("Apply")),
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
          int letterCount = _getLetterCount(notesController.text);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), 
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? ThemeManager.outlineBackground 
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                        : null,
                  ),
                  child: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
                ),
                const SizedBox(height: 16),
                Text("Edit unit details", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: SingleChildScrollView(
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
                    onChanged: (val) => setDialogState(() => letterCount = _getLetterCount(val)),
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: "Notes (Max 100)", 
                      hintText: "Enter tenant or unit notes",
                      prefixIcon: const Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                      counterText: "$letterCount / 100",
                      counterStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: letterCount > 100 ? Theme.of(context).colorScheme.error : null),
                    ), 
                    maxLines: 3
                  ),
                ]
              ),
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
                    onPressed: (isLoading || letterCount > 100 || 
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
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? ThemeManager.outlineBackground 
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                        : null,
                  ),
                  child: Icon(Icons.person_add_outlined, color: Theme.of(context).colorScheme.primary, size: 40),
                ),
                const SizedBox(height: 16),
                Text("Set $subItemName to Occupied", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: Column(
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
                      ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? ThemeManager.outlineBackground 
                        : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: ThemeManager.appThemeNotifier.value == "Outline Theme" 
                        ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.5) 
                        : null,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 40),
                ),
                const SizedBox(height: 16),
                Text("Pending Bill Alert!", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: Column(
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

  static int _getLetterCount(String text) {
    return text.length;
  }

  static Widget _buildRow(BuildContext context, String label, String value, {bool isBold = false, double? fontSize, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)), 
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? (isBold ? Theme.of(context).colorScheme.primary : null), fontSize: fontSize))
        ]
      )
    );
  }

  static String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    DateTime dt = timestamp.toDate();
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
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
}
