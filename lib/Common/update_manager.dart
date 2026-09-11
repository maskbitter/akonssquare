import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

enum AppUpdateStatus { idle, downloading, readyToInstall, completed, error }

class UpdateManager extends ChangeNotifier {
  static final UpdateManager instance = UpdateManager._internal();
  factory UpdateManager() => instance;
  UpdateManager._internal() {
    _loadState();
  }

  AppUpdateStatus _status = AppUpdateStatus.idle;
  double _progress = 0;
  String? _error;
  String? _downloadUrl;
  StreamSubscription? _subscription;
  OtaEvent? _lastEvent;
  bool _isDialogVisible = false;

  AppUpdateStatus get status => _status;
  double get progress => _progress;
  String? get error => _error;
  String? get downloadUrl => _downloadUrl;
  OtaEvent? get lastEvent => _lastEvent;
  bool get isDialogVisible => _isDialogVisible;

  bool get isDownloading => _status == AppUpdateStatus.downloading;
  bool get hasActiveUpdate => _status != AppUpdateStatus.idle && _status != AppUpdateStatus.completed;

  void setDialogVisible(bool visible) {
    _isDialogVisible = visible;
    notifyListeners();
  }

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
    _saveState();
    notifyListeners();

    _runDownload();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('update_status', _status.index);
    await prefs.setDouble('update_progress', _progress);
    if (_downloadUrl != null) await prefs.setString('update_url', _downloadUrl!);
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final statusIndex = prefs.getInt('update_status') ?? AppUpdateStatus.idle.index;
    _status = AppUpdateStatus.values[statusIndex];
    _progress = prefs.getDouble('update_progress') ?? 0;
    _downloadUrl = prefs.getString('update_url');
    
    // If it was downloading, we need to reconnect to the stream
    if (_status == AppUpdateStatus.downloading && _downloadUrl != null) {
      _runDownload();
    }
    notifyListeners();
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
          OtaStatus effectiveStatus = event.status;
          if (event.status.index == 3) {
            effectiveStatus = OtaStatus.INSTALLATION_ERROR;
          } else if (event.status.index == 4) {
            effectiveStatus = OtaStatus.ALREADY_RUNNING_ERROR;
          }

          if (effectiveStatus == OtaStatus.INSTALLING) {
            // Download reached 100% and installer triggered
            _status = AppUpdateStatus.readyToInstall;
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
          _saveState();
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

  Future<void> triggerInstall() async {
    if (_status == AppUpdateStatus.readyToInstall) {
      _progress = 0.99; // Visual cue for "Preparing..."
      notifyListeners();

      try {
        final apkBaseName = _downloadUrl!.split('/').last.split('?').first;
        final possibleNames = [
          apkBaseName,
          apkBaseName.endsWith('.apk') ? apkBaseName : '$apkBaseName.apk',
          'update.apk',
          'app.apk',
        ];

        final dirs = [
          await getExternalStorageDirectory(),
          await getApplicationSupportDirectory(),
          await getApplicationDocumentsDirectory(),
          await getTemporaryDirectory(),
        ];

        File? foundApk;
        for (final dir in dirs) {
          if (dir == null) continue;
          debugPrint("UpdateManager: Checking directory: ${dir.path}");

          // 1. Try exact names
          for (final name in possibleNames) {
            final file = File("${dir.path}/$name");
            if (await file.exists()) {
              foundApk = file;
              break;
            }
          }
          if (foundApk != null) break;

          // 2. Try subdirectories (ota_update sometimes uses them)
          final subDirs = ['ota', 'downloads', 'updates'];
          for (final sub in subDirs) {
            final subDir = Directory("${dir.path}/$sub");
            if (await subDir.exists()) {
              for (final name in possibleNames) {
                final file = File("${subDir.path}/$name");
                if (await file.exists()) {
                  foundApk = file;
                  break;
                }
              }
            }
            if (foundApk != null) break;
          }
          if (foundApk != null) break;

          // 3. Scan for ANY .apk file as a last resort
          try {
            final files = dir.listSync();
            for (final entity in files) {
              if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
                foundApk = entity;
                break;
              }
            }
          } catch (_) {}
          if (foundApk != null) break;
        }

        if (foundApk != null) {
          debugPrint("UpdateManager: APK Found at: ${foundApk.path}! Launching installer...");
          const platform = MethodChannel('com.example.akonssquare/install');
          await platform.invokeMethod('installApk', {'path': foundApk.path});
          return; // Success!
        }
      } catch (e) {
        debugPrint("UpdateManager: Local install logic crashed: $e");
      }

      debugPrint("UpdateManager: Could not find local APK. Falling back to re-download.");
      _runDownload();
    } else if (_downloadUrl != null) {
      _runDownload();
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
    _saveState();
    notifyListeners();
  }

  void reset() {
    cancelUpdate();
  }
}
