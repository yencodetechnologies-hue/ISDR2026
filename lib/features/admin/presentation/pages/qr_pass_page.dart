import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/delegate_badge.dart';
import 'my_profile_page.dart';

/// QR Pass for admins, speakers and event staff — the same badge participants
/// get, labelled with the role. Participants keep their own pass (MyProfilePage).
class QrPassPage extends StatelessWidget {
  /// Badge label, e.g. 'ADMIN', 'SPEAKER', 'EVENT STAFF'.
  final String role;

  /// Show a "My Profile & Password" link (admin replaced its Profile tile).
  final bool showProfileLink;

  const QrPassPage({
    super.key,
    required this.role,
    this.showProfileLink = false,
  });

  /// Older pass code from the role and account id, e.g. "ADM3F2A1C" — shown only
  /// until the account's saved pass number (ADM0001, SPK0001, STF0001…) loads.
  static String passCode(String role, String userId) {
    final prefix = switch (role) {
      'ADMIN' => 'ADM',
      'SPEAKER' => 'SPK',
      _ => 'STF',
    };
    final tail = userId.length > 6
        ? userId.substring(userId.length - 6)
        : userId;
    return '$prefix${tail.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final UserModel? user = authState is AuthAuthenticated
        ? authState.user
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'QR Pass',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Not logged in',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : _PassNumber(
              fallback: passCode(role, user.id),
              builder: (code) => _body(context, user, code),
            ),
    );
  }

  Widget _body(BuildContext context, UserModel user, String code) {
    final registration = {
      'name': user.name,
      'title': '',
      'participantType': role,
      'idNumber': code,
      'designation': user.department ?? '',
      'institution': user.apartmentName ?? '',
      'qrCode': code,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DelegateBadge(registration: registration),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    [
                      code,
                      user.mobileNumber,
                    ].where((v) => v.isNotEmpty).join('   •   '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showProfileLink) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProfilePage()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_rounded, size: 20),
              label: const Text(
                'My Profile & Password',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loads the account's saved pass number (ADM0001 / SPK0001 / STF0001…) from
/// GET /auth/me; shows [fallback] until it arrives or if it can't be loaded.
class _PassNumber extends StatefulWidget {
  final String fallback;
  final Widget Function(String code) builder;

  const _PassNumber({required this.fallback, required this.builder});

  @override
  State<_PassNumber> createState() => _PassNumberState();
}

class _PassNumberState extends State<_PassNumber> {
  String? _passNumber;

  @override
  void initState() {
    super.initState();
    ApiService().getCurrentUser().then((res) {
      final n = res['success'] == true && res['user'] is Map
          ? (res['user'] as Map)['passNumber']?.toString() ?? ''
          : '';
      if (mounted && n.isNotEmpty) setState(() => _passNumber = n);
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_passNumber ?? widget.fallback);
}
