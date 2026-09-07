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

  void startUpdate(String url) {
    if (_status == AppUpdateStatus.downloading && _downloadUrl == url) return;
    
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
          
          if (event.status == OtaStatus.INSTALLING) {
            _status = AppUpdateStatus.completed;
            _progress = 1.0;
            _subscription?.cancel();
          } else if (event.status == OtaStatus.DOWNLOADING) {
            _status = AppUpdateStatus.downloading;
            _progress = (double.tryParse(event.value ?? '0') ?? 0) / 100;
          } else if (event.status == OtaStatus.ALREADY_RUNNING_ERROR) {
            // Already running
          } else if (_isErrorStatus(event.status)) {
            _status = AppUpdateStatus.error;
            _error = "Update failed: ${event.status.name}";
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
        status == OtaStatus.INSTALLATION_ERROR;
  }

  void pauseUpdate() {
    if (_status == AppUpdateStatus.downloading) {
      _subscription?.cancel();
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

  void cancelUpdate() {
    _subscription?.cancel();
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
