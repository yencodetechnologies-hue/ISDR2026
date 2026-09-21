import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';

class ComingSoonPage extends StatelessWidget {
  final String? featureName;

  const ComingSoonPage({super.key, this.featureName});

  @override
  Widget build(BuildContext context) {
    final name = featureName ?? 'This feature';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: AppTheme.primaryColor.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '$name is under development and will be available soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
