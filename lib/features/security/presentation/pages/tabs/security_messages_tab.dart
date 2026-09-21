import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../chat/presentation/pages/guard_conversations_page.dart';

class SecurityMessagesTab extends StatefulWidget {
  const SecurityMessagesTab({super.key});

  @override
  State<SecurityMessagesTab> createState() => _SecurityMessagesTabState();
}

class _SecurityMessagesTabState extends State<SecurityMessagesTab> {
  bool _loading = true;
  String? _token;
  String _odId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = await ApiService().getToken();
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _odId = authState.user.id;
    }
    setState(() {
      _token = token;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_token == null || _odId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _token == null
                ? 'Please sign in again to use messages.'
                : 'Unable to load user information.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GuardConversationsPage(
      token: _token!,
      odId: _odId,
      userType: 'security',
      embedInParent: true,
    );
  }
}
