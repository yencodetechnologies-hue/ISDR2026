import 'package:equatable/equatable.dart';

class EventModel extends Equatable {
  final String id;
  final String title;
  final String? subtitle;
  final String content;
  final DateTime eventDate;
  final DateTime createdAt;
  final String? createdByName;

  const EventModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.content,
    required this.eventDate,
    required this.createdAt,
    this.createdByName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'content': content,
      'eventDate': eventDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'createdByName': createdByName,
    };
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      content: json['content'] as String,
      eventDate: json['eventDate'] != null
          ? DateTime.parse(json['eventDate'] as String).toLocal()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
      createdByName: json['createdBy'] != null && json['createdBy'] is Map
          ? json['createdBy']['name'] as String?
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        content,
        eventDate,
        createdAt,
        createdByName,
      ];
}

