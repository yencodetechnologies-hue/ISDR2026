class SubscriptionPurchaseModel {
  final String id;
  final String apartmentId;
  final String planName;
  final String planDescription;
  final int daysValidity;
  final double amountInr;
  final String currency;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String razorpayPaymentId;
  final DateTime? createdAt;

  const SubscriptionPurchaseModel({
    required this.id,
    required this.apartmentId,
    required this.planName,
    required this.planDescription,
    required this.daysValidity,
    required this.amountInr,
    required this.currency,
    this.periodStart,
    this.periodEnd,
    required this.razorpayPaymentId,
    this.createdAt,
  });

  factory SubscriptionPurchaseModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'])?.toString() ?? '';
    return SubscriptionPurchaseModel(
      id: id,
      apartmentId: json['apartmentId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? '',
      planDescription: json['planDescription']?.toString() ?? '',
      daysValidity: (json['daysValidity'] as num?)?.toInt() ?? 0,
      amountInr: (json['amountInr'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      periodStart: json['periodStart'] != null
          ? DateTime.tryParse(json['periodStart'].toString())
          : null,
      periodEnd: json['periodEnd'] != null
          ? DateTime.tryParse(json['periodEnd'].toString())
          : null,
      razorpayPaymentId: json['razorpayPaymentId']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
