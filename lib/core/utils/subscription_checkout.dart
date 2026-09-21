import '../config/api_config.dart';
import '../constants/app_constants.dart';

/// Razorpay subscription checkout helpers (typed options for MethodChannel).

/// Prefer [serverKeyId] from create-order; fall back to [ApiConfig.razorpayKey].
String resolveRazorpayCheckoutKey(String? serverKeyId) {
  final fromServer = serverKeyId?.trim() ?? '';
  if (fromServer.isNotEmpty) return fromServer;
  return ApiConfig.razorpayKey.trim();
}
int subscriptionAmountPaise(dynamic raw, double planAmountInr) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) return parsed;
  }
  return (planAmountInr * 100).round();
}

Map<String, Object> buildRazorpayCheckoutOptions({
  required String keyId,
  required int amountPaise,
  required String orderId,
  required String planName,
}) {
  return {
    'key': keyId,
    'amount': amountPaise,
    'currency': 'INR',
    'order_id': orderId,
    'name': AppConstants.appName,
    'description': planName,
  };
}
