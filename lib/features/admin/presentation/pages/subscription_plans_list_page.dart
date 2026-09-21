import 'package:flutter/material.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../core/models/apartment_model.dart';
import '../../../../../core/models/subscription_plan_model.dart';
import '../../../../../core/services/api_service.dart';

class SubscriptionPlansListPage extends StatefulWidget {
  const SubscriptionPlansListPage({super.key});

  @override
  State<SubscriptionPlansListPage> createState() => _SubscriptionPlansListPageState();
}

class _SubscriptionPlansListPageState extends State<SubscriptionPlansListPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<SubscriptionPlanModel> _plans = [];
  List<ApartmentModel> _apartments = [];
  List<Map<String, dynamic>> _apartmentSubscriptions = [];
  bool _loadingPlans = true;
  bool _loadingApartments = true;
  String? _selectedApartmentId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadPlans();
    _loadApartments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    final result = await _apiService.getSubscriptionPlansHistory(
      apartmentId: _selectedApartmentId,
    );
    if (!mounted) return;
    setState(() {
      _loadingPlans = false;
      if (result['success'] == true) {
        final list = result['plans'] as List<dynamic>? ?? [];
        _plans = list
            .map((e) => SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  Future<void> _loadApartments() async {
    setState(() => _loadingApartments = true);
    final result = await _apiService.getApartments();
    if (!mounted) return;
    setState(() {
      _loadingApartments = false;
      if (result['success'] == true) {
        final list = result['apartments'] as List<dynamic>? ?? [];
        _apartments = list
            .map((e) => ApartmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
    _loadApartmentSubscriptions();
  }

  Future<void> _loadApartmentSubscriptions() async {
    _apartmentSubscriptions.clear();
    for (final apt in _apartments) {
      final result = await _apiService.getSubscriptionByApartment(apt.id);
      if (result['success'] == true) {
        final subscriptionStatus = result['subscriptionStatus'] as bool? ?? false;
        final daysLeft = result['daysLeft'] as int? ?? 0;
        final plan = result['plan'];
        if (subscriptionStatus || daysLeft > 0) {
          _apartmentSubscriptions.add({
            'apartment': apt,
            'subscriptionStatus': subscriptionStatus,
            'daysLeft': daysLeft,
            'plan': plan,
            'subscriptionEndsAt': result['subscriptionEndsAt'],
          });
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _deletePlan(SubscriptionPlanModel plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text('Are you sure you want to delete "${plan.name}"? This will set it as inactive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.errorElevatedStyle,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await _apiService.deleteSubscriptionPlan(plan.id);
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan deleted successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
      _loadPlans();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Failed to delete plan'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return Colors.blue.shade100;
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPlans();
              _loadApartmentSubscriptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Apartment Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: DropdownButtonFormField<String>(
              value: _selectedApartmentId,
              decoration: const InputDecoration(
                labelText: 'Filter by Apartment',
                prefixIcon: Icon(Icons.apartment),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Apartments'),
                ),
                ..._apartments.map((apt) => DropdownMenuItem<String>(
                      value: apt.id,
                      child: Text(apt.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedApartmentId = value);
                _loadPlans();
              },
            ),
          ),
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Plan Templates'),
                Tab(text: 'Apartment Subscriptions'),
              ],
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplatesTab(),
                _buildSubscriptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    if (_loadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_membership_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No subscription plans found',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        final color = _parseColor(plan.color);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.card_membership, color: Colors.white),
            ),
            title: Text(
              plan.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${plan.amount.toStringAsFixed(0)} - ${plan.daysValidity} days'),
                if (plan.description.isNotEmpty)
                  Text(plan.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: plan.isActive ? AppTheme.secondaryColor : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deletePlan(plan);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsTab() {
    if (_loadingApartments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_apartmentSubscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No active apartment subscriptions',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _apartmentSubscriptions.length,
      itemBuilder: (context, index) {
        final sub = _apartmentSubscriptions[index];
        final apt = sub['apartment'] as ApartmentModel;
        final status = sub['subscriptionStatus'] as bool;
        final daysLeft = sub['daysLeft'] as int;
        final plan = sub['plan'] as Map<String, dynamic>?;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              child: const Icon(Icons.apartment, color: AppTheme.primaryColor),
            ),
            title: Text(
              apt.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan != null) Text('Plan: ${plan['name'] ?? 'N/A'}'),
                Text('Days Left: $daysLeft'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status ? AppTheme.secondaryColor : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status ? 'Active' : 'Expired',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
