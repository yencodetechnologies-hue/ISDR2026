import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';

/// Management's Speakers page: every speaker of the property. Speakers are
/// added here and then picked from a dropdown when adding a schedule.
class ManageSpeakersPage extends StatefulWidget {
  const ManageSpeakersPage({super.key});

  @override
  State<ManageSpeakersPage> createState() => _ManageSpeakersPageState();
}

class _ManageSpeakersPageState extends State<ManageSpeakersPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _speakers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.listSpeakers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _speakers = ((res['speakers'] as List?) ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load speakers';
      }
    });
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddSpeakerPage()),
    );
    if (added == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> speaker) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        title: const Text(
          'Delete speaker?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${speaker['name']} will no longer be able to log in.',
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
    final res = await _api.deleteSpeaker(speaker['id'].toString());
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _speakers.removeWhere((s) => s['id'] == speaker['id']));
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
          'Speakers',
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
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Speaker'),
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
            else if (_error != null || _speakers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: Column(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 44,
                      color: DarkColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'No speakers yet',
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
                          : 'Add speakers here, then pick them when adding a schedule.',
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
              for (final s in _speakers) _row(s),
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final photo = s['photo']?.toString() ?? '';
    final name = s['name']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: darkCardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF1E3A8A),
            backgroundImage: photo.isNotEmpty
                ? CachedNetworkImageProvider(photo)
                : null,
            child: photo.isEmpty
                ? Text(
                    name.isEmpty ? '?' : name.trim()[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['mobileNumber']?.toString() ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: DarkColors.muted,
                  ),
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
            onPressed: () => _delete(s),
          ),
        ],
      ),
    );
  }
}

/// Photo, name, mobile and password — the speaker logs in with mobile +
/// password and sees every schedule they're picked for.
class AddSpeakerPage extends StatefulWidget {
  const AddSpeakerPage({super.key});

  @override
  State<AddSpeakerPage> createState() => _AddSpeakerPageState();
}

class _AddSpeakerPageState extends State<AddSpeakerPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  File? _photo;
  bool _saving = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _password.dispose();
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
    setState(() => _saving = true);
    final res = await ApiService().createSpeaker(
      name: _name.text.trim(),
      mobileNumber: _mobile.text.trim(),
      password: _password.text,
      photoPath: _photo?.path,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Could not add speaker'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(color: Colors.white);
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Add Speaker',
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
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: DarkColors.field,
                      backgroundImage: _photo != null
                          ? FileImage(_photo!)
                          : null,
                      child: _photo == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 44,
                              color: DarkColors.accentLight,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
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
                'Speaker photo',
                style: TextStyle(fontSize: 12, color: DarkColors.muted),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              style: fieldStyle,
              textCapitalization: TextCapitalization.words,
              decoration: darkInputDecoration(
                'Name of the speaker',
                Icons.person_outline,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the speaker name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobile,
              style: fieldStyle,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: darkInputDecoration(
                'Mobile number (login)',
                Icons.phone_outlined,
              ).copyWith(counterText: ''),
              validator: (v) => RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid 10-digit mobile number',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              style: fieldStyle,
              obscureText: !_showPassword,
              decoration: darkInputDecoration('Password', Icons.lock_outline)
                  .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: DarkColors.muted,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
              validator: (v) => (v == null || v.trim().length < 6)
                  ? 'Password must be at least 6 characters'
                  : null,
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
                        'Save Speaker',
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
