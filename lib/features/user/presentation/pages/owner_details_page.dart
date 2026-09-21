import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class OwnerDetailsPage extends StatelessWidget {
  const OwnerDetailsPage({super.key});

  String _statusLabel(AccountStatus status) {
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Details'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: Text('Not signed in'));
          }

          final owner = state.user.linkedOwner;
          if (owner == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No owner linked',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account is not linked to an owner yet. Please contact your apartment administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final unitParts = <String>[];
          if (owner.block != null && owner.block!.isNotEmpty) {
            unitParts.add('Block ${owner.block}');
          }
          if (owner.floor != null && owner.floor!.isNotEmpty) {
            unitParts.add('Floor ${owner.floor}');
          }
          if (owner.roomNumber != null && owner.roomNumber!.isNotEmpty) {
            unitParts.add('Room ${owner.roomNumber}');
          }
          final unitLabel =
              unitParts.isEmpty ? 'Not assigned' : unitParts.join(' • ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            owner.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _detailRow(
                      icon: Icons.phone_rounded,
                      label: 'Mobile Number',
                      value: owner.mobileNumber,
                    ),
                    if (owner.secondaryMobileNumber != null &&
                        owner.secondaryMobileNumber!.isNotEmpty)
                      _detailRow(
                        icon: Icons.phone_outlined,
                        label: 'Secondary Mobile',
                        value: owner.secondaryMobileNumber!,
                      ),
                    _detailRow(
                      icon: Icons.home_work_rounded,
                      label: 'Unit',
                      value: unitLabel,
                    ),
                    _detailRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Account Status',
                      value: _statusLabel(owner.status),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
