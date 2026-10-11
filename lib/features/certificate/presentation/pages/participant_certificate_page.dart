import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brand_gradient_app_bar.dart';
import '../../../../core/widgets/dark_ui.dart';
import 'conference_feedback_form.dart';
/// One certificate image and where the participant's name goes on it
/// (fractions of the image size).
class _Cert {
  final String key;
  final String label;
  final String asset;
  final String fileName;
  final double nameLeft;
  final double nameTop;
  final double nameWidth;
  final double nameHeight;

  const _Cert({
    required this.key,
    required this.label,
    required this.asset,
    required this.fileName,
    required this.nameLeft,
    required this.nameTop,
    required this.nameWidth,
    required this.nameHeight,
  });

  _Cert copyWithLabel(String label, String fileName) => _Cert(
        key: key,
        label: label,
        asset: asset,
        fileName: fileName,
        nameLeft: nameLeft,
        nameTop: nameTop,
        nameWidth: nameWidth,
        nameHeight: nameHeight,
      );
}

// Name sits on the blank line under "This is to Certify that".
const _certificateArt = {
  'student': _Cert(
    key: 'student',
    label: 'STUDENT CONFERENCE CERTIFICATE',
    asset: 'assets/student_conference_certificate.jpg',
    fileName: 'ISDR2026_Student_Conference_Certificate.pdf',
    nameLeft: 0.26,
    nameTop: 0.508,
    nameWidth: 0.48,
    nameHeight: 0.055,
  ),
  'delegate': _Cert(
    key: 'delegate',
    label: 'DELEGATE CERTIFICATE',
    asset: 'assets/delegate_certificate.jpg',
    fileName: 'ISDR2026_Delegate_Certificate.pdf',
    nameLeft: 0.252,
    nameTop: 0.51,
    nameWidth: 0.49,
    nameHeight: 0.055,
  ),
};

/// Participant certificate. Feedback is shown until it is submitted, then the certificate can be downloaded.
class ParticipantCertificatePage extends StatefulWidget {
  const ParticipantCertificatePage({super.key});

  @override
  State<ParticipantCertificatePage> createState() =>
      _ParticipantCertificatePageState();
}

class _ParticipantCertificatePageState
    extends State<ParticipantCertificatePage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  /// Asset of the certificate whose PDF is being built, if any.
  String? _downloading;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.getMyCertificate();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _data = res;
        _error = null;
      } else {
        _error = res['error']?.toString() ?? 'Could not load the certificate';
      }
    });
  }

  bool get _revoked => _data['revoked'] == true;
  bool get _feedbackSubmitted => _data['feedbackSubmitted'] == true;
  String get _name => _data['name']?.toString() ?? '';

  List<Map<String, dynamic>> get _questions => (_data['questions'] as List? ?? [])
      .whereType<Map>()
      .map((q) => Map<String, dynamic>.from(q))
      .toList();

  Future<void> _submitFeedback(Map<String, String> answers) async {
    setState(() => _submitting = true);
    final res = await _api.submitConferenceFeedback(answers);
    if (!mounted) return;
    if (res['success'] == true) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not submit feedback')),
      );
    }
    if (mounted) setState(() => _submitting = false);
  }

  List<Widget> _certificateBlocks() {
    return [
      for (final cert in _certificates) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            cert.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: DarkColors.muted,
            ),
          ),
        ),
        _certificate(cert),
      ],
    ];
  }

  List<_Cert> get _certificates {
    final raw = _data['certificates'];
    if (raw is! List) return _certificateArt.values.toList();
    return raw.whereType<Map>().map((item) {
      final art = _certificateArt[item['key']?.toString()];
      if (art == null) return null;
      final label = item['label']?.toString();
      final fileName = item['fileName']?.toString();
      if ((label == null || label.isEmpty) && (fileName == null || fileName.isEmpty)) {
        return art;
      }
      return art.copyWithLabel(
        label == null || label.isEmpty ? art.label : label.toUpperCase(),
        fileName == null || fileName.isEmpty ? art.fileName : fileName,
      );
    }).whereType<_Cert>().toList();
  }

  Future<void> _download(_Cert cert) async {
    setState(() => _downloading = cert.asset);
    try {
      final bytes = (await rootBundle.load(cert.asset)).buffer.asUint8List();
      final image = await decodeImageFromList(bytes);
      const w = 842.0;
      final h = w * image.height / image.width;
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(w, h),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
              ),
              pw.Positioned(
                left: w * cert.nameLeft,
                top: h * cert.nameTop,
                child: pw.SizedBox(
                  width: w * cert.nameWidth,
                  height: h * cert.nameHeight,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      _name,
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: h * cert.nameHeight * 0.72,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${cert.fileName}');
      await file.writeAsBytes(await doc.save());
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create the PDF: $e')));
      }
    }
    if (mounted) setState(() => _downloading = null);
  }

  Widget _certificate(_Cert cert) {
    final downloading = _downloading == cert.asset;
    final image = Stack(
      children: [
        Image.asset(cert.asset, width: double.infinity),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, c) => Stack(
              children: [
                Positioned(
                  left: c.maxWidth * cert.nameLeft,
                  top: c.maxHeight * cert.nameTop,
                  width: c.maxWidth * cert.nameWidth,
                  height: c.maxHeight * cert.nameHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          image,
          Positioned(
            right: 8,
            bottom: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.6),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _downloading != null ? null : () => _download(cert),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      appBar: buildDarkAppBar(
        title: Text(
          'Certificate',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: DarkColors.muted),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_revoked)
                    Text(
                      'Your certificates are not available yet.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: DarkColors.muted,
                      ),
                    )
                  else if (!_feedbackSubmitted)
                    ConferenceFeedbackForm(
                      questions: _questions,
                      submitting: _submitting,
                      onSubmit: _submitFeedback,
                    )
                  else
                    ..._certificateBlocks(),
                ],
              ),
            ),
    );
  }
}
