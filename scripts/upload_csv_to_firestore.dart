/// Standalone script to upload CSV schemes to Firestore
///
/// Usage:
///   dart run scripts/upload_csv_to_firestore.dart
///
/// Or from Flutter:
///   flutter run -d chrome --target=scripts/upload_csv_to_firestore.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/firebase_options.dart';
import '../lib/models/scheme.dart';

void main() async {
  print('🚀 Starting CSV to Firestore upload...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // Read CSV file
    final csvFile = File('assets/data/scheme.csv');
    if (!await csvFile.exists()) {
      print('❌ CSV file not found at assets/data/scheme.csv');
      print('   Please ensure the file exists in the correct location');
      exit(1);
    }

    final csvContent = await csvFile.readAsString();
    print('✅ CSV file loaded (${csvContent.length} characters)');

    // Parse CSV
    final schemes = _parseCsv(csvContent);
    print('✅ Parsed ${schemes.length} schemes from CSV');

    if (schemes.isEmpty) {
      print('❌ No schemes found in CSV');
      exit(1);
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

    print('');
    print('═══════════════════════════════════════════════════════');
    print('✅ UPLOAD COMPLETE!');
    print('   Uploaded: $uploaded schemes');
    if (failed > 0) {
      print('   Failed: $failed schemes');
    }
    print('═══════════════════════════════════════════════════════');

    exit(0);
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

List<Scheme> _parseCsv(String csvContent) {
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

List<String> _parseCsvLine(String line) {
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

Scheme _csvRowToScheme(Map<String, String> row) {
  final String docsStr = row['Important_Documents'] ?? '';
  final List<String> documents = docsStr
      .split(';')
      .map((d) => d.trim())
      .where((d) => d.isNotEmpty)
      .toList();

  int? maxIncome;
  final String incomeStr = row['Max_Income_INR'] ?? '';
  if (incomeStr.isNotEmpty && incomeStr != 'NA') {
    final String cleanIncome = incomeStr.replaceAll(',', '').trim();
    maxIncome = int.tryParse(cleanIncome);
  }

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

Future<void> _clearExistingSchemes() async {
  final firestore = FirebaseFirestore.instance;
  final QuerySnapshot snapshot = await firestore.collection('schemes').get();

  final WriteBatch batch = firestore.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }

  await batch.commit();
  print('   ✅ Deleted ${snapshot.docs.length} existing schemes');
}

String _generateDocId(String schemeName) {
  return schemeName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .substring(0, schemeName.length > 50 ? 50 : schemeName.length);
}
