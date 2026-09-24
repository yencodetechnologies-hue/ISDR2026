import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_cta_button.dart';
import '../bloc/admin_bloc.dart';
import '../widgets/managed_event_form.dart';

class CreateManagedEventPage extends StatefulWidget {
  final String? apartmentId;
  final bool isEventsProperty;

  const CreateManagedEventPage({
    super.key,
    this.apartmentId,
    this.isEventsProperty = false,
  });

  @override
  State<CreateManagedEventPage> createState() => _CreateManagedEventPageState();
}

class _CreateManagedEventPageState extends State<CreateManagedEventPage> {
  final _api = ApiService();
  final _form = ManagedEventFormData();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final next = await pickManagedEventDateTime(context, _form.eventDate);
    if (next == null || !mounted) return;
    setState(() => _form.eventDate = next);
  }

  Future<void> _pickEndDate() async {
    final next = await pickManagedEventDateTime(
      context,
      _form.eventEndDate ?? _form.eventDate,
    );
    if (next == null || !mounted) return;
    setState(() => _form.eventEndDate = next);
  }

  String? get _effectiveApartmentId {
    if (widget.apartmentId != null && widget.apartmentId!.isNotEmpty) {
      return widget.apartmentId;
    }
    try {
      final state = context.read<AdminBloc>().state;
      if (state is AdminLoaded) {
        final sel = state.selectedApartmentId;
        if (sel != null && sel.isNotEmpty) return sel;
        if (state.blocks.isNotEmpty) {
          return state.blocks.first.apartmentId;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    final err = _form.validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final aptId = _effectiveApartmentId;
    debugPrint(
      '[CreateManagedEventPage] Saving event with apartmentId: $aptId',
    );
    final res = await _api.createManagedEvent(
      title: _form.title.text.trim(),
      description: _form.description.text.trim(),
      venue: _form.venue.text.trim(),
      eventDate: _form.eventDate,
      eventEndDate: widget.isEventsProperty ? _form.eventEndDate : null,
      apartmentId: aptId,
      photoPath: _form.photoPath,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res['success'] == true) {
      final event = Map<String, dynamic>.from(res['event'] as Map? ?? {});
      final slug = event['publicSlug']?.toString() ?? '';
      if (slug.isNotEmpty) {
        await Clipboard.setData(
          ClipboardData(text: ApiConfig.eventRegisterWebUrl(slug)),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, event);
    } else {
      setState(() => _error = res['error']?.toString() ?? 'Create failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      appBar: AppBar(
        title: Text(
          'Create event',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF14141F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withAlpha(16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fill in the event details below. A public register link is generated for sharing where applicable.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorColor.withAlpha(50)),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          ManagedEventFormBody(
            data: _form,
            onChanged: () => setState(() {}),
            onPickDateTime: _pickDate,
            showEndDate: widget.isEventsProperty,
            onPickEndDateTime: _pickEndDate,
          ),
          const SizedBox(height: 24),
          BrandGradientCtaButton(
            height: 50,
            label: 'Create event',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _save,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
