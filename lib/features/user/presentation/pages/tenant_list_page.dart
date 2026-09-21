import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/utils/current_property_context.dart';

class TenantListPage extends StatefulWidget {
  const TenantListPage({super.key});

  @override
  State<TenantListPage> createState() => _TenantListPageState();
}

class _TenantListPageState extends State<TenantListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _tenants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final authState = context.read<AuthBloc>().state;
    final apartmentId = authState is AuthAuthenticated
        ? (authState.selectedApartmentId ?? authState.user.apartmentId)
        : null;
    final result = await _apiService.getTenants(apartmentId: apartmentId);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _tenants = List<Map<String, dynamic>>.from(
          result['tenants'] as List<dynamic>? ?? [],
        );
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to load tenants';
      }
    });
  }

  String _genderLabel(String? gender) {
    if (gender == null) return '-';
    switch (gender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return gender;
    }
  }

  String _statusLabel(String? status) {
    if (status == null) return '-';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Future<void> _deleteTenant(Map<String, dynamic> tenant) async {
    final tenantId = tenant['id'] as String?;
    final tenantName = tenant['name'] as String? ?? 'this tenant';

    if (tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid tenant ID')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text(
          'Are you sure you want to delete $tenantName? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await _apiService.deleteUser(tenantId);
      if (!mounted) return;

      if (result['success'] == true) {
        _loadTenants();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tenant deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to delete tenant'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    bool showUserMobile = true;
    if (authState is AuthAuthenticated) {
      final propertyCtx = resolvePropertyContext(
        authState.user,
        selectedApartmentId: authState.selectedApartmentId,
      );
      showUserMobile = propertyCtx.showUserMobile;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tenants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadTenants,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 160,
                          height: 48,
                          child: BrandGradientCtaButton(
                            height: 48,
                            icon: Icons.refresh_rounded,
                            label: 'Retry',
                            onPressed: _loadTenants,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _tenants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tenants yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add tenants from the drawer menu',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTenants,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tenants.length,
                        itemBuilder: (context, index) {
                          final t = _tenants[index];
                          final name = t['name'] as String? ?? '-';
                          final mobile = t['mobileNumber'] as String? ?? '-';
                          final gender = t['gender'] as String?;
                          final profilePic = t['profilePic'] as String?;
                          final status = t['status'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                backgroundImage: profilePic != null && profilePic.isNotEmpty
                                    ? NetworkImage(profilePic)
                                    : null,
                                child: profilePic == null || profilePic.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showUserMobile) Text('Mobile: $mobile'),
                                  Text('Gender: ${_genderLabel(gender)}'),
                                  Text(
                                    'Status: ${_statusLabel(status)}',
                                    style: TextStyle(
                                      color: status == 'approved'
                                          ? AppTheme.secondaryColor
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat),
                                    color: AppTheme.primaryColor,
                                    onPressed: () {
                                      // Navigate to tenant chat
                                      Navigator.pushNamed(
                                        context,
                                        '/tenant-chat',
                                        arguments: {
                                          'tenantId': t['id'],
                                          'tenantName': name,
                                          'tenantProfilePic': profilePic,
                                        },
                                      );
                                    },
                                    tooltip: 'Chat',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () => _deleteTenant(t),
                                    tooltip: 'Delete tenant',
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
