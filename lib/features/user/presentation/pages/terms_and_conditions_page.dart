import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              '1',
              'Acceptance of Terms',
              'By accessing and using this ${AppConstants.appName} application, you accept and agree to be bound by the terms and conditions of use.',
            ),
            _buildSection(
              context,
              '2',
              'User Responsibilities',
              'Users are responsible for maintaining the confidentiality of their account credentials and for all activities that occur under their account.',
            ),
            _buildSection(
              context,
              '3',
              'Visitor Management',
              'All visitors must be registered through the application. Users are responsible for their visitors\' conduct and compliance with apartment rules.',
            ),
            _buildSection(
              context,
              '4',
              'Payment Terms',
              'Rent and maintenance charges must be paid on time as per the schedule. Late payments may incur penalties as per the apartment policies.',
            ),
            _buildSection(
              context,
              '5',
              'Complaints and Grievances',
              'Complaints should be submitted through the official channels in the application. All complaints will be addressed as per the ${AppConstants.appName} policies.',
            ),
            _buildSection(
              context,
              '6',
              'Privacy Policy',
              'Your personal information will be used only for ${AppConstants.appName} purposes and will not be shared with third parties without your consent.',
            ),
            _buildSection(
              context,
              '7',
              'Code of Conduct',
              'Users must adhere to apartment rules and regulations. Violation of rules may result in warnings or account suspension.',
            ),
            _buildSection(
              context,
              '8',
              'Modifications',
              '${AppConstants.appName} reserves the right to modify these terms and conditions at any time. Users will be notified of significant changes.',
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Last Updated: ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textColor.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String number, String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textColor.withValues(alpha: 0.75),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
