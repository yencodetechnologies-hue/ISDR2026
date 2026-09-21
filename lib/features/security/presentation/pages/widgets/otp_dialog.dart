import 'package:flutter/material.dart';
import '../../../../../../core/app_theme.dart';

class OTPDialog extends StatefulWidget {
  final Function(String) onVerified;

  const OTPDialog({super.key, required this.onVerified});

  @override
  State<OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<OTPDialog> {
  final _otpController = TextEditingController();
  final String _generatedOTP = '123456'; // In real app, generate random OTP

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _handleVerify() {
    if (_otpController.text == _generatedOTP) {
      widget.onVerified(_otpController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('OTP has been sent to the registered user'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'OTP',
              hintText: 'Enter 6-digit OTP',
            ),
            maxLength: 6,
          ),
          const SizedBox(height: 8),
          Text(
            'Demo OTP: $_generatedOTP',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleVerify,
          child: const Text('Verify'),
        ),
      ],
    );
  }
}

