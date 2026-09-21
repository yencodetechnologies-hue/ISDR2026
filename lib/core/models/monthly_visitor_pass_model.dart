import 'package:equatable/equatable.dart';

import 'visitor_model.dart';

class MonthlyVisitorPassUsage extends Equatable {
  final String eventType;
  final DateTime eventAt;
  final String? securityId;
  final int? durationMinutes;

  const MonthlyVisitorPassUsage({
    required this.eventType,
    required this.eventAt,
    this.securityId,
    this.durationMinutes,
  });

  factory MonthlyVisitorPassUsage.fromJson(Map<String, dynamic> json) {
    return MonthlyVisitorPassUsage(
      eventType: (json['eventType'] as String? ?? 'entry').trim(),
      eventAt: DateTime.parse(json['eventAt'] as String).toLocal(),
      securityId: json['securityId']?.toString(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'eventAt': eventAt.toIso8601String(),
      'securityId': securityId,
      'durationMinutes': durationMinutes,
    };
  }

  @override
  List<Object?> get props => [eventType, eventAt, securityId, durationMinutes];
}

class MonthlyVisitorAttendanceSummary extends Equatable {
  final int totalEntries;
  final int totalExits;
  final int totalMinutesInside;
  final DateTime? lastEntryAt;
  final DateTime? lastExitAt;

  const MonthlyVisitorAttendanceSummary({
    this.totalEntries = 0,
    this.totalExits = 0,
    this.totalMinutesInside = 0,
    this.lastEntryAt,
    this.lastExitAt,
  });

  factory MonthlyVisitorAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return MonthlyVisitorAttendanceSummary(
      totalEntries: (json['totalEntries'] as num?)?.toInt() ?? 0,
      totalExits: (json['totalExits'] as num?)?.toInt() ?? 0,
      totalMinutesInside: (json['totalMinutesInside'] as num?)?.toInt() ?? 0,
      lastEntryAt: json['lastEntryAt'] != null ? DateTime.tryParse(json['lastEntryAt'].toString())?.toLocal() : null,
      lastExitAt: json['lastExitAt'] != null ? DateTime.tryParse(json['lastExitAt'].toString())?.toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalEntries': totalEntries,
        'totalExits': totalExits,
        'totalMinutesInside': totalMinutesInside,
        'lastEntryAt': lastEntryAt?.toIso8601String(),
        'lastExitAt': lastExitAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [totalEntries, totalExits, totalMinutesInside, lastEntryAt, lastExitAt];
}

/// Monthly reusable OTP pass for visitors (e.g., maid, electrician).
/// Gate verification accepts OTP when `effectiveEnabled == true`.
class MonthlyVisitorPassModel extends Equatable {
  final String id;
  final VisitorType visitorType;
  final String personName;
  final String mobileNumber;
  final String? otp; // Only returned to the user who has enabled it (enabledByMe).
  final DateTime validFrom;
  final DateTime validTo;

  final bool effectiveEnabled; // OR rule across owner + tenant.
  final bool enabledByMe; // Whether current user turned it ON.
  final String? reasonForPass;
  final List<MonthlyVisitorPassUsage> usageHistory;
  final bool isInside;
  final MonthlyVisitorAttendanceSummary attendanceSummary;
  final String? image;
  final String? category;

  const MonthlyVisitorPassModel({
    required this.id,
    required this.visitorType,
    required this.personName,
    required this.mobileNumber,
    this.otp,
    required this.validFrom,
    required this.validTo,
    required this.effectiveEnabled,
    required this.enabledByMe,
    this.reasonForPass,
    this.usageHistory = const [],
    this.isInside = false,
    this.attendanceSummary = const MonthlyVisitorAttendanceSummary(),
    this.image,
    this.category,
  });

  @override
  List<Object?> get props => [
        id,
        visitorType,
        personName,
        mobileNumber,
        otp,
        validFrom,
        validTo,
        effectiveEnabled,
        enabledByMe,
        reasonForPass,
        usageHistory,
        isInside,
        attendanceSummary,
        image,
        category,
      ];

  static VisitorType _parseVisitorType(String? value) {
    if (value == null) return VisitorType.other;
    final trimmed = value.trim();
    try {
      return VisitorType.values.firstWhere((e) => e.name == trimmed);
    } catch (_) {
      return VisitorType.other;
    }
  }

  factory MonthlyVisitorPassModel.fromJson(Map<String, dynamic> json) {
    return MonthlyVisitorPassModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      visitorType: _parseVisitorType(json['visitorType'] as String?),
      personName: json['personName'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      otp: json['otp'] as String?,
      validFrom: DateTime.parse(json['validFrom'] as String),
      validTo: DateTime.parse(json['validTo'] as String),
      effectiveEnabled: json['effectiveEnabled'] as bool? ?? false,
      enabledByMe: json['enabledByMe'] as bool? ?? false,
      reasonForPass: json['reasonForPass'] as String?,
      usageHistory: ((json['usageHistory'] as List<dynamic>?) ?? const [])
          .map((entry) => MonthlyVisitorPassUsage.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList(),
      isInside: json['isInside'] as bool? ?? false,
      attendanceSummary: json['attendanceSummary'] is Map
          ? MonthlyVisitorAttendanceSummary.fromJson(
              Map<String, dynamic>.from(json['attendanceSummary'] as Map),
            )
          : const MonthlyVisitorAttendanceSummary(),
      image: json['image'] as String?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitorType': visitorType.name,
      'personName': personName,
      'mobileNumber': mobileNumber,
      'otp': otp,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo.toIso8601String(),
      'effectiveEnabled': effectiveEnabled,
      'enabledByMe': enabledByMe,
      'reasonForPass': reasonForPass,
      'usageHistory': usageHistory.map((entry) => entry.toJson()).toList(),
      'isInside': isInside,
      'attendanceSummary': attendanceSummary.toJson(),
      'image': image,
      'category': category,
    };
  }
}

