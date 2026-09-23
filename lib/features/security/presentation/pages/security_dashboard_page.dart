import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/logout_confirm_sheet.dart';
import '../../../../core/models/visitor_model.dart';
import '../../../../core/models/visitor_type_config.dart';
import '../../../../core/widgets/visitor_subtype_picker_sheet.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/models/block_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../bloc/security_bloc.dart';
import 'security_visitor_section.dart';
import 'tabs/security_home_tab.dart';
import 'tabs/security_messages_tab.dart';
import 'tabs/security_operations_tab.dart';
import 'tabs/security_visitors_tab.dart';

class SecurityDashboardPage extends StatefulWidget {
  const SecurityDashboardPage({super.key});

  @override
  State<SecurityDashboardPage> createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends State<SecurityDashboardPage>
    with SingleTickerProviderStateMixin {
  static const int _kTabVisitors = 1;

  late TabController _tabController;
  SecurityVisitorSection _activeSection = SecurityVisitorSection.inside;

  late List<String> _tabTitles;
  late List<IconData> _tabIcons;
  bool _isSchoolOrCollege = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final pType = authState.user.propertyType;
      _isSchoolOrCollege = false;
    }

    _tabTitles = [
      'Home',
      if (!_isSchoolOrCollege) 'Visitors',
      if (!_isSchoolOrCollege) 'Operations',
      if (!_isSchoolOrCollege) 'Messages',
    ];

    _tabIcons = [
      Icons.home_rounded,
      if (!_isSchoolOrCollege) Icons.people_alt_rounded,
      if (!_isSchoolOrCollege) Icons.grid_view_rounded,
      if (!_isSchoolOrCollege) Icons.chat_bubble_rounded,
    ];

    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        setState(() {});
        final aState = context.read<AuthBloc>().state;
        final aptId = aState is AuthAuthenticated ? aState.user.apartmentId : null;
        context.read<SecurityBloc>().add(LoadSecurityDataEvent(apartmentId: aptId));
      }
    });

    final apartmentId = authState is AuthAuthenticated ? authState.user.apartmentId : null;
    context.read<SecurityBloc>().add(LoadSecurityDataEvent(apartmentId: apartmentId));
    context.read<NotificationBloc>().add(const LoadUnreadCount());

    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      final apartmentId = authState is AuthAuthenticated ? authState.user.apartmentId : null;
      context.read<SecurityBloc>().add(LoadSecurityDataEvent(apartmentId: apartmentId));
      context.read<NotificationBloc>().add(const LoadUnreadCount());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshSecurity() async {
    final authState = context.read<AuthBloc>().state;
    final apartmentId = authState is AuthAuthenticated ? authState.user.apartmentId : null;
    context.read<SecurityBloc>().add(LoadSecurityDataEvent(apartmentId: apartmentId));
    context.read<NotificationBloc>().add(const LoadUnreadCount());
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ),
        leadingWidth: 52,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gate Security',
              style: GoogleFonts.outfit(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _tabTitles[_tabController.index],
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.brandHeaderGradient,
          ),
        ),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              int unreadCount = 0;
              if (state is NotificationLoaded) {
                unreadCount = state.unreadCount;
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.read<NotificationBloc>().add(const LoadUnreadCount());
                });
              }
              return Stack(
                children: [
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/notification.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.notifications);
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              LogoutConfirmSheet.showLogoutConfirmSheet(context, onLogout: () {
                context.read<AuthBloc>().add(LogoutEvent());
                AppNavigation.resetTo(context, AppRoutes.userTypeSelection);
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: _isSchoolOrCollege
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: List.generate(_tabTitles.length, (index) {
                      final isSelected = _tabController.index == index;
                      return Expanded(
                        flex: isSelected ? 32 : 18,
                        child: InkWell(
                          onTap: () {
                            setState(() => _tabController.animateTo(index));
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF13275D)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF13275D).withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _tabIcons[index],
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                                if (isSelected)
                                  Expanded(
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 250),
                                      opacity: isSelected ? 1.0 : 0.0,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _tabTitles[index],
                                            maxLines: 1,
                                            softWrap: false,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
      body: BlocConsumer<SecurityBloc, SecurityState>(
        listener: (context, state) {
          if (state is SecurityLoaded && state.lastAddVisitorError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.lastAddVisitorError!),
                backgroundColor: AppTheme.accentColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<SecurityBloc>().add(ClearSecurityErrorEvent());
          }
          if (state is SecurityLoaded && state.pendingVisitorsSection != null) {
            if (!context.mounted) return;
            setState(() => _activeSection = state.pendingVisitorsSection!);
            if (!_isSchoolOrCollege && _tabController.index != _kTabVisitors) {
              _tabController.animateTo(_kTabVisitors);
            } else if (_isSchoolOrCollege) {
              _openVisitorsPage(context, state);
            }
            context.read<SecurityBloc>().add(ClearPendingVisitorsSectionEvent());
          }
        },
        builder: (context, state) {
          if (state is SecurityLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                SecurityHomeTab(
                  state: state,
                  onRefresh: _refreshSecurity,
                  onAddVisitor: () => _showAddVisitorSheet(context, state.blocks),
                  onBulkVisit: () => _showBulkVisitSheet(context, state.blocks),
                  onVerify: ([otp]) => _showVerifyVisitorSheet(context, state.visitors, initialOtp: otp),
                  onScanQr: () => _showScanVehicleQRSheet(context),
                  tabController: _tabController,
                  visitorsTabIndex: _isSchoolOrCollege ? 0 : _kTabVisitors,
                  activeSection: _activeSection,
                  onSelectSection: (s) => setState(() => _activeSection = s),
                  onUpcomingSheet: () => _showUpcomingVisitorsSheet(context, state.visitors),
                  onOpenVisitors: _isSchoolOrCollege ? () => _openVisitorsPage(context, state) : null,
                ),
                if (!_isSchoolOrCollege)
                  SecurityVisitorsTab(
                    state: state,
                    activeSection: _activeSection,
                    onSectionChanged: (s) => setState(() => _activeSection = s),
                    onRefresh: _refreshSecurity,
                  ),
                if (!_isSchoolOrCollege)
                  SecurityOperationsTab(
                    state: state,
                    tabController: _tabController,
                    visitorsTabIndex: _kTabVisitors,
                    activeSection: _activeSection,
                    isSchoolOrCollege: _isSchoolOrCollege,
                    onSelectSection: (s) => setState(() => _activeSection = s),
                    onAddVisitor: () => _showAddVisitorSheet(context, state.blocks),
                    onBulkVisit: () => _showBulkVisitSheet(context, state.blocks),
                    onVerify: () => _showVerifyVisitorSheet(context, state.visitors),
                    onScanQr: () => _showScanVehicleQRSheet(context),
                    onUpcomingSheet: () => _showUpcomingVisitorsSheet(context, state.visitors),
                  ),
                if (!_isSchoolOrCollege)
                  const SecurityMessagesTab(),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void _openVisitorsPage(BuildContext context, SecurityLoaded state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pageContext) => StatefulBuilder(
          builder: (context, setPageState) {
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                elevation: 0,
                title: Text(
                  'Visitors Log',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandHeaderGradient,
                  ),
                ),
              ),
              body: BlocBuilder<SecurityBloc, SecurityState>(
                builder: (context, currentSecurityState) {
                  final activeState = currentSecurityState is SecurityLoaded
                      ? currentSecurityState
                      : state;
                  return SecurityVisitorsTab(
                    state: activeState,
                    activeSection: _activeSection,
                    onSectionChanged: (s) {
                      setState(() => _activeSection = s);
                      setPageState(() {});
                    },
                    onRefresh: _refreshSecurity,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddVisitorSheet(BuildContext context, List<BlockModel> blocks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) => _AddVisitorSheet(
          blocks: blocks,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showBulkVisitSheet(BuildContext context, List<BlockModel> blocks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) => _BulkVisitSheet(
          blocks: blocks,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showUpcomingVisitorsSheet(BuildContext context, List<VisitorModel> visitors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => _UpcomingVisitorsSheet(
          visitors: visitors.where((v) => v.visitTime.isAfter(DateTime.now())).toList(),
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showScanVehicleQRSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ScanVehicleQRSheet(),
    );
  }

  void _showVerifyVisitorSheet(BuildContext context, List<VisitorModel> visitors, {String? initialOtp}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => _VerifyVisitorSheet(
          visitors: visitors,
          scrollController: scrollController,
          initialOtp: initialOtp,
        ),
      ),
    );
  }

}

// ————— Bottom sheet: Upcoming Visitors with date picker —————
class _UpcomingVisitorsSheet extends StatefulWidget {
  final List<VisitorModel> visitors;
  final ScrollController scrollController;

  const _UpcomingVisitorsSheet({required this.visitors, required this.scrollController});

  @override
  State<_UpcomingVisitorsSheet> createState() => _UpcomingVisitorsSheetState();
}

class _UpcomingVisitorsSheetState extends State<_UpcomingVisitorsSheet> {
  DateTime _selectedDate = DateTime.now();

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<VisitorModel> get _forDate => widget.visitors.where((v) => _isSameDay(v.visitTime, _selectedDate)).toList();

  @override
  Widget build(BuildContext context) {
    final forDate = _forDate;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming Visitors', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor)),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: AppTheme.textColor.withOpacity(0.7)), style: IconButton.styleFrom(backgroundColor: AppTheme.dividerColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primaryColor.withOpacity(0.12), AppTheme.secondaryColor.withOpacity(0.06)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select date', style: TextStyle(fontSize: 12, color: AppTheme.textColor.withOpacity(0.6), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('${_selectedDate.day} / ${_selectedDate.month} / ${_selectedDate.year}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textColor)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textColor.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('${forDate.length} visitor${forDate.length == 1 ? "" : "s"} on this date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: forDate.isEmpty
                ? Center(child: Text('No visitors on selected date', style: TextStyle(fontSize: 13, color: AppTheme.textColor.withOpacity(0.5))))
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: forDate.length,
                    itemBuilder: (context, index) {
                      final v = forDate[index];
                      final vt = v.visitTime.toLocal();
                      final timeStr = '${vt.hour.toString().padLeft(2, '0')}:${vt.minute.toString().padLeft(2, '0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.dividerColor.withOpacity(0.8)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: v.image != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(v.image!, fit: BoxFit.cover))
                                  : Icon(Icons.person_rounded, color: AppTheme.primaryColor.withOpacity(0.8), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(v.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${v.typeLabelLine}${v.block.trim().isNotEmpty && v.block != '—' ? ' • Block ${v.block}${v.homeNumber.trim().isNotEmpty ? '-${v.homeNumber}' : ''}' : ''}',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textColor.withOpacity(0.65)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(timeStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor.withOpacity(0.9))),
                                if (v.approvalStatus == VisitorApprovalStatus.pending)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                      child: Text('PENDING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accentColor)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ————— Bottom sheet: Verify Visitor (OTP or Scan QR) —————
class _VerifyVisitorSheet extends StatefulWidget {
  final List<VisitorModel> visitors;
  final ScrollController scrollController;
  final String? initialOtp;

  const _VerifyVisitorSheet({
    required this.visitors,
    required this.scrollController,
    this.initialOtp,
  });

  @override
  State<_VerifyVisitorSheet> createState() => _VerifyVisitorSheetState();
}

class _VerifyVisitorSheetState extends State<_VerifyVisitorSheet> {
  final _otpController = TextEditingController();
  String? _message;
  bool _success = false;
  bool _verifying = false;
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  bool _scannerLoading = true;
  bool _scannerPermissionGranted = false;
  bool _scannerPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOtp != null && widget.initialOtp!.isNotEmpty) {
      _otpController.text = widget.initialOtp!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyOtp();
      });
    }
  }

  /// Opens scanner UI and initializes camera for QR-only scanning.
  Future<void> _openScanner() async {
    setState(() {
      _showScanner = true;
      _message = null;
      _scannerLoading = true;
      _scannerPermissionGranted = false;
      _scannerPermanentlyDenied = false;
    });
    await _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    if (!mounted) return;
    try {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Camera permission required'),
            content: const Text(
              'Camera access is needed to scan visitor QR codes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (shouldRequest != true) {
          status = await Permission.camera.status;
          if (mounted) {
            setState(() {
              _scannerLoading = false;
              _scannerPermissionGranted = false;
              _scannerPermanentlyDenied = status.isPermanentlyDenied;
            });
          }
          return;
        }
        // On iOS, request after a short delay so the system permission dialog can show reliably
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
        }
        status = await Permission.camera.request();
      }
      if (!mounted) return;
      if (status.isGranted) {
        _scannerController = MobileScannerController(
          formats: [BarcodeFormat.qrCode],
        );
        setState(() {
          _scannerLoading = false;
          _scannerPermissionGranted = true;
          _scannerPermanentlyDenied = false;
        });
      } else {
        setState(() {
          _scannerLoading = false;
          _scannerPermissionGranted = false;
          _scannerPermanentlyDenied = status.isPermanentlyDenied;
        });
        if (status.isPermanentlyDenied && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permission required'),
              content: const Text(
                'Please enable camera access in app settings to scan QR codes.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open settings'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scannerLoading = false;
          _scannerPermissionGranted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    // On iOS, delay request so the system permission dialog appears correctly
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _scannerPermissionGranted = status.isGranted;
      _scannerPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (status.isGranted && _scannerController == null) {
      _scannerController = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
      );
    } else if (status.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'Please enable camera access in app settings to scan QR codes.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    }
  }

  void _closeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() {
      _showScanner = false;
      _scannerLoading = true;
      _scannerPermissionGranted = false;
      _scannerPermanentlyDenied = false;
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _scannerController = null;
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() { _message = 'Enter 6-digit OTP'; _success = false; });
      return;
    }
    if (_verifying) return;
    setState(() { _verifying = true; _message = null; });
    final result = await ApiService().verifyVisitorByOtp(otp);
    if (!mounted) return;
    setState(() { _verifying = false; });
    if (result['success'] == true && result['visitor'] != null) {
      final visitor = Map<String, dynamic>.from(result['visitor'] as Map);
      final name = visitor['name'] as String? ?? 'Visitor';
      final visitorId = visitor['id']?.toString();
      final visitMode = visitor['visitMode']?.toString();

      if (visitorId != null && visitorId.isNotEmpty) {
        final entryResult = await ApiService().markVisitorEntry(visitorId, entryMethod: 'otp');
        if (!mounted) return;
        if (entryResult['success'] == true) {
          context.read<SecurityBloc>().add(const LoadSecurityDataEvent());
          final msg = visitMode == 'monthlyPass' 
              ? 'Monthly Access: $name - Entry recorded' 
              : 'Entry recorded: $name';
          setState(() { _message = msg; _success = true; });
        } else {
          setState(() {
            _message = entryResult['error'] as String? ?? 'Failed to record entry';
            _success = false;
          });
          return;
        }
      } else {
        context.read<SecurityBloc>().add(const LoadSecurityDataEvent());
        setState(() { _message = 'Entry recorded: $name'; _success = true; });
      }
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() {
        _message = result['error'] as String? ?? 'Verification failed';
        _success = false;
      });
    }
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_message != null || _verifying) return;
    final list = capture.barcodes;
    if (list.isEmpty) return;
    final code = list.first.rawValue;
    if (code == null || code.isEmpty) return;
    try {
      final map = jsonDecode(code) as Map<String, dynamic>;
      final type = map['type']?.toString();
      final api = ApiService();

      setState(() { _verifying = true; _message = null; });

      Map<String, dynamic> result;
      if (type == 'event_ticket') {
        result = await api.verifyEventTicketQr(
          registrationId: map['registrationId']?.toString(),
          otp: map['otp']?.toString(),
          idNumber: map['idNumber']?.toString(),
        );
      } else if (type == 'hostel_leave') {
        result = await api.verifyLeaveByQr(
          leaveId: map['leaveId']?.toString(),
          otp: map['otp']?.toString(),
          payload: code,
        );
      } else if (type == 'hostel_resident') {
        result = await api.verifyHostelQr(
          userId: map['userId']?.toString(),
          otp: map['otp']?.toString(),
          payload: code,
        );
      } else if (type == 'staff_entry') {
        // Staff daily entry QR — send full payload to verify-by-qr endpoint
        result = await api.verifyStaffByQr(map);
      } else {
        final visitorId = map['visitorId']?.toString();
        final otp = map['otp']?.toString();
        if (visitorId == null || visitorId.isEmpty || otp == null || otp.isEmpty) {
          setState(() { _verifying = false; _message = 'Invalid QR code'; _success = false; });
          return;
        }
        result = await api.verifyVisitorByQr(visitorId, otp);
      }

      if (!mounted) return;
      _scannerController?.dispose();
      _scannerController = null;
      setState(() { _verifying = false; _showScanner = false; });

      if (result['success'] == true) {
        if (type == 'event_ticket') {
          final reg = Map<String, dynamic>.from(
            (result['registration'] as Map?) ?? {},
          );
          final name = reg['name'] as String? ?? 'Guest';
          final eventTitle = (reg['event'] as Map?)?['title']?.toString() ?? 'Event';
          final already = result['alreadyCheckedIn'] == true;
          setState(() {
            _message = already
                ? 'Already checked in: $name\n$eventTitle'
                : 'Entry allowed: $name\n$eventTitle';
            _success = true;
          });
        } else if (type == 'hostel_leave') {
          final resident = Map<String, dynamic>.from(
            (result['resident'] as Map?) ?? {},
          );
          final name = resident['name'] as String? ?? 'Resident';
          final room = resident['hostelRoom'] as String? ?? '';
          final bed = resident['hostelBed'] as String? ?? '';
          final loc = [if (room.isNotEmpty) 'Room $room', if (bed.isNotEmpty) 'Bed $bed'].join(' • ');
          setState(() {
            _message = loc.isEmpty
                ? 'Leave pass OK: $name'
                : 'Leave pass OK: $name ($loc)';
            _success = true;
          });
        } else if (type == 'hostel_resident') {
          final resident = Map<String, dynamic>.from(
            (result['resident'] as Map?) ?? {},
          );
          final name = resident['name'] as String? ?? 'Resident';
          final room = resident['hostelRoom'] as String? ?? '';
          final bed = resident['hostelBed'] as String? ?? '';
          final hostel = result['hostelName'] as String? ?? '';
          final loc = [if (room.isNotEmpty) 'Room $room', if (bed.isNotEmpty) 'Bed $bed'].join(' • ');
          setState(() {
            _message = [
              'Hostel ID OK: $name',
              if (hostel.isNotEmpty) hostel,
              if (loc.isNotEmpty) loc,
            ].join('\n');
            _success = true;
          });
        } else if (type == 'staff_entry') {
          final user = Map<String, dynamic>.from(
            (result['user'] as Map?) ?? {},
          );
          final staffName = user['name'] as String? ?? map['name'] as String? ?? 'Staff';
          context.read<SecurityBloc>().add(const LoadSecurityDataEvent());
          setState(() {
            _message = 'Staff entry logged: $staffName';
            _success = true;
          });
        } else if (result['visitor'] != null) {
          final visitor = Map<String, dynamic>.from(result['visitor'] as Map);
          final name = visitor['name'] as String? ?? 'Visitor';
          final msg = result['message'] as String? ?? 'Visitor QR processed: $name';
          context.read<SecurityBloc>().add(const LoadSecurityDataEvent());
          setState(() { _message = msg; _success = true; });
        } else {
          setState(() { _message = 'Verified'; _success = true; });
        }
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _message = result['error'] as String? ?? 'Verification failed';
          _success = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _verifying = false; _message = 'Invalid QR code'; _success = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scan QR code',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_scannerController != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _scannerController!.torchEnabled
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _scannerController?.toggleTorch(),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _closeScanner,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _scannerLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : _scannerPermissionGranted &&
                                  _scannerController != null
                              ? MobileScanner(
                                  controller: _scannerController,
                                  onDetect: _onQrDetected,
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _scannerPermissionGranted
                                              ? 'Camera could not start'
                                              : 'Camera access is required to scan visitor QR codes.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton(
                                          onPressed: _requestCameraPermission,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                const Color(0xFF0F172A),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Grant Camera Permission',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (_scannerPermanentlyDenied) ...[
                                          const SizedBox(height: 12),
                                          TextButton(
                                            onPressed: openAppSettings,
                                            child: Text(
                                              'Open App Settings',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                    ),
                    if (_verifying)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Verifying QR Code...',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _message!,
                  style: GoogleFonts.outfit(
                    color: _success
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Navy Header banner
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13275D), Color(0xFF1D3576)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13275D).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Visitor',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Scan QR code or enter 6-digit OTP',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scan QR card
                  InkWell(
                    onTap: _openScanner,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scan QR code',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Visitor, hostel ID, or leave pass',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR VERIFY WITH OTP',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_verifying,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      labelText: '6-Digit OTP',
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                      hintText: 'Enter OTP',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0,
                      ),
                      prefixIcon: const Icon(Icons.lock_rounded,
                          color: Color(0xFF13275D), size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFF13275D), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: GoogleFonts.outfit(
                          color: _success
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  BrandGradientCtaButton(
                    onPressed: _verifying ? null : _verifyOtp,
                    icon: _verifying
                        ? Icons.sync_rounded
                        : Icons.verified_user_rounded,
                    label: _verifying ? 'Verifying OTP...' : 'Verify OTP',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ————— Bottom sheet: Scan Vehicle QR —————
class _ScanVehicleQRSheet extends StatefulWidget {
  const _ScanVehicleQRSheet();

  @override
  State<_ScanVehicleQRSheet> createState() => _ScanVehicleQRSheetState();
}

class _ScanVehicleQRSheetState extends State<_ScanVehicleQRSheet> {
  String? _message;
  bool _success = false;
  bool _showScanner = true;
  bool _verifying = false;
  MobileScannerController? _scannerController;
  bool _scannerLoading = true;
  bool _scannerPermissionGranted = false;
  bool _scannerPermanentlyDenied = false;
  Map<String, dynamic>? _verifiedData;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    if (!mounted) return;
    try {
      var status = await Permission.camera.status;
      if (status.isDenied) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Camera permission required'),
            content: const Text(
              'Camera access is needed to scan vehicle QR codes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (shouldRequest != true) {
          status = await Permission.camera.status;
          if (mounted) {
            setState(() {
              _scannerLoading = false;
              _scannerPermissionGranted = false;
              _scannerPermanentlyDenied = status.isPermanentlyDenied;
            });
          }
          return;
        }
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
        }
        status = await Permission.camera.request();
      }
      if (!mounted) return;
      if (status.isGranted) {
        _scannerController = MobileScannerController(
          formats: [BarcodeFormat.qrCode],
        );
        setState(() {
          _scannerLoading = false;
          _scannerPermissionGranted = true;
          _scannerPermanentlyDenied = false;
        });
      } else {
        setState(() {
          _scannerLoading = false;
          _scannerPermissionGranted = false;
          _scannerPermanentlyDenied = status.isPermanentlyDenied;
        });
        if (status.isPermanentlyDenied && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permission required'),
              content: const Text(
                'Please enable camera access in app settings to scan vehicle QR codes.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open settings'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scannerLoading = false;
          _scannerPermissionGranted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _scannerPermissionGranted = status.isGranted;
      _scannerPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (status.isGranted && _scannerController == null) {
      _scannerController = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
      );
    } else if (status.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'Please enable camera access in app settings to scan vehicle QR codes.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    }
  }

  void _closeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Failures can land on a fallback view that doesn't render `_message`
  /// (e.g. once the scanner UI has already been dismissed), so also surface
  /// the error as a SnackBar to guarantee the guard always sees it.
  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// On any scan failure (e.g. an already-used QR), close this sheet
  /// entirely instead of leaving it on a confusing idle "scan again" card,
  /// and surface the reason via a SnackBar on the page underneath.
  void _failAndClose(String message) {
    _scannerController?.dispose();
    _scannerController = null;
    _showErrorSnack(message);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_verifying || _verifiedData != null) return;
    final list = capture.barcodes;
    if (list.isEmpty) return;
    final code = list.first.rawValue;
    if (code == null || code.isEmpty) return;
    try {
      final map = jsonDecode(code) as Map<String, dynamic>;
      final type = map['type']?.toString();
      final apiService = ApiService();

      // ── Staff entry QR ──
      if (type == 'staff_entry') {
        setState(() => _verifying = true);
        final result = await apiService.verifyStaffByQr(map);
        if (!mounted) return;
        _scannerController?.dispose();
        _scannerController = null;
        setState(() {
          _verifying = false;
          _showScanner = false;
        });
        if (result['success'] == true) {
          final user = Map<String, dynamic>.from(
            (result['user'] as Map?) ?? {},
          );
          final staffName = user['name'] as String? ?? map['name'] as String? ?? 'Staff';
          final msg = result['message'] as String? ?? (result['entryType'] == 'staff_exit' ? 'Staff exit logged: $staffName' : 'Staff entry logged: $staffName');
          setState(() {
            _verifiedData = result;
            _message = msg;
            _success = true;
          });
          context.read<SecurityBloc>().add(const LoadSecurityDataEvent());
        } else {
          _failAndClose(result['error'] as String? ?? 'Staff verification failed');
        }
        return;
      }

      // ── Visitor QR ──
      if (type == 'visitor' || (map['visitorId'] != null && map['otp'] != null && type == null)) {
        final visitorId = map['visitorId']?.toString();
        final otp = map['otp']?.toString();
        if (visitorId == null || visitorId.isEmpty || otp == null || otp.isEmpty) {
          _failAndClose('Invalid visitor QR');
          return;
        }
        setState(() => _verifying = true);
        final result = await apiService.verifyVisitorByQr(visitorId, otp);
        if (!mounted) return;
        _scannerController?.dispose();
        _scannerController = null;
        setState(() { _verifying = false; _showScanner = false; });
        if (result['success'] == true && result['visitor'] != null) {
          final visitor = Map<String, dynamic>.from(result['visitor'] as Map);
          final name = visitor['name'] as String? ?? 'Visitor';
          final vId = visitor['id']?.toString();
          if (vId != null && vId.isNotEmpty) {
            await apiService.markVisitorEntry(vId, entryMethod: 'qr');
          }
          if (!mounted) return;
          setState(() {
            _verifiedData = result;
            _message = 'Entry recorded: $name';
            _success = true;
          });
        } else {
          _failAndClose(result['error'] as String? ?? 'Verification failed');
        }
        return;
      }

      // ── Hostel resident QR ──
      if (type == 'hostel_resident') {
        setState(() => _verifying = true);
        final result = await apiService.verifyHostelQr(
          userId: map['userId']?.toString(),
          otp: map['otp']?.toString(),
          payload: code,
        );
        if (!mounted) return;
        _scannerController?.dispose();
        _scannerController = null;
        setState(() { _verifying = false; _showScanner = false; });
        if (result['success'] == true) {
          final resident = Map<String, dynamic>.from(
            (result['resident'] as Map?) ?? {},
          );
          final name = resident['name'] as String? ?? 'Resident';
          setState(() {
            _verifiedData = result;
            _message = 'Hostel ID OK: $name';
            _success = true;
          });
        } else {
          _failAndClose(result['error'] as String? ?? 'Verification failed');
        }
        return;
      }

      // ── Hostel leave QR ──
      if (type == 'hostel_leave') {
        setState(() => _verifying = true);
        final result = await apiService.verifyLeaveByQr(
          leaveId: map['leaveId']?.toString(),
          otp: map['otp']?.toString(),
          payload: code,
        );
        if (!mounted) return;
        _scannerController?.dispose();
        _scannerController = null;
        setState(() { _verifying = false; _showScanner = false; });
        if (result['success'] == true) {
          final resident = Map<String, dynamic>.from(
            (result['resident'] as Map?) ?? {},
          );
          final name = resident['name'] as String? ?? 'Resident';
          setState(() {
            _verifiedData = result;
            _message = 'Leave pass OK: $name';
            _success = true;
          });
        } else {
          _failAndClose(result['error'] as String? ?? 'Verification failed');
        }
        return;
      }

      // ── Event ticket QR ──
      if (type == 'event_ticket') {
        setState(() => _verifying = true);
        final result = await apiService.verifyEventTicketQr(
          registrationId: map['registrationId']?.toString(),
          otp: map['otp']?.toString(),
          idNumber: map['idNumber']?.toString(),
        );
        if (!mounted) return;
        _scannerController?.dispose();
        _scannerController = null;
        setState(() { _verifying = false; _showScanner = false; });
        if (result['success'] == true) {
          final reg = Map<String, dynamic>.from(
            (result['registration'] as Map?) ?? {},
          );
          final name = reg['name'] as String? ?? 'Guest';
          setState(() {
            _verifiedData = result;
            _message = 'Event entry: $name';
            _success = true;
          });
        } else {
          _failAndClose(result['error'] as String? ?? 'Verification failed');
        }
        return;
      }

      // ── Vehicle QR (original behaviour) ──
      final vehicleId = map['vehicleId'] as String?;
      if (vehicleId == null || vehicleId.isEmpty) {
        _failAndClose('Not a valid QR code');
        return;
      }
      setState(() => _verifying = true);
      final result = await apiService.verifyVehicle(vehicleId);
      if (!mounted) return;
      setState(() => _verifying = false);
      if (result['success'] == true && result['vehicle'] != null && result['user'] != null) {
        _scannerController?.dispose();
        _scannerController = null;
        setState(() {
          _verifiedData = result;
          _message = 'Verified successfully';
          _success = true;
          _showScanner = false;
        });
      } else {
        _failAndClose(result['error'] as String? ?? 'Not a valid vehicle');
      }
    } catch (_) {
      if (mounted) {
        _failAndClose('Not a valid QR code');
      }
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _scannerController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan vehicle QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_scannerController != null)
                        IconButton(
                          icon: Icon(
                            _scannerController!.torchEnabled
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: Colors.white,
                          ),
                          onPressed: () => _scannerController?.toggleTorch(),
                        ),
                      IconButton(
                        onPressed: _closeScanner,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _scannerLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _scannerPermissionGranted && _scannerController != null
                        ? MobileScanner(
                            controller: _scannerController,
                            onDetect: _onQrDetected,
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _scannerPermissionGranted
                                        ? 'Camera could not start'
                                        : 'Camera access is required to scan vehicle QR codes.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _requestCameraPermission,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Grant camera permission'),
                                  ),
                                  if (_scannerPermanentlyDenied) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: openAppSettings,
                                      child: const Text(
                                        'Open settings',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
              ),
            ),
            if (_verifying)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Verifying...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            else if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _success
                        ? AppTheme.secondaryColor
                        : AppTheme.errorColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      );
    }
    if (_verifiedData != null) {
      final user = _verifiedData!['user'] as Map<String, dynamic>? ?? {};
      final vehicle = _verifiedData!['vehicle'] as Map<String, dynamic>? ?? {};
      final visitor = _verifiedData!['visitor'] as Map<String, dynamic>? ?? {};
      final resident = _verifiedData!['resident'] as Map<String, dynamic>? ?? {};
      final registration = _verifiedData!['registration'] as Map<String, dynamic>? ?? {};

      final userName = (user['name'] as String?)?.trim().isNotEmpty == true
          ? user['name'] as String
          : (visitor['name'] as String?)?.trim().isNotEmpty == true
              ? visitor['name'] as String
              : (resident['name'] as String?)?.trim().isNotEmpty == true
                  ? resident['name'] as String
                  : (registration['name'] as String?)?.trim().isNotEmpty == true
                      ? registration['name'] as String
                      : '—';

      final blockRaw = (user['block'] as String?)?.trim().isNotEmpty == true
          ? user['block'] as String
          : (visitor['block'] as String?)?.trim().isNotEmpty == true
              ? visitor['block'] as String
              : (resident['block'] as String?)?.trim().isNotEmpty == true
                  ? resident['block'] as String
                  : '—';

      final roomRaw = (user['roomNumber'] as String?)?.trim().isNotEmpty == true
          ? user['roomNumber'] as String
          : (user['hostelRoom'] as String?)?.trim().isNotEmpty == true
              ? user['hostelRoom'] as String
              : (visitor['homeNumber'] as String?)?.trim().isNotEmpty == true
                  ? visitor['homeNumber'] as String
                  : (visitor['roomNumber'] as String?)?.trim().isNotEmpty == true
                      ? visitor['roomNumber'] as String
                      : (resident['hostelRoom'] as String?)?.trim().isNotEmpty == true
                          ? resident['hostelRoom'] as String
                          : (resident['roomNumber'] as String?)?.trim().isNotEmpty == true
                              ? resident['roomNumber'] as String
                              : '—';

      final floor = user['floor'] as String? ?? visitor['floor'] as String?;

      final visitorCat = (visitor['category'] as String? ?? visitor['type'] as String? ?? '').toLowerCase();
      final userType = (user['userType'] as String? ?? '').toLowerCase();

      final roleLabel = visitorCat == 'staff' || userType == 'staff'
          ? 'Staff'
          : (visitorCat.isNotEmpty && visitorCat != 'user') || visitor.isNotEmpty
              ? 'Visitor / Guest'
              : userType == 'tenant'
                  ? 'Tenant'
                  : 'Resident';

      final titleText = visitor.isNotEmpty
          ? 'Visitor Verified'
          : resident.isNotEmpty
              ? 'Resident Verified'
              : vehicle.isNotEmpty
                  ? 'Vehicle Verified'
                  : 'Verification Successful';

      final unitDisplay = (blockRaw != '—' || roomRaw != '—')
          ? [
              if (blockRaw != '—') 'Block $blockRaw',
              if (floor != null && floor.toString().trim().isNotEmpty) 'Floor $floor',
              if (roomRaw != '—') 'Room $roomRaw',
            ].join(', ')
          : '—';

      final vehicleNumber = vehicle['vehicleNumber'] as String? ?? visitor['vehicleNumber'] as String? ?? '—';
      final vehicleType = vehicle['vehicleType'] as String? ?? 'other';
      final typeLabel = vehicleType == 'twoWheeler'
          ? 'Two wheeler'
          : vehicleType == 'fourWheeler'
              ? 'Four wheeler'
              : 'Other';

      final userEmail = (visitor['email'] as String?)?.trim().isNotEmpty == true
          ? visitor['email'] as String
          : (user['email'] as String?)?.trim().isNotEmpty == true
              ? user['email'] as String
              : '—';
      final reason = (visitor['reasonForVisit'] as String?)?.trim().isNotEmpty == true
          ? visitor['reasonForVisit'] as String
          : (visitor['purpose'] as String?)?.trim().isNotEmpty == true
              ? visitor['purpose'] as String
              : '—';

      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppTheme.secondaryColor, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            titleText,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: AppTheme.textColor.withOpacity(0.7),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.dividerColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.secondaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(Icons.person, 'Name', userName),
                        _buildDetailRow(
                          Icons.badge,
                          'Role',
                          roleLabel,
                        ),
                        if (userEmail != '—')
                          _buildDetailRow(
                            Icons.email,
                            'Email ID',
                            userEmail,
                          ),
                        if (reason != '—')
                          _buildDetailRow(
                            Icons.assignment,
                            'Purpose',
                            reason,
                          ),
                        if (vehicleNumber != '—')
                          _buildDetailRow(
                            Icons.directions_car,
                            'Vehicle',
                            '$vehicleNumber ($typeLabel)',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scan Vehicle QR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.textColor.withOpacity(0.7),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.dividerColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showScanner = true;
                      _message = null;
                      _verifiedData = null;
                      _scannerLoading = true;
                      _scannerPermissionGranted = false;
                      _scannerPermanentlyDenied = false;
                    });
                    _initializeScanner();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.1),
                          AppTheme.secondaryColor.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Scan QR code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Open camera to scan resident\'s vehicle QR',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppTheme.textColor.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textColor.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _AddVisitorSheet extends StatefulWidget {
  final List<BlockModel> blocks;
  final ScrollController scrollController;

  const _AddVisitorSheet({
    required this.blocks,
    required this.scrollController,
  });

  @override
  State<_AddVisitorSheet> createState() => _AddVisitorSheetState();
}

class _RoomOption {
  final FloorModel floor;
  final RoomModel room;
  _RoomOption(this.floor, this.room);
  String get label => 'Floor ${floor.number} – ${room.number}';
}

class _AddVisitorSheetState extends State<_AddVisitorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _purposeController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _manualRoomController = TextEditingController();
  final _blockSearchController = TextEditingController();
  final _roomSearchController = TextEditingController();

  BlockModel? _selectedBlock;
  _RoomOption? _selectedRoomOption;
  VisitorType? _selectedType = VisitorType.guest;
  String? _selectedTypeDetail;
  late DateTime _entryTime;
  File? _visitorImage;
  Timer? _mobileDebounce;
  String? _matchedVisitorImageUrl;
  bool _nameWasManuallyEdited = false;
  final ImagePicker _picker = ImagePicker();

  static String _normalizeMobile10(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  VisitorModel? _findVisitorByMobile10(String mobile10) {
    if (mobile10.length != 10) return null;
    final s = context.read<SecurityBloc>().state;
    if (s is! SecurityLoaded) return null;
    for (final v in s.visitors) {
      final v10 = _normalizeMobile10(v.mobileNumber);
      if (v10 == mobile10) return v;
    }
    return null;
  }

  void _scheduleMobileLookup() {
    _mobileDebounce?.cancel();
    _mobileDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final mobile10 = _normalizeMobile10(_mobileController.text);
      if (mobile10.length != 10) {
        if (_matchedVisitorImageUrl != null) {
          setState(() => _matchedVisitorImageUrl = null);
        }
        return;
      }

      final matched = _findVisitorByMobile10(mobile10);
      final imageUrl = matched?.image;

      if (!_nameWasManuallyEdited &&
          matched != null &&
          matched.name.trim().isNotEmpty &&
          _nameController.text.trim() != matched.name.trim()) {
        _nameController.text = matched.name.trim();
      }

      if (_matchedVisitorImageUrl != imageUrl) {
        setState(() => _matchedVisitorImageUrl = imageUrl);
      }
    });
  }

  List<_RoomOption> get _blockRooms {
    if (_selectedBlock == null) return [];
    final seen = <String>{};
    final list = <_RoomOption>[];
    for (final f in _selectedBlock!.floors) {
      for (final r in f.rooms) {
        final key = '${f.id}_${r.id}';
        if (seen.contains(key)) continue;
        seen.add(key);
        list.add(_RoomOption(f, r));
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _entryTime = DateTime.now();
  }

  @override
  void didUpdateWidget(covariant _AddVisitorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedBlock != null && oldWidget.blocks != widget.blocks) {
      final matched = widget.blocks.where((b) => b.id == _selectedBlock!.id).toList();
      _selectedBlock = matched.isNotEmpty ? matched.first : null;
      _selectedRoomOption = null;
    }
  }

  @override
  void dispose() {
    _mobileDebounce?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    _purposeController.dispose();
    _vehicleController.dispose();
    _manualRoomController.dispose();
    _blockSearchController.dispose();
    _roomSearchController.dispose();
    super.dispose();
  }

  void _showBlockSearchSheet() {
    if (widget.blocks.isEmpty) return;
    _blockSearchController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = _blockSearchController.text.trim().isEmpty
              ? widget.blocks
              : widget.blocks
                  .where((b) => b.name.toLowerCase().contains(_blockSearchController.text.trim().toLowerCase()))
                  .toList();
          final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _blockSearchController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search block by name...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final block = filtered[i];
                        final selected = _selectedBlock?.id == block.id;
                        return ListTile(
                          leading: Icon(Icons.apartment, color: selected ? AppTheme.primaryColor : null),
                          title: Text('Block ${block.name}', style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                          onTap: () {
                            setState(() {
                              _selectedBlock = block;
                              _selectedRoomOption = null;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No block found for "${_blockSearchController.text}"', style: TextStyle(color: AppTheme.textColor.withOpacity(0.6))),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRoomSearchSheet() {
    final blockRooms = _blockRooms;
    if (_selectedBlock == null || blockRooms.isEmpty) return;
    _roomSearchController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final q = _roomSearchController.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? blockRooms
              : blockRooms
                  .where((o) =>
                      o.floor.number.toLowerCase().contains(q) ||
                      o.room.number.toLowerCase().contains(q) ||
                      o.label.toLowerCase().contains(q))
                  .toList();
          final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _roomSearchController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by floor or flat number...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final opt = filtered[i];
                        final selected = _selectedRoomOption != null &&
                            _selectedRoomOption!.floor.id == opt.floor.id &&
                            _selectedRoomOption!.room.id == opt.room.id;
                        return ListTile(
                          leading: Icon(Icons.door_front_door_rounded, color: selected ? AppTheme.primaryColor : null),
                          title: Text(
                            'Block ${_selectedBlock!.name}, Floor ${opt.floor.number}, Flat ${opt.room.number}',
                            style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedRoomOption = opt;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No room/flat found for "${_roomSearchController.text}"', style: TextStyle(color: AppTheme.textColor.withOpacity(0.6))),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _visitorImage = File(image.path);
      });
    }
  }

  String? get _resolvedBaseHomeNumber {
    if (_selectedRoomOption != null) return _selectedRoomOption!.room.number;
    if (_selectedBlock != null && _blockRooms.isEmpty && _manualRoomController.text.trim().isNotEmpty) {
      return _manualRoomController.text.trim();
    }
    return null;
  }

  /// Flat/room from selection — stored as `homeNumber` on submit.
  String? get _storedHomeNumber {
    final base = _resolvedBaseHomeNumber;
    if (base == null) return null;
    return base;
  }


  bool get _isCollege {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return false;
    }
    return false;
  }

  void _handleAdd() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select visitor type'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (visitorTypeRequiresSubtype(_selectedType!) &&
        (_selectedTypeDetail == null || _selectedTypeDetail!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select vendor or sub-type'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final isCollege = _isCollege;
    final blockValid = isCollege || _selectedBlock != null;
    final homeValid = isCollege || _storedHomeNumber != null;
    if (_formKey.currentState!.validate() &&
        blockValid &&
        homeValid &&
        _selectedType != null) {
      context.read<SecurityBloc>().add(
            AddVisitorEvent(
              name: _nameController.text.trim(),
              mobileNumber: _mobileController.text.trim(),
              type: _selectedType!,
              block: isCollege ? (_selectedBlock?.name ?? 'Campus') : _selectedBlock!.name,
              homeNumber: isCollege ? (_storedHomeNumber ?? 'Visitor') : _storedHomeNumber!,
              visitorImage: _visitorImage,
              purposeOfVisit: _purposeController.text.trim().isEmpty ? null : _purposeController.text.trim(),
              vehicleNumber: _vehicleController.text.trim().isEmpty ? null : _vehicleController.text.trim(),
              typeDetail: _selectedTypeDetail?.trim().isNotEmpty == true ? _selectedTypeDetail!.trim() : null,
            ),
          );
      Navigator.pop(context);
    } else if (!isCollege && (_selectedBlock == null || _storedHomeNumber == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select block and room / flat'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRoomFlatSelector() {
    final blockRooms = _blockRooms;
    if (blockRooms.isEmpty) return const SizedBox.shrink();
    final selectedLabel = _selectedRoomOption == null
        ? 'Search & choose room / flat'
        : 'Block ${_selectedBlock!.name}, Floor ${_selectedRoomOption!.floor.number}, Flat ${_selectedRoomOption!.room.number}';
    return _buildDropdownContainer(
      child: InkWell(
        onTap: _showRoomSearchSheet,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select Room / Flat',
            prefixIcon: Icon(Icons.door_front_door_rounded, color: AppTheme.primaryColor, size: 22),
            suffixIcon: Icon(Icons.search, color: AppTheme.textColor.withOpacity(0.5), size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
          ),
          child: Text(
            selectedLabel,
            style: TextStyle(
              fontSize: 16,
              color: _selectedRoomOption == null ? AppTheme.textColor.withOpacity(0.6) : AppTheme.textColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entryTimeStr =
        '${_entryTime.day}/${_entryTime.month}/${_entryTime.year} ${_entryTime.hour}:${_entryTime.minute.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 14),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // Header with gradient
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13275D), Color(0xFF1D3576)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13275D).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register Visitor',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Block, room & visitor details',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildSectionCard(
                    icon: Icons.badge_outlined,
                    title: 'Visitor Details',
                    subtitle: 'Mobile · name · vehicle · photo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration('Mobile Number', Icons.phone_android_rounded),
                          onChanged: (_) => _scheduleMobileLookup(),
                          validator: (v) {
                            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isEmpty) return 'Enter mobile number';
                            if (digits.length != 10) return 'Enter valid 10-digit mobile number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF2A437E),
                                          Color(0xFF13275D),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF13275D)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _visitorImage != null
                                          ? Image.file(_visitorImage!,
                                              fit: BoxFit.cover,
                                              width: 80,
                                              height: 80)
                                          : (_matchedVisitorImageUrl != null &&
                                                  _matchedVisitorImageUrl!
                                                      .trim()
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  _matchedVisitorImageUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 80,
                                                  height: 80,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                    color:
                                                        const Color(0xFF13275D),
                                                    child: const Icon(
                                                        Icons
                                                            .add_a_photo_rounded,
                                                        color: Colors.white,
                                                        size: 26),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.transparent,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .add_a_photo_rounded,
                                                          color: Colors.white,
                                                          size: 22),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'Add Photo\n(optional)',
                                                        textAlign: TextAlign.center,
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: _inputDecoration('Visitor Name', Icons.person_outline_rounded).copyWith(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    onChanged: (_) {
                                      if (!_nameWasManuallyEdited) {
                                        setState(() => _nameWasManuallyEdited = true);
                                      }
                                    },
                                    validator: (v) => (v == null || v.isEmpty) ? 'Enter visitor name' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _vehicleController,
                                    decoration: _inputDecoration('Vehicle No. (optional)', Icons.directions_car_rounded).copyWith(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isCollege) ...[
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      icon: Icons.apartment_rounded,
                      title: 'Block, Room & Flat',
                      subtitle: 'Search and select block, then room/flat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDropdownContainer(
                            child: InkWell(
                              onTap: widget.blocks.isEmpty ? null : _showBlockSearchSheet,
                              borderRadius: BorderRadius.circular(14),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Select Block',
                                  prefixIcon: Icon(Icons.apartment, color: AppTheme.primaryColor, size: 22),
                                  suffixIcon: Icon(Icons.search, color: AppTheme.textColor.withOpacity(0.5), size: 22),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                                ),
                                child: Text(
                                  _selectedBlock == null
                                      ? (widget.blocks.isEmpty ? 'No blocks loaded' : 'Search & choose block')
                                      : 'Block ${_selectedBlock!.name}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedBlock == null ? AppTheme.textColor.withOpacity(0.6) : AppTheme.textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedBlock != null) ...[
                            const SizedBox(height: 12),
                            _buildRoomFlatSelector(),
                          ],
                          if (_selectedBlock != null && _blockRooms.isEmpty) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _manualRoomController,
                              onChanged: (_) => setState(() {}),
                              decoration: _inputDecoration('Room / Flat number', Icons.door_front_door),
                              validator: (v) {
                                if (_blockRooms.isNotEmpty) return null;
                                return (v == null || v.trim().isEmpty) ? 'Enter room number' : null;
                              },
                            ),
                          ],
                          if (_selectedBlock != null &&
                              (_selectedRoomOption != null ||
                                  (_blockRooms.isEmpty && _manualRoomController.text.trim().isNotEmpty))) ...[
                            if (_storedHomeNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Stored flat / unit: ${_storedHomeNumber!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor.withOpacity(0.9),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _purposeController,
                    decoration: _inputDecoration('Purpose of Visit', Icons.edit_note_rounded),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter purpose of visit' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    icon: Icons.access_time_rounded,
                    title: 'Entry Time',
                    subtitle: 'Auto-captured',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            AppTheme.secondaryColor.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.schedule_rounded, color: AppTheme.primaryColor, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entryTimeStr,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Visitor check-in time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textColor.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textColor.withOpacity(0.8),
                            side: BorderSide(color: AppTheme.dividerColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: BrandGradientCtaButton(
                          onPressed: _handleAdd,
                          icon: Icons.person_add_rounded,
                          label: 'Add Visitor',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF13275D).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF13275D), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF64748B),
      ),
      floatingLabelStyle: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF13275D),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF13275D), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _BulkVisitSheet extends StatefulWidget {
  final List<BlockModel> blocks;
  final ScrollController scrollController;

  const _BulkVisitSheet({
    required this.blocks,
    required this.scrollController,
  });

  @override
  State<_BulkVisitSheet> createState() => _BulkVisitSheetState();
}

class _BulkVisitSheetState extends State<_BulkVisitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _purposeController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _blockSearchController = TextEditingController();
  final _roomSearchController = TextEditingController();

  BlockModel? _tempBlock;
  final List<({String block, String homeNumber})> _selectedHomes = [];
  VisitorType? _selectedType = VisitorType.guest;
  String? _selectedTypeDetail;
  File? _visitorImage;
  Timer? _mobileDebounce;
  String? _matchedVisitorImageUrl;
  bool _nameWasManuallyEdited = false;
  final ImagePicker _picker = ImagePicker();

  static String _normalizeMobile10(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  VisitorModel? _findVisitorByMobile10(String mobile10) {
    if (mobile10.length != 10) return null;
    final s = context.read<SecurityBloc>().state;
    if (s is! SecurityLoaded) return null;
    for (final v in s.visitors) {
      final v10 = _normalizeMobile10(v.mobileNumber);
      if (v10 == mobile10) return v;
    }
    return null;
  }

  void _scheduleMobileLookup() {
    _mobileDebounce?.cancel();
    _mobileDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final mobile10 = _normalizeMobile10(_mobileController.text);
      if (mobile10.length != 10) {
        if (_matchedVisitorImageUrl != null) {
          setState(() => _matchedVisitorImageUrl = null);
        }
        return;
      }

      final matched = _findVisitorByMobile10(mobile10);
      final imageUrl = matched?.image;

      if (!_nameWasManuallyEdited &&
          matched != null &&
          matched.name.trim().isNotEmpty &&
          _nameController.text.trim() != matched.name.trim()) {
        _nameController.text = matched.name.trim();
      }

      if (_matchedVisitorImageUrl != imageUrl) {
        setState(() => _matchedVisitorImageUrl = imageUrl);
      }
    });
  }

  List<_RoomOption> _getBlockRooms(BlockModel block) {
    final seen = <String>{};
    final list = <_RoomOption>[];
    for (final f in block.floors) {
      for (final r in f.rooms) {
        final key = '${f.id}_${r.id}';
        if (seen.contains(key)) continue;
        seen.add(key);
        list.add(_RoomOption(f, r));
      }
    }
    return list;
  }

  @override
  void dispose() {
    _mobileDebounce?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    _purposeController.dispose();
    _vehicleController.dispose();
    _blockSearchController.dispose();
    _roomSearchController.dispose();
    super.dispose();
  }

  void _showAddHomeSheet() {
    if (widget.blocks.isEmpty) return;
    _blockSearchController.clear();
    _roomSearchController.clear();
    _tempBlock = null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (_tempBlock == null) {
            final filtered = _blockSearchController.text.trim().isEmpty
                ? widget.blocks
                : widget.blocks
                    .where((b) => b.name.toLowerCase().contains(_blockSearchController.text.trim().toLowerCase()))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _blockSearchController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search block by name...',
                          prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final block = filtered[i];
                          return ListTile(
                            leading: Icon(Icons.apartment, color: AppTheme.primaryColor),
                            title: Text('Block ${block.name}'),
                            onTap: () {
                              setState(() => _tempBlock = block);
                              setModalState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final blockRooms = _getBlockRooms(_tempBlock!);
          final q = _roomSearchController.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? blockRooms
              : blockRooms
                  .where((o) =>
                      o.floor.number.toLowerCase().contains(q) ||
                      o.room.number.toLowerCase().contains(q) ||
                      o.label.toLowerCase().contains(q))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
                  ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() => _tempBlock = null);
                        setModalState(() {});
                      },
                    ),
                    title: Text('Select flat – Block ${_tempBlock!.name}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _roomSearchController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by floor or flat...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final opt = filtered[i];
                        final blockName = _tempBlock!.name;
                        final baseFlat = opt.room.number;
                        final alreadyListed = _selectedHomes.any(
                            (h) => h.block == blockName && h.homeNumber == baseFlat);
                        return ListTile(
                          leading: Icon(
                            alreadyListed ? Icons.check_circle : Icons.door_front_door_rounded,
                            color: alreadyListed ? AppTheme.primaryColor : null,
                          ),
                          title: Text('Block $blockName, Floor ${opt.floor.number}, Flat $baseFlat'),
                          onTap: () {
                            final already = _selectedHomes.any(
                                (h) => h.block == blockName && h.homeNumber == baseFlat);
                            setState(() {
                              if (already) {
                                _selectedHomes.removeWhere(
                                    (h) => h.block == blockName && h.homeNumber == baseFlat);
                              } else {
                                _selectedHomes.add((block: blockName, homeNumber: baseFlat));
                              }
                            });
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _visitorImage = File(image.path));
    }
  }


  bool get _isCollege {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return false;
    }
    return false;
  }

  void _handleSubmit() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select visitor type'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (visitorTypeRequiresSubtype(_selectedType!) &&
        (_selectedTypeDetail == null || _selectedTypeDetail!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select vendor or sub-type'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final isCollege = _isCollege;
    if (!isCollege && _selectedHomes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one home to visit'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final homesToSend = isCollege
        ? (_selectedHomes.isEmpty ? [(block: 'Campus', homeNumber: 'Visitor')] : List<({String block, String homeNumber})>.from(_selectedHomes))
        : List<({String block, String homeNumber})>.from(_selectedHomes);
    context.read<SecurityBloc>().add(
          AddBulkVisitorEvent(
            name: _nameController.text.trim(),
            mobileNumber: _mobileController.text.trim(),
            type: _selectedType!,
            homes: homesToSend,
            purposeOfVisit: _purposeController.text.trim().isEmpty ? null : _purposeController.text.trim(),
            vehicleNumber: _vehicleController.text.trim().isEmpty ? null : _vehicleController.text.trim(),
            visitorImage: _visitorImage,
            typeDetail: _selectedTypeDetail?.trim().isNotEmpty == true ? _selectedTypeDetail!.trim() : null,
          ),
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCollege ? 'Visitor registered successfully' : 'Registered visitor for ${homesToSend.length} home(s)'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textColor.withOpacity(0.55), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 22),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.dividerColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: AppTheme.dividerColor.withOpacity(0.8), borderRadius: BorderRadius.circular(3))),
          // Header with gradient
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13275D), Color(0xFF1D3576)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13275D).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Visit',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Same person visiting multiple homes',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildSectionCard(
                    icon: Icons.badge_outlined,
                    title: 'Visitor Details',
                    subtitle: 'Mobile · name · vehicle · photo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                              'Mobile Number', Icons.phone_android_rounded),
                          onChanged: (_) => _scheduleMobileLookup(),
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isEmpty) return 'Enter mobile number';
                            if (digits.length != 10) {
                              return 'Enter valid 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF2A437E),
                                          Color(0xFF13275D),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF13275D)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _visitorImage != null
                                          ? Image.file(_visitorImage!,
                                              fit: BoxFit.cover,
                                              width: 80,
                                              height: 80)
                                          : (_matchedVisitorImageUrl != null &&
                                                  _matchedVisitorImageUrl!
                                                      .trim()
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  _matchedVisitorImageUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 80,
                                                  height: 80,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          Container(
                                                    color: const Color(
                                                        0xFF13275D),
                                                    child: const Icon(
                                                        Icons
                                                            .add_a_photo_rounded,
                                                        color: Colors.white,
                                                        size: 26),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.transparent,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .add_a_photo_rounded,
                                                          color: Colors.white,
                                                          size: 22),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'Add Photo',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: _inputDecoration('Visitor Name', Icons.person_outline_rounded).copyWith(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    onChanged: (_) {
                                      if (!_nameWasManuallyEdited) {
                                        setState(() => _nameWasManuallyEdited = true);
                                      }
                                    },
                                    validator: (v) => (v == null || v.isEmpty) ? 'Enter visitor name' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _vehicleController,
                                    decoration: _inputDecoration('Vehicle No.', Icons.directions_car_rounded).copyWith(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (!_isCollege) ...[
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      icon: Icons.apartment_rounded,
                      title: 'Homes to Visit',
                      subtitle: 'Add multiple homes',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showAddHomeSheet,
                            icon: const Icon(Icons.add_home_rounded, size: 20),
                            label: const Text('Add Home'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.6)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          if (_selectedHomes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedHomes.map((h) {
                                return Chip(
                                  label: Text('Block ${h.block}-${h.homeNumber}'),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () => setState(() => _selectedHomes.removeWhere((x) => x.block == h.block && x.homeNumber == h.homeNumber)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 4),
                            Text('${_selectedHomes.length} home(s) selected', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    icon: Icons.edit_note_rounded,
                    title: 'Additional Info',
                    subtitle: 'Purpose (optional)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(controller: _purposeController, decoration: _inputDecoration('Purpose of Visit', Icons.edit_note_rounded)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textColor.withOpacity(0.8),
                            side: BorderSide(color: AppTheme.dividerColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: BrandGradientCtaButton(
                          onPressed: _handleSubmit,
                          icon: Icons.groups_rounded,
                          label: 'Register Bulk Visit',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

