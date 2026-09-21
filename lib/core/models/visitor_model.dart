import 'package:equatable/equatable.dart';

import '../utils/mongo_id.dart';

enum VisitorType {
  guest,
  courierDelivery,
  cabDriver,
  gasDelivery,
  groceryShop,
  carpenter,
  beautician,
  repairMaintenance,
  pestControl,
  tutor,
  otherVendors,
  other,
}

/// Display labels for visitor type grid; order matches [VisitorType] excluding [VisitorType.other].
const List<String> visitorTypeDisplayNames = [
  'Guest',
  'Courier / Delivery',
  'Cab driver',
  'Gas delivery',
  'Grocery shop',
  'Carpenter',
  'Beautician',
  'Repair & maintenance',
  'Pest control',
  'Tutor',
  'Other vendors',
];

extension VisitorTypeX on VisitorType {
  String get displayName {
    const names = visitorTypeDisplayNames;
    final index = indexOf(this);
    if (index >= 0 && index < names.length) return names[index];
    return name;
  }

  static int indexOf(VisitorType type) {
    final list = VisitorType.values.where((e) => e != VisitorType.other).toList();
    final i = list.indexOf(type);
    return i >= 0 ? i : -1;
  }

  static VisitorType? fromDisplayName(String displayName) {
    final lower = displayName.trim().toLowerCase();
    final nonOther = VisitorType.values.where((e) => e != VisitorType.other).toList();
    for (int i = 0; i < visitorTypeDisplayNames.length; i++) {
      if (visitorTypeDisplayNames[i].toLowerCase() == lower) {
        return i < nonOther.length ? nonOther[i] : null;
      }
    }
    return null;
  }
}

/// Visitor approval: pending until resident/security approves; then allowed.
enum VisitorApprovalStatus {
  pending,
  approved,
  rejected,
}

enum VisitorVisitMode {
  scheduled,
  walkIn,
  monthlyPass,
}

enum VisitorVisitStatus {
  pendingApproval,
  approved,
  entered,
  exited,
  rejected,
  cancelled,
  expired,
}

enum VisitorCategory {
  relative,
  outsider,
}

enum RelativeType {
  father,
  mother,
  brother,
  sister,
  spouse,
  son,
  daughter,
  other,
}

class VisitorModel extends Equatable {
  final String id;
  final String name;
  final String mobileNumber;
  final String? image;
  final VisitorType type;
  final VisitorCategory category;
  final RelativeType? relativeType;
  final String? reasonForVisit;
  final String? vehicleNumber;
  final String block;
  final String homeNumber;
  final DateTime visitTime;
  final DateTime? scheduledFor;
  final DateTime? arrivedAt;
  final DateTime? approvedAt;
  final DateTime? enteredAt;
  final DateTime? exitedAt;
  final int? durationMinutes;
  final int? durationSeconds;
  final String? otp;
  final String? qrCode;
  final bool isRegistered;
  final VisitorApprovalStatus approvalStatus;
  final VisitorVisitMode visitMode;
  final VisitorVisitStatus visitStatus;
  final String? entryMethod;
  final String? securityNotes;
  final String? rejectionReason;
  final DateTime? overstayStartedAt;
  final DateTime? lastOverstayAlertAt;
  final int overstayAlertCount;
  final bool overstayAlertActive;
  final String? overstayCategory;
  /// Sub-label from type picker (e.g. Swiggy, Uber). Optional.
  final String? typeDetail;

  bool get isPendingApproval =>
      visitStatus == VisitorVisitStatus.pendingApproval && approvalStatus == VisitorApprovalStatus.pending;
  bool get isApprovedForGate =>
      !isInside &&
      !isCompleted &&
      (visitStatus == VisitorVisitStatus.approved || approvalStatus == VisitorApprovalStatus.approved);
  bool get isInside => visitStatus == VisitorVisitStatus.entered;
  bool get isCompleted => visitStatus == VisitorVisitStatus.exited;
  bool get isOverstayActive => overstayAlertActive;

  /// Returns exact formatted stay duration (e.g. "1h 12m 30s", "5m 20s", "45s")
  String? get formattedStayDuration {
    Duration? d;
    if (enteredAt != null && exitedAt != null) {
      d = exitedAt!.difference(enteredAt!);
    } else if (durationSeconds != null) {
      d = Duration(seconds: durationSeconds!);
    } else if (durationMinutes != null) {
      d = Duration(minutes: durationMinutes!);
    }
    if (d == null) return null;
    if (d.isNegative) d = Duration.zero;

    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    }
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }

  String get statusLabel {
    switch (visitStatus) {
      case VisitorVisitStatus.pendingApproval:
        return 'Pending approval';
      case VisitorVisitStatus.approved:
        return 'Approved';
      case VisitorVisitStatus.entered:
        return 'Inside';
      case VisitorVisitStatus.exited:
        return 'Exited';
      case VisitorVisitStatus.rejected:
        return 'Rejected';
      case VisitorVisitStatus.cancelled:
        return 'Cancelled';
      case VisitorVisitStatus.expired:
        return 'Expired';
    }
  }

  /// Primary type label plus optional sub-label for lists and badges.
  String get typeLabelLine {
    final base = type.displayName;
    if (typeDetail != null && typeDetail!.trim().isNotEmpty) {
      return '$base · ${typeDetail!.trim()}';
    }
    return base;
  }

  const VisitorModel({
    required this.id,
    required this.name,
    required this.mobileNumber,
    this.image,
    required this.type,
    required this.category,
    this.relativeType,
    this.reasonForVisit,
    this.vehicleNumber,
    required this.block,
    required this.homeNumber,
    required this.visitTime,
    this.scheduledFor,
    this.arrivedAt,
    this.approvedAt,
    this.enteredAt,
    this.exitedAt,
    this.durationMinutes,
    this.durationSeconds,
    this.otp,
    this.qrCode,
    this.isRegistered = false,
    this.approvalStatus = VisitorApprovalStatus.pending,
    this.visitMode = VisitorVisitMode.scheduled,
    this.visitStatus = VisitorVisitStatus.pendingApproval,
    this.entryMethod,
    this.securityNotes,
    this.rejectionReason,
    this.overstayStartedAt,
    this.lastOverstayAlertAt,
    this.overstayAlertCount = 0,
    this.overstayAlertActive = false,
    this.overstayCategory,
    this.typeDetail,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobileNumber': mobileNumber,
      'image': image,
      'type': type.name,
      'category': category.name,
      'relativeType': relativeType?.name,
      'reasonForVisit': reasonForVisit,
      'vehicleNumber': vehicleNumber,
      'block': block,
      'homeNumber': homeNumber,
      'visitTime': visitTime.toIso8601String(),
      'scheduledFor': scheduledFor?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'enteredAt': enteredAt?.toIso8601String(),
      'exitedAt': exitedAt?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,
      'otp': otp,
      'qrCode': qrCode,
      'isRegistered': isRegistered,
      'approvalStatus': approvalStatus.name,
      'visitMode': visitMode.name,
      'visitStatus': visitStatus.name,
      'entryMethod': entryMethod,
      'securityNotes': securityNotes,
      'rejectionReason': rejectionReason,
      'overstayStartedAt': overstayStartedAt?.toIso8601String(),
      'lastOverstayAlertAt': lastOverstayAlertAt?.toIso8601String(),
      'overstayAlertCount': overstayAlertCount,
      'overstayAlertActive': overstayAlertActive,
      'overstayCategory': overstayCategory,
      'typeDetail': typeDetail,
    };
  }

  static const Map<String, VisitorType> _legacyVisitorTypeNames = {
    'cabTaxi': VisitorType.cabDriver,
    'family': VisitorType.guest,
    'deliveryBoy': VisitorType.courierDelivery,
    'maid': VisitorType.otherVendors,
    'electrician': VisitorType.repairMaintenance,
    'plumber': VisitorType.repairMaintenance,
    'courier': VisitorType.courierDelivery,
    'maintenance': VisitorType.repairMaintenance,
    'officialVisitor': VisitorType.guest,
    'emergency': VisitorType.otherVendors,
    'delivery': VisitorType.courierDelivery,
    'cab': VisitorType.cabDriver,
    'tuitionTeacher': VisitorType.tutor,
  };

  static VisitorType _parseVisitorType(dynamic value) {
    if (value == null || value is! String) return VisitorType.other;
    final name = value.toString().trim();
    for (final e in VisitorType.values) {
      if (e.name == name) return e;
    }
    return _legacyVisitorTypeNames[name] ?? VisitorType.other;
  }

  /// Backend [serializeVisitor] emits ISO-8601 UTC strings; one conversion to local for UI.
  static DateTime parseApiInstantToLocal(dynamic value) {
    if (value == null) return DateTime.now();
    final raw = value.toString().trim();
    if (raw.isEmpty) return DateTime.now();
    return DateTime.parse(raw).toLocal();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  factory VisitorModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['_id'];
    final id = parseMongoId(idRaw);
    return VisitorModel(
      id: id,
      name: json['name'] as String,
      mobileNumber: json['mobileNumber'] as String,
      image: json['image'] as String?,
      type: _parseVisitorType(json['type']),
      category: json['category'] != null
          ? VisitorCategory.values.firstWhere(
              (e) => e.name == json['category'],
              orElse: () => VisitorCategory.outsider,
            )
          : VisitorCategory.outsider,
      relativeType: json['relativeType'] != null
          ? RelativeType.values.firstWhere(
              (e) => e.name == json['relativeType'],
              orElse: () => RelativeType.other,
            )
          : null,
      reasonForVisit: json['reasonForVisit'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      block: json['block'] as String,
      homeNumber: json['homeNumber'] as String,
      visitTime: parseApiInstantToLocal(json['visitTime']),
      scheduledFor: _parseDate(json['scheduledFor']),
      arrivedAt: _parseDate(json['arrivedAt']),
      approvedAt: _parseDate(json['approvedAt']),
      enteredAt: _parseDate(json['enteredAt']),
      exitedAt: _parseDate(json['exitedAt']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      otp: json['otp'] as String?,
      qrCode: json['qrCode'] as String?,
      isRegistered: json['isRegistered'] as bool? ?? false,
      approvalStatus: json['approvalStatus'] != null
          ? VisitorApprovalStatus.values.firstWhere(
              (e) => e.name == json['approvalStatus'],
              orElse: () => VisitorApprovalStatus.pending,
            )
          : VisitorApprovalStatus.pending,
      visitMode: json['visitMode'] != null
          ? VisitorVisitMode.values.firstWhere(
              (e) => e.name == json['visitMode'],
              orElse: () => VisitorVisitMode.scheduled,
            )
          : ((json['isRegistered'] as bool? ?? false)
                ? VisitorVisitMode.scheduled
                : VisitorVisitMode.walkIn),
      visitStatus: json['visitStatus'] != null
          ? VisitorVisitStatus.values.firstWhere(
              (e) => e.name == json['visitStatus'],
              orElse: () => VisitorVisitStatus.pendingApproval,
            )
          : ((json['approvalStatus'] == 'approved')
                ? VisitorVisitStatus.approved
                : (json['approvalStatus'] == 'rejected')
                    ? VisitorVisitStatus.rejected
                    : VisitorVisitStatus.pendingApproval),
      entryMethod: json['entryMethod'] as String?,
      securityNotes: json['securityNotes'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      overstayStartedAt: _parseDate(json['overstayStartedAt']),
      lastOverstayAlertAt: _parseDate(json['lastOverstayAlertAt']),
      overstayAlertCount: (json['overstayAlertCount'] as num?)?.toInt() ?? 0,
      overstayAlertActive: json['overstayAlertActive'] as bool? ?? false,
      overstayCategory: json['overstayCategory']?.toString(),
      typeDetail: json['typeDetail']?.toString(),
    );
  }

  VisitorModel copyWith({
    String? id,
    String? name,
    String? mobileNumber,
    String? image,
    VisitorType? type,
    VisitorCategory? category,
    RelativeType? relativeType,
    String? reasonForVisit,
    String? vehicleNumber,
    String? block,
    String? homeNumber,
    DateTime? visitTime,
    DateTime? scheduledFor,
    DateTime? arrivedAt,
    DateTime? approvedAt,
    DateTime? enteredAt,
    DateTime? exitedAt,
    String? otp,
    String? qrCode,
    bool? isRegistered,
    VisitorApprovalStatus? approvalStatus,
    VisitorVisitMode? visitMode,
    VisitorVisitStatus? visitStatus,
    String? entryMethod,
    String? securityNotes,
    String? rejectionReason,
    DateTime? overstayStartedAt,
    DateTime? lastOverstayAlertAt,
    int? overstayAlertCount,
    bool? overstayAlertActive,
    String? overstayCategory,
    String? typeDetail,
  }) {
    return VisitorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      image: image ?? this.image,
      type: type ?? this.type,
      category: category ?? this.category,
      relativeType: relativeType ?? this.relativeType,
      reasonForVisit: reasonForVisit ?? this.reasonForVisit,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      block: block ?? this.block,
      homeNumber: homeNumber ?? this.homeNumber,
      visitTime: visitTime ?? this.visitTime,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      enteredAt: enteredAt ?? this.enteredAt,
      exitedAt: exitedAt ?? this.exitedAt,
      otp: otp ?? this.otp,
      qrCode: qrCode ?? this.qrCode,
      isRegistered: isRegistered ?? this.isRegistered,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      visitMode: visitMode ?? this.visitMode,
      visitStatus: visitStatus ?? this.visitStatus,
      entryMethod: entryMethod ?? this.entryMethod,
      securityNotes: securityNotes ?? this.securityNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      overstayStartedAt: overstayStartedAt ?? this.overstayStartedAt,
      lastOverstayAlertAt: lastOverstayAlertAt ?? this.lastOverstayAlertAt,
      overstayAlertCount: overstayAlertCount ?? this.overstayAlertCount,
      overstayAlertActive: overstayAlertActive ?? this.overstayAlertActive,
      overstayCategory: overstayCategory ?? this.overstayCategory,
      typeDetail: typeDetail ?? this.typeDetail,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        mobileNumber,
        image,
        type,
        category,
        relativeType,
        reasonForVisit,
        vehicleNumber,
        block,
        homeNumber,
        visitTime,
        scheduledFor,
        arrivedAt,
        approvedAt,
        enteredAt,
        exitedAt,
        otp,
        qrCode,
        isRegistered,
        approvalStatus,
        visitMode,
        visitStatus,
        entryMethod,
        securityNotes,
        rejectionReason,
        overstayStartedAt,
        lastOverstayAlertAt,
        overstayAlertCount,
        overstayAlertActive,
        overstayCategory,
        typeDetail,
      ];
}

