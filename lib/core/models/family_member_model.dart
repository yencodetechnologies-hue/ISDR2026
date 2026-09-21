import 'package:equatable/equatable.dart';

class FamilyMemberModel extends Equatable {
  final String id;
  final String name;
  final String relationType;
  final DateTime? dateOfBirth;
  final String? profileImageUrl;

  const FamilyMemberModel({
    required this.id,
    required this.name,
    required this.relationType,
    this.dateOfBirth,
    this.profileImageUrl,
  });

  String get displayRelation {
    switch (relationType) {
      case 'spouse':
        return 'Spouse';
      case 'child':
        return 'Child';
      case 'parent':
        return 'Parent';
      case 'sibling':
        return 'Sibling';
      case 'grandparent':
        return 'Grandparent';
      default:
        return 'Other';
    }
  }

  String? get formattedDateOfBirth {
    if (dateOfBirth == null) return null;
    final d = dateOfBirth!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    DateTime? dob;
    if (json['dateOfBirth'] != null) {
      if (json['dateOfBirth'] is String) {
        dob = DateTime.tryParse(json['dateOfBirth'] as String);
      } else if (json['dateOfBirth'] is Map && json['dateOfBirth']['\$date'] != null) {
        dob = DateTime.tryParse(json['dateOfBirth']['\$date'].toString());
      }
    }
    return FamilyMemberModel(
      id: id,
      name: json['name'] as String? ?? '',
      relationType: json['relationType'] as String? ?? 'other',
      dateOfBirth: dob,
      profileImageUrl: json['profileImage'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, relationType, dateOfBirth, profileImageUrl];
}
