import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../participant/presentation/pages/session_file_viewer.dart';
import '../widgets/speaker_ui.dart';

/// Speaker uploads PDFs or PPTs ([kind] 'pdf' / 'ppt') to one of their
/// sessions; participants see them on the session's details page.
class SpeakerSessionFilesPage extends StatefulWidget {
  final SpeakerSessionRef session;
  final String kind;

  const SpeakerSessionFilesPage({
    super.key,
    required this.session,
    required this.kind,
  });

  @override
  State<SpeakerSessionFilesPage> createState() =>
      _SpeakerSessionFilesPageState();
}

class _SpeakerSessionFilesPageState extends State<SpeakerSessionFilesPage> {
  static const _maxBytes = 10 * 1024 * 1024; // matches the backend limit

  final _api = ApiService();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  int _progress = 0; // percent

  bool get _isPdf => widget.kind == 'pdf';
  String get _label => _isPdf ? 'PDF' : 'PPT';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _load() async {
    final res = await _api.getSessionContent(widget.session.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _error = null;
        _files = ((res['files'] as List?) ?? [])
            .map((f) => Map<String, dynamic>.from(f as Map))
            .where((f) => f['kind'] == widget.kind)
            .toList();
      } else {
        _error = res['error']?.toString() ?? 'Could not load files';
      }
    });
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _isPdf ? ['pdf'] : ['ppt', 'pptx'],
    );
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    if (file.size > _maxBytes) {
      return _toast('File is too large (max 10 MB)');
    }
    setState(() {
      _uploading = true;
      _progress = 0;
    });
    final res = await _api.uploadSessionFile(
      widget.session.id,
      filePath: file.path!,
      fileName: file.name,
      onProgress: (sent, total) {
        if (total > 0 && mounted) {
          setState(() => _progress = (sent * 100 / total).round());
        }
      },
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (res['success'] == true) {
      _toast('$_label uploaded');
      _load();
    } else {
      _toast(res['error']?.toString() ?? 'Upload failed');
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    if (!await confirmSpeakerDelete(context, _label)) return;
    final res = await _api.deleteSessionFile(
      widget.session.id,
      file['id'].toString(),
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _files.removeWhere((f) => f['id'] == file['id']));
    } else {
      _toast(res['error']?.toString() ?? 'Could not delete');
    }
  }

  String _sizeText(num bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpeakerColors.bg,
      appBar: speakerAppBar('Upload $_label'),
      bottomNavigationBar: SpeakerActionButton(
        label: 'Upload $_label',
        icon: Icons.upload_rounded,
        onPressed: _pickAndUpload,
        busy: _uploading,
        busyLabel: 'Uploading $_progress%',
      ),
      body: RefreshIndicator(
        color: SpeakerColors.green,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            SpeakerSessionHeader(session: widget.session),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: SpeakerColors.green),
                ),
              )
            else if (_error != null)
              SpeakerEmptyText('${_error!}\nPull down to try again.')
            else if (_files.isEmpty)
              SpeakerEmptyText(
                'No ${_label}s uploaded yet.\n'
                'Participants will see them on this session’s details page.',
              )
            else
              for (final f in _files) _fileRow(f),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(Map<String, dynamic> f) {
    final created = DateTime.tryParse(f['createdAt']?.toString() ?? '');
    final meta = [
      _sizeText((f['size'] as num?) ?? 0),
      if (created != null)
        DateFormat('d MMM, h:mm a').format(created.toLocal()),
    ].join('  ·  ');
    final color = _isPdf ? const Color(0xFFE11D48) : const Color(0xFFF97316);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: speakerCardDecoration(),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => openSessionFile(context, f),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.slideshow_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['name']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: SpeakerColors.sub,
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
                    onPressed: () => _delete(f),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
