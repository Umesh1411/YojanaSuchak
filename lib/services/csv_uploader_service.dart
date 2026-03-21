import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/scheme.dart';
import 'firestore_service.dart';

/// Service to upload schemes from CSV to Firestore
/// This will clear existing schemes and upload new ones from CSV
class CsvUploaderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload schemes from CSV string content (from file picker)
  Future<UploadResult> uploadSchemesFromCsvContent(String csvContent) async {
    try {
      final List<Scheme> schemes = _parseCsv(csvContent);
      debugPrint('✅ Parsed ${schemes.length} schemes from picked CSV');

      if (schemes.isEmpty) {
        return UploadResult(success: false, message: 'No valid schemes found in the CSV.', schemesUploaded: 0);
      }

      int uploaded = 0;
      int failed = 0;
      for (final scheme in schemes) {
        try {
          final docId = scheme.schemeId.isNotEmpty
              ? scheme.schemeId
              : _generateDocId(scheme.schemeName);
          await _firestore.collection('schemes').doc(docId).set(scheme.toJson());
          uploaded++;
        } catch (e) {
          debugPrint('❌ Failed to upload ${scheme.schemeName}: $e');
          failed++;
        }
      }
      FirestoreService.clearCache();
      return UploadResult(
        success: uploaded > 0,
        message: 'Uploaded $uploaded scheme(s) successfully${failed > 0 ? ", $failed failed" : ""}.',
        schemesUploaded: uploaded,
        schemesFailed: failed,
      );
    } catch (e) {
      return UploadResult(success: false, message: 'Error processing CSV: $e', schemesUploaded: 0);
    }
  }

  /// Upload schemes from CSV to Firestore
  /// Clears existing schemes and uploads new ones
  Future<UploadResult> uploadSchemesFromCsv() async {
    try {
      debugPrint('📂 Starting CSV upload process...');

      // Step 1: Read CSV file
      final String csvContent =
          await rootBundle.loadString('assets/data/scheme.csv');
      debugPrint('✅ CSV file loaded (${csvContent.length} characters)');

      // Step 2: Parse CSV
      final List<Scheme> schemes = _parseCsv(csvContent);
      debugPrint('✅ Parsed ${schemes.length} schemes from CSV');

      if (schemes.isEmpty) {
        return UploadResult(
          success: false,
          message: 'No schemes found in CSV file',
          schemesUploaded: 0,
        );
      }

      // Step 3: Clear existing schemes
      debugPrint('🗑️ Clearing existing schemes from Firestore...');
      await _clearExistingSchemes();
      debugPrint('✅ Existing schemes cleared');

      // Step 4: Upload new schemes
      debugPrint('📤 Uploading ${schemes.length} schemes to Firestore...');
      int uploaded = 0;
      int failed = 0;

      for (final scheme in schemes) {
        try {
          // Use schemeId as document ID, or generate one if empty
          final docId = scheme.schemeId.isNotEmpty
              ? scheme.schemeId
              : _generateDocId(scheme.schemeName);

          await _firestore
              .collection('schemes')
              .doc(docId)
              .set(scheme.toJson());

          uploaded++;
          if (uploaded % 10 == 0) {
            debugPrint('📤 Uploaded $uploaded/${schemes.length} schemes...');
          }
        } catch (e) {
          debugPrint('❌ Failed to upload scheme ${scheme.schemeName}: $e');
          failed++;
        }
      }

      // Clear cache so new schemes are loaded
      FirestoreService.clearCache();

      debugPrint('✅ Upload complete: $uploaded uploaded, $failed failed');

      return UploadResult(
        success: uploaded > 0,
        message:
            'Uploaded $uploaded schemes successfully${failed > 0 ? ', $failed failed' : ''}',
        schemesUploaded: uploaded,
        schemesFailed: failed,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading schemes: $e');
      debugPrint('Stack trace: $stackTrace');
      return UploadResult(
        success: false,
        message: 'Error: $e',
        schemesUploaded: 0,
      );
    }
  }

  /// Parse CSV content into List<Scheme>
  List<Scheme> _parseCsv(String csvContent) {
    final List<Scheme> schemes = [];
    final List<String> lines = csvContent.split('\n');

    if (lines.length < 2) {
      return schemes; // Need at least header + 1 data row
    }

    // Parse header
    final List<String> headers = _parseCsvLine(lines[0]);
    debugPrint('📋 CSV Headers: ${headers.length} columns');

    // Parse data rows
    for (int i = 1; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final List<String> values = _parseCsvLine(line);
        if (values.length < headers.length) {
          debugPrint(
              '⚠️ Row $i has ${values.length} values, expected ${headers.length}');
          continue;
        }

        final Map<String, String> rowData = {};
        for (int j = 0; j < headers.length && j < values.length; j++) {
          rowData[headers[j]] = values[j].trim();
        }

        // Convert to Scheme object
        final Scheme scheme = _csvRowToScheme(rowData);
        if (scheme.schemeName.isNotEmpty) {
          schemes.add(scheme);
        }
      } catch (e) {
        debugPrint('❌ Error parsing row $i: $e');
      }
    }

    return schemes;
  }

  /// Parse a CSV line handling quoted fields
  List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    String currentField = '';
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          currentField += '"';
          i++; // Skip next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // Field separator
        fields.add(currentField);
        currentField = '';
      } else {
        currentField += char;
      }
    }
    fields.add(currentField); // Add last field

    return fields;
  }

  /// Convert CSV row data to Scheme object
  Scheme _csvRowToScheme(Map<String, String> row) {
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
      // Remove commas and parse
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
  Future<void> _clearExistingSchemes() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection('schemes').get();

      final WriteBatch batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Deleted ${snapshot.docs.length} existing schemes');
    } catch (e) {
      debugPrint('❌ Error clearing schemes: $e');
      rethrow;
    }
  }

  /// Generate document ID from scheme name
  String _generateDocId(String schemeName) {
    return schemeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, schemeName.length > 50 ? 50 : schemeName.length);
  }
}

/// Result of CSV upload operation
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
