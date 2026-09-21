import 'package:equatable/equatable.dart';

class SubscriptionPlanModel extends Equatable {
  final String id;
  final String name;
  final int daysValidity;
  final double amount;
  final String description;
  final bool isActive;
  final String? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.daysValidity,
    required this.amount,
    this.description = '',
    this.isActive = true,
    this.color,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final amount = json['amount'];
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        createdAt = DateTime.tryParse(json['createdAt'] as String);
      } else if (json['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int);
      }
    }
    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(json['updatedAt'] as String);
      } else if (json['updatedAt'] is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int);
      }
    }
    return SubscriptionPlanModel(
      id: id,
      name: json['name'] as String? ?? '',
      daysValidity: (json['daysValidity'] is int)
          ? json['daysValidity'] as int
          : (json['daysValidity'] as num?)?.toInt() ?? 0,
      amount: amount is int ? amount.toDouble() : (amount as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      color: json['color'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, daysValidity, amount, description, isActive, color, createdAt, updatedAt];
}
