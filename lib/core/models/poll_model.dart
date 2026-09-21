import 'package:equatable/equatable.dart';

class PollModel extends Equatable {
  final String id;
  final String question;
  final List<String> options;
  final String? block;
  final String? floor;
  final String? roomNumber;
  final String createdById;
  final String? createdByName;
  final String? createdByProfilePic;
  final DateTime createdAt;
  /// Vote counts per option (same length as options). Empty if not from API.
  final List<int> optionVoteCounts;
  /// Current user's voted option index, or null if not voted.
  final int? myVoteOptionIndex;

  const PollModel({
    required this.id,
    required this.question,
    required this.options,
    this.block,
    this.floor,
    this.roomNumber,
    required this.createdById,
    this.createdByName,
    this.createdByProfilePic,
    required this.createdAt,
    this.optionVoteCounts = const [],
    this.myVoteOptionIndex,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    String? name;
    String? profilePic;
    String createdById = '';
    if (createdBy != null && createdBy is Map) {
      name = createdBy['name'] as String?;
      profilePic = createdBy['profilePic'] as String?;
      createdById = createdBy['_id']?.toString() ?? createdBy['id']?.toString() ?? '';
    }
    final opts = json['options'];
    List<String> optionsList = [];
    if (opts is List) {
      optionsList = opts.map((e) => e.toString()).toList();
    }
    List<int> optionVoteCounts = [];
    if (json['optionVoteCounts'] is List) {
      optionVoteCounts = (json['optionVoteCounts'] as List)
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    }
    int? myVoteOptionIndex;
    if (json['myVoteOptionIndex'] != null) {
      final v = json['myVoteOptionIndex'];
      myVoteOptionIndex = v is int ? v : int.tryParse(v.toString());
    }
    return PollModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      question: json['question'] as String? ?? '',
      options: optionsList,
      block: json['block'] as String?,
      floor: json['floor'] as String?,
      roomNumber: json['roomNumber'] as String?,
      createdById: createdById,
      createdByName: name,
      createdByProfilePic: profilePic,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      optionVoteCounts: optionVoteCounts,
      myVoteOptionIndex: myVoteOptionIndex,
    );
  }

  int get totalVotes =>
      optionVoteCounts.isEmpty ? 0 : optionVoteCounts.reduce((a, b) => a + b);

  @override
  List<Object?> get props => [
        id,
        question,
        options,
        block,
        floor,
        roomNumber,
        createdById,
        createdByName,
        createdAt,
        optionVoteCounts,
        myVoteOptionIndex,
      ];
}
