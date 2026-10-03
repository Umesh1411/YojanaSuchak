import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/scheme.dart';

class SchemeDetailScreen extends StatelessWidget {
  final Scheme scheme;

  const SchemeDetailScreen({super.key, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(scheme.schemeName),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scheme.department,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoChip('State', scheme.state),
            const SizedBox(height: 8),
            _buildInfoChip('Level', scheme.schemeLevel),
            const SizedBox(height: 8),
            if (scheme.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: scheme.tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.12),
                          labelStyle:
                              const TextStyle(color: AppTheme.primaryColor),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 20),
            const Text(
              'Eligibility',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(scheme.eligibility.isNotEmpty
                ? scheme.eligibility
                : 'No specific eligibility details available.'),
            const SizedBox(height: 20),
            const Text(
              'Benefits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(scheme.allBenefitsDescription.isNotEmpty
                ? scheme.allBenefitsDescription
                : scheme.benefits),
            const SizedBox(height: 20),
            const Text(
              'Application Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Mode', scheme.applicationMode),
            _buildDetailRow('Deadline', scheme.applicationDeadline),
            if (scheme.officialApplyLink.isNotEmpty)
              _buildDetailRow('Apply Link', scheme.officialApplyLink),
            if (scheme.officialSource.isNotEmpty)
              _buildDetailRow('Source', scheme.officialSource),
            if (scheme.remarks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  scheme.remarks,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
