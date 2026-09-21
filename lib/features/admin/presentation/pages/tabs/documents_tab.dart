import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/models/property_document_requirement_model.dart';
import '../../../../../../core/models/user_model.dart';
import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/widgets/brand_gradient_cta_button.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../bloc/admin_bloc.dart';

class DocumentsTab extends StatefulWidget {
  final AdminLoaded state;
  final String? selectedApartmentId;
  final bool canManage;

  const DocumentsTab({
    required this.state,
    this.selectedApartmentId,
    this.canManage = true,
    super.key,
  });

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  final ApiService _apiService = ApiService();
  final _nameController = TextEditingController();
  List<PropertyDocumentRequirementModel> _requirements = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _documentType = 'pdf';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequirements());
  }

  @override
  void didUpdateWidget(DocumentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedApartmentId != widget.selectedApartmentId) {
      _loadRequirements();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _getApartmentId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      if (authState.user.userType == UserType.apartment) {
        return authState.user.apartmentId;
      }
      if (authState.user.userType == UserType.admin) {
        final sel = widget.selectedApartmentId;
        if (sel != null && sel.isNotEmpty) return sel;
        if (widget.state.blocks.isNotEmpty) {
          final bApt = widget.state.blocks.first.apartmentId;
          if (bApt != null && bApt.isNotEmpty) return bApt;
        }
      }
      return authState.user.apartmentId;
    }
    final sel = widget.selectedApartmentId;
    if (sel != null && sel.isNotEmpty) return sel;
    if (widget.state.blocks.isNotEmpty) {
      final bApt = widget.state.blocks.first.apartmentId;
      if (bApt != null && bApt.isNotEmpty) return bApt;
    }
    return null;
  }

  Future<void> _loadRequirements() async {
    setState(() => _isLoading = true);
    try {
      final apartmentId = _getApartmentId();
      final response = await _apiService.getPropertyDocumentRequirements(
        apartmentId: apartmentId,
      );
      if (response['success'] == true && response['requirements'] != null) {
        setState(() {
          _requirements = (response['requirements'] as List)
              .map(
                (e) => PropertyDocumentRequirementModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading documents: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createRequirement() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a document name'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final apartmentId = _getApartmentId();
    if (apartmentId == null || apartmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apartment ID is required'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await _apiService.createPropertyDocumentRequirement(
        name: name,
        documentType: _documentType,
        apartmentId: apartmentId,
      );
      if (response['success'] == true) {
        _nameController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document requirement added successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadRequirements();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to add requirement'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteRequirement(PropertyDocumentRequirementModel req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete Requirement',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Remove "${req.name}"? Residents will no longer see this document requirement.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final response = await _apiService.deletePropertyDocumentRequirement(req.id);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Requirement deleted')),
          );
          _loadRequirements();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to delete'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF13275D),
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRequirements,
              color: const Color(0xFF13275D),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (widget.canManage)
                    SliverToBoxAdapter(child: _buildAddForm()),
                  _requirements.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          sliver: SliverList.separated(
                            itemCount: _requirements.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _RequirementCard(
                              requirement: _requirements[index],
                              canManage: widget.canManage,
                              onDelete: () =>
                                  _deleteRequirement(_requirements[index]),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF13275D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.folder_shared_rounded,
              color: Color(0xFF13275D),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Property Documents',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.canManage
                      ? (_requirements.isEmpty
                          ? 'Define documents residents must upload'
                          : '${_requirements.length} requirement${_requirements.length == 1 ? '' : 's'} configured')
                      : 'View required documents for residents',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _isLoading ? null : _loadRequirements,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Color(0xFF13275D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 20,
                  color: Color(0xFF13275D),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add document requirement',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                labelText: 'Document name',
                hintText: 'e.g. Identity Proof, Rental Agreement',
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _documentType,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),
              decoration: InputDecoration(
                labelText: 'Document type',
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
                prefixIcon: const Icon(
                  Icons.file_present_rounded,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF13275D), width: 1.5),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'pdf', child: Text('PDF Format')),
                DropdownMenuItem(value: 'image', child: Text('Image (JPG / PNG)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _documentType = v);
              },
            ),
            const SizedBox(height: 16),
            BrandGradientCtaButton(
              label: _isSaving ? 'Adding Requirement...' : 'Add Requirement',
              icon: Icons.add_rounded,
              height: 48,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _createRequirement,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF13275D).withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF13275D).withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 38,
                color: Color(0xFF13275D),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.canManage
                  ? 'No Document Requirements'
                  : 'No Requirements Defined',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.canManage
                  ? 'Specify required document names and accepted file formats for resident onboarding & records.'
                  : 'The society administrator has not added any mandatory document requirements.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  final PropertyDocumentRequirementModel requirement;
  final bool canManage;
  final VoidCallback onDelete;

  const _RequirementCard({
    required this.requirement,
    required this.canManage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = requirement.isPdf;
    final badgeColor = isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final badgeBg = isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);
    final dateStr = requirement.createdAt != null
        ? DateFormat('dd MMM yyyy').format(requirement.createdAt!)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: badgeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        isPdf ? 'PDF' : 'IMAGE',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (dateStr != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Added $dateStr',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
