import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import '../../../participant/presentation/pages/program_schedule_page.dart';

/// Admin upload for the programme PDF participants see when they open Schedule.
class ManageSchedulePdfPage extends StatefulWidget {
  const ManageSchedulePdfPage({super.key});

  @override
  State<ManageSchedulePdfPage> createState() => _ManageSchedulePdfPageState();
}

class _ManageSchedulePdfPageState extends State<ManageSchedulePdfPage> {
  final _api = ApiService();
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String _fileName = '';
  String _url = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _load() async {
    final res = await _api.getSchedulePdf();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _fileName = res['fileName']?.toString() ?? '';
        _url = res['url']?.toString() ?? '';
      } else {
        _error = res['error']?.toString() ?? 'Could not load the schedule PDF';
      }
    });
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    final res = await _api.uploadSchedulePdf(path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (res['success'] == true) {
      setState(() {
        _fileName = res['fileName']?.toString() ?? _fileName;
        _url = res['url']?.toString() ?? _url;
        _error = null;
      });
      _toast('Schedule PDF updated');
    } else {
      _toast(res['error']?.toString() ?? 'Could not upload the PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Schedule PDF',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: darkCardDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFF97316)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error ?? (_fileName.isEmpty ? 'No schedule PDF' : _fileName),
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _url.isEmpty
                                  ? 'Upload a PDF to show it on Schedule'
                                  : 'Showing the Cloudinary PDF on Schedule',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: DarkColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'UPLOAD PDF',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color: DarkColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Participants see this file when they open Schedule. Choose a PDF to replace it.',
                  style: GoogleFonts.inter(fontSize: 13, color: DarkColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _uploading ? null : _pickAndUpload,
                    style: FilledButton.styleFrom(
                      backgroundColor: DarkColors.accent,
                      disabledBackgroundColor: DarkColors.accent.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file_rounded, color: Colors.white),
                    label: Text(
                      _uploading ? 'Uploading…' : 'Upload schedule PDF',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _url.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProgramSchedulePage()),
                          ),
                  icon: const Icon(Icons.visibility_outlined, color: Colors.white70),
                  label: Text(
                    'Preview what participants see',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                ),
              ],
            ),
    );
  }
}
