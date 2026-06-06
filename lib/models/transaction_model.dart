enum TransactionType { send, pay, withdraw, topup }

class TransactionRecord {
  final String id;
  final TransactionType type;
  final double amount; // In user's local currency
  final String destination; // Account number or Merchant ID
  final String customerName;
  final String accountNumber;
  final String country;
  final String currency;
  final DateTime timestamp;
  final bool isOfflinePending;
  final String channel;
  bool isReversed;

  TransactionRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.destination,
    required this.customerName,
    required this.accountNumber,
    required this.country,
    required this.currency,
    required this.timestamp,
    this.isOfflinePending = false,
    this.channel = 'Online',
    this.isReversed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'destination': destination,
      'customerName': customerName,
      'accountNumber': accountNumber,
      'country': country,
      'currency': currency,
      'timestamp': timestamp.toIso8601String(),
      'isOfflinePending': isOfflinePending,
      'channel': channel,
      'isReversed': isReversed,
    };
  }

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String? ?? '',
      type: TransactionType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => TransactionType.send,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      destination: json['destination'] as String? ?? 'Unknown',
      customerName: json['customerName'] as String? ?? 'Unknown customer',
      accountNumber: json['accountNumber'] as String? ?? 'Unknown',
      country: json['country'] as String? ?? 'Unknown',
      currency: json['currency'] as String? ?? 'USD',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isOfflinePending: json['isOfflinePending'] as bool? ?? false,
      channel: json['channel'] as String? ?? 'Online',
      isReversed: json['isReversed'] as bool? ?? false,
    );
  }
}
