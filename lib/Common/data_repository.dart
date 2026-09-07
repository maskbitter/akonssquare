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
  
  // Meter readings history cache
  final ValueNotifier<Map<String, Map<String, dynamic>>> mainMeterReadingsHistory = ValueNotifier({});
  
  // Financial calculation cache to prevent UI lag
  final ValueNotifier<Map<String, double>> subItemPayableCache = ValueNotifier({});
  final ValueNotifier<Map<String, Map<String, dynamic>>> subItemSummaryCache = ValueNotifier({});
  final ValueNotifier<double> grandTotalNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> receivedTotalNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> dueTotalNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> rentTotalNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> utilityTotalNotifier = ValueNotifier(0.0);
  
  String _currentRecalcMonth = DatabaseService.getCurrentMonthYear();

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

    _startMeterReadingsListener();
  }

  StreamSubscription? _meterReadingsSub;
  void _startMeterReadingsListener() {
    _meterReadingsSub?.cancel();
    _meterReadingsSub = _db.collection('main_meter_readings').where('monthYear', isEqualTo: _currentRecalcMonth).snapshots().listen((snap) {
      Map<String, Map<String, dynamic>> results = {};
      for (var doc in snap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String? meterNo = data['meterNo'];
        if (meterNo != null) {
          results[meterNo] = data;
        }
      }
      mainMeterReadingsHistory.value = results;
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

  void _recalculateAllFinancials() {
    recalculateForMonth(_currentRecalcMonth);
  }

  void recalculateForMonth(String monthYear) {
    if (_currentRecalcMonth != monthYear) {
      _currentRecalcMonth = monthYear;
      _startMeterReadingsListener();
    }
    Map<String, double> newCache = {};
    Map<String, Map<String, dynamic>> newSummaryCache = {};
    double gTotal = 0;
    double rTotal = 0;
    double rentSum = 0;
    double dTotal = 0;

    // Pre-filter billing history for speed
    var currentMonthRecords = billingHistory.value.where((d) => (d.data() as Map)['monthYear'] == monthYear).toList();
    
    // Determine historical status: 
    // A unit is "historically occupied" if:
    // 1. It has a billing record for that month (Paid or Due)
    // 2. OR it's currently occupied and looking at current month
    Set<String> historicallyOccupiedIds = {};
    for (var doc in currentMonthRecords) {
      historicallyOccupiedIds.add((doc.data() as Map)['subItemId']);
    }
    
    if (monthYear == DatabaseService.getCurrentMonthYear()) {
      for (var doc in subItems.value) {
        if ((doc.data() as Map)['status'] == 'Occupied') {
          historicallyOccupiedIds.add(doc.id);
        }
      }
    }

    for (var subDoc in subItems.value) {
      String subId = subDoc.id;
      bool wasOccupied = historicallyOccupiedIds.contains(subId);
      
      double estimatedMonthAmount = _calculateSingleMonthEstimateLocal(subDoc, monthYear);
      var summary = calculateFinancialSummaryLocal(subId, estimatedMonthAmount, monthYear);
      
      newCache[subId] = (summary['currentMonthBill'] as num).toDouble();
      newSummaryCache[subId] = summary;

      // Only count in totals if it was actually occupied or has a due record
      bool wasOccupiedInMonth = summary['isVacant'] != true || wasOccupied;

      if (wasOccupiedInMonth) {
        gTotal += (summary['currentMonthBill'] as num).toDouble();
        dTotal += (summary['total'] as num).toDouble();
      }
    }

    // Calculate Received and Rent from actual records of occupied units
    for (var doc in currentMonthRecords) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'Due') continue;

      rTotal += (data['totalAmount'] as num).toDouble();
      List services = data.containsKey('services') ? data['services'] : [];
      for (var s in services) {
        if (s['name'].toString().toLowerCase().contains('rent')) {
          rentSum += (s['amount'] as num).toDouble();
        }
      }
    }
    
    subItemPayableCache.value = newCache;
    subItemSummaryCache.value = newSummaryCache;
    receivedTotalNotifier.value = rTotal;
    dueTotalNotifier.value = dTotal;
    // Grand Total is now everything expected: Received + What is still Due (including arrears)
    grandTotalNotifier.value = rTotal + dTotal; 
    rentTotalNotifier.value = rentSum;
    utilityTotalNotifier.value = rTotal - rentSum;
  }

  double _calculateSingleMonthEstimateLocal(QueryDocumentSnapshot subDoc, String monthYear) {
    var subData = subDoc.data() as Map<String, dynamic>;
    String catId = subData['categoryId'] ?? '';
    if (catId.isEmpty) return 0;

    // Logic: If looking at a specific month, was it occupied then?
    // If it's currently vacant and we are looking at the current month, estimate is 0.
    if (subData['status'] == 'Vacant' && monthYear == DatabaseService.getCurrentMonthYear()) {
      return 0;
    }

    // If looking at a past month, we check occupiedAt or createdAt
    // However, the best way to know past state is the billing_history record.
    // This method is for "Estimation" when no record exists.
    // If no record exists for monthYear, and it's currently occupied, 
    // we check if occupiedAt was before or during that month.
    
    if (subData['status'] == 'Occupied') {
      Timestamp? occAt = subData['occupiedAt'] as Timestamp?;
      if (occAt != null) {
        String occMY = DatabaseService.formatMonthYear(occAt.toDate());
        if (DatabaseService.compareMonthYear(monthYear, occMY) < 0) {
          return 0; // Was vacant before occupation
        }
      }
    } else {
      // Currently vacant, and looking at some month. 
      // If it's a past month, and no record exists, it was likely vacant.
      return 0;
    }

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
    bool isCurrentlyVacantInSelectedMonth = false;
    
    var subDoc = subItems.value.where((s) => s.id == subId).firstOrNull;
    var subData = subDoc?.data() as Map<String, dynamic>?;
    List manualDues = subData != null ? subData['manualDues'] ?? [] : [];
    double manualDuesTotal = 0;

    for (var m in manualDues) {
      if (m is Map) {
        String? dMY = m['monthYear']?.toString();
        // Only include if it belongs to the selected month OR has no specific month assigned (legacy data)
        if (dMY == null || dMY == 'null' || dMY.isEmpty || dMY.trim().toLowerCase() == currentMonthYear.trim().toLowerCase()) {
          manualDuesTotal += (m['amount'] as num).toDouble();
        }
      }
    }

    // Get active services for estimation details
    List<Map<String, dynamic>> activeServices = [];
    if (subDoc != null) {
      String catId = subData?['categoryId'] ?? '';
      var catDoc = categories.value.where((c) => c.id == catId).firstOrNull;
      if (catDoc != null) {
        var catData = catDoc.data() as Map<String, dynamic>;
        activeServices = DatabaseService.getEffectiveServices(
          categoryServices: catData['assignedServices'] ?? [],
          excludedServices: subData?['excludedServices'] ?? [],
          overriddenServices: subData?['overriddenServices'] ?? [],
        );
      }
    }
    double servicesTotal = activeServices.fold(0.0, (acc, s) => acc + (s['amount'] as num).toDouble());

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
          'isVacant': false,
        });
      } else if (data['status'] == 'Paid' && my == currentMonthYear.trim().toLowerCase()) {
        totalPayable += amt;
      }
      processedMonths.add(my);
    }

    if (!processedMonths.contains(currentMonthYear.trim().toLowerCase())) {
      // Check if it was vacant in this month
      if (subData != null) {
        String status = subData['status'] ?? 'Vacant';
        if (status == 'Vacant' && currentMonthYear == DatabaseService.getCurrentMonthYear()) {
          isCurrentlyVacantInSelectedMonth = true;
        } else {
          // Check createdAt
          Timestamp? created = subData['createdAt'] as Timestamp?;
          if (created != null) {
            String createdMY = DatabaseService.formatMonthYear(created.toDate());
            if (DatabaseService.compareMonthYear(currentMonthYear, createdMY) < 0) {
              isCurrentlyVacantInSelectedMonth = true;
            }
          }

          if (!isCurrentlyVacantInSelectedMonth && status == 'Occupied') {
            Timestamp? occAt = subData['occupiedAt'] as Timestamp?;
            if (occAt != null) {
              String occMY = DatabaseService.formatMonthYear(occAt.toDate());
              if (DatabaseService.compareMonthYear(currentMonthYear, occMY) < 0) {
                isCurrentlyVacantInSelectedMonth = true;
              }
            } else {
              // If occupiedAt is null, and there's no record for this past month,
              // it's safer to assume it was vacant.
              isCurrentlyVacantInSelectedMonth = true;
            }
          } else if (!isCurrentlyVacantInSelectedMonth && status == 'Vacant') {
            isCurrentlyVacantInSelectedMonth = true;
          }
        }
      }

      if (isCurrentlyVacantInSelectedMonth) {
        currentMonthBill = 0;
      } else {
        totalOutstanding += currentMonthAmount;
        currentMonthBill = currentMonthAmount;
        pendingMonths.add({
          'monthYear': currentMonthYear,
          'isHistory': false,
          'isVacant': false,
        });
      }
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
      'manualDuesTotal': manualDuesTotal,
      'servicesTotal': servicesTotal,
      'activeServices': activeServices,
      'isVacant': isCurrentlyVacantInSelectedMonth,
    };
  }
}
