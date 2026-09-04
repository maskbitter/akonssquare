import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:akons_square/Common/database_service.dart';

class ShareHelper {
  static Future<void> shareApp(BuildContext context) async {
    try {
      // Fetch download URL from app_config/settings
      DocumentSnapshot configSnap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .get();

      String downloadUrl = "";
      String appName = "AkonsSquare";

      if (configSnap.exists) {
        var data = configSnap.data() as Map<String, dynamic>;
        downloadUrl = data['downloadUrl'] ?? "";
        appName = data['appName'] ?? "AkonsSquare";
      }

      if (downloadUrl.isEmpty) {
        if (context.mounted) {
          DatabaseService.showToast(
            context, 
            "Share link not available. Please contact admin.",
            backgroundColor: Theme.of(context).colorScheme.error
          );
        }
        return;
      }

      final String message = "Check out $appName app! \nDownload it from here: $downloadUrl";
      
      await Share.share(message, subject: "Share $appName");
      
    } catch (e) {
      if (context.mounted) {
        DatabaseService.showToast(
          context, 
          "Failed to share: $e",
          backgroundColor: Theme.of(context).colorScheme.error
        );
      }
    }
  }
}
