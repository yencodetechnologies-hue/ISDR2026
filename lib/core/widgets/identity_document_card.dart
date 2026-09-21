import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// ISO/IEC 7810 ID-1 aspect ratio (credit card / government ID).
const double kIdentityCardAspectRatio = 1.586;

enum IdentityDocumentSide { front, back }

/// Attractive preview for a single identity document image.
class IdentityDocumentCard extends StatelessWidget {
  final IdentityDocumentSide side;
  final String label;
  final String? imageUrl;
  final File? imageFile;
  final VoidCallback? onTap;

  const IdentityDocumentCard({
    super.key,
    required this.side,
    required this.label,
    this.imageUrl,
    this.imageFile,
    this.onTap,
  });

  bool get _hasImage =>
      imageFile != null || (imageUrl != null && imageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final isFront = side == IdentityDocumentSide.front;
    final accent = isFront ? AppTheme.primaryColor : AppTheme.secondaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _hasImage
            ? (onTap ?? () => showIdentityDocumentFullscreen(
                  context,
                  label: label,
                  imageUrl: imageUrl,
                  imageFile: imageFile,
                ))
            : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withAlpha(55),
                accent.withAlpha(20),
                AppTheme.accentColor.withAlpha(18),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.5),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              accent.withAlpha(200),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(50),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFront
                                  ? Icons.badge_outlined
                                  : Icons.flip_to_back_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isFront ? 'FRONT' : 'BACK',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_hasImage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: AspectRatio(
                    aspectRatio: kIdentityCardAspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _hasImage
                          ? _DocumentImage(
                              imageUrl: imageUrl,
                              imageFile: imageFile,
                            )
                          : _EmptyDocumentPlaceholder(
                              accent: accent,
                              isFront: isFront,
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor.withAlpha(170),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Side-by-side or stacked layout for ID front + back.
class IdentityDocumentPair extends StatelessWidget {
  final String? frontImageUrl;
  final String? backImageUrl;
  final File? frontImageFile;
  final File? backImageFile;
  final VoidCallback? onFrontTap;
  final VoidCallback? onBackTap;
  final String frontLabel;
  final String backLabel;

  const IdentityDocumentPair({
    super.key,
    this.frontImageUrl,
    this.backImageUrl,
    this.frontImageFile,
    this.backImageFile,
    this.onFrontTap,
    this.onBackTap,
    this.frontLabel = 'Identity card — front',
    this.backLabel = 'Identity card — back',
  });

  bool get _hasFront =>
      frontImageFile != null ||
      (frontImageUrl != null && frontImageUrl!.isNotEmpty);

  bool get _hasBack =>
      backImageFile != null ||
      (backImageUrl != null && backImageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasFront || onFrontTap != null)
          IdentityDocumentCard(
            side: IdentityDocumentSide.front,
            label: frontLabel,
            imageUrl: frontImageUrl,
            imageFile: frontImageFile,
            onTap: onFrontTap,
          ),
        if ((_hasFront || onFrontTap != null) &&
            (_hasBack || onBackTap != null))
          const SizedBox(height: 12),
        if (_hasBack || onBackTap != null)
          IdentityDocumentCard(
            side: IdentityDocumentSide.back,
            label: backLabel,
            imageUrl: backImageUrl,
            imageFile: backImageFile,
            onTap: onBackTap,
          ),
      ],
    );
  }
}

/// Upload slot styled like an identity card.
class IdentityDocumentUploadSlot extends StatelessWidget {
  final IdentityDocumentSide side;
  final String label;
  final File? imageFile;
  final String? existingUrl;
  final VoidCallback onTap;

  const IdentityDocumentUploadSlot({
    super.key,
    required this.side,
    required this.label,
    this.imageFile,
    this.existingUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IdentityDocumentCard(
      side: side,
      label: label,
      imageUrl: existingUrl,
      imageFile: imageFile,
      onTap: onTap,
    );
  }
}

class _DocumentImage extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;

  const _DocumentImage({this.imageUrl, this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.backgroundColor,
                Colors.grey.shade100,
              ],
            ),
          ),
        ),
        if (imageFile != null)
          Image.file(
            imageFile!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          )
        else if (imageUrl != null && imageUrl!.isNotEmpty)
          Image.network(
            imageUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.primaryColor,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => const _ImageErrorState(),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withAlpha(140),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withAlpha(80),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyDocumentPlaceholder extends StatelessWidget {
  final Color accent;
  final bool isFront;

  const _EmptyDocumentPlaceholder({
    required this.accent,
    required this.isFront,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withAlpha(60),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withAlpha(35),
                  accent.withAlpha(15),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withAlpha(50)),
            ),
            child: Icon(
              isFront ? Icons.add_a_photo_outlined : Icons.flip_camera_ios_outlined,
              color: accent,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to upload',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFront ? 'Front side' : 'Back side',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textColor.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageErrorState extends StatelessWidget {
  const _ImageErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.grey[500], size: 32),
          const SizedBox(height: 6),
          Text(
            'Failed to load',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}

void showIdentityDocumentFullscreen(
  BuildContext context, {
  required String label,
  String? imageUrl,
  File? imageFile,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: label,
    barrierColor: Colors.black.withAlpha(220),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _FullscreenDocumentViewer(
        label: label,
        imageUrl: imageUrl,
        imageFile: imageFile,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _FullscreenDocumentViewer extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final File? imageFile;

  const _FullscreenDocumentViewer({
    required this.label,
    this.imageUrl,
    this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(25),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: imageFile != null
                          ? Image.file(imageFile!, fit: BoxFit.contain)
                          : Image.network(
                              imageUrl ?? '',
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  const _ImageErrorState(),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Pinch to zoom',
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
