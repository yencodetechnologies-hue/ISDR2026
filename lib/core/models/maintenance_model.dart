class MaintenanceModel {
  final String id;
  final double amount;
  final String month;
  final int year;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceModel({
    required this.id,
    required this.amount,
    required this.month,
    required this.year,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceModel(
      id: json['_id'] ?? json['id'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      month: json['month'] ?? '',
      year: json['year'] ?? 0,
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'amount': amount,
      'month': month,
      'year': year,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

