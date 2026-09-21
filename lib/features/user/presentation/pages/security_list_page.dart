import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SecurityListPage extends StatefulWidget {
  const SecurityListPage({super.key});

  @override
  State<SecurityListPage> createState() => _SecurityListPageState();
}

class _SecurityListPageState extends State<SecurityListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _securityList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSecurityList();
  }

  Future<void> _loadSecurityList() async {
    final authState = context.read<AuthBloc>().state;
    String? apartmentId;
    if (authState is AuthAuthenticated) {
      apartmentId = authState.selectedApartmentId ?? authState.user.apartmentId;
      if ((apartmentId == null || apartmentId.isEmpty) &&
          authState.user.apartments != null &&
          authState.user.apartments!.isNotEmpty) {
        apartmentId = authState.user.apartments!.first.id;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiService.getSecurityList(apartmentId: apartmentId);
      if (mounted) {
        if (response['success'] == true && response['security'] != null) {
          setState(() {
            _securityList = List<Map<String, dynamic>>.from(
              (response['security'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
            );
            _loading = false;
          });
        } else {
          setState(() {
            _error = response['error'] as String? ?? 'Failed to load security list';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _callSecurity(String mobileNumber) async {
    final uri = Uri.parse('tel:$mobileNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open dialer'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not place call: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadSecurityList,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 56, color: Colors.orange.shade700),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textColor.withValues(alpha: 0.8), fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 160,
                          height: 44,
                          child: BrandGradientCtaButton(
                            height: 44,
                            icon: Icons.refresh_rounded,
                            label: 'Retry',
                            onPressed: _loadSecurityList,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSecurityList,
                  color: AppTheme.primaryColor,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Emergency Banner Tip
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '24/7 Gate & Security Contacts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Tap the phone button to place an immediate call.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_securityList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.security_rounded,
                                  size: 32,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Security Personnel Listed',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Security staff and gate contacts registered for your property will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._securityList.map((s) {
                          final name = s['name'] as String? ?? 'Security Guard';
                          final mobile = s['mobileNumber'] as String? ?? '';
                          final profilePic = s['profilePic'] as String?;
                          final role = s['role'] as String? ?? 'Gate Security';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                    ),
                                    child: ClipOval(
                                      child: profilePic != null && profilePic.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: profilePic,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => const Icon(
                                                Icons.person_rounded,
                                                color: AppTheme.primaryColor,
                                                size: 28,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_rounded,
                                              color: AppTheme.primaryColor,
                                              size: 28,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Active',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF16A34A),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (mobile.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(Icons.phone_outlined, size: 13, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                mobile,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Text(
                                            role,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Call Action Button
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: mobile.isNotEmpty
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFCBD5E1),
                                      shape: BoxShape.circle,
                                      boxShadow: mobile.isNotEmpty
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: mobile.isNotEmpty
                                            ? () => _callSecurity(mobile)
                                            : null,
                                        child: const Center(
                                          child: Icon(
                                            Icons.call_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
