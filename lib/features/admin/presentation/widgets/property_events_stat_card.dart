import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

class PropertyEventsStatCard extends StatelessWidget {
  static const double cardHeight = 132;

  final int eventCount;
  final VoidCallback? onTap;

  const PropertyEventsStatCard({
    super.key,
    required this.eventCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFDB2777);

    Widget cardContent = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            color: color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Total Events',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor.withOpacity(0.75),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$eventCount',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 26,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          eventCount == 1 ? 'managed event' : 'managed events',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textColor.withOpacity(0.5),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return SizedBox(
      height: cardHeight,
      width: double.infinity,
      child: cardContent,
    );
  }
}
