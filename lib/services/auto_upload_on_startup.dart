import 'package:shared_preferences/shared_preferences.dart';
import 'one_time_upload.dart';

/// Service to automatically upload CSV schemes on first app launch
/// Call this from main.dart or app initialization
class AutoUploadOnStartup {
  static const String _uploadKey = 'csv_schemes_uploaded';

  /// Check if schemes have been uploaded, if not, upload them
  /// Returns true if upload was performed, false if already uploaded
  static Future<bool> checkAndUploadIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyUploaded = prefs.getBool(_uploadKey) ?? false;

      if (alreadyUploaded) {
        print('ℹ️  Schemes already uploaded. Skipping...');
        return false;
      }

      print('🚀 First launch detected. Uploading schemes from CSV...');
      final result = await OneTimeUploadService.uploadSchemes();

      if (result.success) {
        await prefs.setBool(_uploadKey, true);
        print('✅ Schemes uploaded successfully!');
        return true;
      } else {
        print('❌ Upload failed: ${result.message}');
        return false;
      }
    } catch (e) {
      print('❌ Error in auto-upload: $e');
      return false;
    }
  }

  /// Reset upload flag (useful for testing or re-uploading)
  static Future<void> resetUploadFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uploadKey);
    print('✅ Upload flag reset. Schemes will be uploaded on next launch.');
  }

  /// Check if schemes have been uploaded
  static Future<bool> hasUploaded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_uploadKey) ?? false;
  }
}
