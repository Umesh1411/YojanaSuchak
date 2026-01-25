import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/scheme.dart';
import 'firestore_service.dart';

/// One-time upload service to upload CSV schemes to Firestore
/// Call this from your app initialization or a button
class OneTimeUploadService {
  /// Upload schemes from CSV to Firestore
  /// This will clear existing schemes and upload new ones
  static Future<UploadResult> uploadSchemes() async {
    try {
      print('🚀 Starting CSV upload to Firestore...');

      // Firebase should already be initialized in main.dart
      // Just verify it's available
      try {
        FirebaseFirestore.instance; // This will throw if not initialized
        print('✅ Firebase Firestore is ready');
      } catch (e) {
        print('❌ Firebase not initialized: $e');
        return UploadResult(
          success: false,
          message: 'Firebase not initialized. Please restart the app.',
          schemesUploaded: 0,
        );
      }

      // Read CSV file
      String csvContent;
      try {
        csvContent = await rootBundle.loadString('assets/data/scheme.csv');
        print('✅ CSV file loaded (${csvContent.length} characters)');
      } catch (e) {
        print('❌ Error loading CSV file: $e');
        print(
            '   Make sure assets/data/scheme.csv exists and is listed in pubspec.yaml');
        return UploadResult(
          success: false,
          message: 'Failed to load CSV file: $e. Check console for details.',
          schemesUploaded: 0,
        );
      }

      // Parse CSV
      final List<Scheme> schemes = _parseCsv(csvContent);
      print('✅ Parsed ${schemes.length} schemes from CSV');

      if (schemes.isEmpty) {
        return UploadResult(
          success: false,
          message: 'No schemes found in CSV file',
          schemesUploaded: 0,
        );
      }

      // Clear existing schemes
      print('🗑️  Clearing existing schemes from Firestore...');
      await _clearExistingSchemes();
      print('✅ Existing schemes cleared');

      // Upload new schemes
      print('📤 Uploading ${schemes.length} schemes to Firestore...');
      final firestore = FirebaseFirestore.instance;
      int uploaded = 0;
      int failed = 0;

      for (final scheme in schemes) {
        try {
          final docId = scheme.schemeId.isNotEmpty
              ? scheme.schemeId
              : _generateDocId(scheme.schemeName);

          await firestore.collection('schemes').doc(docId).set(scheme.toJson());

          uploaded++;
          if (uploaded % 10 == 0) {
            print('   📤 Uploaded $uploaded/${schemes.length} schemes...');
          }
        } catch (e) {
          print('   ❌ Failed to upload ${scheme.schemeName}: $e');
          failed++;
        }
      }

      // Clear cache
      FirestoreService.clearCache();

      print('✅ Upload complete: $uploaded uploaded, $failed failed');

      return UploadResult(
        success: uploaded > 0,
        message:
            'Uploaded $uploaded schemes successfully${failed > 0 ? ', $failed failed' : ''}',
        schemesUploaded: uploaded,
        schemesFailed: failed,
      );
    } catch (e, stackTrace) {
      print('❌ Error uploading schemes: $e');
      print('Stack trace: $stackTrace');
      return UploadResult(
        success: false,
        message: 'Error: $e',
        schemesUploaded: 0,
      );
    }
  }

  /// Parse CSV content into List<Scheme>
  static List<Scheme> _parseCsv(String csvContent) {
    final List<Scheme> schemes = [];
    final List<String> lines = csvContent.split('\n');

    if (lines.length < 2) return schemes;

    // Parse header
    final List<String> headers = _parseCsvLine(lines[0]);

    // Parse data rows
    for (int i = 1; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final List<String> values = _parseCsvLine(line);
        if (values.length < headers.length) continue;

        final Map<String, String> rowData = {};
        for (int j = 0; j < headers.length && j < values.length; j++) {
          rowData[headers[j]] = values[j].trim();
        }

        final Scheme scheme = _csvRowToScheme(rowData);
        if (scheme.schemeName.isNotEmpty) {
          schemes.add(scheme);
        }
      } catch (e) {
        print('   ⚠️  Error parsing row $i: $e');
      }
    }

    return schemes;
  }

  /// Parse a CSV line handling quoted fields
  static List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    String currentField = '';
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentField += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField);
        currentField = '';
      } else {
        currentField += char;
      }
    }
    fields.add(currentField);

    return fields;
  }

  /// Convert CSV row data to Scheme object
  static Scheme _csvRowToScheme(Map<String, String> row) {
    // Parse documents (semicolon-separated)
    final String docsStr = row['Important_Documents'] ?? '';
    final List<String> documents = docsStr
        .split(';')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    // Parse income (handle "NA" and numbers)
    int? maxIncome;
    final String incomeStr = row['Max_Income_INR'] ?? '';
    if (incomeStr.isNotEmpty && incomeStr != 'NA') {
      final String cleanIncome = incomeStr.replaceAll(',', '').trim();
      maxIncome = int.tryParse(cleanIncome);
    }

    // Parse ages
    int? minAge = int.tryParse(row['Min_Age'] ?? '');
    int? maxAge = int.tryParse(row['Max_Age'] ?? '');

    return Scheme(
      schemeId: row['Scheme_ID'] ?? '',
      schemeName: row['Scheme_Name'] ?? '',
      state: row['State'] ?? 'India',
      schemeLevel: row['Scheme_Level'] ?? 'Central',
      department: row['Department'] ?? '',
      occupationEligible: row['Occupation_Eligible'] ?? 'Any',
      genderEligible: row['Gender_Eligible'] ?? 'All',
      categoryEligible: row['Category_Eligible'] ?? 'All',
      casteEligible: row['Caste_Eligible'] ?? 'All',
      minAge: minAge,
      maxAge: maxAge,
      maxIncomeINR: maxIncome,
      incomeRuleType: row['Income_Rule_Type'] ?? 'NO_LIMIT',
      maritalStatus: row['Marital_Status'] ?? 'Any',
      otherEligibilityCriteria: row['Other_Eligibility_Criteria'] ?? '',
      beneficiaryType: row['Beneficiary_Type'] ?? '',
      benefitType: row['Benefit_Type'] ?? '',
      benefitAmount: row['Benefit_Amount'] ?? '',
      benefitFrequency: row['Benefit_Frequency'] ?? '',
      allBenefitsDescription: row['All_Benefits_Description'] ?? '',
      applicationMode: row['Application_Mode'] ?? 'Online',
      applicationDeadline: row['Application_Deadline'] ?? 'Open',
      importantDocuments: documents,
      officialApplyLink: row['Official_Apply_Link'] ?? '',
      officialSource: row['Official_Source'] ?? '',
      remarks: row['Remarks'] ?? '',
    );
  }

  /// Clear all existing schemes from Firestore
  static Future<void> _clearExistingSchemes() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot =
          await firestore.collection('schemes').get();

      final WriteBatch batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Deleted ${snapshot.docs.length} existing schemes');
    } catch (e) {
      print('❌ Error clearing schemes: $e');
      rethrow;
    }
  }

  /// Generate document ID from scheme name
  static String _generateDocId(String schemeName) {
    return schemeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, schemeName.length > 50 ? 50 : schemeName.length);
  }
}

/// Result of upload operation
class UploadResult {
  final bool success;
  final String message;
  final int schemesUploaded;
  final int schemesFailed;

  UploadResult({
    required this.success,
    required this.message,
    required this.schemesUploaded,
    this.schemesFailed = 0,
  });
}
