import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Static Cache for Pre-fetching ---
  static List<Map<String, dynamic>> cachedSubItems = [];
  static Map<String, dynamic>? cachedAppConfig;
  static double? cachedDBVersion;

  // ==========================================
  // 1. AUDIT & LOGGING SYSTEM
  // ==========================================

  Future<void> logActivity({
    required String actor,
    required String action,
    required String details,
    String? category,
  }) async {
    await _db.collection('activity_log').add({
      'actor': actor,
      'action': action,
      'details': details,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================
  // 2. CATEGORY METHODS
  // ==========================================

  Stream<QuerySnapshot> getCategoriesStream() {
    return _db.collection('categories').orderBy('createdAt', descending: true).snapshots();
  }

  Future<DocumentSnapshot> getCategoryById(String categoryId) async {
    if (categoryId.trim().isEmpty) {
      throw ArgumentError("Category ID cannot be empty");
    }
    return await _db.collection('categories').doc(categoryId).get();
  }

  Future<bool> checkCategoryExists(String lowerName) async {
    var existingDocs = await _db.collection('categories').where('categoryNameLower', isEqualTo: lowerName).get();
    return existingDocs.docs.isNotEmpty;
  }

  Future<void> addCategory(String name, String actor) async {
    DocumentReference doc = await _db.collection('categories').add({
      'categoryName': name,
      'categoryNameLower': name.toLowerCase(),
      'assignedServices': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
      actor: actor,
      action: "Add Category",
      details: "Created new category '$name' (ID: ${doc.id})",
      category: "Management",
    );
  }

  Future<void> updateCategoryServices(String categoryId, List assignedServices, String actor) async {
    DocumentSnapshot old = await _db.collection('categories').doc(categoryId).get();
    String name = (old.data() as Map?)?['categoryName'] ?? 'Unknown';
    
    await _db.collection('categories').doc(categoryId).update({
      'assignedServices': assignedServices,
    });

    await logActivity(
      actor: actor,
      action: "Update Category Services",
      details: "Updated services for category '$name'. Total services: ${assignedServices.length}",
      category: "Management",
    );
  }

  // ==========================================
  // 3. SERVICE METHODS
  // ==========================================

  Stream<QuerySnapshot> getServicesStream() {
    return _db.collection('services').orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addService(String name, double amount, String actor) async {
    DocumentReference doc = await _db.collection('services').add({
      'serviceName': name,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await logActivity(
      actor: actor,
      action: "Add Global Service",
      details: "Added service '$name' with rate ৳$amount",
      category: "Configuration",
    );
  }

  // ==========================================
  // 4. SUB-ITEM (ROOM/SHOP) METHODS
  // ==========================================

  Stream<QuerySnapshot> getSubItemsStream(String categoryId) {
    return _db.collection('sub_items').where('categoryId', isEqualTo: categoryId).snapshots();
  }

  Future<QuerySnapshot> getSubItemByName(String name) async {
    return await _db.collection('sub_items').where('subItemName', isEqualTo: name).limit(1).get();
  }

  Future<bool> checkSubItemExists(String categoryId, String name) async {
    var duplicateCheck = await _db
        .collection('sub_items')
        .where('categoryId', isEqualTo: categoryId)
        .where('subItemName', isEqualTo: name)
        .get();
    return duplicateCheck.docs.isNotEmpty;
  }

  Future<void> addSubItem(String categoryId, String name, String actor, {String? TenantName, String? nidNumber, String? notes}) async {
    String rName = (TenantName == null || TenantName.isEmpty) ? 'No Tenant' : TenantName;
    String nNumber = (nidNumber == null || nidNumber.isEmpty) ? 'No Number' : nidNumber;
    bool isOccupied = rName != 'No Tenant';
    
    DocumentReference doc = await _db.collection('sub_items').add({
      'categoryId': categoryId,
      'subItemName': name,
      'TenantName': rName,
      'nidNumber': nNumber,
      'notes': notes ?? '',
      'status': isOccupied ? 'Occupied' : 'Vacant',
      'occupiedAt': isOccupied ? FieldValue.serverTimestamp() : null,
      'excludedServices': [],
      'overriddenServices': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await logActivity(
      actor: actor,
      action: "Add Unit",
      details: "Added unit '$name' to category ID: $categoryId. Tenant: $rName",
      category: "Units",
    );
  }

  Future<void> updateSubItemStatus(String subItemId, String status, String actor, {String? TenantName, String? nidNumber}) async {
    DocumentSnapshot old = await _db.collection('sub_items').doc(subItemId).get();
    String unitName = (old.data() as Map?)?['subItemName'] ?? 'Unknown';

    Map<String, dynamic> data = {'status': status};
    if (status == 'Vacant') {
      data['TenantName'] = 'No Tenant';
      data['nidNumber'] = 'No Number';
      data['occupiedAt'] = null;
    } else {
      if (TenantName != null) data['TenantName'] = TenantName.isEmpty ? 'No Tenant' : TenantName;
      if (nidNumber != null) data['nidNumber'] = nidNumber.isEmpty ? 'No Number' : nidNumber;
      data['occupiedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('sub_items').doc(subItemId).update(data);

    await logActivity(
      actor: actor,
      action: "Change Unit Status",
      details: "Changed status of '$unitName' to '$status'. Tenant: ${data['TenantName']}",
      category: "Units",
    );
  }

  Future<void> updateSubItemDetails(String subItemId, Map<String, dynamic> data, String actor) async {
    DocumentSnapshot old = await _db.collection('sub_items').doc(subItemId).get();
    String unitName = (old.data() as Map?)?['subItemName'] ?? 'Unknown';

    if (data.containsKey('TenantName')) {
      String Tenant = data['TenantName'] ?? '';
      if (Tenant.isEmpty || Tenant == 'No Tenant') {
        data['TenantName'] = 'No Tenant';
        data['status'] = 'Vacant';
        data['nidNumber'] = 'No Number';
        data['occupiedAt'] = null;
      } else {
        if (!old.exists || old['status'] == 'Vacant' || old['occupiedAt'] == null) {
          data['occupiedAt'] = FieldValue.serverTimestamp();
        }
        data['status'] = 'Occupied';
      }
    }
    if (data.containsKey('nidNumber')) {
      String nid = data['nidNumber'] ?? '';
      if (nid.isEmpty) data['nidNumber'] = 'No Number';
    }
    await _db.collection('sub_items').doc(subItemId).update(data);

    await logActivity(
      actor: actor,
      action: "Update Unit Details",
      details: "Updated info for unit '$unitName'. Fields changed: ${data.keys.join(', ')}",
      category: "Units",
    );
  }

  Future<void> updateSubItemExcludedServices(String subItemId, List excludedServices, String actor) async {
    DocumentSnapshot old = await _db.collection('sub_items').doc(subItemId).get();
    String unitName = (old.data() as Map?)?['subItemName'] ?? 'Unknown';

    await _db.collection('sub_items').doc(subItemId).update({
      'excludedServices': excludedServices,
    });

    await logActivity(
      actor: actor,
      action: "Update Unit Services",
      details: "Modified service exclusions for '$unitName'.",
      category: "Units",
    );
  }

  Future<void> updateSubItemOverriddenServices(String subItemId, List overriddenServices, String actor) async {
    DocumentSnapshot old = await _db.collection('sub_items').doc(subItemId).get();
    String unitName = (old.data() as Map?)?['subItemName'] ?? 'Unknown';

    await _db.collection('sub_items').doc(subItemId).update({
      'overriddenServices': overriddenServices,
    });

    await logActivity(
      actor: actor,
      action: "Override Unit Services",
      details: "Updated custom service rates for '$unitName'.",
      category: "Units",
    );
  }

  Future<void> updateSubItemElectricity(String subItemId, Map<String, dynamic> electricityDetails, String actor) async {
    DocumentSnapshot old = await _db.collection('sub_items').doc(subItemId).get();
    String unitName = (old.data() as Map?)?['subItemName'] ?? 'Unknown';

    await _db.collection('sub_items').doc(subItemId).update({
      'electricityDetails': electricityDetails,
    });

    await logActivity(
      actor: actor,
      action: "Update Unit Electricity",
      details: "Updated readings for '$unitName'. Present: ${electricityDetails['presentReading']}",
      category: "Electricity",
    );
  }

  Future<void> updateSubItemElectricityStatus(String subItemId, bool isStopped, String actor) async {
    DocumentSnapshot old = await _db.collection('sub_items').doc(subItemId).get();
    String unitName = (old.data() as Map?)?['subItemName'] ?? 'Unknown';

    await _db.collection('sub_items').doc(subItemId).update({
      'electricityDetails.isStopped': isStopped,
    });

    await logActivity(
      actor: actor,
      action: "Toggle Electricity",
      details: "${isStopped ? 'Stopped' : 'Resumed'} electricity billing for '$unitName'",
      category: "Electricity",
    );
  }

  // ==========================================
  // 5. MAIN METER METHODS
  // ==========================================

  Stream<QuerySnapshot> getMainMetersStream() {
    return _db.collection('main_meters').orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getSubItemsByMainMeter(String mainMeterNo) {
    return _db.collection('sub_items').where('electricityDetails.mainMeterNo', isEqualTo: mainMeterNo).snapshots();
  }

  Future<void> addMainMeter(Map<String, dynamic> data, String actor) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    DocumentReference doc = await _db.collection('main_meters').add(data);

    await logActivity(
      actor: actor,
      action: "Add Main Meter",
      details: "Added main meter '${data['meterNo']}' type ${data['meterType']}",
      category: "Electricity",
    );
  }

  Future<void> updateMainMeter(String docId, Map<String, dynamic> data, String actor) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('main_meters').doc(docId).update(data);

    await logActivity(
      actor: actor,
      action: "Update Main Meter",
      details: "Updated readings for main meter '${data['meterNo']}'",
      category: "Electricity",
    );
  }

  // ==========================================
  // 5.1 SUB-METER METHODS
  // ==========================================

  Stream<QuerySnapshot> getSubMetersStream() {
    return _db.collection('sub_meters').orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addSubMeter(Map<String, dynamic> data, String actor) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['isAssigned'] = false;
    data['lastReading'] = 0.0;
    data['presentReading'] = 0.0;
    await _db.collection('sub_meters').add(data);

    await logActivity(
      actor: actor,
      action: "Add Sub Meter",
      details: "Added sub meter '${data['subMeterNo']}' linked to main meter '${data['mainMeterNo']}'",
      category: "Electricity",
    );
  }

  Future<void> updateSubMeter(String docId, Map<String, dynamic> data, String actor) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('sub_meters').doc(docId).update(data);
  }

  Future<void> removeSubMeter(String docId, String actor) async {
    await archiveAndRemove(collection: 'sub_meters', docId: docId, removedBy: actor, reason: 'Admin removed sub meter');
  }

  Stream<QuerySnapshot> getAvailableSubMetersStream() {
    return _db.collection('sub_meters').where('isAssigned', isEqualTo: false).snapshots();
  }

  Future<void> setSubMeterAssignment(String subMeterNo, bool isAssigned) async {
    var snap = await _db.collection('sub_meters').where('subMeterNo', isEqualTo: subMeterNo).limit(1).get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.update({'isAssigned': isAssigned});
    }
  }

  Future<void> syncSubMeterReading(String subMeterNo, double presentReading, String actor) async {
    var snap = await _db.collection('sub_meters').where('subMeterNo', isEqualTo: subMeterNo).limit(1).get();
    if (snap.docs.isNotEmpty) {
      var doc = snap.docs.first;
      var data = doc.data() as Map<String, dynamic>;
      await doc.reference.update({
        'lastReading': (data['presentReading'] ?? 0).toDouble(),
        'presentReading': presentReading,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==========================================
  // 6. APP CONFIG & UTILITY METHODS
  // ==========================================

  Stream<DocumentSnapshot> getAppConfigStream() {
    return _db.collection('app_config').doc('settings').snapshots();
  }

  Stream<DocumentSnapshot> getDatabaseInfoStream() {
    return _db.collection('app_config').doc('database_info').snapshots();
  }

  Future<void> updateRequiredVersion(String version) async {
    await _db.collection('app_config').doc('settings').set({
      'requiredVersion': version,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePopupStatus(bool isEnabled) async {
    await _db.collection('app_config').doc('settings').set({
      'isPopupEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDashboardVisibility(String role, Map<String, bool> settings) async {
    await _db.collection('app_config').doc('visibility_$role').set({
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getDashboardVisibilityStream(String role) {
    return _db.collection('app_config').doc('visibility_$role').snapshots();
  }

  Future<void> setServerStatus(String status) async {
    await _db.collection('app_config').doc('database_info').set({
      'serverStatus': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==========================================
  // 7. BILLING & HISTORY METHODS
  // ==========================================

  Future<void> addBillingRecord(Map<String, dynamic> data, String actor) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('billing_history').add(data);

    await logActivity(
      actor: actor,
      action: "Accept Payment",
      details: "Marked as paid for '${data['subItemName']}' month ${data['monthYear']}. Amount: ৳${data['totalAmount']}",
      category: "Billing",
    );
  }

  Future<bool> checkPaymentExists(String subItemId, String monthYear) async {
    var snap = await _db.collection('billing_history').where('subItemId', isEqualTo: subItemId).where('monthYear', isEqualTo: monthYear).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<QuerySnapshot> getPaymentRecords(String subItemId, String monthYear) async {
    return await _db.collection('billing_history')
        .where('subItemId', isEqualTo: subItemId)
        .where('monthYear', isEqualTo: monthYear)
        .get();
  }

  Future<DocumentSnapshot?> getPaymentRecord(String subItemId, String monthYear) async {
    var snap = await _db.collection('billing_history').where('subItemId', isEqualTo: subItemId).where('monthYear', isEqualTo: monthYear).limit(1).get();
    if (snap.docs.isNotEmpty) return snap.docs.first;
    return null;
  }

  Stream<QuerySnapshot> getBillingHistory(String subItemId, {int limit = 2}) {
    return _db.collection('billing_history').where('subItemId', isEqualTo: subItemId).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }

  Stream<QuerySnapshot> getUsersStream() {
    return _db.collection('users').snapshots();
  }

  Future<void> saveUser(String username, String password, String role, String actor, {String? docId}) async {
    Map<String, dynamic> data = {
      'username': username,
      'password': password,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (docId == null) {
      await _db.collection('users').add(data);
      await logActivity(actor: actor, action: "Create User", details: "Created new $role account: $username", category: "Security");
    } else {
      await _db.collection('users').doc(docId).update(data);
      await logActivity(actor: actor, action: "Update User", details: "Updated credentials for $role: $username", category: "Security");
    }
  }

  // ==========================================
  // 8. ARCHIVE & REMOVAL SYSTEM (LOGGED)
  // ==========================================

  Future<void> archiveAndRemove({
    required String collection,
    required String docId,
    required String removedBy,
    required String reason,
  }) async {
    DocumentSnapshot doc = await _db.collection(collection).doc(docId).get();
    if (!doc.exists) return;

    Map<String, dynamic> originalData = doc.data() as Map<String, dynamic>;
    String itemDesc = originalData['categoryName'] ?? originalData['subItemName'] ?? originalData['username'] ?? originalData['meterNo'] ?? docId;

    await _db.collection('removed_history').add({
      'collection': collection,
      'originalDocId': docId,
      'originalData': originalData,
      'removedBy': removedBy,
      'removedAt': FieldValue.serverTimestamp(),
      'reason': reason,
    });

    await _db.collection(collection).doc(docId).delete();

    await logActivity(
      actor: removedBy,
      action: "Remove Item",
      details: "Removed and archived '$itemDesc' from '$collection'.",
      category: "Removal",
    );
  }

  Future<void> removeCategory(String categoryId, String removedBy) async {
    await archiveAndRemove(collection: 'categories', docId: categoryId, removedBy: removedBy, reason: 'Admin removed category');
  }

  Future<void> removeService(String serviceId, String removedBy) async {
    await archiveAndRemove(collection: 'services', docId: serviceId, removedBy: removedBy, reason: 'Admin removed global service');
  }

  Future<void> removeSubItem(String subItemId, String removedBy) async {
    await archiveAndRemove(collection: 'sub_items', docId: subItemId, removedBy: removedBy, reason: 'Admin/Operator removed unit');
  }

  Future<void> removeMainMeter(String docId, String removedBy) async {
    await archiveAndRemove(collection: 'main_meters', docId: docId, removedBy: removedBy, reason: 'Admin removed main meter');
  }

  Future<void> removeUser(String docId, String removedBy) async {
    await archiveAndRemove(collection: 'users', docId: docId, removedBy: removedBy, reason: 'Admin removed administrative user');
  }

  // ==========================================
  // 9. DATABASE BACKUP & RESTORE
  // ==========================================

  // Get current database version
  Future<double> getDBVersion() async {
    DocumentSnapshot snap = await _db.collection('app_config').doc('database_info').get();
    if (snap.exists) {
      return (snap.data() as Map<String, dynamic>)['dbVersion']?.toDouble() ?? 1.0;
    }
    return 1.0;
  }

  // Export all data to Map for JSON
  Future<Map<String, dynamic>> exportDatabase(String actor, {Function(double)? onProgress}) async {
    double currentVersion = await getDBVersion();
    double nextVersion = currentVersion + 1.0;

    List<String> collections = [
      'categories', 'services', 'sub_items', 'main_meters', 
      'billing_history', 'users', 'activity_log', 'removed_history'
    ];

    Map<String, dynamic> exportData = {
      'dbVersion': nextVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'exportedBy': actor,
      'data': {},
    };

    // 1. Calculate Total Documents for granular progress
    int totalDocs = 0;
    Map<String, QuerySnapshot> snapshots = {};
    for (String col in collections) {
      QuerySnapshot snap = await _db.collection(col).get();
      snapshots[col] = snap;
      totalDocs += snap.docs.length;
    }

    if (totalDocs == 0) totalDocs = 1; // Avoid div by zero

    // 2. Process documents
    int processedCount = 0;
    for (String col in collections) {
      QuerySnapshot snap = snapshots[col]!;
      exportData['data'][col] = snap.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['_docId'] = doc.id; 
        
        processedCount++;
        if (onProgress != null) onProgress(processedCount / totalDocs);
        
        return _toJsonEncodable(data);
      }).toList();
    }

    // Note: We no longer update server version during export. 
    // Server version ONLY increases when a higher-version backup is Restored.

    await logActivity(
      actor: actor,
      action: "Database Backup",
      details: "Full database backup generated. Version: $nextVersion",
      category: "System",
    );

    return exportData;
  }

  // Wipe all administrative data EXCEPT users with countdown progress
  Future<void> wipeDatabase(String actor, {Function(double)? onProgress}) async {
    List<String> collections = [
      'categories', 'services', 'sub_items', 'main_meters', 
      'billing_history', 'activity_log', 'removed_history'
    ];

    // 1. Count total documents
    int totalDocs = 0;
    Map<String, List<DocumentReference>> docRefs = {};
    
    for (String col in collections) {
      QuerySnapshot snap = await _db.collection(col).get();
      totalDocs += snap.docs.length;
      docRefs[col] = snap.docs.map((d) => d.reference).toList();
    }

    if (totalDocs == 0) {
      if (onProgress != null) onProgress(0.0); // End at 0%
      return;
    }

    // 2. Delete with countdown progress (1.0 -> 0.0)
    int deletedCount = 0;
    for (String col in collections) {
      for (var ref in docRefs[col]!) {
        await ref.delete();
        deletedCount++;
        if (onProgress != null) {
          // Progress starts at 1.0 (100%) and goes down to 0.0 (0%)
          onProgress(1.0 - (deletedCount / totalDocs));
        }
      }
    }

    await logActivity(
      actor: actor,
      action: "Database Wipe",
      details: "All administrative collections were wiped from the server.",
      category: "Danger Zone",
    );
  }

  // Import data from Map (Restore)
  Future<void> importDatabase(Map<String, dynamic> importData, String actor, {Function(double)? onProgress}) async {
    // 1. Wipe first (Stage 1: 10%)
    await wipeDatabase(actor);
    if (onProgress != null) onProgress(0.1);

    // 2. Restore collections (Stage 2: 90%)
    Map<String, dynamic> collectionsData = importData['data'];
    
    // Calculate total documents for granular progress
    int totalDocs = 0;
    for (var colList in collectionsData.values) {
      if (colList is List) totalDocs += colList.length;
    }

    if (totalDocs == 0) totalDocs = 1;

    int processedCount = 0;
    for (String col in collectionsData.keys) {
      List docs = collectionsData[col];
      for (var docData in docs) {
        Map<String, dynamic> data = Map<String, dynamic>.from(docData);
        String? docId = data['_docId'];
        data.remove('_docId');

        // Clean up Timestamps
        Map<String, dynamic> cleanedData = Map<String, dynamic>.from(_fromJsonDecodable(data));

        if (docId != null) {
          await _db.collection(col).doc(docId).set(cleanedData);
        } else {
          await _db.collection(col).add(cleanedData);
        }

        processedCount++;
        if (onProgress != null) {
          // Range 0.1 to 1.0 based on doc count
          onProgress(0.1 + (0.9 * (processedCount / totalDocs)));
        }
      }
    }

    // 3. Update server version
    num restoredVersion = importData['dbVersion'] ?? 1.0;
    await _db.collection('app_config').doc('database_info').set({
      'dbVersion': restoredVersion,
      'lastRestoreAt': FieldValue.serverTimestamp(),
      'lastRestoreBy': actor,
    }, SetOptions(merge: true));

    await logActivity(
      actor: actor,
      action: "Database Restore",
      details: "Database restored to version $restoredVersion",
      category: "System",
    );
  }

  // Static Helpers
  static Future<void> vibrate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool enabled = prefs.getBool('isHapticEnabled') ?? true;
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void showToast(BuildContext context, String message, {Color? backgroundColor}) {
    vibrate(); // Use custom vibrate helper
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor ?? Colors.blue.shade800,
        width: 280,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static String getCurrentMonthYear() => formatMonthYear(DateTime.now());

  static String formatMonthYear(DateTime date) {
    final List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[date.month - 1]}-${date.year.toString().substring(2)}";
  }

  static List<Map<String, dynamic>> getEffectiveServices({required List categoryServices, required List excludedServices, required List overriddenServices}) {
    List<Map<String, dynamic>> effectiveList = [];
    Set<String> processedNames = {};
    num parseNum(dynamic val) => (val is num) ? val : (val is String ? num.tryParse(val) ?? 0 : 0);

    for (var service in categoryServices) {
      String originalName = (service is Map) ? (service['name'] ?? service.toString()) : service.toString();
      if (originalName.trim().isEmpty || excludedServices.contains(originalName) || processedNames.contains(originalName)) continue;
      processedNames.add(originalName);
      num defaultAmount = (service is Map) ? parseNum(service['amount']) : 0;
      var overrideMatch = overriddenServices.firstWhere((element) => element is Map && element['originalName'] == originalName, orElse: () => null);
      if (overrideMatch != null) {
        effectiveList.add({'name': overrideMatch['name'] ?? originalName, 'amount': parseNum(overrideMatch['amount']), 'isOverridden': true, 'originalName': originalName, 'deviceQuantity': overrideMatch['deviceQuantity'], 'wifiCost': overrideMatch['wifiCost']});
      } else {
        Map<String, dynamic> serviceData = {'name': originalName, 'amount': defaultAmount, 'isOverridden': false, 'originalName': originalName};
        if (originalName.toLowerCase().contains("wifi")) { serviceData['deviceQuantity'] = 1; serviceData['wifiCost'] = defaultAmount; }
        effectiveList.add(serviceData);
      }
    }
    return effectiveList;
  }

  static String formatDuration(Timestamp? updatedAt) {
    if (updatedAt == null) return "Never updated";
    DateTime lastUpdate = updatedAt.toDate();
    Duration diff = DateTime.now().difference(lastUpdate);
    if (diff.isNegative) diff = Duration.zero;
    return "${diff.inDays} days ${diff.inHours % 24} hours ${diff.inMinutes % 60} mins ${diff.inSeconds % 60} secs";
  }

  // --- PRIVATE SERIALIZATION HELPERS ---

  dynamic _toJsonEncodable(dynamic value) {
    if (value is Timestamp) {
      return {'_type': 'Timestamp', 'value': value.toDate().toIso8601String()};
    } else if (value is DocumentReference) {
      return {'_type': 'DocumentReference', 'value': value.path};
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toJsonEncodable(v)));
    } else if (value is List) {
      return value.map((i) => _toJsonEncodable(i)).toList();
    }
    return value;
  }

  dynamic _fromJsonDecodable(dynamic value) {
    if (value is Map) {
      if (value.containsKey('_type')) {
        if (value['_type'] == 'Timestamp') {
          return Timestamp.fromDate(DateTime.parse(value['value']));
        } else if (value['_type'] == 'DocumentReference') {
          return _db.doc(value['value']);
        }
      }
      return value.map((k, v) => MapEntry(k.toString(), _fromJsonDecodable(v)));
    } else if (value is List) {
      return value.map((i) => _fromJsonDecodable(i)).toList();
    }
    return value;
  }
}
