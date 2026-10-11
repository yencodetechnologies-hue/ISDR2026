import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

/// Participant: day-by-day entry/exit progress and the certificates.
/// The certificate opens after conference feedback is submitted, unless an admin has locked it.
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

  List<Map<String, dynamic>> get _days => (_data['days'] as List? ?? [])
      .whereType<Map>()
      .map((d) => Map<String, dynamic>.from(d))
      .toList();

  bool get _revoked => _data['revoked'] == true;
  bool get _feedbackSubmitted => _data['feedbackSubmitted'] == true;
  bool get _unlocked => !_revoked && _feedbackSubmitted;
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

  Widget _progressBar() {
    final days = _days;
    if (days.isEmpty) {
      return Text(
        'Event dates are not set yet',
        style: GoogleFonts.inter(color: DarkColors.muted, fontSize: 12.5),
      );
    }
    bool done(Map d) => d['entryAt'] != null && d['exitAt'] != null;
    Widget mark(bool ok, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 11,
          color: ok ? const Color(0xFF22C55E) : DarkColors.muted,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: ok ? Colors.white : DarkColors.muted,
          ),
        ),
      ],
    );

    final steps = <Widget>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final complete = done(d);
      final partial = !complete && d['entryAt'] != null;
      final date = DateTime.tryParse(d['date'].toString());
      final color = complete
          ? const Color(0xFF22C55E)
          : partial
          ? const Color(0xFFF59E0B)
          : DarkColors.line;
      steps.add(
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i == 0
                          ? Colors.transparent
                          : (complete
                                ? const Color(0xFF22C55E)
                                : DarkColors.line),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: complete || partial ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: complete
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: partial ? Colors.white : DarkColors.muted,
                            ),
                          ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i == days.length - 1
                          ? Colors.transparent
                          : (i + 1 < days.length && done(days[i + 1])
                                ? const Color(0xFF22C55E)
                                : DarkColors.line),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                date == null
                    ? 'Day ${i + 1}'
                    : DateFormat('d MMM').format(date),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: complete ? Colors.white : DarkColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              mark(d['entryAt'] != null, 'In'),
              const SizedBox(height: 2),
              mark(d['exitAt'] != null, 'Out'),
            ],
          ),
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: steps);
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
      child: _unlocked
          ? Stack(
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
                      onTap: _downloading != null
                          ? null
                          : () => _download(cert),
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
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: image,
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 34,
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
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
                    decoration: darkCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 14),
                          child: Text(
                            'ATTENDANCE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                              color: DarkColors.muted,
                            ),
                          ),
                        ),
                        _progressBar(),
                      ],
                    ),
                  ),
                  if (_revoked) ...[
                    ..._certificateBlocks(),
                    const SizedBox(height: 14),
                    Text(
                      'Your certificates are not available yet.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: DarkColors.muted,
                      ),
                    ),
                  ] else if (!_feedbackSubmitted) ...[
                    const SizedBox(height: 16),
                    ConferenceFeedbackForm(
                      questions: _questions,
                      submitting: _submitting,
                      onSubmit: _submitFeedback,
                    ),
                  ] else
                    ..._certificateBlocks(),
                ],
              ),
            ),
    );
  }
}
