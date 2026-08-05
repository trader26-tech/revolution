/// Domain models mirroring the backend phone-verification payloads.
library;

/// Response from POST /phone/verify/start — everything the app needs to launch
/// the WhatsApp verify step.
class VerificationStart {
  const VerificationStart({
    required this.id,
    required this.phone,
    required this.status,
    required this.whatsappUrl,
    required this.whatsappMessage,
    this.debugCode,
  });

  final String id;
  final String phone;
  final String status;

  /// wa.me deep link with the code pre-filled to our business number.
  final String whatsappUrl;

  /// The exact message body, so we can show/copy it if the deep link fails.
  final String whatsappMessage;

  /// Only present in dev (OTP_DEBUG_RETURN_CODE) — the raw code, for testing.
  final String? debugCode;

  factory VerificationStart.fromJson(Map<String, dynamic> json) =>
      VerificationStart(
        id: json['id'] as String,
        phone: json['phone'] as String,
        status: json['status'] as String,
        whatsappUrl: json['whatsapp_url'] as String,
        whatsappMessage: json['whatsapp_message'] as String,
        debugCode: json['debug_code'] as String?,
      );
}

/// Response from GET /phone/verify/{id} — polled until verified.
class VerificationState {
  const VerificationState({
    required this.id,
    required this.phone,
    required this.status,
    required this.verified,
  });

  final String id;
  final String phone;
  final String status; // 'pending' | 'verified' | 'expired'
  final bool verified;

  bool get isExpired => status == 'expired';

  factory VerificationState.fromJson(Map<String, dynamic> json) =>
      VerificationState(
        id: json['id'] as String,
        phone: json['phone'] as String,
        status: json['status'] as String,
        verified: json['verified'] as bool,
      );
}
