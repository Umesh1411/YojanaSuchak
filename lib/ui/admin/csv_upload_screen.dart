import 'package:flutter/material.dart';
import '../../services/one_time_upload.dart';
import '../../services/auto_upload_on_startup.dart';

/// Admin screen to upload schemes from CSV to Firestore
/// This will clear existing schemes and upload new ones
class CsvUploadScreen extends StatefulWidget {
  const CsvUploadScreen({super.key});

  @override
  State<CsvUploadScreen> createState() => _CsvUploadScreenState();
}

class _CsvUploadScreenState extends State<CsvUploadScreen> {
  bool _isUploading = false;
  String? _statusMessage;
  int? _schemesUploaded;
  int? _schemesFailed;

  Future<void> _uploadSchemes() async {
    setState(() {
      _isUploading = true;
      _statusMessage = 'Starting upload...';
      _schemesUploaded = null;
      _schemesFailed = null;
    });

    try {
      final result = await OneTimeUploadService.uploadSchemes();

      setState(() {
        _isUploading = false;
        _statusMessage = result.message;
        _schemesUploaded = result.schemesUploaded;
        _schemesFailed = result.schemesFailed;
      });

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Successfully uploaded ${result.schemesUploaded} schemes!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Upload failed: ${result.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Schemes from CSV'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Instructions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This will:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Read schemes from assets/data/scheme.csv'),
                      const Text('2. Clear ALL existing schemes in Firestore'),
                      const Text('3. Upload new schemes from CSV'),
                      const SizedBox(height: 12),
                      const Text(
                        '⚠️ Warning: This action cannot be undone!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Reset Upload Flag Button
              OutlinedButton.icon(
                onPressed: _isUploading
                    ? null
                    : () async {
                        await AutoUploadOnStartup.resetUploadFlag();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '✅ Upload flag reset. You can now upload again.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Upload Flag'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              // Upload Button
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadSchemes,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading
                    ? 'Uploading...'
                    : 'Upload Schemes to Firestore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 24),

              // Status
              if (_statusMessage != null)
                Card(
                  color: _schemesUploaded != null && _schemesUploaded! > 0
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(_statusMessage ?? ''),
                        if (_schemesUploaded != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Uploaded: $_schemesUploaded schemes',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_schemesFailed != null && _schemesFailed! > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.error,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Failed: $_schemesFailed schemes',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
