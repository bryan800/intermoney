enum SmsTransactionKind { send, withdrawal }

enum SmsDeliveryStatus { queued, sent }

class SmsReceipt {
  const SmsReceipt({
    required this.toNumber,
    required this.message,
    required this.status,
    required this.reference,
  });

  final String toNumber;
  final String message;
  final SmsDeliveryStatus status;
  final String reference;
}

class SmsNotificationService {
  static const String appId = 'INTERFLEX';
  static const String settlementNumber = 'INTERFLEX-SIM-NETWORK';

  static List<SmsReceipt> sentMoneySms({
    required String senderNumber,
    required String receiverNumber,
    required String amount,
    required String senderAppId,
    bool isOffline = false,
    String? country,
  }) {
    final reference = _referenceFor(SmsTransactionKind.send);
    final status =
        isOffline ? SmsDeliveryStatus.queued : SmsDeliveryStatus.sent;
    final route = isOffline ? 'Offline SIM' : 'INTERFLEX';
    final location = country == null ? '' : ' Country: $country.';

    return [
      SmsReceipt(
        toNumber: senderNumber,
        status: status,
        reference: reference,
        message:
            '$route: Send request for $amount to $receiverNumber is ${isOffline ? 'queued for mobile-network settlement' : 'complete'}. Ref: $reference. App ID: $senderAppId.$location',
      ),
      SmsReceipt(
        toNumber: receiverNumber,
        status: status,
        reference: reference,
        message:
            '$route: $amount from $senderNumber is ${isOffline ? 'pending SIM settlement' : 'available'}. Ref: $reference. Sender App ID: $senderAppId. App ID: $appId.',
      ),
      if (isOffline)
        SmsReceipt(
          toNumber: settlementNumber,
          status: SmsDeliveryStatus.queued,
          reference: reference,
          message:
              'INTERFLEX SETTLEMENT: Queue offline SIM transfer $reference. Debit $senderNumber, credit $receiverNumber, amount $amount.$location',
        ),
    ];
  }

  static List<SmsReceipt> withdrawnMoneySms({
    required String senderNumber,
    required String receiverNumber,
    required String amount,
    required String senderAppId,
    bool isOffline = false,
    String? country,
  }) {
    final reference = _referenceFor(SmsTransactionKind.withdrawal);
    final status =
        isOffline ? SmsDeliveryStatus.queued : SmsDeliveryStatus.sent;
    final route = isOffline ? 'Offline SIM' : 'INTERFLEX';
    final location = country == null ? '' : ' Country: $country.';

    return [
      SmsReceipt(
        toNumber: senderNumber,
        status: status,
        reference: reference,
        message:
            '$route: Withdrawal of $amount to $receiverNumber is ${isOffline ? 'queued for SIM/mobile-money payout' : 'being processed'}. Ref: $reference. App ID: $senderAppId.$location',
      ),
      SmsReceipt(
        toNumber: receiverNumber,
        status: status,
        reference: reference,
        message:
            '$route: $amount payout from $senderNumber is ${isOffline ? 'pending mobile-network settlement' : 'being delivered'}. Ref: $reference. Sender App ID: $senderAppId. App ID: $appId.',
      ),
      if (isOffline)
        SmsReceipt(
          toNumber: settlementNumber,
          status: SmsDeliveryStatus.queued,
          reference: reference,
          message:
              'INTERFLEX SETTLEMENT: Queue offline SIM withdrawal $reference. Debit wallet $senderNumber, payout $receiverNumber, amount $amount.$location',
        ),
    ];
  }

  static String _referenceFor(SmsTransactionKind kind) {
    final prefix = kind == SmsTransactionKind.send ? 'SEND' : 'WDL';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$timestamp';
  }
}
