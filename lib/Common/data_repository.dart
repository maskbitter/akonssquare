import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:akons_square/Common/database_service.dart';

class DataRepository {
  static final DataRepository _instance = DataRepository._internal();
  factory DataRepository() => _instance;
  DataRepository._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _dbService = DatabaseService();

  // ValueNotifiers for UI binding
  final ValueNotifier<List<QueryDocumentSnapshot>> categories = ValueNotifier([]);
  final ValueNotifier<List<QueryDocumentSnapshot>> services = ValueNotifier([]);
  final ValueNotifier<List<QueryDocumentSnapshot>> subItems = ValueNotifier([]);
  final ValueNotifier<List<QueryDocumentSnapshot>> billingHistory = ValueNotifier([]);
  final ValueNotifier<List<QueryDocumentSnapshot>> mainMeters = ValueNotifier([]);
  final ValueNotifier<List<QueryDocumentSnapshot>> subMeters = ValueNotifier([]);
  
  // Financial calculation cache to prevent UI lag
  final ValueNotifier<Map<String, double>> subItemPayableCache = ValueNotifier({});
  
  StreamSubscription? _catSub;
  StreamSubscription? _serviceSub;
  StreamSubscription? _subItemSub;
  StreamSubscription? _billingSub;
  StreamSubscription? _mainMeterSub;
  StreamSubscription? _subMeterSub;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Listen to Categories
    _catSub = _db.collection('categories').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      categories.value = snap.docs;
    });

    // Listen to Services
    _serviceSub = _db.collection('services').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      services.value = snap.docs;
    });

    // Listen to Sub Items (Units)
    _subItemSub = _db.collection('sub_items').snapshots().listen((snap) {
      subItems.value = snap.docs;
      _recalculateAllFinancials();
    });

    // Listen to Billing History (Recent)
    _billingSub = _db.collection('billing_history').snapshots().listen((snap) {
      billingHistory.value = snap.docs;
      _recalculateAllFinancials();
    });

    // Listen to Main Meters
    _mainMeterSub = _db.collection('main_meters').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      mainMeters.value = snap.docs;
    });

    // Listen to Sub Meters
    _subMeterSub = _db.collection('sub_meters').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      subMeters.value = snap.docs;
    });
  }

  void dispose() {
    _catSub?.cancel();
    _serviceSub?.cancel();
    _subItemSub?.cancel();
    _billingSub?.cancel();
    _mainMeterSub?.cancel();
    _subMeterSub?.cancel();
  }

  // --- Financial Logic Optimized for Local Data ---

  void _recalculateAllFinancials() async {
    Map<String, double> newCache = {};
    String currentMonthStr = DatabaseService.getCurrentMonthYear();

    for (var subDoc in subItems.value) {
      String subId = subDoc.id;
      double estimatedMonthAmount = _calculateSingleMonthEstimateLocal(subDoc);
      
      var summary = calculateFinancialSummaryLocal(subId, estimatedMonthAmount, currentMonthStr);
      // Cache only the bill for the CURRENT month (including what's already paid)
      newCache[subId] = (summary['currentMonthBill'] as num).toDouble();
    }
    
    subItemPayableCache.value = newCache;
  }

  double _calculateSingleMonthEstimateLocal(QueryDocumentSnapshot subDoc) {
    var subData = subDoc.data() as Map<String, dynamic>;
    String catId = subData['categoryId'] ?? '';
    if (catId.isEmpty) return 0;

    var catDoc = categories.value.where((c) => c.id == catId).firstOrNull;
    if (catDoc == null) return 0;
    var catData = catDoc.data() as Map<String, dynamic>;

    List categoryServices = catData['assignedServices'] ?? [];
    List excluded = subData['excludedServices'] ?? [];
    List overridden = subData['overriddenServices'] ?? [];

    List<Map<String, dynamic>> active = DatabaseService.getEffectiveServices(
      categoryServices: categoryServices,
      excludedServices: excluded,
      overriddenServices: overridden,
    );

    double servicesSum = active.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());
    
    var ed = subData['electricityDetails'];
    double eBill = 0;
    if (ed != null && ed['isStopped'] != true) {
      double last = (ed['lastReading'] as num?)?.toDouble() ?? 0;
      double present = (ed['presentReading'] as num?)?.toDouble() ?? 0;
      double rate = (ed['pricePerUnit'] as num?)?.toDouble() ?? 0;
      eBill = (present - last) * rate;
    }

    return servicesSum + eBill;
  }

  Map<String, dynamic> calculateFinancialSummaryLocal(String subId, double currentMonthAmount, String currentMonthYear) {
    // Filter billing history from memory
    var historyDocs = billingHistory.value.where((doc) => (doc.data() as Map)['subItemId'] == subId).toList();
    
    double totalOutstanding = 0;
    double totalPayable = 0;
    double currentMonthBill = 0;
    List<Map<String, dynamic>> pendingMonths = [];
    Set<String> processedMonths = {};
    
    var subDoc = subItems.value.where((s) => s.id == subId).firstOrNull;
    List manualDues = subDoc != null ? (subDoc.data() as Map)['manualDues'] ?? [] : [];
    double manualDuesTotal = 0;

    for (var m in manualDues) {
      if (m is Map) manualDuesTotal += (m['amount'] as num).toDouble();
    }

    for (var doc in historyDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String my = data['monthYear'].toString().trim().toLowerCase();
      double amt = (data['totalAmount'] as num).toDouble();
      
      if (my == currentMonthYear.trim().toLowerCase()) {
        currentMonthBill = amt;
      }

      if (data['status'] == 'Due') {
        totalOutstanding += amt;
        pendingMonths.add({
          'monthYear': data['monthYear'],
          'data': {...data, 'docId': doc.id},
          'isHistory': true,
        });
      } else if (data['status'] == 'Paid' && my == currentMonthYear.trim().toLowerCase()) {
        totalPayable += amt;
      }
      processedMonths.add(my);
    }

    if (!processedMonths.contains(currentMonthYear.trim().toLowerCase())) {
      totalOutstanding += currentMonthAmount;
      currentMonthBill = currentMonthAmount;
      pendingMonths.add({
        'monthYear': currentMonthYear,
        'isHistory': false,
      });
    }

    totalOutstanding += manualDuesTotal;
    totalPayable += totalOutstanding;
    
    // Sort pending months
    pendingMonths.sort((a, b) {
      try {
        List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var aParts = a['monthYear'].split('-');
        var bParts = b['monthYear'].split('-');
        int aMonth = months.indexOf(aParts[0]);
        int bMonth = months.indexOf(bParts[0]);
        int aYear = int.parse(aParts[1]);
        int bYear = int.parse(bParts[1]);
        if (aYear != bYear) return aYear.compareTo(bYear);
        return aMonth.compareTo(bMonth);
      } catch (e) { return 0; }
    });

    return {
      'total': totalOutstanding,
      'totalPayable': totalPayable,
      'currentMonthBill': currentMonthBill,
      'pendingMonths': pendingMonths,
      'arrearsCount': pendingMonths.where((m) => m['isHistory'] == true).length,
    };
  }
}
