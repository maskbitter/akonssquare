import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

enum AppUpdateStatus { idle, downloading, paused, completed, error }

class UpdateManager extends ChangeNotifier {
  static final UpdateManager instance = UpdateManager._internal();
  factory UpdateManager() => instance;
  UpdateManager._internal();

  AppUpdateStatus _status = AppUpdateStatus.idle;
  double _progress = 0;
  String? _error;
  String? _downloadUrl;
  StreamSubscription? _subscription;
  OtaEvent? _lastEvent;

  AppUpdateStatus get status => _status;
  double get progress => _progress;
  String? get error => _error;
  String? get downloadUrl => _downloadUrl;
  OtaEvent? get lastEvent => _lastEvent;

  bool get isDownloading => _status == AppUpdateStatus.downloading;
  bool get hasActiveUpdate => _status != AppUpdateStatus.idle && _status != AppUpdateStatus.completed;

  void startUpdate(String url) async {
    if (_status == AppUpdateStatus.downloading && _downloadUrl == url) return;
    
    // Always try to cancel any existing native session first
    try {
      await OtaUpdate().cancel();
    } catch (e) {
      print("UpdateManager: Error canceling previous update: $e");
    }

    _downloadUrl = url;
    _status = AppUpdateStatus.downloading;
    _error = null;
    _progress = 0;
    notifyListeners();

    _runDownload();
  }

  void _runDownload() {
    try {
      _subscription?.cancel();
      _subscription = OtaUpdate().execute(
        _downloadUrl!,
        androidProviderAuthority: "com.example.akonssquare.ota_update_provider",
      ).listen(
        (OtaEvent event) {
          _lastEvent = event;
          print("UpdateManager: Status=${event.status}, Value=${event.value}");
          
          // Workaround for ota_update 7.1.0 enum mismatch
          // Java Index 3 is INSTALLATION_ERROR, index 4 is ALREADY_RUNNING_ERROR
          // Dart Index 3 is ALREADY_RUNNING_ERROR, index 4 is INSTALLATION_ERROR
          OtaStatus effectiveStatus = event.status;
          if (event.status.index == 3) {
            effectiveStatus = OtaStatus.INSTALLATION_ERROR;
          } else if (event.status.index == 4) {
            effectiveStatus = OtaStatus.ALREADY_RUNNING_ERROR;
          }

          if (effectiveStatus == OtaStatus.INSTALLING) {
            _status = AppUpdateStatus.completed;
            _progress = 1.0;
            _subscription?.cancel();
          } else if (effectiveStatus == OtaStatus.DOWNLOADING) {
            _status = AppUpdateStatus.downloading;
            _progress = (double.tryParse(event.value ?? '0') ?? 0) / 100;
          } else if (effectiveStatus == OtaStatus.ALREADY_RUNNING_ERROR) {
             print("UpdateManager: Detected ALREADY_RUNNING_ERROR, attempting to cancel and restart...");
             cancelUpdate();
             startUpdate(_downloadUrl!);
          } else if (_isErrorStatus(effectiveStatus)) {
            _status = AppUpdateStatus.error;
            _error = "Update failed: ${effectiveStatus.name}${event.value != null ? ' - ${event.value}' : ''}";
            _subscription?.cancel();
          }
          notifyListeners();
        },
        onError: (e) {
          _status = AppUpdateStatus.error;
          _error = "Download error: $e";
          notifyListeners();
        },
      );
    } catch (e) {
      _status = AppUpdateStatus.error;
      _error = "System error: $e";
      notifyListeners();
    }
  }

  bool _isErrorStatus(OtaStatus status) {
    return status == OtaStatus.DOWNLOAD_ERROR ||
        status == OtaStatus.INTERNAL_ERROR ||
        status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR ||
        status == OtaStatus.CHECKSUM_ERROR ||
        status == OtaStatus.INSTALLATION_ERROR ||
        status == OtaStatus.ALREADY_RUNNING_ERROR;
  }

  void pauseUpdate() async {
    if (_status == AppUpdateStatus.downloading) {
      _subscription?.cancel();
      try {
        await OtaUpdate().cancel();
      } catch (e) {
        print("UpdateManager: Error canceling native update during pause: $e");
      }
      _status = AppUpdateStatus.paused;
      notifyListeners();
    }
  }

  void resumeUpdate() {
    if (_status == AppUpdateStatus.paused && _downloadUrl != null) {
      _status = AppUpdateStatus.downloading;
      notifyListeners();
      _runDownload();
    }
  }

  void cancelUpdate() async {
    _subscription?.cancel();
    try {
      await OtaUpdate().cancel();
    } catch (e) {
      print("UpdateManager: Error canceling native update: $e");
    }
    _status = AppUpdateStatus.idle;
    _progress = 0;
    _error = null;
    _downloadUrl = null;
    notifyListeners();
  }

  void reset() {
    cancelUpdate();
  }
}
