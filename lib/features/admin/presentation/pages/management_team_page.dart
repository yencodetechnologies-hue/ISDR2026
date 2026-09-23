import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/api_service.dart';

class ManagementTeamPage extends StatefulWidget {
  final String? apartmentId;
  final bool hideAppBar;

  const ManagementTeamPage({
    super.key,
    this.apartmentId,
    this.hideAppBar = false,
  });

  @override
  State<ManagementTeamPage> createState() => _ManagementTeamPageState();
}

class _ManagementTeamPageState extends State<ManagementTeamPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _team = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeam();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _apiService.getManagementTeam(
      apartmentId: widget.apartmentId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final list = result['users'] as List<dynamic>? ?? [];
        _team = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _error = result['error'] as String? ?? 'Failed to load management team';
      }
    });
  }

  List<Map<String, dynamic>> get _filteredTeam {
    if (_searchQuery.isEmpty) return _team;
    return _team.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final email = (m['email'] as String? ?? '').toLowerCase();
      final role = (m['roleTitle'] as String? ?? '').toLowerCase();
      final mobile = (m['mobileNumber'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.contains(_searchQuery) ||
          mobile.contains(_searchQuery);
    }).toList();
  }

  Future<void> _removeManagementUser(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Management ID'),
        content: Text(
          'Remove $name as co-management ID? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.errorElevatedStyle,
            child: const Text('Remove ID'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final result = await _apiService.deleteManagementTeamUser(id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      _loadTeam();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Management ID removed'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Failed to remove'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _openAddManagementModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddManagementIdBottomSheet(
        apartmentId: widget.apartmentId,
        onCreated: () {
          _loadTeam();
        },
      ),
    );
  }

  void _openEditManagementModal(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditManagementIdBottomSheet(
        member: member,
        onUpdated: () {
          _loadTeam();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: Text(
                'Management IDs',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _loadTeam,
                ),
              ],
            ),
      body: Column(
        children: [
          // Header & Search Banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Registered IDs (${_team.length})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openAddManagementModal,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Management ID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage registered management accounts. Existing management users can add or manage team IDs.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name, role, or mobile...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadTeam,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredTeam.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No management IDs match your search'
                                        : 'No management IDs registered yet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Click "+ Add Management ID" to grant access to another team member.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadTeam,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredTeam.length,
                              itemBuilder: (context, index) {
                                final m = _filteredTeam[index];
                                final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
                                final isPrimary = id.startsWith('primary_');
                                final name = m['name']?.toString() ?? 'Management Member';
                                final role = m['roleTitle']?.toString() ?? 'Management Member';
                                final mobile = m['mobileNumber']?.toString() ?? '—';
                                final email = m['email']?.toString() ?? '—';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x05000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                role,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E3A8A),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone_outlined,
                                                  size: 14,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  mobile,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (email.isNotEmpty && email != '—') ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.email_outlined,
                                                    size: 14,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      email,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF475569),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!isPrimary) ...[
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _openEditManagementModal(m),
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppTheme.primaryColor,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              child: const Text('Edit'),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _removeManagementUser(id, name),
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFFDC2626),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              child: const Text('Remove ID'),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Primary Owner',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _AddManagementIdBottomSheet extends StatefulWidget {
  final String? apartmentId;
  final VoidCallback onCreated;

  const _AddManagementIdBottomSheet({
    required this.apartmentId,
    required this.onCreated,
  });

  @override
  State<_AddManagementIdBottomSheet> createState() =>
      __AddManagementIdBottomSheetState();
}

class __AddManagementIdBottomSheetState
    extends State<_AddManagementIdBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _saving = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await _apiService.createManagementTeamUser(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      roleTitle: 'Management Member',
      apartmentId: widget.apartmentId,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] as String? ?? 'New management ID added successfully',
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      setState(() => _error = result['error'] as String? ?? 'Failed to add ID');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Add Management ID',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'This new management ID will have full access to manage all operations for this property.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Full Name', 'e.g. Rajesh Kumar', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: _inputDecoration('Login Mobile Phone (10 digits)', '10-digit number for login', Icons.phone_android_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                  if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email Address', 'member@apartment.com', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email address is required';
                  if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecoration(
                  'Set Password',
                  'Set login password',
                  Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create Management ID',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}

class _EditManagementIdBottomSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  final VoidCallback onUpdated;

  const _EditManagementIdBottomSheet({
    required this.member,
    required this.onUpdated,
  });

  @override
  State<_EditManagementIdBottomSheet> createState() =>
      _EditManagementIdBottomSheetState();
}

class _EditManagementIdBottomSheetState
    extends State<_EditManagementIdBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
      text: widget.member['name']?.toString() ?? '');
  late final _mobileController = TextEditingController(
      text: widget.member['mobileNumber']?.toString() ?? '');
  late final _emailController = TextEditingController(
      text: widget.member['email']?.toString() == '—'
          ? ''
          : widget.member['email']?.toString() ?? '');
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _saving = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final id = widget.member['_id']?.toString() ??
        widget.member['id']?.toString() ??
        '';

    setState(() => _saving = true);
    final result = await _apiService.updateManagementTeamUser(
      id: id,
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      roleTitle: widget.member['roleTitle']?.toString(),
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context);
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] as String? ?? 'Management ID updated successfully',
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    } else {
      setState(() => _error = result['error'] as String? ?? 'Failed to update ID');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit Management ID',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Update this management ID\'s details. Leave the password blank to keep it unchanged.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                  ),
                ),
              ],
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Full Name', 'e.g. Rajesh Kumar', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: _inputDecoration('Login Mobile Phone (10 digits)', '10-digit number for login', Icons.phone_android_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                  if (v.trim().length != 10) return 'Enter a valid 10-digit mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email Address', 'member@apartment.com', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email address is required';
                  if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) return 'Enter a valid email address';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecoration(
                  'New Password (optional)',
                  'Leave blank to keep current password',
                  Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}
