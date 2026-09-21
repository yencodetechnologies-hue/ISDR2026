import 'package:equatable/equatable.dart';

class PaymentLineItem extends Equatable {
  final String type;
  final double amount;

  const PaymentLineItem({required this.type, required this.amount});

  factory PaymentLineItem.fromJson(Map<String, dynamic> json) {
    return PaymentLineItem(
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'amount': amount};

  @override
  List<Object?> get props => [type, amount];
}

class PaymentModel extends Equatable {
  final String id;
  final String? userId;
  final String? userName;
  final String? userBlock;
  final String? userFloor;
  final String? userRoomNumber;
  final double amount;
  final List<PaymentLineItem> lineItems;
  final double totalAmount;
  final String month;
  final int year;
  final String status;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? transactionId;
  final String? notes;
  final String? proofImageUrl;
  final DateTime? proofUploadedAt;
  final DateTime? dueDate;
  final DateTime? reminderSentAt;
  final int overdueStage;

  const PaymentModel({
    required this.id,
    this.userId,
    this.userName,
    this.userBlock,
    this.userFloor,
    this.userRoomNumber,
    this.amount = 0,
    this.lineItems = const [],
    this.totalAmount = 0,
    required this.month,
    required this.year,
    this.status = 'pending',
    this.paymentDate,
    this.paymentMethod,
    this.transactionId,
    this.notes,
    this.proofImageUrl,
    this.proofUploadedAt,
    this.dueDate,
    this.reminderSentAt,
    this.overdueStage = 0,
  });

  double get displayAmount => totalAmount > 0 ? totalAmount : amount;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final uid = json['userId'];
    String? uidStr;
    String? uName;
    String? uBlock;
    String? uFloor;
    String? uRoom;
    if (uid is Map) {
      uidStr = uid['_id']?.toString() ?? uid['id']?.toString();
      uName = uid['name'] as String?;
      uBlock = uid['block']?.toString();
      uFloor = uid['floor']?.toString();
      uRoom = uid['roomNumber']?.toString();
    } else if (uid != null) {
      uidStr = uid.toString();
    }

    final rawId = json['_id'] ?? json['id'];
    final id = rawId?.toString() ?? '';

    final lineItemsList = json['lineItems'] as List?;
    final items = lineItemsList != null
        ? lineItemsList
            .map((e) => PaymentLineItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PaymentLineItem>[];

    final amt = (json['amount'] as num?)?.toDouble();
    final total = (json['totalAmount'] as num?)?.toDouble();
    final tot = total ?? amt ?? 0.0;

    return PaymentModel(
      id: id,
      userId: uidStr,
      userName: uName,
      userBlock: uBlock,
      userFloor: uFloor,
      userRoomNumber: uRoom,
      amount: amt ?? 0,
      lineItems: items,
      totalAmount: tot,
      month: json['month']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'].toString())
          : null,
      paymentMethod: json['paymentMethod'] as String?,
      transactionId: json['transactionId'] as String?,
      notes: json['notes'] as String?,
      proofImageUrl: json['proofImageUrl'] as String?,
      proofUploadedAt: json['proofUploadedAt'] != null
          ? DateTime.tryParse(json['proofUploadedAt'].toString())
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString())
          : null,
      reminderSentAt: json['reminderSentAt'] != null
          ? DateTime.tryParse(json['reminderSentAt'].toString())
          : null,
      overdueStage: (json['overdueStage'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'lineItems': lineItems.map((e) => e.toJson()).toList(),
      'totalAmount': totalAmount,
      'month': month,
      'year': year,
      'status': status,
      'paymentDate': paymentDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'notes': notes,
      'dueDate': dueDate?.toIso8601String(),
      'reminderSentAt': reminderSentAt?.toIso8601String(),
      'overdueStage': overdueStage,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        amount,
        lineItems,
        totalAmount,
        month,
        year,
        status,
        paymentDate,
        dueDate,
        reminderSentAt,
        overdueStage,
      ];
}
