import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';

/// Contact Us Screen
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@yojanasuchak.com',
      query: 'subject=YojanaSuchak Support',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+17654358068');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        debugPrint('Could not launch phone: $phoneUri');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to make phone call. Please dial +1 765-435-8068 manually.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching phone: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.contactUs),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Get in Touch',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'d love to hear from you!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            // Contact Cards
            Card(
              child: ListTile(
                leading: const Icon(Icons.email, color: AppTheme.primaryColor),
                title: const Text('Email'),
                subtitle: const Text('support@yojanasuchak.com'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _launchEmail(context),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone, color: AppTheme.primaryColor),
                title: const Text('Phone'),
                subtitle: const Text('+1 765-435-8068'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _launchPhone(context),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.location_on, color: AppTheme.primaryColor),
                title: Text('Address'),
                subtitle: Text('Mumbai, Maharashtra, India'),
              ),
            ),
            const SizedBox(height: 32),
            // Contact Form
            const Text(
              'Send us a message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Your Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Your Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Message',
                prefixIcon: Icon(Icons.message),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message sent successfully!'),
                  ),
                );
              },
              child: const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }
}






