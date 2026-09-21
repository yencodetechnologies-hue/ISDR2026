import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfx/pdfx.dart';
import '../../../../core/app_theme.dart';

/// Shows the ISDR 36th International Conference brochure (bundled PDF).
class BrochurePage extends StatefulWidget {
  const BrochurePage({super.key});

  static const String _assetPath =
      'assets/ISDR 36th international conference brochure_compressed.pdf';

  @override
  State<BrochurePage> createState() => _BrochurePageState();
}

class _BrochurePageState extends State<BrochurePage> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    // Load the bytes through Flutter's asset loader (handles the spaces in the file name),
    // then hand them to the PDF renderer.
    _controller = PdfControllerPinch(
      document: rootBundle
          .load(BrochurePage._assetPath)
          .then((data) => PdfDocument.openData(data.buffer.asUint8List())),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          'Brochure',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: PdfPageNumber(
                controller: _controller,
                builder: (context, loadingState, page, pagesCount) => Text(
                  '$page / ${pagesCount ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        scrollDirection: Axis.vertical,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not open the brochure.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
