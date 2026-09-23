import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a session file (from the session-content API) inside the app:
/// PDFs in [SessionPdfViewerPage], PPTs in Microsoft's online viewer.
Future<void> openSessionFile(
  BuildContext context,
  Map<String, dynamic> file,
) async {
  final url = file['url']?.toString() ?? '';
  final name = file['name']?.toString() ?? 'File';
  if (url.isEmpty) return;

  if (file['kind'] == 'pdf') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionPdfViewerPage(url: url, title: name),
      ),
    );
    return;
  }

  // Phones can't render PPT natively, so Office's web viewer shows it in an
  // in-app browser tab.
  final viewer = Uri.parse(
    'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(url)}',
  );
  final opened = await launchUrl(viewer, mode: LaunchMode.inAppBrowserView);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open the file')));
  }
}

/// Downloads a PDF and shows it with pinch-to-zoom.
class SessionPdfViewerPage extends StatefulWidget {
  final String url;
  final String title;

  const SessionPdfViewerPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<SessionPdfViewerPage> createState() => _SessionPdfViewerPageState();
}

class _SessionPdfViewerPageState extends State<SessionPdfViewerPage> {
  late final PdfControllerPinch _controller = PdfControllerPinch(
    document: _download(),
  );

  Future<PdfDocument> _download() async {
    final res = await Dio().get<List<int>>(
      widget.url,
      options: Options(responseType: ResponseType.bytes),
    );
    return PdfDocument.openData(Uint8List.fromList(res.data ?? const []));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: PdfPageNumber(
                controller: _controller,
                builder: (_, state, page, pagesCount) => Text(
                  pagesCount == null ? '' : '$page / $pagesCount',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorBuilder: (_, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not open this PDF.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
