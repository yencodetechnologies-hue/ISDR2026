import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class MyEventTicketsPage extends StatefulWidget {
  const MyEventTicketsPage({super.key});

  @override
  State<MyEventTicketsPage> createState() => _MyEventTicketsPageState();
}

class _MyEventTicketsPageState extends State<MyEventTicketsPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthBloc>().state;
    final mobile = auth is AuthAuthenticated ? auth.user.mobileNumber : null;
    final res = await _api.getMyEventTickets(mobile: mobile);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _tickets = List<Map<String, dynamic>>.from(
          (res['tickets'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ??
              [],
        );
      } else {
        _error = res['error']?.toString() ?? 'Failed to load tickets';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My event tickets')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                : _tickets.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'No event tickets yet.\nOpen an organizer register link to book.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _tickets.length,
                        itemBuilder: (context, index) {
                          final t = _tickets[index];
                          final event = t['event'] as Map?;
                          return ListTile(
                            leading: const Icon(Icons.confirmation_number),
                            title: Text(event?['title']?.toString() ?? 'Event'),
                            subtitle: Text(
                              '${t['ticketCode'] ?? ''} · ${t['status'] ?? ''}',
                            ),
                            trailing: TextButton(
                              onPressed: () => setState(() => _selected = t),
                              child: const Text('QR'),
                            ),
                          );
                        },
                      ),
      ),
      bottomSheet: _selected == null
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (_selected!['event'] as Map?)?['title']?.toString() ?? 'Ticket',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_selected!['ticketCode']?.toString() ?? ''),
                    const SizedBox(height: 12),
                    if (_selected!['qrCode'] != null)
                      QrImageView(
                        data: _selected!['qrCode'].toString(),
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    Text(
                      'Status: ${_selected!['status']}',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selected = null),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
