import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/models/apartment_model.dart';
import '../../../../core/utils/unit_labels.dart';

class PropertyVacancyStatCard extends StatelessWidget {
  static const double cardHeight = 132;

  final int vacantCount;
  final int totalRooms;
  final PropertyType? propertyType;
  final VoidCallback? onTap;

  const PropertyVacancyStatCard({
    super.key,
    required this.vacantCount,
    required this.totalRooms,
    this.propertyType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0D9488);
    final isApartment = usesHouseNoLabel(propertyType);

    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.80),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.08),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isApartment
                                  ? Icons.home_outlined
                                  : Icons.meeting_room_outlined,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Vacancies',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '$vacantCount',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vacantOfTotalPhrase(
                          vacantCount,
                          totalRooms,
                          propertyType,
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      cardContent = GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return SizedBox(
      height: cardHeight,
      width: double.infinity,
      child: cardContent,
    );
  }
}

