part of '../category_dialogs.dart';

extension BillingServiceDialogs on CategoryDialogs {
  void showAddServiceDialog(BuildContext context) {
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
              width: MediaQuery.of(context).size.width * 0.8,
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
                        try {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await CategoryDialogs._dbService.addService(name, amt, prefs.getString('username') ?? "Admin");
                          nameController.clear();
                          amountController.clear();
                        } catch (e) {
                          if (e.toString().contains("DuplicateFound")) {
                            if (context.mounted) CategoryDialogs._showDuplicateErrorDialog(context, name, "Service");
                          }
                        } finally {
                          setDialogState(() => isLoading = false);
                        }
                      }, 
                      child: Text(isLoading ? "Saving..." : "Add Service")
                    ),
                    const Divider(height: 32),
                    Text("Existing Services", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: CategoryDialogs._dbService.getServicesStream(),
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
                                    icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                                    onPressed: () {
                                      showEditGlobalServiceDialog(
                                        context: context,
                                        serviceId: doc.id,
                                        currentName: sName,
                                        currentAmount: amt,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 20),
                                    onPressed: () => showConfirmDialog(
                                      context: context, 
                                      title: "Delete Service?", 
                                      content: "Remove '$sName' permanently?", 
                                      onConfirm: () async {
                                        SharedPreferences prefs = await SharedPreferences.getInstance();
                                        await CategoryDialogs._dbService.removeService(doc.id, prefs.getString('username') ?? "Admin");
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

  void showEditGlobalServiceDialog({
    required BuildContext context,
    required String serviceId,
    required String currentName,
    required double currentAmount,
  }) {
    final nameController = TextEditingController(text: currentName);
    final amountController = TextEditingController(text: currentAmount.toStringAsFixed(0));
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Center(child: Text("Edit Service", style: Theme.of(context).textTheme.titleLarge)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(labelText: "Service Name", prefixIcon: Icon(Icons.miscellaneous_services_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Price (BDT)", prefixIcon: Icon(Icons.payments_outlined), prefixText: "৳ "),
                ),
              ],
            ),
          ),
          actions: [
            AppDialogActions(
              actions: [
                AppButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh, foregroundColor: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                AppButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary, foregroundColor: Theme.of(context).colorScheme.onTertiary),
                  onPressed: isLoading ? null : () async {
                    String name = nameController.text.trim();
                    double amt = double.tryParse(amountController.text) ?? 0;
                    if (name.isEmpty) return;

                    setST(() => isLoading = true);
                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await CategoryDialogs._dbService.updateService(
                        serviceId: serviceId,
                        oldName: currentName,
                        newName: name,
                        newAmount: amt,
                        actor: prefs.getString('username') ?? "Admin",
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        DatabaseService.showToast(context, "Service Updated!");
                      }
                    } catch (e) {
                      // handle error
                    } finally {
                      setST(() => isLoading = false);
                    }
                  },
                  child: Text(isLoading ? "Updating..." : "Update"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void showElectricityDialog({required BuildContext context, required String subItemId, required String subItemName, Map<String, dynamic>? existingData, bool isOperator = false}) {
    String? selectedMainMeter = existingData?['mainMeterNo'];
    String? selectedSubMeter = existingData?['subMeterNo'];
    final lastReadingController = TextEditingController(text: (existingData?['lastReading'] ?? 0).toString());
    final presentReadingController = TextEditingController(text: (existingData?['presentReading'] ?? '').toString());
    final priceController = TextEditingController(text: (existingData?['pricePerUnit'] ?? 10).toString());
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Always enable if any of the fields have content and it's a new assignment,
          // or if values changed from existing data.
          bool hasChanged = true;
          if (existingData != null) {
            hasChanged = selectedSubMeter != existingData['subMeterNo'] ||
                        double.tryParse(lastReadingController.text) != (existingData['lastReading'] ?? 0).toDouble() ||
                        double.tryParse(presentReadingController.text) != (existingData['presentReading'] ?? 0).toDouble() ||
                        double.tryParse(priceController.text) != (existingData['pricePerUnit'] ?? 10).toDouble();
          }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
            Icon(Icons.electric_bolt, color: context.electric, size: 40),
              const SizedBox(height: 12),
              Text("Sub-Meter Assignment", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              Text("Update for $subItemName", style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (existingData?['updatedAt'] != null) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("Last updated: ${DatabaseService.formatFullDateTime(existingData?['updatedAt'] as Timestamp?)}", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            Text("${DatabaseService.formatDuration(existingData?['updatedAt'] as Timestamp?)} ago", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                StreamBuilder<QuerySnapshot>(
                  stream: CategoryDialogs._dbService.getSubMetersStream(),
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
                      isExpanded: true,
                      value: dropdownValue,
                      decoration: const InputDecoration(labelText: "Sub-meter No", isDense: true),
                      items: available.map((doc) => DropdownMenuItem(
                        value: doc['subMeterNo'].toString(), 
                        child: Text(
                          "SM: ${doc['subMeterNo']} (Main: ${doc['mainMeterNo']})", 
                          style: Theme.of(context).textTheme.bodyMedium,
                          softWrap: true,
                        )
                      )).toList(),
                      onChanged: isOperator ? null : (v) => setDialogState(() {
                        selectedSubMeter = v;
                        var match = available.firstWhere((d) => d['subMeterNo'] == v);
                        selectedMainMeter = match['mainMeterNo']?.toString();
                        
                        // Pick the highest reading available from the meter as the starting point
                        var mData = match.data() as Map<String, dynamic>;
                        double meterPresent = (mData['presentReading'] ?? 0).toDouble();
                        double meterLast = (mData['lastReading'] ?? 0).toDouble();
                        double meterRead = meterPresent >= meterLast ? meterPresent : meterLast;
                        
                        lastReadingController.text = meterRead.toString();
                        presentReadingController.text = meterRead.toString();
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastReadingController, 
                  keyboardType: TextInputType.number, 
                  onChanged: (val) {
                    setDialogState(() {
                      double last = double.tryParse(val) ?? 0;
                      double pres = double.tryParse(presentReadingController.text) ?? 0;
                      // If present reading is behind the new last reading, sync them
                      if (pres < last) {
                        presentReadingController.text = last.toString();
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Last Reading (Previous)", 
                    hintText: "Enter previous reading",
                    prefixIcon: Icon(Icons.history),
                    isDense: true
                  )
                ),
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
                  ),
                ),
              ],
            ),
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
                  onPressed: (isLoading || !hasChanged || selectedSubMeter == null) ? null : () async {
                    double last = double.tryParse(lastReadingController.text) ?? 0; 
                    double pres = double.tryParse(presentReadingController.text) ?? last;
                    
                    if (pres < last) {
                      CategoryDialogs._showValidationWarning(context, "Present reading ($pres) cannot be lower than the previous reading ($last).");
                      return;
                    }

                    if (selectedMainMeter == null || selectedSubMeter == null) { CategoryDialogs._showValidationWarning(context, "Please select both Main and Sub meters."); return; }
                    
                    setDialogState(() => isLoading = true);
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String actor = prefs.getString('username') ?? "Admin";

                    if (existingData?['subMeterNo'] != null && existingData?['subMeterNo'] != selectedSubMeter) {
                      await CategoryDialogs._dbService.setSubMeterAssignment(existingData?['subMeterNo'], false);
                    }
                    await CategoryDialogs._dbService.setSubMeterAssignment(selectedSubMeter!, true);

                    // Update both presentReading and lastReading from controller values
                    await CategoryDialogs._dbService.updateSubItemElectricity(subItemId, {
                      'mainMeterNo': selectedMainMeter,
                      'subMeterNo': selectedSubMeter,
                      'lastReading': last,
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

  void showMarkAsPaidDialog({
    required BuildContext context, 
    required String subItemId, 
    required String subItemName, 
    required String TenantName, 
    required String nidNumber, 
    required double houseRentTotal, 
    required double electricityBill, 
    required List<Map<String, dynamic>> services, 
    required Map<String, dynamic>? electricityDetails,
    required String mainCategoryName,
    required List manualDues,
    String? notes
  }) {
    final noteController = TextEditingController(); 
    final presentUnitsController = TextEditingController(text: (electricityDetails?['presentReading'] ?? 0).toString());
    DateTime now = DateTime.now(); 
    DateTime selectedDate = DateTime(now.year, now.month);
    final List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    bool isLoading = false;
    bool clearManualDues = true; // Default to clear manual dues on payment

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        String monthYear = "${months[selectedDate.month - 1]}-${selectedDate.year.toString().substring(2)}";
        bool isFuture = selectedDate.year > now.year || (selectedDate.year == now.year && selectedDate.month > now.month);
        int letterCount = CategoryDialogs._getLetterCount(noteController.text);

        double lastRead = (electricityDetails?['lastReading'] ?? 0).toDouble();
        double currentRead = double.tryParse(presentUnitsController.text) ?? lastRead;
        double unitRate = (electricityDetails?['pricePerUnit'] ?? 0).toDouble();
        double dynamicElecBill = (currentRead - lastRead) * unitRate;
        if (dynamicElecBill < 0) dynamicElecBill = 0;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Center(child: Text("Payment: $subItemName", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
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

                // Breakdown Section
                Column(
                  children: [
                    // House Rent (if available)
                    ...services.where((s) => s['name'].toString().toLowerCase().contains('rent')).map((s) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: CategoryDialogs._buildRow(context, "${s['name']}:", "৳${(s['amount'] as num).toDouble().toStringAsFixed(1)}", isBold: true),
                      )
                    ),

                    // Other Services
                    ...services.where((s) => !s['name'].toString().toLowerCase().contains('rent')).map((s) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: CategoryDialogs._buildRow(context, "${s['name']}:", "৳${(s['amount'] as num).toDouble().toStringAsFixed(1)}"),
                      )
                    ),

                    if (electricityDetails != null && electricityDetails['isStopped'] != true) ...[
                      const SizedBox(height: 6),
                      CategoryDialogs._buildRow(context, "Sub-Meter Bill:", "৳${dynamicElecBill.toStringAsFixed(1)}", isBold: true),
                    ],

                    const Divider(height: 16),
                    CategoryDialogs._buildRow(context, "Total:", "৳${(houseRentTotal + dynamicElecBill).toStringAsFixed(1)}", isBold: true),
                    const Divider(height: 16),

                    // Manual Dues/Advances Breakdown
                    if (manualDues.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Adjust Dues/Adv:", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      ...manualDues.map((d) {
                        double amt = (d['amount'] as num).toDouble();
                        bool isAdv = amt < 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: CategoryDialogs._buildRow(
                            context, 
                            "${d['reason']}${isAdv ? ' (Adv)' : ''}:", 
                            "৳${amt.abs().toStringAsFixed(1)}", 
                            color: isAdv ? Colors.green : Colors.red
                          ),
                        );
                      }),
                      const Divider(height: 16),
                    ],
                  ],
                ),
                
                // Calculate Total Payable including manual dues
                Builder(builder: (context) {
                  double mDuesSum = manualDues.fold(0.0, (acc, d) => acc + (d['amount'] as num).toDouble());
                  double grandTotal = houseRentTotal + dynamicElecBill + mDuesSum;
                  return CategoryDialogs._buildRow(context, "Total Payable:", "৳${grandTotal.toStringAsFixed(1)}", isBold: true, fontSize: 18);
                }),

                if (manualDues.isNotEmpty)
                  CheckboxListTile(
                    title: const Text("Clear all pending dues with this payment?", style: TextStyle(fontSize: 12)),
                    value: clearManualDues,
                    onChanged: (val) => setDialogState(() => clearManualDues = val ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                
                if (notes != null && notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_outlined, size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Unit Notes: $notes", 
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold
                            )
                          )
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                if (!isFuture) ...[
                   TextField(
                    controller: noteController, 
                    onChanged: (val) => setDialogState(() => letterCount = CategoryDialogs._getLetterCount(val)),
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: "Notes", 
                      hintText: "Add payment notes",
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      isDense: true,
                      counterText: "$letterCount / 100",
                      counterStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: letterCount > 100 ? Theme.of(context).colorScheme.error : null),
                    ),
                  ),
                ] else
                   Text("Future payments cannot be recorded.", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),

                // --- HISTORY SECTION ---
                FutureBuilder<QuerySnapshot>(
                  future: CategoryDialogs._dbService.getPaymentRecords(subItemId, monthYear),
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
                                  Text("Time: ${CategoryDialogs._formatTimestamp(hData['paidAt'] as Timestamp?)}", style: Theme.of(context).textTheme.bodySmall),
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
                    onPressed: (isLoading || letterCount > 100) ? null : () async {
                      if (electricityDetails != null && currentRead < lastRead) {
                        CategoryDialogs._showValidationWarning(context, "Reading cannot be lower than previous for final payment.");
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      SharedPreferences prefs = await SharedPreferences.getInstance(); 
                      String actor = prefs.getString('username') ?? "Unknown";
                      String note = noteController.text.trim().isEmpty ? "In cash" : noteController.text.trim();
                      
                      Map<String, dynamic>? finalElecDetails;
                      if (electricityDetails != null) {
                         finalElecDetails = Map<String, dynamic>.from(electricityDetails);
                         finalElecDetails['presentReading'] = currentRead;
                      }

                      double mDuesSum = manualDues.fold(0.0, (acc, d) => acc + (d['amount'] as num).toDouble());

                        await CategoryDialogs._dbService.addBillingRecord({
                          'subItemId': subItemId, 
                          'subItemName': subItemName, 
                          'TenantName': TenantName, 
                          'nidNumber': nidNumber,
                          'monthYear': monthYear, 
                          'houseRentTotal': houseRentTotal,
                          'electricityBill': dynamicElecBill,
                          'electricityDetails': finalElecDetails,
                          'manualDues': manualDues,
                          'totalAmount': houseRentTotal + dynamicElecBill + mDuesSum, 
                          'services': services, 
                          'paymentNotes': note, 
                          'paidAt': FieldValue.serverTimestamp()
                        }, actor);

                      if (clearManualDues && manualDues.isNotEmpty) {
                        await CategoryDialogs._dbService.updateSubItemManualDues(subItemId, [], actor);
                      }
                      
                      if (finalElecDetails != null) {
                        double used = currentRead - lastRead;
                        String? meterNo = finalElecDetails['mainMeterNo'];
                        String? subMeterNo = finalElecDetails['subMeterNo'];

                        // IMPORTANT: Finalize the reading cycle. Present becomes Last.
                        await CategoryDialogs._dbService.updateSubItemElectricity(subItemId, {
                          ...finalElecDetails, 
                          'lastReading': currentRead, 
                          'updatedAt': FieldValue.serverTimestamp()
                        }, actor);

                        if (subMeterNo != null) {
                          await CategoryDialogs._dbService.syncSubMeterReading(subMeterNo, currentRead, actor);
                        }

                        if (meterNo != null && used > 0) {
                          await CategoryDialogs._dbService.incrementMainMeterPaidUnits(meterNo, used);
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

  void showManualDueDialog({required BuildContext context, required String subItemId, required String subItemName, required List manualDues}) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    List<Map<String, dynamic>> currentDues = List<Map<String, dynamic>>.from(manualDues.map((e) => Map<String, dynamic>.from(e)));
    bool isLoading = false;
    bool isAdvance = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Adjust Dues/Adv: $subItemName", textAlign: TextAlign.center),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppDialogActions(
                      actions: [
                        AppButton(
                          onPressed: () => setDialogState(() => isAdvance = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isAdvance ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.surfaceContainerHigh,
                            foregroundColor: !isAdvance ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                            elevation: 0,
                          ),
                          child: const Text("Due"),
                        ),
                        AppButton(
                          onPressed: () => setDialogState(() => isAdvance = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAdvance ? Theme.of(context).colorScheme.tertiaryContainer : Theme.of(context).colorScheme.surfaceContainerHigh,
                            foregroundColor: isAdvance ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                            elevation: 0,
                          ),
                          child: const Text("Advance"),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isAdvance ? "Advance Amount (৳)" : "Due Amount (৳)", 
                      prefixText: "৳ ",
                      labelStyle: TextStyle(color: isAdvance ? Colors.green : Colors.red),
                    ),
                  ),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: "Reason", hintText: "e.g. Back rent June-July"),
                  ),
                  const SizedBox(height: 12),
                  AppDialogActions(
                    actions: [
                      AppButton(
                        onPressed: () {
                          double? amt = double.tryParse(amountController.text);
                          String reason = reasonController.text.trim();
                          if (amt != null && reason.isNotEmpty) {
                            setDialogState(() {
                              double finalAmt = isAdvance ? -amt.abs() : amt.abs();
                              currentDues.add({'amount': finalAmt, 'reason': reason, 'date': DateTime.now().toIso8601String()});
                              amountController.clear();
                              reasonController.clear();
                            });
                          }
                        },
                        child: Text(isAdvance ? "Add Advance Item" : "Add Due Item"),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (currentDues.isEmpty)
                    const Text("No manual dues or advances pending.")
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: currentDues.length,
                        itemBuilder: (context, index) {
                          var due = currentDues[index];
                          double amt = (due['amount'] as num).toDouble();
                          bool isAdv = amt < 0;
                          return ListTile(
                            dense: true,
                            title: Text("${due['reason']} ${isAdv ? '(Advance)' : ''}"),
                            subtitle: Text("Added: ${due['date'].toString().split('T')[0]}"),
                            trailing: Text(
                              "৳${amt.abs().toStringAsFixed(1)}", 
                              style: TextStyle(fontWeight: FontWeight.bold, color: isAdv ? Colors.green : Colors.red)
                            ),
                            onLongPress: () {
                              setDialogState(() => currentDues.removeAt(index));
                            },
                          );
                        },
                      ),
                    ),
                ],
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
                    onPressed: isLoading ? null : () async {
                      setDialogState(() => isLoading = true);
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await CategoryDialogs._dbService.updateSubItemManualDues(subItemId, currentDues, prefs.getString('username') ?? "Admin");
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void showWifiServiceEditDialog({
    required BuildContext context, 
    required String subItemId, 
    required String subItemName, 
    required Map<String, dynamic> serviceMap, 
    required List overriddenServices,
    required List macAddresses
  }) {
    int quantity = (serviceMap['deviceQuantity'] ?? 1).toInt();
    double unitPrice = (serviceMap['wifiCost'] ?? serviceMap['amount'] ?? 0).toDouble();
    List<Map<String, dynamic>> currentMacs = List<Map<String, dynamic>>.from(macAddresses.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return {'mac': e.toString(), 'sn': ''};
    }));
    final macController = TextEditingController();
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
                Text("Wifi Service: $subItemName", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Edit pricing and register devices", style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    
                    // Device Quantity Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Devices:", style: Theme.of(context).textTheme.titleMedium),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                              onPressed: () { if (quantity > 1) setDialogState(() => quantity--); },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(8)),
                              child: Text("$quantity", style: Theme.of(context).textTheme.headlineSmall),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.tertiary),
                              onPressed: () => setDialogState(() => quantity++),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Cost Input
                    TextField(
                      keyboardType: TextInputType.number,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        labelText: "Cost per device", 
                        prefixIcon: Icon(Icons.price_change_outlined),
                        prefixText: "৳ "
                      ),
                      onChanged: (val) {
                        double? p = double.tryParse(val);
                        if (p != null) setDialogState(() => unitPrice = p);
                      },
                      controller: TextEditingController(text: unitPrice.toStringAsFixed(0))..selection = TextSelection.fromPosition(TextSelection.fromPosition(TextPosition(offset: unitPrice.toStringAsFixed(0).length)).extent),
                    ),
                    
                    const Divider(height: 32),
                    
                    // MAC Address Management
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("MAC Addresses (${currentMacs.length})", style: Theme.of(context).textTheme.titleMedium),
                        TextButton.icon(
                          onPressed: () {
                              showDialog(
                                context: context,
                                builder: (macCtx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text("Add Device"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: macController,
                                        inputFormatters: [MacAddressFormatter()],
                                        decoration: const InputDecoration(
                                          labelText: "MAC Address",
                                          hintText: "e.g. 00:0A:95:9D:68:16",
                                          counterText: "",
                                          prefixIcon: Icon(Icons.wifi_tethering),
                                        ),
                                        maxLength: 17,
                                        style: const TextStyle(fontFamily: 'monospace'),
                                      ),
                                    ],
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
                                          onPressed: () => Navigator.pop(macCtx), 
                                          child: const Text("Cancel")
                                        ),
                                        AppButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                                            foregroundColor: Theme.of(context).colorScheme.onTertiary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () async {
                                            String mac = macController.text.trim().toUpperCase();
                                            if (mac.isNotEmpty) {
                                              // Auto-generate SN
                                              String nextSn = await CategoryDialogs._dbService.generateNextSerialNumber();
                                              
                                              // Update locally (in the dialog's state)
                                              setDialogState(() {
                                                // Check if this SN is already in currentMacs to avoid local collision
                                                // although the DB check is the source of truth
                                                int maxLocal = 0;
                                                for(var m in currentMacs) {
                                                  int? v = int.tryParse(m['sn'].toString());
                                                  if(v != null && v > maxLocal) maxLocal = v;
                                                }
                                                int finalSn = int.parse(nextSn);
                                                if(finalSn <= maxLocal) finalSn = maxLocal + 1;

                                                currentMacs.add({'mac': mac, 'sn': finalSn.toString()});
                                              });
                                              
                                              macController.clear();
                                              Navigator.pop(macCtx);
                                            }
                                          },
                                          child: const Text("Add"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }, 
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add"),
                          ),
                      ],
                    ),
                    
                    if (currentMacs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text("No devices registered", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      )
                    else
                      ...currentMacs.map((dev) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            if (dev['sn'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text("${dev['sn']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            Icon(Icons.important_devices, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dev['mac'], style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () => CategoryDialogs.showConfirmDialog(
                                context: context, 
                                title: "Remove MAC?", 
                                content: "Are you sure you want to remove ${dev['mac']} from $subItemName?", 
                                onConfirm: () => setDialogState(() => currentMacs.remove(dev)),
                              ),
                            ),
                          ],
                        ),
                      )),
                    
                    const SizedBox(height: 16),
                    Text("Total Bill: ৳${total.toStringAsFixed(0)}", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
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
                      onPressed: (isLoading) ? null : () async {
                        setDialogState(() => isLoading = true);
                        
                        // Update overrides
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
                        String actor = prefs.getString('username') ?? "Admin";
                        
                        await CategoryDialogs._dbService.updateSubItemOverriddenServices(subItemId, updated, actor);
                        await CategoryDialogs._dbService.updateSubItemMacAddresses(subItemId, currentMacs, actor);
                        
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: isLoading 
                        ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onTertiary))
                        : const Text("Save Changes"),
                    ),
                  ],
                ),
              ],
            );
        },
      ),
    );
  }

  void showGlobalMacListDialog({required BuildContext context}) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: CategoryDialogs._dbService.getAllActiveMacAddresses(),
            builder: (context, snapshot) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: const Center(child: Text("Wifi Devices Registry", style: TextStyle(fontWeight: FontWeight.w900))),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 450,
                  child: !snapshot.hasData 
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.data!.isEmpty 
                      ? const Center(child: Text("No MAC addresses registered."))
                      : ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            var item = snapshot.data![index];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    if (item['sn'] != null && item['sn'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text("${item['sn']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.devices, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['mac'], 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)
                                          ),
                                          Text(
                                            "${item['subItemName']} (${item['tenantName']})", 
                                            style: const TextStyle(fontSize: 10)
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                      onPressed: () => _showEditMacDialog(
                                        context: context,
                                        subItemId: item['subItemId'],
                                        oldMac: item['mac'],
                                        oldSn: item['sn'] ?? '',
                                        onSuccess: () => setDialogState(() {}),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () => CategoryDialogs.showConfirmDialog(
                                        context: context,
                                        title: "Remove MAC?",
                                        content: "Are you sure you want to remove ${item['mac']} from ${item['subItemName']}?",
                                        onConfirm: () async {
                                          SharedPreferences prefs = await SharedPreferences.getInstance();
                                          String actor = prefs.getString('username') ?? "Admin";
                                          
                                          // Fetch current macs for this subItem
                                          DocumentSnapshot doc = await FirebaseFirestore.instance.collection('sub_items').doc(item['subItemId']).get();
                                          List macs = List.from((doc.data() as Map?)?['macAddresses'] ?? []);
                                          macs.removeWhere((m) => (m is Map ? m['mac'] : m) == item['mac']);
                                          
                                          await CategoryDialogs._dbService.updateSubItemMacAddresses(item['subItemId'], macs, actor);
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
                        child: const Text("Close")
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        }
      ),
    );
  }

  void _showEditMacDialog({required BuildContext context, required String subItemId, required String oldMac, required String oldSn, required VoidCallback onSuccess}) {
    final macController = TextEditingController(text: oldMac);
    final snController = TextEditingController(text: oldSn);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Center(child: Text("Edit Device Info")),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: macController,
                inputFormatters: [MacAddressFormatter()],
                decoration: const InputDecoration(
                  labelText: "MAC Address",
                  hintText: "XX:XX:XX:XX:XX:XX",
                  prefixIcon: Icon(Icons.edit_outlined),
                  counterText: "",
                ),
                maxLength: 17,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: snController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Serial Number",
                  hintText: "Auto SN",
                  prefixIcon: Icon(Icons.numbers),
                  filled: true,
                ),
                style: const TextStyle(fontFamily: 'monospace', color: Colors.blueGrey),
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
                onPressed: () async {
                  String newMac = macController.text.trim().toUpperCase();
                  String newSn = snController.text.trim().toUpperCase();
                  if (newMac.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  String actor = prefs.getString('username') ?? "Admin";
                  
                  // Fetch current macs for this subItem
                  DocumentSnapshot doc = await FirebaseFirestore.instance.collection('sub_items').doc(subItemId).get();
                  List macs = List.from((doc.data() as Map?)?['macAddresses'] ?? []);
                  
                  // Find the original item (which could be a Map or String)
                  int idx = macs.indexWhere((m) => (m is Map ? m['mac'] : m) == oldMac);
                  if (idx != -1) {
                    macs[idx] = {'mac': newMac, 'sn': newSn};
                  } else {
                    macs.add({'mac': newMac, 'sn': newSn});
                  }
                  
                  await CategoryDialogs._dbService.updateSubItemMacAddresses(subItemId, macs, actor);
                  onSuccess();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text("Update"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showUserMacDetailsDialog({required BuildContext context, required String subItemName, required List macAddresses, required Map<String, dynamic> wifiService}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.wifi_tethering, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text("Wifi Details: $subItemName", style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.router, size: 20),
                      const SizedBox(width: 12),
                      Text("Devices Allowed: ${wifiService['deviceQuantity'] ?? 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Registered Devices:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                if (macAddresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No devices registered by admin yet.", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11))),
                  )
                else
                  ...macAddresses.map((dev) {
                    String mac = dev is Map ? dev['mac'] : dev.toString();
                    String sn = dev is Map ? dev['sn'] ?? '' : '';
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            if (sn.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text("$sn)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            const Icon(Icons.check_circle, size: 18, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mac, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Close")
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showSubItemServiceSettingsDialog({required BuildContext context, required String subItemId, required String subItemName, required List categoryServices, required List excludedServices}) {
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
            width: MediaQuery.of(context).size.width * 0.8,
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
                    await CategoryDialogs._dbService.updateSubItemExcludedServices(subItemId, currentExcluded, prefs.getString('username') ?? "Admin");
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      DatabaseService.showToast(context, "Services Updated!");
                    }
                  }, 
                  child: isLoading 
                    ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
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

  void showEditSubItemServiceDialog({required BuildContext context, required String subItemId, required String subItemName, required Map<String, dynamic> serviceMap, required List overriddenServices}) {
    final nameController = TextEditingController(text: serviceMap['name']); 
    final amountController = TextEditingController(text: serviceMap['amount'].toString());
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
        title: const Center(child: Text("Edit Service")), 
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
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
                  await CategoryDialogs._dbService.updateSubItemOverriddenServices(subItemId, updated, prefs.getString('username') ?? "Admin");
                  if (context.mounted) Navigator.pop(ctx);
                }, 
                child: const Text("Save")
              ),
            ],
          ),
        ],
      );
    }));
  }

  void showConfirmDialog({
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
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Text(content, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
}
