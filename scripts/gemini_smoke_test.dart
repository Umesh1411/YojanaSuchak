import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

Future<void> main(List<String> args) async {
  final key = Platform.environment['GEMINI_API_KEY'] ??
      (args.isNotEmpty ? args[0] : '');
  if (key.isEmpty) {
    print('No GEMINI_API_KEY provided. Provide via env or first arg.');
    exit(1);
  }

  final candidateModels = [
    // Added per user request (flash-lite series)
    'gemini-flash-lite-latest',
    'gemini-1.0-pro',
    'gemini-1.0',
    'gemini-1.0-mini',
    'gemini-1.1'
  ];

  // If user passed an explicit model as ENV or first arg (like 'models/gemini-flash-lite-latest'), normalize it
  final envModel =
      Platform.environment['GEMINI_MODEL'] ?? (args.length > 1 ? args[1] : '');
  String normalizeModel(String m) =>
      m.startsWith('models/') ? m.substring('models/'.length) : m;
  if (envModel.isNotEmpty) {
    final nm = normalizeModel(envModel);
    if (!candidateModels.contains(nm)) {
      candidateModels.insert(0, nm);
    }
  }
  final prompt =
      '''You are an assistant that answers in one short sentence. If asked to gather profile fields, ask for the next missing field only. Now reply briefly to: "Hello, I want to find government schemes."''';

  print('📡 Attempting to call Gemini models: ${candidateModels.join(', ')}');
  for (final modelName in candidateModels) {
    try {
      final model = GenerativeModel(model: modelName, apiKey: key);
      final response = await model.generateContent(
          [Content.text(prompt)]).timeout(const Duration(seconds: 30));
      print('✅ Success with model: $modelName');
      print('📥 Gemini response:');
      print(response.text ?? '<empty>');
      exit(0);
    } catch (e) {
      final es = e.toString();
      print('⚠️ Model $modelName failed: $es');
      if (es.contains('is not found for API version') ||
          es.contains('model not found')) {
        print(
            '   → This usually means the Generative AI API is not enabled for the project that issued the API key, or the key does not have access to that model.');
      }
      if (es.contains('401') || es.contains('Unauthorized')) {
        print('   → 401 Unauthorized: the API key may be invalid or revoked.');
      }
      if (es.contains('403') || es.contains('Forbidden')) {
        print(
            '   → 403 Forbidden: the API key may be restricted or billing is not enabled for the project.');
      }
      // try next
    }
  }

  print(
      '❌ All candidate models failed. Attempting to list available models via REST API...');

  try {
    final uri =
        Uri.parse('https://generativeai.googleapis.com/v1beta/models?key=$key');
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    print('📄 Models list response (v1):');
    if (body.trim().startsWith('<!DOCTYPE html>') ||
        response.statusCode == 404) {
      print('❌ REST models endpoint returned HTML 404 page or not found.');
      print(
          '   → Likely cause: Generative AI API not enabled for the project that owns the key, or the endpoint is not available to your key.');
      print(
          '   → Fix: Enable "Generative AI API" in the Google Cloud Console for the same project as the API key, ensure billing is enabled, or use a service-account with the required IAM role.');
    }

    // Otherwise print a short snippet
    final snippet = body.length > 1000 ? body.substring(0, 1000) : body;
    print(snippet);
    httpClient.close();
  } catch (e) {
    print('⚠️ Could not list models: $e');
  }

  exit(2);
}
