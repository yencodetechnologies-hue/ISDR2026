import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/api_service.dart';
import '../bloc/admin_bloc.dart';

class AccountsListPage extends StatefulWidget {
  const AccountsListPage({super.key});

  @override
  State<AccountsListPage> createState() => _AccountsListPageState();
}

class _AccountsListPageState extends State<AccountsListPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedApartmentFilter;
  List<String> _availableApartmentIds = [];
  Map<String, String> _apartmentIdToName = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadApartments();
  }

  Future<void> _loadApartments() async {
    try {
      final response = await _apiService.getApartments();
      if (response['success'] == true && response['apartments'] != null) {
        final apartments = response['apartments'] as List;
        setState(() {
          _availableApartmentIds = ['all', ...apartments.map((a) => a['_id'] as String).toList()];
          _apartmentIdToName = {
            'all': 'All Apartments',
            for (var apt in apartments)
              apt['_id'] as String: apt['name'] as String,
          };
        });
      }
    } catch (e) {
      // Silently fail - apartments list is optional
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final blocState = context.read<AdminBloc>().state;
      final apartmentId = blocState is AdminLoaded ? blocState.selectedApartmentId : null;
      
      // Use selected apartmentId if available, otherwise use filter
      final filterApartmentId = _selectedApartmentFilter == 'all' || _selectedApartmentFilter == null
          ? apartmentId
          : _selectedApartmentFilter;

      final response = await _apiService.getAllUsers(
        apartmentId: filterApartmentId,
      );

      if (response['success'] == true && response['users'] != null) {
        setState(() {
          _accounts = (response['users'] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['error'] ?? 'Failed to load accounts';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter dropdown
          if (_availableApartmentIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Text(
                    'Filter by Apartment:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedApartmentFilter ?? 'all',
                      isExpanded: true,
                      items: _availableApartmentIds.map((id) {
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(_apartmentIdToName[id] ?? id),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedApartmentFilter = value;
                        });
                        _loadAccounts();
                      },
                    ),
                  ),
                ],
              ),
            ),
          // Accounts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadAccounts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _accounts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No accounts found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _accounts.length,
                            itemBuilder: (context, index) {
                              final account = _accounts[index];
                              return _AccountListItem(
                                account: account,
                                apartmentName: account['apartmentId'] != null
                                    ? _apartmentIdToName[account['apartmentId']]
                                    : null,
                                onTap: () => _showAccountDetails(context, account),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showAccountDetails(BuildContext context, Map<String, dynamic> account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccountDetailsSheet(account: account),
    );
  }
}

class _AccountListItem extends StatelessWidget {
  final Map<String, dynamic> account;
  final String? apartmentName;
  final VoidCallback onTap;

  const _AccountListItem({
    required this.account,
    this.apartmentName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasApartmentId = account['apartmentId'] != null && account['apartmentId'].toString().isNotEmpty;
    final userType = account['userType'] ?? 'user';
    final status = account['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasApartmentId ? AppTheme.secondaryColor.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: hasApartmentId ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: hasApartmentId ? AppTheme.secondaryColor : Colors.orange,
                child: Text(
                  (account['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Account info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account['email'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getUserTypeColor(userType).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            userType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getUserTypeColor(userType),
                            ),
                          ),
                        ),
                        if (hasApartmentId) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              apartmentName ?? 'Apartment Assigned',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.warning,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'No Apartment ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppTheme.secondaryColor;
      case 'pending':
        return AppTheme.accentColor;
      case 'rejected':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  Color _getUserTypeColor(String userType) {
    switch (userType.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'security':
        return Colors.green;
      case 'user':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }
}

class _AccountDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> account;

  const _AccountDetailsSheet({required this.account});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _DetailRow(
                      label: 'Name',
                      value: account['name'] ?? 'N/A',
                    ),
                    _DetailRow(
                      label: 'Email',
                      value: account['email'] ?? 'N/A',
                    ),
                    _DetailRow(
                      label: 'Mobile',
                      value: account['mobileNumber'] ?? 'N/A',
                    ),
                    _DetailRow(
                      label: 'Username',
                      value: account['username'] ?? 'N/A',
                    ),
                    _DetailRow(
                      label: 'User Type',
                      value: (account['userType'] ?? 'user').toUpperCase(),
                    ),
                    _DetailRow(
                      label: 'Status',
                      value: (account['status'] ?? 'pending').toUpperCase(),
                    ),
                    _DetailRow(
                      label: 'Apartment ID',
                      value: account['apartmentId']?.toString() ?? 'NOT ASSIGNED',
                      isWarning: account['apartmentId'] == null,
                    ),
                    if (account['block'] != null)
                      _DetailRow(
                        label: 'Block',
                        value: account['block'],
                      ),
                    if (account['floor'] != null)
                      _DetailRow(
                        label: 'Floor',
                        value: account['floor'],
                      ),
                    if (account['roomNumber'] != null)
                      _DetailRow(
                        label: 'Room Number',
                        value: account['roomNumber'],
                      ),
                    _DetailRow(
                      label: 'Active',
                      value: account['isActive'] == true ? 'Yes' : 'No',
                    ),
                    if (account['createdAt'] != null)
                      _DetailRow(
                        label: 'Created At',
                        value: DateTime.parse(account['createdAt']).toString().split('.')[0],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isWarning ? Colors.orange : Colors.black87,
                fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
