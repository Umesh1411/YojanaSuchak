import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/scheme.dart';

/// Service for sending emails via SMTP
class EmailService {
  final String smtpHost;
  final int smtpPort;
  final String username;
  final String password;
  final bool useTls;

  EmailService({
    required this.smtpHost,
    this.smtpPort = 587,
    required this.username,
    required this.password,
    this.useTls = true,
  });

  /// Send scheme details via email
  Future<bool> sendSchemeDetails({
    required String recipientEmail,
    required String recipientName,
    required Scheme scheme,
  }) async {
    try {
      // Create SMTP server
      // For Gmail on port 587, we use STARTTLS (not direct SSL)
      // The mailer package handles STARTTLS when ssl is false and port is 587
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: username,
        password: password,
        ssl: false, // Use STARTTLS for port 587
        allowInsecure: false, // Don't allow insecure connections
        ignoreBadCertificate: false, // Verify certificates
      );

      // Create email message
      final message = Message()
        ..from = Address(username, 'YojanaSuchak')
        ..recipients.add(recipientEmail)
        ..subject = 'Scheme Details: ${scheme.schemeName}'
        ..html = _buildEmailHtml(recipientName, scheme);

      // Send email
      debugPrint('📧 ========== EMAIL SERVICE START ==========');
      debugPrint('📧 Sending email to: $recipientEmail');
      debugPrint('📧 From: $username');
      debugPrint('📧 Subject: ${message.subject}');
      debugPrint('📧 SMTP Host: $smtpHost:$smtpPort');
      debugPrint('📧 Using TLS: $useTls');
      
      final sendReport = await send(message, smtpServer);
      
      debugPrint('✅ Email sent successfully!');
      debugPrint('📧 Send report: $sendReport');
      debugPrint('📧 ========== EMAIL SERVICE END ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ========== EMAIL ERROR ==========');
      debugPrint('❌ Error sending email: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      
      // Provide more specific error messages
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('535') ||
          e.toString().contains('authentication')) {
        debugPrint('❌ Authentication failed. Check username and password.');
      } else if (e.toString().contains('Connection') || 
                 e.toString().contains('timeout') ||
                 e.toString().contains('SocketException')) {
        debugPrint('❌ Connection error. Check internet and SMTP server.');
      } else if (e.toString().contains('Certificate') ||
                 e.toString().contains('SSL')) {
        debugPrint('❌ SSL/TLS error. Try disabling TLS or check certificate.');
      }
      debugPrint('❌ ========== EMAIL ERROR END ==========');
      return false;
    }
  }

  /// Build HTML email content
  String _buildEmailHtml(String recipientName, Scheme scheme) {
    String documentsList = scheme.requiredDocuments
        .map((doc) => '<li>$doc</li>')
        .join('');

    return '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background-color: #1E88E5; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background-color: #f9f9f9; }
        .scheme-name { font-size: 24px; font-weight: bold; color: #1E88E5; margin: 20px 0; }
        .section { margin: 20px 0; }
        .section-title { font-weight: bold; color: #1E88E5; margin-bottom: 10px; }
        ul { margin: 10px 0; padding-left: 20px; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>YojanaSuchak</h1>
            <p>Your Scheme Details</p>
        </div>
        <div class="content">
            <p>Dear $recipientName,</p>
            <p>Thank you for using YojanaSuchak! Here are the details of the scheme you requested:</p>
            
            <div class="scheme-name">${scheme.schemeName}</div>
            
            <div class="section">
                <div class="section-title">Department:</div>
                <p>${scheme.department}</p>
            </div>
            
            <div class="section">
                <div class="section-title">Target Group:</div>
                <p>${scheme.targetGroup}</p>
            </div>
            
            <div class="section">
                <div class="section-title">Eligibility:</div>
                <p>${scheme.eligibility}</p>
            </div>
            
            <div class="section">
                <div class="section-title">Benefits:</div>
                <p>${scheme.benefits}</p>
            </div>
            
            <div class="section">
                <div class="section-title">Required Documents:</div>
                <ul>
                    $documentsList
                </ul>
            </div>
            
            ${scheme.incomeLimit != null ? '<div class="section"><div class="section-title">Income Limit:</div><p>₹${scheme.incomeLimit!.toStringAsFixed(0)}</p></div>' : ''}
            ${scheme.ageLimit != null ? '<div class="section"><div class="section-title">Age Limit:</div><p>${scheme.ageLimit} years</p></div>' : ''}
            
            <p style="margin-top: 30px;">For more information, please visit the official government website or contact the department directly.</p>
            
            <p>Best regards,<br>YojanaSuchak Team</p>
        </div>
        <div class="footer">
            <p>This is an automated email from YojanaSuchak app.</p>
        </div>
    </div>
</body>
</html>
''';
  }
}



