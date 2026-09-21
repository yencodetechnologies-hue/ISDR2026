import 'package:equatable/equatable.dart';

class KidExitModel extends Equatable {
  final String id;
  final String kidName;
  final String? familyMemberId;
  final String block;
  final String homeNumber;
  final DateTime exitTime;
  final String? note;
  final DateTime? acknowledgedAt;
  final String? reporterName;
  final String? reporterMobile;

  const KidExitModel({
    required this.id,
    required this.kidName,
    this.familyMemberId,
    required this.block,
    required this.homeNumber,
    required this.exitTime,
    this.note,
    this.acknowledgedAt,
    this.reporterName,
    this.reporterMobile,
  });

  bool get isAcknowledged => acknowledgedAt != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kidName': kidName,
      'familyMemberId': familyMemberId,
      'block': block,
      'homeNumber': homeNumber,
      'exitTime': exitTime.toIso8601String(),
      'note': note,
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'reporterName': reporterName,
      'reporterMobile': reporterMobile,
    };
  }

  factory KidExitModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final reportedBy = json['reportedBy'];
    String? reporterName;
    String? reporterMobile;
    if (reportedBy is Map) {
      reporterName = reportedBy['name'] as String?;
      reporterMobile = reportedBy['mobileNumber'] as String?;
    }
    return KidExitModel(
      id: id,
      kidName: json['kidName'] as String? ?? '',
      familyMemberId: json['familyMemberId']?.toString(),
      block: json['block'] as String? ?? '',
      homeNumber: json['homeNumber'] as String? ?? '',
      exitTime: json['exitTime'] != null
          ? (DateTime.tryParse(json['exitTime'].toString()) ?? DateTime.now()).toLocal()
          : DateTime.now(),
      note: json['note'] as String?,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())?.toLocal()
          : null,
      reporterName: reporterName,
      reporterMobile: reporterMobile,
    );
  }

  KidExitModel copyWith({
    String? id,
    String? kidName,
    String? familyMemberId,
    String? block,
    String? homeNumber,
    DateTime? exitTime,
    String? note,
    DateTime? acknowledgedAt,
    String? reporterName,
    String? reporterMobile,
  }) {
    return KidExitModel(
      id: id ?? this.id,
      kidName: kidName ?? this.kidName,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      block: block ?? this.block,
      homeNumber: homeNumber ?? this.homeNumber,
      exitTime: exitTime ?? this.exitTime,
      note: note ?? this.note,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      reporterName: reporterName ?? this.reporterName,
      reporterMobile: reporterMobile ?? this.reporterMobile,
    );
  }

  @override
  List<Object?> get props => [
        id,
        kidName,
        familyMemberId,
        block,
        homeNumber,
        exitTime,
        note,
        acknowledgedAt,
        reporterName,
        reporterMobile,
      ];
}
