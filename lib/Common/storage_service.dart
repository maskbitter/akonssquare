import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadTenantImage({
    required File imageFile,
    required String unitName,
    required String subItemId,
    required String imageType, // 'profile' or 'nid'
  }) async {
    try {
      String fileName = "${imageType}_picture.jpg";
      String path = "current tenants nid/profile/$unitName/$subItemId/$fileName";
      
      Reference ref = _storage.ref().child(path);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<void> handleTenantVacated({
    required String unitName,
    required String subItemId,
  }) async {
    try {
      String currentPath = "current tenants nid/profile/$unitName/$subItemId";
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String historyPath = "left tenants nid/profile/$unitName/$subItemId/$timestamp";

      Reference currentRef = _storage.ref().child(currentPath);
      final listResult = await currentRef.listAll();

      for (var item in listResult.items) {
        String downloadUrl = await item.getDownloadURL();
        // Since Firebase Storage doesn't have a direct 'move', we might just log or copy if needed.
        // But the requirement says "save that picture into the firebase storage as left tenants...".
        // Idiomatically, we should upload the existing file to the new location or just store the URL in history.
        // However, Storage doesn't support server-side copy easily without Cloud Functions.
        // A common workaround is to download and re-upload, but that's expensive.
        // For now, I will implement a "copy" by re-uploading from URL if possible, or just note that the requirement implies moving.
        
        // Actually, let's just upload to both or move. 
        // If we want to move, we have to download and upload to new path, then delete old.
        // But wait, the requirement is "when admin make that occupied unit to vacant then it will save in the firebase 'left tenants...'"
        
        // Let's keep it simple: When vacating, we can just leave it or move it.
        // I'll implement a simple copy logic using `getData` and `putData`.
        
        final data = await item.getData();
        if (data != null) {
          String newPath = "$historyPath/${item.name}";
          await _storage.ref().child(newPath).putData(data);
          await item.delete();
        }
      }
    } catch (e) {
      print("Error moving images to history: $e");
    }
  }

  Future<void> deleteImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print("Error deleting image: $e");
    }
  }
}
