part of '../category_dialogs.dart';

extension MeterDialogs on CategoryDialogs {
  void showAddMainMeterDialog(BuildContext context) {
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
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: Column(
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
                      try {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await CategoryDialogs._dbService.addMainMeter({
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
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (e.toString().contains("DuplicateFound")) {
                          if (context.mounted) CategoryDialogs._showDuplicateErrorDialog(context, no, "MainMeter");
                        }
                      }
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

  void showUpdateMainMeterDialog({required BuildContext context, required Map<String, dynamic> data, required String docId}) {
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
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  if (data['updatedAt'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("Last updated: ${DatabaseService.formatFullDateTime(data['updatedAt'] as Timestamp?)}", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                              Text("${DatabaseService.formatDuration(data['updatedAt'] as Timestamp?)} ago", textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  CategoryDialogs._buildReadOnlyRow(context, "Meter Type", data['meterType']),
                  CategoryDialogs._buildReadOnlyRow(context, "Meter No", data['meterNo']),
                  CategoryDialogs._buildReadOnlyRow(context, "Last Reading", lastReading.toStringAsFixed(1)),
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
                  CategoryDialogs._buildReadOnlyRow(context, "Last Govt. Bill Reading", lastGovtReading.toStringAsFixed(1)),
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
                  CategoryDialogs._buildReadOnlyRow(context, "Govt. Bill Unit", govtBillUnit.toStringAsFixed(1)),
                  CategoryDialogs._buildReadOnlyRow(context, "Last Month Unit Rate", "৳${lastMonthRate.toStringAsFixed(2)}"),
                  CategoryDialogs._buildReadOnlyRow(context, "This Month Unit Rate", "৳${thisMonthRate.toStringAsFixed(2)}"),
                  CategoryDialogs._buildReadOnlyRow(context, "Govt. Due/Adv Units", govtDueAdv.toStringAsFixed(1)),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("Detailed Statistics (Calculated)", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  ),
                  CategoryDialogs._buildReadOnlyRow(context, "Main Meter Used Unit", mainUsed.toStringAsFixed(1)),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: CategoryDialogs._dbService.getSubItemsByMainMeter(data['meterNo']),
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
                          CategoryDialogs._buildReadOnlyRow(context, "Total Sub-meter Units", totalSubUnits.toStringAsFixed(1)),
                          CategoryDialogs._buildReadOnlyRow(context, "Balance Units (Main-Sub)", balance.toStringAsFixed(1), valueColor: balance > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                        ],
                      );
                    }
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
                    onPressed: (isLoading || 
                                (presentReadingController.text == data['presentReading'].toString() &&
                                 govtReadingController.text == data['govtBillReading'].toString() &&
                                 amountController.text == data['govtBillAmount'].toString() &&
                                 (govtBillUnit > 0 ? (billAmount / govtBillUnit) : 0) == (data['unitRate'] ?? 0).toDouble()
                                )) ? null : () async {
                      double last = double.tryParse(lastReadingController.text) ?? 0; 
                      double pres = double.tryParse(presentReadingController.text) ?? last;
                      double govt = double.tryParse(govtReadingController.text) ?? 0; 
                      double amt = double.tryParse(amountController.text) ?? 0;

                      if (pres < lastReading) {
                        CategoryDialogs._showValidationWarning(context, "Present reading ($pres) cannot be lower than the last reading ($lastReading).");
                        return;
                      }
                      if (govt < lastGovtReading) {
                        CategoryDialogs._showValidationWarning(context, "Govt. reading ($govt) cannot be lower than the last govt. reading ($lastGovtReading).");
                        return;
                      }
                      
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
                            content: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.95,
                              child: Text("Previous reading was $prevSavedMain. Should this be set as the 'Last Reading' for this month?", style: Theme.of(context).textTheme.bodyMedium),
                            ),
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
                            content: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.95,
                              child: Text("Previous Govt. reading was $prevSavedGovt. Should this be set as the 'Last Govt. Reading' for this month?", style: Theme.of(context).textTheme.bodyMedium),
                            ),
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
                      await CategoryDialogs._dbService.updateMainMeter(docId, updateData, actor);
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

  void showAddSubMeterDialog(BuildContext context) {
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
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: CategoryDialogs._dbService.getMainMetersStream(),
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
                    try {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await CategoryDialogs._dbService.addSubMeter({
                        'subMeterNo': no,
                        'mainMeterNo': selectedMainMeter,
                      }, prefs.getString('username') ?? "Admin");
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => isLoading = false);
                      if (e.toString().contains("DuplicateFound")) {
                        if (context.mounted) CategoryDialogs._showDuplicateErrorDialog(context, no, "SubMeter");
                      }
                    }
                  },
                  child: isLoading 
                    ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: ThemeManager.outlineBackground))
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

  void showDeleteMeterDialog({
    required BuildContext context,
    required String type, 
    required String meterNo,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text("Remove $type?", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text("Meter: $meterNo", style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Warning: Removing this meter will hide it from all active lists. History will be preserved in records. Please check current usage:",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (type == 'MainMeter')
                StreamBuilder<QuerySnapshot>(
                  stream: CategoryDialogs._dbService.getSubMetersByMainMeter(meterNo),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator());
                    var linkedSubMeters = snapshot.data!.docs;
                    if (linkedSubMeters.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Linked Sub-Meters:", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                        ...linkedSubMeters.map((d) => Text("• ${d['subMeterNo']}", style: Theme.of(context).textTheme.labelMedium)).toList(),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              StreamBuilder<QuerySnapshot>(
                stream: type == 'SubMeter' 
                  ? CategoryDialogs._dbService.getSubItemsBySubMeter(meterNo)
                  : CategoryDialogs._dbService.getSubItemsByMainMeter(meterNo),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator());
                  var linkedUnits = snapshot.data!.docs;
                  if (linkedUnits.isEmpty) return Text("No linked Units/Rooms found.", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Linked Units/Rooms:", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      ...linkedUnits.map((d) => Text("• ${d['subItemName']}", style: Theme.of(context).textTheme.labelMedium)).toList(),
                    ],
                  );
                },
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("Cancel")
              ),
              AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onConfirm();
                }, 
                child: const Text("Confirm Remove")
              ),
            ],
          ),
        ],
      ),
    );
  }
}
