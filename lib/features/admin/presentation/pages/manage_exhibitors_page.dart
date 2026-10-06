import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/exhibitor_stalls.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Admin's Exhibitors page: every exhibitor (shop) of the property. Added
/// exhibitors show on the participant home in place of the Next Session card.
class ManageExhibitorsPage extends StatefulWidget {
  const ManageExhibitorsPage({super.key});

  @override
  State<ManageExhibitorsPage> createState() => _ManageExhibitorsPageState();
}

class _ManageExhibitorsPageState extends State<ManageExhibitorsPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _exhibitors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.listExhibitors();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _exhibitors = ((res['exhibitors'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load exhibitors';
      }
    });
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddExhibitorPage()),
    );
    if (added == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> exhibitor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        title: const Text(
          'Delete exhibitor?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${exhibitor['shopName']} will be removed from the participant home.',
          style: const TextStyle(color: DarkColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _api.deleteExhibitor(exhibitor['id'].toString());
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _exhibitors.removeWhere((e) => e['id'] == exhibitor['id']));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not delete')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Exhibitors',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: DarkColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add Exhibitor'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_error != null || _exhibitors.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 44,
                      color: DarkColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'No exhibitors yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error != null
                          ? 'Pull down to try again.'
                          : 'Added exhibitors show on the participant home.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: DarkColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final group in stallGroups(_exhibitors)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        group.title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: DarkColors.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.items.length}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: DarkColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final e in group.items) _row(e),
              ],
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> e) {
    final photo = e['photo']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: darkCardDecoration(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: photo.isNotEmpty
                  ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
                  : Container(
                      color: DarkColors.field,
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: DarkColors.accentLight,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['shopName']?.toString() ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e['category']?.toString() ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: DarkColors.accentLight,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: DarkColors.muted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        stallCode(e['location']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: DarkColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFF87171),
            ),
            onPressed: () => _delete(e),
          ),
        ],
      ),
    );
  }
}

/// Shop name, optional photo, category and location.
class AddExhibitorPage extends StatefulWidget {
  const AddExhibitorPage({super.key});

  @override
  State<AddExhibitorPage> createState() => _AddExhibitorPageState();
}

class _AddExhibitorPageState extends State<AddExhibitorPage> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _category = TextEditingController();
  final _location = TextEditingController();
  File? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _shopName.dispose();
    _category.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final res = await ApiService().createExhibitor(
      shopName: _shopName.text.trim(),
      category: _category.text.trim(),
      location: _location.text.trim(),
      photoPath: _photo?.path,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Could not add exhibitor'),
        ),
      );
    }
  }

  String? _required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(color: Colors.white);
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Add Exhibitor',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 110,
                        height: 110,
                        color: DarkColors.field,
                        child: _photo != null
                            ? Image.file(_photo!, fit: BoxFit.cover)
                            : const Icon(
                                Icons.storefront_rounded,
                                size: 44,
                                color: DarkColors.accentLight,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: DarkColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Photo (optional)',
                style: TextStyle(fontSize: 12, color: DarkColors.muted),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shopName,
              style: fieldStyle,
              textCapitalization: TextCapitalization.words,
              decoration: darkInputDecoration(
                'Shop name',
                Icons.storefront_outlined,
              ),
              validator: (v) => _required(v, 'Enter the shop name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              style: fieldStyle,
              textCapitalization: TextCapitalization.words,
              decoration: darkInputDecoration(
                'Category',
                Icons.category_outlined,
              ),
              validator: (v) => _required(v, 'Enter the category'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              style: fieldStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: darkInputDecoration(
                'Stall',
                Icons.location_on_outlined,
              ),
              validator: (v) => _required(v, 'Enter the stall, e.g. A1'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DarkColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Exhibitor',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
